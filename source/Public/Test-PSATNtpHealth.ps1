function Test-PSATNtpHealth
{
    <#
    .SYNOPSIS
        Checks the NTP health of computers by analysing their W32Time event log entries.

    .DESCRIPTION
        For each target machine Test-PSATNtpHealth queries the System event log remotely
        via WinRM, filtering for events from the Microsoft-Windows-Time-Service provider
        within a configurable lookback window.

        Events are classified by their native Windows log level:
          - Error / Critical : synchronisation failures, no accessible time source (e.g. IDs 29, 129)
          - Warning          : temporary sync gaps, unreachable peers (e.g. IDs 36, 38, 47)
          - Information      : successful sync, valid data received (e.g. IDs 35, 37)

        A machine is considered healthy when no Error or Critical events appear in the
        lookback window. The last successful synchronisation event is extracted to provide
        LastSyncTime and LastSyncSource even when the machine is currently healthy.

        When no ComputerName is provided all Domain Controllers are automatically
        discovered via Active Directory.

    .PARAMETER ComputerName
        One or more computer names or FQDNs to check. Accepts pipeline input.
        When omitted all Domain Controllers discovered via AD are targeted.

    .PARAMETER Hours
        Number of hours to look back in the event log. Default: 24.

    .PARAMETER ADServer
        The Domain Controller used to discover the list of DCs when ComputerName is
        not provided. Defaults to the PDC Emulator of the current domain.

    .PARAMETER Credential
        Credentials for remote WinRM connections via Invoke-Command.

    .EXAMPLE
        Test-PSATNtpHealth | Format-Table -AutoSize

        Checks NTP health on all Domain Controllers over the last 24 hours.

    .EXAMPLE
        Test-PSATNtpHealth -ComputerName 'SRV01', 'SRV02' -Hours 48

        Checks two specific servers with a 48-hour lookback window.

    .EXAMPLE
        Test-PSATNtpHealth | Where-Object { -not $_.IsHealthy }

        Returns only machines with NTP errors.

    .EXAMPLE
        Test-PSATNtpHealth | Where-Object { $_.HasWarnings() } | ForEach-Object { $_.GetWarnings() }

        Lists all warning-level NTP events from machines that have them.

    .EXAMPLE
        Test-PSATNtpHealth -ComputerName 'DC01' -Credential (Get-Credential)

        Checks a specific DC with explicit credentials.

    .OUTPUTS
        PSATNtpHealthCheck
    #>
    [CmdletBinding()]
    [OutputType([PSATNtpHealthCheck])]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ComputerName,

        [Parameter()]
        [ValidateRange(1, 8760)]
        [int] $Hours = 24,

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

        $script:healthScriptBlock = {
            param ([int] $LookbackHours)

            $since = (Get-Date).AddHours(-$LookbackHours)

            $filterHash = @{
                LogName      = 'System'
                ProviderName = 'Microsoft-Windows-Time-Service'
                StartTime    = $since
            }

            $allEvents = Get-WinEvent -FilterHashtable $filterHash -ErrorAction SilentlyContinue

            $rawEvents = [System.Collections.Generic.List[object]]::new()

            foreach ($evt in $allEvents)
            {
                $level = switch ($evt.Level)
                {
                    1       { 'Critical' }
                    2       { 'Error' }
                    3       { 'Warning' }
                    default { 'Information' }
                }

                $rawEvents.Add([PSCustomObject]@{
                    EventId     = [int]$evt.Id
                    Level       = $level
                    Message     = [string]$evt.Message
                    TimeCreated = [datetime]$evt.TimeCreated
                })
            }

            # Extract last successful sync event (IDs 35 and 37 indicate active sync)
            $syncIds   = @(35, 37)
            $syncEvent = $allEvents |
                Where-Object { $_.Id -in $syncIds } |
                Sort-Object -Property TimeCreated -Descending |
                Select-Object -First 1

            $lastSyncTime   = $null
            $lastSyncSource = ''

            if ($null -ne $syncEvent)
            {
                $lastSyncTime = [datetime]$syncEvent.TimeCreated
                if ($syncEvent.Message -match '(?:from|with)\s+([^\s\.,]+)')
                {
                    $lastSyncSource = $Matches[1].Trim()
                }
            }

            [PSCustomObject]@{
                RawEvents      = $rawEvents.ToArray()
                LastSyncTime   = $lastSyncTime
                LastSyncSource = $lastSyncSource
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
            Write-Error "Target list is empty — no computers to check."
            return
        }

        foreach ($target in $targetList)
        {
            Write-Verbose "Checking NTP health on '$target' (last $Hours hour(s))"

            $rawResult  = $null
            $reachable  = $true

            try
            {
                $invokeParams = @{
                    ComputerName = $target
                    ScriptBlock  = $script:healthScriptBlock
                    ArgumentList = @($Hours)
                    ErrorAction  = 'Stop'
                }
                if ($PSBoundParameters.ContainsKey('Credential'))
                {
                    $invokeParams['Credential'] = $Credential
                }
                $rawResult = Invoke-Command @invokeParams
            }
            catch
            {
                Write-Warning "Failed to connect to '$target': $($_.Exception.Message)"
                $reachable = $false
            }

            if (-not $reachable)
            {
                [PSATNtpHealthCheck]::new([PSCustomObject]@{
                    ComputerName   = $target
                    IsHealthy      = $false
                    Events         = [PSATNtpHealthEvent[]]@()
                    LastSyncTime   = $null
                    LastSyncSource = ''
                    CheckedAt      = Get-Date
                })
                continue
            }

            $events = [System.Collections.Generic.List[PSATNtpHealthEvent]]::new()
            if ($null -ne $rawResult -and $null -ne $rawResult.RawEvents)
            {
                foreach ($e in $rawResult.RawEvents)
                {
                    $events.Add([PSATNtpHealthEvent]::new($e))
                }
            }

            $hasErrors = $false
            foreach ($e in $events)
            {
                if ($e.IsError())
                {
                    $hasErrors = $true
                    break
                }
            }

            [PSATNtpHealthCheck]::new([PSCustomObject]@{
                ComputerName   = $target
                IsHealthy      = -not $hasErrors
                Events         = $events.ToArray()
                LastSyncTime   = if ($null -ne $rawResult) { $rawResult.LastSyncTime } else { $null }
                LastSyncSource = if ($null -ne $rawResult) { [string]$rawResult.LastSyncSource } else { '' }
                CheckedAt      = Get-Date
            })
        }
    }

    END
    {
        Write-Verbose "Ending $($MyInvocation.MyCommand.Name)"
    }
}
