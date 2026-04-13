function Get-PSATADNTPConfiguration
{
    <#
    .SYNOPSIS
        Retrieves the NTP configuration from one or more computers.

    .DESCRIPTION
        Queries the W32Time service and registry on each target machine via WinRM.
        When no ComputerName is specified the function automatically discovers all
        Domain Controllers in the domain using the PDC Emulator (or the server
        specified by -ADServer) and targets them.

        Each result is returned as a [PSATNtpConfiguration] object containing the
        active NTP source, the configured synchronisation type, the W32Time service
        status, and whether the machine is a Domain Controller.

    .PARAMETER ComputerName
        One or more computer names or FQDNs to query. Accepts pipeline input.
        When omitted all Domain Controllers discovered via AD are targeted.

    .PARAMETER ADServer
        The Domain Controller used to query the list of DCs when ComputerName is
        not provided. Defaults to the PDC Emulator of the current domain.

    .PARAMETER Credential
        Credentials for remote WinRM connections via Invoke-Command.

    .EXAMPLE
        Get-PSATADNTPConfiguration | Format-Table -AutoSize

        Queries all Domain Controllers in the current domain and displays results.

    .EXAMPLE
        Get-PSATADNTPConfiguration -ComputerName 'SRV01', 'SRV02'

        Queries two specific servers.

    .EXAMPLE
        Get-PSATADNTPConfiguration -ComputerName 'SRV01' -Credential (Get-Credential)

        Queries a specific server with explicit credentials.

    .EXAMPLE
        Get-PSATADNTPConfiguration | Where-Object { -not $_.IsServiceRunning() }

        Returns all machines where W32Time is not running.

    .OUTPUTS
        PSATNtpConfiguration
    #>
    [CmdletBinding()]
    [OutputType([PSATNtpConfiguration])]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ComputerName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ADServer,

        [Parameter()]
        [System.Management.Automation.PSCredential] $Credential
    )

    BEGIN
    {
        Write-Verbose "Starting $($MyInvocation.MyCommand.Name)"

        if (-not $PSBoundParameters.ContainsKey('ADServer'))
        {
            try
            {
                $ADServer = (Get-ADDomain -ErrorAction Stop).PDCEmulator
                Write-Verbose "PDC Emulator resolved to '$ADServer'"
            }
            catch
            {
                Write-Error "Failed to resolve PDC Emulator: $($_.Exception.Message)"
                return
            }
        }

        $script:ntpScriptBlock = {
            $result = [PSCustomObject]@{
                ComputerName  = $env:COMPUTERNAME
                NTPSource     = 'N/A'
                ConfigType    = 'N/A'
                ServiceStatus = 'N/A'
                IsDC          = $false
            }

            try
            {
                $reg = Get-ItemProperty `
                    -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' `
                    -ErrorAction Stop
                $result.ConfigType = [string]$reg.Type

                $w32Status = w32tm /query /status 2>&1
                $sourceMatch = $w32Status | Select-String -Pattern 'Source:\s*(.+)'
                if ($null -ne $sourceMatch)
                {
                    $result.NTPSource = $sourceMatch.Matches[0].Groups[1].Value.Trim()
                }

                $svc = Get-Service -Name 'w32time' -ErrorAction Stop
                $result.ServiceStatus = $svc.Status.ToString()

                $productType = (Get-ItemProperty `
                    -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ProductOptions' `
                    -ErrorAction SilentlyContinue).ProductType
                $result.IsDC = $productType -eq 'LanmanNT'
            }
            catch
            {
                $result.NTPSource     = 'Error'
                $result.ConfigType    = 'Error'
                $result.ServiceStatus = 'Error'
            }

            $result
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
                foreach ($dc in $dcs)
                {
                    $targetList.Add($dc)
                }
                Write-Verbose "Found $($targetList.Count) Domain Controller(s)"
            }
            catch
            {
                Write-Error "Failed to retrieve Domain Controllers from '$ADServer': $($_.Exception.Message)"
                return
            }
        }

        if ($targetList.Count -eq 0)
        {
            Write-Error "Target list is empty — no computers to query."
            return
        }

        foreach ($target in $targetList)
        {
            Write-Verbose "Querying NTP configuration on '$target'"
            try
            {
                $invokeParams = @{
                    ComputerName = $target
                    ScriptBlock  = $script:ntpScriptBlock
                    ErrorAction  = 'Stop'
                }
                if ($PSBoundParameters.ContainsKey('Credential'))
                {
                    $invokeParams['Credential'] = $Credential
                }
                $raw = Invoke-Command @invokeParams
                [PSATNtpConfiguration]::new($raw)
            }
            catch
            {
                Write-Warning "Failed to query '$target': $($_.Exception.Message)"
                [PSATNtpConfiguration]::new([PSCustomObject]@{
                    ComputerName  = $target
                    NTPSource     = 'Error'
                    ConfigType    = 'Error'
                    ServiceStatus = 'Error'
                    IsDC          = $false
                })
            }
        }
    }

    END
    {
        Write-Verbose "Ending $($MyInvocation.MyCommand.Name)"
    }
}
