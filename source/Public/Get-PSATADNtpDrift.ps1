function Get-PSATADNtpDrift
{
    <#
    .SYNOPSIS
        Measures the NTP time drift of computers against the PDC Emulator.

    .DESCRIPTION
        For each target machine the function runs w32tm /stripchart remotely via
        WinRM, measuring the time offset of that machine against the PDC Emulator
        (or the server specified by -Reference).

        When no ComputerName is provided all Domain Controllers are discovered
        automatically. The PDC Emulator itself is excluded from the list because
        its drift against itself is always zero.

        Each result is a [PSATNtpDrift] object with the drift in milliseconds, an
        absolute value, a status level (OK / WARNING / CRITICAL / ERROR) and a
        sync direction (Ahead / Behind / Unreachable).

    .PARAMETER ComputerName
        One or more computer names or FQDNs to measure. Accepts pipeline input.
        When omitted all Domain Controllers are targeted automatically.

    .PARAMETER ADServer
        The Domain Controller used to discover the list of DCs when ComputerName is
        not provided. Defaults to the PDC Emulator of the current domain.

    .PARAMETER Reference
        The NTP reference server to measure drift against.
        Defaults to the PDC Emulator of the current domain.

    .PARAMETER WarnThresholdMs
        Drift threshold in milliseconds above which status becomes WARNING.
        Default: 500 ms.

    .PARAMETER ErrorThresholdMs
        Drift threshold in milliseconds above which status becomes CRITICAL.
        Default: 2000 ms.

    .PARAMETER Credential
        Credentials for remote WinRM connections via Invoke-Command.

    .EXAMPLE
        Get-PSATADNtpDrift | Sort-Object AbsDriftMs -Descending | Format-Table -AutoSize

        Measures drift on all DCs and sorts by largest drift first.

    .EXAMPLE
        Get-PSATADNtpDrift -ComputerName 'SRV01' | Export-Csv -Path 'DriftReport.csv' -NoTypeInformation

        Measures drift on a specific server and exports the result to CSV.

    .EXAMPLE
        Get-PSATADNtpDrift -WarnThresholdMs 200 -ErrorThresholdMs 1000

        Uses custom thresholds for the status classification.

    .EXAMPLE
        Get-PSATADNtpDrift | Where-Object { $_.IsCritical() }

        Returns only machines with critical drift.

    .OUTPUTS
        PSATNtpDrift
    #>
    [CmdletBinding()]
    [OutputType([PSATNtpDrift])]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ComputerName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ADServer,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Reference,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $WarnThresholdMs = 500,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ErrorThresholdMs = 2000,

        [Parameter()]
        [System.Management.Automation.PSCredential] $Credential
    )

    BEGIN
    {
        Write-Verbose "Starting $($MyInvocation.MyCommand.Name)"

        try
        {
            $domain = Get-ADDomain -ErrorAction Stop
        }
        catch
        {
            Write-Error "Failed to contact Active Directory: $($_.Exception.Message)"
            return
        }

        if (-not $PSBoundParameters.ContainsKey('ADServer'))
        {
            $ADServer = $domain.PDCEmulator
            Write-Verbose "ADServer resolved to '$ADServer'"
        }

        if (-not $PSBoundParameters.ContainsKey('Reference'))
        {
            $Reference = $domain.PDCEmulator
            Write-Verbose "Reference NTP server resolved to '$Reference'"
        }

        # Script block executed on each remote machine.
        # Returns the raw offset in seconds as a double, or $null on failure.
        $script:driftScriptBlock = {
            param ([string] $ReferenceFqdn)

            try
            {
                $output = w32tm /stripchart /computer:$ReferenceFqdn /samples:1 /dataonly 2>&1
                $sample = [string]($output | Select-Object -Last 1)

                if ($sample -match 'error')
                {
                    throw "w32tm returned an error: $sample"
                }

                $parts = $sample -split ','
                if ($parts.Count -lt 2)
                {
                    throw "Unexpected w32tm output format: '$sample'"
                }

                $rawOffset = $parts[1].Trim().TrimEnd('s').Trim()
                [double] $rawOffset
            }
            catch
            {
                $null
            }
        }
    }

    PROCESS
    {
        $targetList = [System.Collections.Generic.List[string]]::new()

        if ($PSBoundParameters.ContainsKey('ComputerName'))
        {
            foreach ($name in $ComputerName)
            {
                $targetList.Add($name)
            }
            Write-Verbose "Targeting $($targetList.Count) specified computer(s)"
        }
        else
        {
            Write-Verbose "Discovering Domain Controllers via '$ADServer'"
            try
            {
                $adParams = @{
                    Filter      = '*'
                    Server      = $ADServer
                    ErrorAction = 'Stop'
                }
                if ($PSBoundParameters.ContainsKey('Credential'))
                {
                    $adParams['Credential'] = $Credential
                }
                $dcs = Get-ADDomainController @adParams |
                    Select-Object -ExpandProperty HostName

                # Exclude the reference server — its drift against itself is always zero.
                $referenceName = $Reference.Split('.')[0].ToUpper()
                foreach ($dc in $dcs)
                {
                    if ($dc.Split('.')[0].ToUpper() -ne $referenceName)
                    {
                        $targetList.Add($dc)
                    }
                }
                Write-Verbose "Found $($targetList.Count) Domain Controller(s) to measure (excluding reference)"
            }
            catch
            {
                Write-Error "Failed to retrieve Domain Controllers from '$ADServer': $($_.Exception.Message)"
                return
            }
        }

        if ($targetList.Count -eq 0)
        {
            Write-Warning "Target list is empty — no computers to measure."
            return
        }

        foreach ($target in $targetList)
        {
            Write-Verbose "Measuring NTP drift on '$target' against '$Reference'"

            try
            {
                $invokeParams = @{
                    ComputerName = $target
                    ScriptBlock  = $script:driftScriptBlock
                    ArgumentList = @($Reference)
                    ErrorAction  = 'Stop'
                }
                if ($PSBoundParameters.ContainsKey('Credential'))
                {
                    $invokeParams['Credential'] = $Credential
                }
                $rawOffsetSeconds = Invoke-Command @invokeParams
            }
            catch
            {
                Write-Warning "Failed to connect to '$target': $($_.Exception.Message)"
                $rawOffsetSeconds = $null
            }

            if ($null -eq $rawOffsetSeconds)
            {
                [PSATNtpDrift]::new([PSCustomObject]@{
                    ComputerName = $target
                    Reference    = $Reference
                    DriftMs      = $null
                    AbsDriftMs   = $null
                    Status       = 'ERROR'
                    SyncMode     = 'Unreachable'
                    Timestamp    = Get-Date
                })
                continue
            }

            $driftMs    = [Math]::Round($rawOffsetSeconds * 1000, 2)
            $absDriftMs = [Math]::Abs($driftMs)

            $status = 'OK'
            if ($absDriftMs -gt $ErrorThresholdMs)
            {
                $status = 'CRITICAL'
            }
            elseif ($absDriftMs -gt $WarnThresholdMs)
            {
                $status = 'WARNING'
            }

            $syncMode = if ($driftMs -ge 0) { 'Ahead' } else { 'Behind' }

            [PSATNtpDrift]::new([PSCustomObject]@{
                ComputerName = $target
                Reference    = $Reference
                DriftMs      = $driftMs
                AbsDriftMs   = $absDriftMs
                Status       = $status
                SyncMode     = $syncMode
                Timestamp    = Get-Date
            })
        }
    }

    END
    {
        Write-Verbose "Ending $($MyInvocation.MyCommand.Name)"
    }
}
