#Region '.\Classes\01_PSATDhcpScope.ps1' -1

class PSATDhcpScope
{
    #region <Properties>

    [string]   $ComputerName
    [string]   $ScopeId
    [string]   $Name
    [string]   $State
    [string]   $SubnetMask
    [string]   $StartRange
    [string]   $EndRange
    [timespan] $LeaseDuration
    [string[]] $DnsServers
    [string]   $DnsServersSource
    [string]   $DomainName
    [string[]] $Router

    #endregion <Properties>

    #region <Constructor>

    PSATDhcpScope(
        [string]   $ComputerName,
        [string]   $ScopeId,
        [string]   $Name,
        [string]   $State,
        [string]   $SubnetMask,
        [string]   $StartRange,
        [string]   $EndRange,
        [timespan] $LeaseDuration,
        [string[]] $DnsServers,
        [string]   $DnsServersSource,
        [string]   $DomainName,
        [string[]] $Router
    )
    {
        $this.ComputerName     = $ComputerName
        $this.ScopeId          = $ScopeId
        $this.Name             = $Name
        $this.State            = $State
        $this.SubnetMask       = $SubnetMask
        $this.StartRange       = $StartRange
        $this.EndRange         = $EndRange
        $this.LeaseDuration    = $LeaseDuration
        $this.DnsServers       = $DnsServers
        $this.DnsServersSource = $DnsServersSource
        $this.DomainName       = $DomainName
        $this.Router           = $Router
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if the given IP address appears in the effective DNS server list.
    [bool] HasDnsServer([string] $IpAddress)
    {
        return $IpAddress -in $this.DnsServers
    }

    # Returns $true if at least one IP from the provided list appears in DnsServers.
    [bool] HasAnyDnsServer([string[]] $IpAddresses)
    {
        foreach ($ip in $IpAddresses)
        {
            if ($this.HasDnsServer($ip))
            {
                return $true
            }
        }
        return $false
    }

    # Returns a human-readable summary of the scope.
    [string] ToString()
    {
        return "[$($this.ComputerName)] $($this.ScopeId) ($($this.Name)) — State: $($this.State) — DNS: $($this.DnsServers -join ', ')"
    }

    #endregion <Methods>
}
#EndRegion '.\Classes\01_PSATDhcpScope.ps1' 82
#Region '.\Classes\02_PSATComputerDisk.ps1' -1

class PSATComputerDisk
{
    #region <Properties>

    [string] $DriveLetter
    [string] $Label
    [string] $FileSystem
    [double] $TotalGB
    [double] $FreeGB
    [double] $PercentFree

    #endregion <Properties>

    #region <Constructor>

    PSATComputerDisk(
        [string] $DriveLetter,
        [string] $Label,
        [string] $FileSystem,
        [double] $TotalGB,
        [double] $FreeGB
    )
    {
        $this.DriveLetter = $DriveLetter
        $this.Label       = $Label
        $this.FileSystem  = $FileSystem
        $this.TotalGB     = [Math]::Round($TotalGB, 2)
        $this.FreeGB      = [Math]::Round($FreeGB, 2)

        if ($TotalGB -gt 0)
        {
            $this.PercentFree = [Math]::Round(($FreeGB / $TotalGB) * 100, 1)
        }
        else
        {
            $this.PercentFree = 0
        }
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if free space is below the given percentage threshold.
    [bool] IsLowSpace([double] $ThresholdPercent)
    {
        return $this.PercentFree -lt $ThresholdPercent
    }

    # Returns a human-readable summary of the disk.
    [string] ToString()
    {
        return "$($this.DriveLetter) — $($this.FreeGB) GB free / $($this.TotalGB) GB ($($this.PercentFree)% free)"
    }

    #endregion <Methods>
}
#EndRegion '.\Classes\02_PSATComputerDisk.ps1' 58
#Region '.\Classes\03_PSATComputer.ps1' -1

class PSATComputer
{
    #region <Properties>

    # Identity / AD
    [string] $ComputerName
    [string] $FQDN
    [string] $OU
    [string] $ADSite
    [string] $Description
    [bool]   $IsEnabled
    [object] $LastLogonDate
    [object] $ADCreationDate

    # Operating System
    [string] $OperatingSystem
    [string] $OSVersion
    [string] $OSBuild
    [string] $Architecture
    [object] $InstallDate
    [object] $LastBootTime
    [object] $Uptime

    # Hardware
    [bool]   $IsVirtual
    [string] $Manufacturer
    [string] $Model
    [int]    $ProcessorCount
    [int]    $CoresPerProcessor
    [double] $TotalRAMGB

    # Network
    [string[]] $IPAddresses
    [string[]] $DnsServers
    [string]   $DefaultGateway

    # Storage
    [PSATComputerDisk[]] $Disks

    # Health
    [bool]   $IsOnline
    [bool]   $PendingReboot

    # Classification
    [string] $ComputerType

    #endregion <Properties>

    #region <Constructor>

    PSATComputer([PSCustomObject] $raw)
    {
        $this.ComputerName    = $raw.ComputerName
        $this.FQDN            = $raw.FQDN
        $this.OU              = $raw.OU
        $this.ADSite          = $raw.ADSite
        $this.Description     = $raw.Description
        $this.IsEnabled       = $raw.IsEnabled
        $this.LastLogonDate   = $raw.LastLogonDate
        $this.ADCreationDate  = $raw.ADCreationDate

        $this.OperatingSystem = $raw.OperatingSystem
        $this.OSVersion       = $raw.OSVersion
        $this.OSBuild         = $raw.OSBuild
        $this.Architecture    = $raw.Architecture
        $this.InstallDate     = $raw.InstallDate
        $this.LastBootTime    = $raw.LastBootTime
        $this.Uptime          = $raw.Uptime

        $this.IsVirtual          = $raw.IsVirtual
        $this.Manufacturer       = $raw.Manufacturer
        $this.Model              = $raw.Model
        $this.ProcessorCount     = $raw.ProcessorCount
        $this.CoresPerProcessor  = $raw.CoresPerProcessor
        $this.TotalRAMGB         = $raw.TotalRAMGB

        $this.IPAddresses    = $raw.IPAddresses
        $this.DnsServers     = $raw.DnsServers
        $this.DefaultGateway = $raw.DefaultGateway

        $this.Disks = $raw.Disks

        $this.IsOnline      = $raw.IsOnline
        $this.PendingReboot = $raw.PendingReboot
        $this.ComputerType  = $raw.ComputerType
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if any disk is below the given free-space percentage threshold.
    [bool] HasLowDiskSpace([double] $ThresholdPercent)
    {
        foreach ($disk in $this.Disks)
        {
            if ($disk.IsLowSpace($ThresholdPercent))
            {
                return $true
            }
        }
        return $false
    }

    # Returns a human-readable summary of the computer.
    [string] ToString()
    {
        return "[$($this.ComputerType)] $($this.ComputerName) — OS: $($this.OperatingSystem) — Online: $($this.IsOnline)"
    }

    #endregion <Methods>
}
#EndRegion '.\Classes\03_PSATComputer.ps1' 113
#Region '.\Classes\04_PSATServer.ps1' -1

class PSATServer : PSATComputer
{
    #region <Properties>

    [bool]     $IsDomainController
    [string[]] $InstalledRoles
    [object]   $LastWindowsUpdate

    #endregion <Properties>

    #region <Constructor>

    PSATServer([PSCustomObject] $raw) : base($raw)
    {
        $this.IsDomainController = $raw.IsDomainController
        $this.InstalledRoles     = $raw.InstalledRoles
        $this.LastWindowsUpdate  = $raw.LastWindowsUpdate
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if the specified Windows role is installed.
    [bool] HasRole([string] $RoleName)
    {
        return $RoleName -in $this.InstalledRoles
    }

    # Returns a human-readable summary of the server.
    [string] ToString()
    {
        $dcLabel = if ($this.IsDomainController) { 'DC' } else { 'MemberServer' }
        return "[$dcLabel] $($this.ComputerName) — OS: $($this.OperatingSystem) — Online: $($this.IsOnline) — Roles: $($this.InstalledRoles.Count)"
    }

    #endregion <Methods>
}
#EndRegion '.\Classes\04_PSATServer.ps1' 39
#Region '.\Classes\05_PSATWorkstation.ps1' -1

class PSATWorkstation : PSATComputer
{
    #region <Properties>

    [string] $WorkstationType
    [string] $CurrentLoggedOnUser
    [string] $LastLoggedOnUser

    #endregion <Properties>

    #region <Constructor>

    PSATWorkstation([PSCustomObject] $raw) : base($raw)
    {
        $this.WorkstationType     = $raw.WorkstationType
        $this.CurrentLoggedOnUser = $raw.CurrentLoggedOnUser
        $this.LastLoggedOnUser    = $raw.LastLoggedOnUser
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if a user is currently logged on interactively.
    [bool] HasActiveUser()
    {
        return -not [string]::IsNullOrEmpty($this.CurrentLoggedOnUser)
    }

    # Returns a human-readable summary of the workstation.
    [string] ToString()
    {
        return "[$($this.WorkstationType)] $($this.ComputerName) — OS: $($this.OperatingSystem) — Online: $($this.IsOnline) — User: $($this.CurrentLoggedOnUser)"
    }

    #endregion <Methods>
}
#EndRegion '.\Classes\05_PSATWorkstation.ps1' 38
#Region '.\Classes\06_PSATNtpConfiguration.ps1' -1

class PSATNtpConfiguration
{
    #region <Properties>

    [string] $ComputerName
    [string] $NTPSource
    [string] $ConfigType
    [string] $ServiceStatus
    [bool]   $IsDC

    #endregion <Properties>

    #region <Constructor>

    PSATNtpConfiguration([PSCustomObject] $raw)
    {
        $this.ComputerName  = $raw.ComputerName
        $this.NTPSource     = $raw.NTPSource
        $this.ConfigType    = $raw.ConfigType
        $this.ServiceStatus = $raw.ServiceStatus
        $this.IsDC          = $raw.IsDC
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if NTP is actively configured (source is not N/A or Error).
    [bool] IsConfigured()
    {
        $unconfigured = @('N/A', 'Error', '')
        return $this.NTPSource -notin $unconfigured
    }

    # Returns $true if the W32Time service is in the Running state.
    [bool] IsServiceRunning()
    {
        return $this.ServiceStatus -eq 'Running'
    }

    # Returns a human-readable summary of the NTP configuration.
    [string] ToString()
    {
        $dcLabel = if ($this.IsDC) { 'DC' } else { 'Member' }
        return "[$dcLabel] $($this.ComputerName) — Source: $($this.NTPSource) — Type: $($this.ConfigType) — Service: $($this.ServiceStatus)"
    }

    #endregion <Methods>
}
#EndRegion '.\Classes\06_PSATNtpConfiguration.ps1' 50
#Region '.\Classes\07_PSATNtpDrift.ps1' -1

class PSATNtpDrift
{
    #region <Properties>

    [string]   $ComputerName
    [string]   $Reference
    [object]   $DriftMs
    [object]   $AbsDriftMs
    [string]   $Status
    [string]   $SyncMode
    [datetime] $Timestamp

    #endregion <Properties>

    #region <Constructor>

    PSATNtpDrift([PSCustomObject] $raw)
    {
        $this.ComputerName = $raw.ComputerName
        $this.Reference    = $raw.Reference
        $this.DriftMs      = $raw.DriftMs
        $this.AbsDriftMs   = $raw.AbsDriftMs
        $this.Status       = $raw.Status
        $this.SyncMode     = $raw.SyncMode
        $this.Timestamp    = $raw.Timestamp
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if the drift is at WARNING level.
    [bool] IsWarning()
    {
        return $this.Status -eq 'WARNING'
    }

    # Returns $true if the drift is at CRITICAL level.
    [bool] IsCritical()
    {
        return $this.Status -eq 'CRITICAL'
    }

    # Returns $true if the target was unreachable or an error occurred.
    [bool] IsError()
    {
        return $this.Status -eq 'ERROR'
    }

    # Returns a human-readable summary of the drift measurement.
    [string] ToString()
    {
        if ($this.IsError())
        {
            return "[$($this.Status)] $($this.ComputerName) vs $($this.Reference) — Unreachable"
        }
        return "[$($this.Status)] $($this.ComputerName) vs $($this.Reference) — Drift: $($this.DriftMs) ms ($($this.SyncMode))"
    }

    #endregion <Methods>
}
#EndRegion '.\Classes\07_PSATNtpDrift.ps1' 62
#Region '.\Classes\08_PSATNtpHealthEvent.ps1' -1

class PSATNtpHealthEvent
{
    #region <Properties>

    [int]      $EventId
    [string]   $Level
    [string]   $Message
    [datetime] $TimeCreated

    #endregion <Properties>

    #region <Constructor>

    PSATNtpHealthEvent([PSCustomObject] $raw)
    {
        $this.EventId     = $raw.EventId
        $this.Level       = $raw.Level
        $this.Message     = $raw.Message
        $this.TimeCreated = $raw.TimeCreated
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if this event is at Error or Critical level.
    [bool] IsError()
    {
        return $this.Level -in @('Error', 'Critical')
    }

    # Returns $true if this event is at Warning level.
    [bool] IsWarning()
    {
        return $this.Level -eq 'Warning'
    }

    # Returns a human-readable summary of the event.
    [string] ToString()
    {
        return "[$($this.Level)] $($this.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')) — EventId: $($this.EventId) — $($this.Message.Split([System.Environment]::NewLine)[0])"
    }

    #endregion <Methods>
}
#EndRegion '.\Classes\08_PSATNtpHealthEvent.ps1' 46
#Region '.\Classes\09_PSATNtpHealthCheck.ps1' -1

class PSATNtpHealthCheck
{
    #region <Properties>

    [string]               $ComputerName
    [bool]                 $IsHealthy
    [PSATNtpHealthEvent[]] $Events
    [object]               $LastSyncTime
    [string]               $LastSyncSource
    [datetime]             $CheckedAt

    #endregion <Properties>

    #region <Constructor>

    PSATNtpHealthCheck([PSCustomObject] $raw)
    {
        $this.ComputerName    = $raw.ComputerName
        $this.IsHealthy       = $raw.IsHealthy
        $this.Events          = $raw.Events
        $this.LastSyncTime    = $raw.LastSyncTime
        $this.LastSyncSource  = $raw.LastSyncSource
        $this.CheckedAt       = $raw.CheckedAt
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if any event is at Error or Critical level.
    [bool] HasErrors()
    {
        foreach ($event in $this.Events)
        {
            if ($event.IsError())
            {
                return $true
            }
        }
        return $false
    }

    # Returns $true if any event is at Warning level.
    [bool] HasWarnings()
    {
        foreach ($event in $this.Events)
        {
            if ($event.IsWarning())
            {
                return $true
            }
        }
        return $false
    }

    # Returns all Error and Critical level events.
    [PSATNtpHealthEvent[]] GetErrors()
    {
        $errors = [System.Collections.Generic.List[PSATNtpHealthEvent]]::new()
        foreach ($event in $this.Events)
        {
            if ($event.IsError())
            {
                $errors.Add($event)
            }
        }
        return $errors.ToArray()
    }

    # Returns all Warning level events.
    [PSATNtpHealthEvent[]] GetWarnings()
    {
        $warnings = [System.Collections.Generic.List[PSATNtpHealthEvent]]::new()
        foreach ($event in $this.Events)
        {
            if ($event.IsWarning())
            {
                $warnings.Add($event)
            }
        }
        return $warnings.ToArray()
    }

    # Returns a human-readable summary of the health check result.
    [string] ToString()
    {
        $status  = if ($this.IsHealthy) { 'Healthy' } else { 'Unhealthy' }
        $errors  = ($this.Events | Where-Object { $_.IsError() }).Count
        $warns   = ($this.Events | Where-Object { $_.IsWarning() }).Count
        $sync    = if ($null -ne $this.LastSyncTime) { $this.LastSyncTime.ToString('yyyy-MM-dd HH:mm:ss') } else { 'Unknown' }
        return "[$status] $($this.ComputerName) — Errors: $errors — Warnings: $warns — LastSync: $sync ($($this.LastSyncSource))"
    }

    #endregion <Methods>
}
#EndRegion '.\Classes\09_PSATNtpHealthCheck.ps1' 96
#Region '.\Public\Get-PSATADNTPConfiguration.ps1' -1

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
#EndRegion '.\Public\Get-PSATADNTPConfiguration.ps1' 209
#Region '.\Public\Get-PSATADNtpDrift.ps1' -1

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
#EndRegion '.\Public\Get-PSATADNtpDrift.ps1' 273
#Region '.\Public\Get-PSATADServerLogonAudit.ps1' -1

function Get-PSATADServerLogonAudit {
    <#
    .SYNOPSIS
        Audits administrative and user logon events using high-performance server-side XPath filtering.
    .DESCRIPTION
        Queries Security (Event ID 4624) and TerminalServices-LocalSessionManager (Event IDs 21, 25)
        logs on target hosts. Utilizes server-side XML/XPath execution to minimize RPC payload overhead,
        memory allocation, and remote execution latency. Fully sanitized and sanitized for enterprise deployment.
    .PARAMETER ComputerName
        The target host name or FQDN to query. Defaults to 'DC01.corp.contoso.com'.
    .PARAMETER StartTime
        Start of the search window. Defaults to 1 hour prior to execution time.
    .PARAMETER EndTime
        End of the search window. Defaults to current execution time.
    .PARAMETER Credential
        Optional explicit PSCredential for remote RPC / WinRM connections.
    .EXAMPLE
        Get-ADServerLogonAudit -ComputerName "DC01.corp.contoso.com" -StartTime (Get-Date).AddHours(-2) | Format-Table -AutoSize
    .EXAMPLE
        'DC01.corp.contoso.com', 'DC02.corp.contoso.com' | Get-ADServerLogonAudit -Credential (Get-Credential)
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName = 'DC01.corp.contoso.com',

        [Parameter(Mandatory = $false)]
        [datetime]$StartTime = (Get-Date).AddHours(-1),

        [Parameter(Mandatory = $false)]
        [datetime]$EndTime = (Get-Date),

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential
    )

    begin {
        $ErrorActionPreference = 'Stop'
        Write-Verbose -Message "Initializing optimized logon session audit subsystem."
    }

    process {
        if ($PSCmdlet.ShouldProcess($ComputerName, "Audit Security and TerminalServices Logon Events via XPath")) {

            # Convert system datetimes to ISO 8601 UTC format for XPath query execution
            $utcStart = $StartTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            $utcEnd   = $EndTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

            Write-Verbose -Message "Target Host: $ComputerName | Window (UTC): $utcStart to $utcEnd"

            $splatParams = @{
                ComputerName = $ComputerName
                ErrorAction  = 'Stop'
            }
            if ($PSBoundParameters.ContainsKey('Credential')) {
                $splatParams['Credential'] = $Credential
            }

            $auditResults = [System.Collections.Generic.List[PSObject]]::new()

            # ------------------------------------------------------------------
            # 1. Audit Security Log (Event ID 4624) via Server-Side XPath
            # ------------------------------------------------------------------
            # Server-side exclusion of system accounts (SYSTEM, LOCAL SERVICE, NETWORK SERVICE, ANONYMOUS LOGON, DWM-*, UMFD-*)
            $securityXPath = @"
*[System[(EventID=4624) and TimeCreated[@SystemTime>='$utcStart' and @SystemTime<='$utcEnd']]]
and
*[EventData[
    Data[@Name='TargetUserName'] != 'SYSTEM' and
    Data[@Name='TargetUserName'] != 'LOCAL SERVICE' and
    Data[@Name='TargetUserName'] != 'NETWORK SERVICE' and
    Data[@Name='TargetUserName'] != 'ANONYMOUS LOGON' and
    not(starts-with(Data[@Name='TargetUserName'], 'DWM-')) and
    not(starts-with(Data[@Name='TargetUserName'], 'UMFD-')) and
    Data[@Name='TargetDomainName'] != 'NT AUTHORITY'
]]
"@

            Write-Verbose -Message "Executing server-side XPath query against Security Log on target: $ComputerName"

            try {
                $secEvents = Get-WinEvent @splatParams -LogName 'Security' -FilterXPath $securityXPath

                foreach ($evt in $secEvents) {
                    $xml = [xml]$evt.ToXml()
                    $eventData = @{}
                    foreach ($data in $xml.Event.EventData.Data) {
                        if ($data.Name) {
                            $eventData[$data.Name] = $data.'#text'
                        }
                    }

                    $rawLogonType = [string]$eventData['LogonType']
                    $logonTypeDesc = switch ($rawLogonType) {
                        '2'  { "Interactive (Console)" }
                        '3'  { "Network (WinRM/SMB)" }
                        '10' { "RemoteInteractive (RDP)" }
                        '11' { "CachedInteractive" }
                        Default { "LogonType: $rawLogonType" }
                    }

                    $domainUser = "$($eventData['TargetDomainName'])\$($eventData['TargetUserName'])"

                    $auditResults.Add([PSCustomObject]@{
                        Timestamp    = $evt.TimeCreated
                        LogSource    = 'Security (ID 4624)'
                        Account      = $domainUser
                        LogonType    = $logonTypeDesc
                        SourceIP     = $eventData['IpAddress']
                        ComputerName = $evt.MachineName
                    })
                }
            }
            catch [System.UnauthorizedAccessException] {
                Write-Error -Message "Access Denied reading Security Event Log on target '$ComputerName': $($_.Exception.Message)" -ErrorAction Continue
            }
            catch [System.Diagnostics.Eventing.Reader.EventLogNotFoundException] {
                Write-Warning -Message "Security Log unavailable or inaccessible on target host '$ComputerName'."
            }
            catch [System.Exception] {
                $innerMsg = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message }
                Write-Warning -Message "Failed processing Security Log query on '$ComputerName': $innerMsg"
            }

            # ------------------------------------------------------------------
            # 2. Audit TerminalServices Operational Log (Event IDs 21, 25)
            # ------------------------------------------------------------------
            $tsXPath = @"
*[System[(EventID=21 or EventID=25) and TimeCreated[@SystemTime>='$utcStart' and @SystemTime<='$utcEnd']]]
"@

            Write-Verbose -Message "Executing XPath query against TerminalServices Log on target: $ComputerName"

            try {
                $tsEvents = Get-WinEvent @splatParams -LogName 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational' -FilterXPath $tsXPath

                foreach ($evt in $tsEvents) {
                    $xml = [xml]$evt.ToXml()
                    $userData = $xml.Event.UserData.EventXML

                    $user = $userData.User
                    $ip   = $userData.Address

                    $action = if ($evt.Id -eq 21) { "RDP Session Shell Started" } else { "RDP Session Reconnected" }

                    $auditResults.Add([PSCustomObject]@{
                        Timestamp    = $evt.TimeCreated
                        LogSource    = "TerminalServices (ID $($evt.Id))"
                        Account      = $user
                        LogonType    = $action
                        SourceIP     = $ip
                        ComputerName = $evt.MachineName
                    })
                }
            }
            catch [System.Exception] {
                # Catch non-existent log or zero events gracefully without halting pipeline
                Write-Verbose -Message "No TerminalServices operational events retrieved from '$ComputerName': $($_.Exception.Message)"
            }

            # Return chronologically sorted structured stream output
            $auditResults | Sort-Object -Property Timestamp
        }
    }

    end {
        Write-Verbose -Message "Logon audit execution cycle completed."
    }
}
#EndRegion '.\Public\Get-PSATADServerLogonAudit.ps1' 173
#Region '.\Public\Get-PSATComputerInventory.ps1' -1

function Get-PSATComputerInventory
{
    <#
    .SYNOPSIS
        Collects a complete inventory of Windows computers from Active Directory.

    .DESCRIPTION
        Get-PSATComputerInventory queries Active Directory to discover computers and then
        collects detailed information from each machine via CIM/WMI over WinRM.

        When no ComputerName is specified the function queries AD and returns all machines
        matching the ComputerType filter. When ComputerName is provided the function
        resolves each name against AD and then connects to it directly.

        If a machine is unreachable the AD identity data is still returned with IsOnline
        set to $false and all CIM-sourced properties left at their default values.

        Output objects are either [PSATServer] or [PSATWorkstation], both inheriting from
        [PSATComputer]. You can use standard PowerShell filtering and pipeline processing
        on the returned collection.

    .PARAMETER ComputerName
        One or more computer names to inventory. Accepts pipeline input.
        When omitted the function queries Active Directory for all computers matching
        the ComputerType filter.

    .PARAMETER ComputerType
        Filters which computers to include. Accepted values: Server, Workstation, All.
        Defaults to All.
        When querying AD without a ComputerName this filter is applied server-side.
        When ComputerName is provided machines that do not match the filter are skipped.

    .PARAMETER SearchBase
        Limits the AD query to the specified OU (LDAP distinguished name).
        Example: 'OU=Servers,DC=contoso,DC=com'

    .PARAMETER Credential
        Credentials used for remote WinRM connections via Invoke-Command.
        AD queries always run under the current user context.

    .EXAMPLE
        Get-PSATComputerInventory

        Returns an inventory of all Windows computers found in Active Directory.

    .EXAMPLE
        Get-PSATComputerInventory -ComputerType Server -SearchBase 'OU=Servers,DC=contoso,DC=com'

        Returns an inventory of servers found in the specified OU.

    .EXAMPLE
        Get-PSATComputerInventory -ComputerName 'SRV01', 'SRV02' -Credential (Get-Credential)

        Returns an inventory of two specific servers using explicit credentials.

    .EXAMPLE
        'PC01', 'PC02' | Get-PSATComputerInventory -ComputerType Workstation

        Pipes computer names and returns only those classified as workstations.

    .EXAMPLE
        Get-PSATComputerInventory -ComputerType Server | Where-Object { $_.PendingReboot }

        Returns all servers that have a pending reboot.

    .OUTPUTS
        PSATServer
        PSATWorkstation
    #>
    [CmdletBinding()]
    [OutputType([PSATComputer])]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ComputerName,

        [Parameter()]
        [ValidateSet('Server', 'Workstation', 'All')]
        [string] $ComputerType = 'All',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $SearchBase,

        [Parameter()]
        [System.Management.Automation.PSCredential] $Credential
    )

    BEGIN
    {
        Write-Verbose "Starting $($MyInvocation.MyCommand.Name)"

        $script:cimScriptBlock = {
            $result = [PSCustomObject]@{
                OperatingSystem      = ''
                OSVersion            = ''
                OSBuild              = ''
                Architecture         = ''
                InstallDate          = $null
                LastBootTime         = $null
                Uptime               = $null
                ProductType          = 0
                IsDomainController   = $false
                IsVirtual            = $false
                Manufacturer         = ''
                Model                = ''
                ProcessorCount       = 0
                CoresPerProcessor    = 0
                TotalRAMGB           = 0.0
                IPAddresses          = [string[]]@()
                DnsServers           = [string[]]@()
                DefaultGateway       = ''
                RawDisks             = @()
                PendingReboot        = $false
                ADSite               = ''
                InstalledRoles       = [string[]]@()
                LastWindowsUpdate    = $null
                WorkstationType      = ''
                CurrentLoggedOnUser  = ''
                LastLoggedOnUser     = ''
            }

            # Operating system
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($null -ne $os)
            {
                $result.OperatingSystem    = $os.Caption
                $result.OSVersion          = $os.Version
                $result.OSBuild            = $os.BuildNumber
                $result.Architecture       = $os.OSArchitecture
                $result.InstallDate        = $os.InstallDate
                $result.LastBootTime       = $os.LastBootUpTime
                $result.Uptime             = (Get-Date) - $os.LastBootUpTime
                $result.ProductType        = [int]$os.ProductType
                $result.IsDomainController = ($os.ProductType -eq 2)
                $result.TotalRAMGB         = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
            }

            # Computer system (hardware + user)
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
            if ($null -ne $cs)
            {
                $result.Manufacturer   = $cs.Manufacturer
                $result.Model          = $cs.Model
                $result.ProcessorCount = [int]$cs.NumberOfProcessors

                $vmKeywords = @('Virtual', 'VMware', 'VirtualBox', 'HVM domU', 'KVM', 'Hyper-V')
                $result.IsVirtual = ($vmKeywords | Where-Object { $cs.Model -match $_ }).Count -gt 0

                if (-not [string]::IsNullOrEmpty($cs.UserName))
                {
                    $result.CurrentLoggedOnUser = $cs.UserName
                }
            }

            # Processor cores
            $proc = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($null -ne $proc)
            {
                $result.CoresPerProcessor = [int]$proc.NumberOfCores
            }

            # Workstation chassis type
            if ($result.ProductType -eq 1)
            {
                $enclosure = Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction SilentlyContinue
                if ($null -ne $enclosure)
                {
                    $laptopTypes = @(8, 9, 10, 11, 12, 14)
                    $chassisTypes = @($enclosure.ChassisTypes)
                    if (($chassisTypes | Where-Object { $_ -in $laptopTypes }).Count -gt 0)
                    {
                        $result.WorkstationType = 'Laptop'
                    }
                    elseif ($result.IsVirtual)
                    {
                        $result.WorkstationType = 'Virtual'
                    }
                    else
                    {
                        $result.WorkstationType = 'Desktop'
                    }
                }

                # Last logged on user from registry
                try
                {
                    $logonKey = Get-ItemProperty `
                        -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI' `
                        -Name 'LastLoggedOnUser' `
                        -ErrorAction Stop
                    $result.LastLoggedOnUser = $logonKey.LastLoggedOnUser
                }
                catch
                {
                    $result.LastLoggedOnUser = ''
                }
            }

            # Logical disks (local fixed drives only)
            $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 3' -ErrorAction SilentlyContinue
            $result.RawDisks = @(
                foreach ($disk in $disks)
                {
                    [PSCustomObject]@{
                        DriveLetter = [string]$disk.DeviceID
                        Label       = [string]$disk.VolumeName
                        FileSystem  = [string]$disk.FileSystem
                        TotalGB     = [Math]::Round($disk.Size / 1GB, 2)
                        FreeGB      = [Math]::Round($disk.FreeSpace / 1GB, 2)
                    }
                }
            )

            # Network adapters (IP-enabled only, IPv4 only)
            $adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = True' `
                -ErrorAction SilentlyContinue
            $ipList  = [System.Collections.Generic.List[string]]::new()
            $dnsList = [System.Collections.Generic.List[string]]::new()

            foreach ($adapter in $adapters)
            {
                foreach ($ip in $adapter.IPAddress)
                {
                    if ($ip -notmatch ':')
                    {
                        $ipList.Add($ip)
                    }
                }
                foreach ($dns in $adapter.DNSServerSearchOrder)
                {
                    if (-not $dnsList.Contains($dns))
                    {
                        $dnsList.Add($dns)
                    }
                }
                if ($null -ne $adapter.DefaultIPGateway -and $adapter.DefaultIPGateway.Count -gt 0)
                {
                    $result.DefaultGateway = $adapter.DefaultIPGateway[0]
                }
            }

            $result.IPAddresses = $ipList.ToArray()
            $result.DnsServers  = $dnsList.ToArray()

            # Pending reboot detection via registry keys
            $rebootKeys = @(
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
                'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations'
            )
            foreach ($key in $rebootKeys)
            {
                if (Test-Path -Path $key)
                {
                    $result.PendingReboot = $true
                    break
                }
            }

            # AD site of the remote machine
            try
            {
                $result.ADSite = [System.DirectoryServices.ActiveDirectory.ActiveDirectorySite]::GetComputerSite().Name
            }
            catch
            {
                $result.ADSite = ''
            }

            # Server roles (ProductType 2 = DC, 3 = member server)
            if ($result.ProductType -ge 2)
            {
                try
                {
                    $roles = Get-WindowsFeature -ErrorAction Stop |
                        Where-Object { $_.Installed -and $_.FeatureType -eq 'Role' }
                    $result.InstalledRoles = [string[]]@($roles | Select-Object -ExpandProperty Name)
                }
                catch
                {
                    $result.InstalledRoles = [string[]]@()
                }

                try
                {
                    $lastHotfix = Get-HotFix -ErrorAction SilentlyContinue |
                        Sort-Object -Property InstalledOn -Descending |
                        Select-Object -First 1
                    if ($null -ne $lastHotfix)
                    {
                        $result.LastWindowsUpdate = $lastHotfix.InstalledOn
                    }
                }
                catch
                {
                    $result.LastWindowsUpdate = $null
                }
            }

            $result
        }
    }

    PROCESS
    {
        $adComputers = [System.Collections.Generic.List[object]]::new()

        if ($PSBoundParameters.ContainsKey('ComputerName'))
        {
            foreach ($name in $ComputerName)
            {
                try
                {
                    $adParams = @{
                        Identity    = $name
                        Properties  = @('DistinguishedName', 'DNSHostName', 'Description', 'Enabled',
                                        'LastLogonDate', 'Created', 'OperatingSystem')
                        ErrorAction = 'Stop'
                    }
                    $adComputers.Add((Get-ADComputer @adParams))
                }
                catch
                {
                    Write-Warning "Computer '$name' not found in Active Directory: $($_.Exception.Message)"
                }
            }
        }
        else
        {
            $adFilter = switch ($ComputerType)
            {
                'Server'      { "OperatingSystem -like '*Server*'" }
                'Workstation' { "OperatingSystem -notlike '*Server*' -and OperatingSystem -like '*Windows*'" }
                default       { "OperatingSystem -like '*Windows*'" }
            }

            $adParams = @{
                Filter      = $adFilter
                Properties  = @('DistinguishedName', 'DNSHostName', 'Description', 'Enabled',
                                'LastLogonDate', 'Created', 'OperatingSystem')
                ErrorAction = 'Stop'
            }

            if ($PSBoundParameters.ContainsKey('SearchBase'))
            {
                $adParams['SearchBase'] = $SearchBase
            }

            try
            {
                $adComputers.AddRange([object[]]@(Get-ADComputer @adParams))
            }
            catch
            {
                Write-Error "Failed to query Active Directory: $($_.Exception.Message)"
                return
            }
        }

        foreach ($adComputer in $adComputers)
        {
            $name = $adComputer.Name
            Write-Verbose "Processing '$name'"

            # Detect type from AD OS attribute
            $type = if ($adComputer.OperatingSystem -like '*Server*') { 'Server' } else { 'Workstation' }

            # Skip when ComputerName was specified and type does not match the filter
            if ($ComputerType -ne 'All' -and $type -ne $ComputerType)
            {
                Write-Verbose "Skipping '$name' — type '$type' does not match filter '$ComputerType'"
                continue
            }

            # Extract OU path from DistinguishedName
            $ou = $adComputer.DistinguishedName -replace '^CN=[^,]+,', ''

            # Connectivity check
            $isOnline = Test-Connection -ComputerName $name -Count 1 -Quiet -ErrorAction SilentlyContinue

            # CIM data collection (only when reachable)
            $rawCim = $null
            if ($isOnline)
            {
                try
                {
                    $invokeParams = @{
                        ComputerName = $name
                        ScriptBlock  = $script:cimScriptBlock
                        ErrorAction  = 'Stop'
                    }
                    if ($PSBoundParameters.ContainsKey('Credential'))
                    {
                        $invokeParams['Credential'] = $Credential
                    }
                    $rawCim = Invoke-Command @invokeParams
                }
                catch
                {
                    Write-Warning "Failed to collect CIM data from '$name': $($_.Exception.Message)"
                }
            }
            else
            {
                Write-Verbose "'$name' is offline — only AD data will be available"
            }

            # Build disk objects from raw CIM data
            $disks = [System.Collections.Generic.List[PSATComputerDisk]]::new()
            if ($null -ne $rawCim -and $null -ne $rawCim.RawDisks)
            {
                foreach ($d in $rawCim.RawDisks)
                {
                    $disks.Add([PSATComputerDisk]::new(
                        [string]$d.DriveLetter,
                        [string]$d.Label,
                        [string]$d.FileSystem,
                        [double]$d.TotalGB,
                        [double]$d.FreeGB
                    ))
                }
            }

            # Merge AD and CIM data into a single object for the class constructor
            $raw = [PSCustomObject]@{
                ComputerName      = $name
                FQDN              = [string]$adComputer.DNSHostName
                OU                = $ou
                ADSite            = if ($null -ne $rawCim) { [string]$rawCim.ADSite } else { '' }
                Description       = [string]$adComputer.Description
                IsEnabled         = [bool]$adComputer.Enabled
                LastLogonDate     = $adComputer.LastLogonDate
                ADCreationDate    = $adComputer.Created
                OperatingSystem   = if ($null -ne $rawCim) { [string]$rawCim.OperatingSystem } else { [string]$adComputer.OperatingSystem }
                OSVersion         = if ($null -ne $rawCim) { [string]$rawCim.OSVersion } else { '' }
                OSBuild           = if ($null -ne $rawCim) { [string]$rawCim.OSBuild } else { '' }
                Architecture      = if ($null -ne $rawCim) { [string]$rawCim.Architecture } else { '' }
                InstallDate       = if ($null -ne $rawCim) { $rawCim.InstallDate } else { $null }
                LastBootTime      = if ($null -ne $rawCim) { $rawCim.LastBootTime } else { $null }
                Uptime            = if ($null -ne $rawCim) { $rawCim.Uptime } else { $null }
                IsVirtual         = if ($null -ne $rawCim) { [bool]$rawCim.IsVirtual } else { $false }
                Manufacturer      = if ($null -ne $rawCim) { [string]$rawCim.Manufacturer } else { '' }
                Model             = if ($null -ne $rawCim) { [string]$rawCim.Model } else { '' }
                ProcessorCount    = if ($null -ne $rawCim) { [int]$rawCim.ProcessorCount } else { 0 }
                CoresPerProcessor = if ($null -ne $rawCim) { [int]$rawCim.CoresPerProcessor } else { 0 }
                TotalRAMGB        = if ($null -ne $rawCim) { [double]$rawCim.TotalRAMGB } else { 0.0 }
                IPAddresses       = if ($null -ne $rawCim -and $null -ne $rawCim.IPAddresses) { [string[]]$rawCim.IPAddresses } else { [string[]]@() }
                DnsServers        = if ($null -ne $rawCim -and $null -ne $rawCim.DnsServers) { [string[]]$rawCim.DnsServers } else { [string[]]@() }
                DefaultGateway    = if ($null -ne $rawCim) { [string]$rawCim.DefaultGateway } else { '' }
                Disks             = $disks.ToArray()
                IsOnline          = $isOnline
                PendingReboot     = if ($null -ne $rawCim) { [bool]$rawCim.PendingReboot } else { $false }
                ComputerType      = $type
                IsDomainController = if ($null -ne $rawCim) { [bool]$rawCim.IsDomainController } else { $false }
                InstalledRoles    = if ($null -ne $rawCim -and $null -ne $rawCim.InstalledRoles) { [string[]]$rawCim.InstalledRoles } else { [string[]]@() }
                LastWindowsUpdate = if ($null -ne $rawCim) { $rawCim.LastWindowsUpdate } else { $null }
                WorkstationType      = if ($null -ne $rawCim) { [string]$rawCim.WorkstationType } else { '' }
                CurrentLoggedOnUser  = if ($null -ne $rawCim) { [string]$rawCim.CurrentLoggedOnUser } else { '' }
                LastLoggedOnUser     = if ($null -ne $rawCim) { [string]$rawCim.LastLoggedOnUser } else { '' }
            }

            if ($type -eq 'Server')
            {
                [PSATServer]::new($raw)
            }
            else
            {
                [PSATWorkstation]::new($raw)
            }
        }
    }

    END
    {
        Write-Verbose "Ending $($MyInvocation.MyCommand.Name)"
    }
}
#EndRegion '.\Public\Get-PSATComputerInventory.ps1' 480
#Region '.\Public\Get-PSATDhcpScopeInfo.ps1' -1

function Get-PSATDhcpScopeInfo {
    [CmdletBinding()]
    [OutputType([PSATDhcpScope])]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName = @($env:COMPUTERNAME),

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [string[]]$ScopeId,

        [Parameter()]
        [string[]]$DnsServer,

        [Parameter()]
        [switch]$IncludeInactive
    )

    BEGIN {
        Write-Verbose "Starting $($MyInvocation.MyCommand.Name)"
        $localName = if ($null -ne $env:COMPUTERNAME) { $env:COMPUTERNAME } else { [System.Net.Dns]::GetHostName() }

        # Script block de collecte (exécuté sur le serveur cible)
        $script:dhcpScriptBlock = {
            param ([string[]]$FilterScopeIds, [bool]$IncludeInactive)

            # Force en-US culture to avoid missing fr-FR localization files in DhcpServer module
            $savedCulture = [System.Threading.Thread]::CurrentThread.CurrentUICulture
            [System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
            try
            {
                Import-Module -Name DhcpServer -ErrorAction Stop
            }
            finally
            {
                [System.Threading.Thread]::CurrentThread.CurrentUICulture = $savedCulture
            }

            $serverOptions = Get-DhcpServerv4OptionValue -ErrorAction SilentlyContinue
            $serverDns     = ($serverOptions | Where-Object { $_.OptionId -eq 6 }).Value
            $serverRouter  = ($serverOptions | Where-Object { $_.OptionId -eq 3 }).Value
            $serverDomain  = ($serverOptions | Where-Object { $_.OptionId -eq 15 }).Value

            $scopes = Get-DhcpServerv4Scope -ErrorAction Stop
            if (-not $IncludeInactive) { $scopes = $scopes | Where-Object { $_.State -eq 'Active' } }

            if ($null -ne $FilterScopeIds -and $FilterScopeIds.Count -gt 0) {
                $scopes = $scopes | Where-Object { $_.ScopeId.IPAddressToString -in $FilterScopeIds }
            }

            foreach ($scope in $scopes) {
                $scopeOptions = Get-DhcpServerv4OptionValue -ScopeId $scope.ScopeId -ErrorAction SilentlyContinue
                $sDns    = ($scopeOptions | Where-Object { $_.OptionId -eq 6 }).Value
                $sRouter = ($scopeOptions | Where-Object { $_.OptionId -eq 3 }).Value
                $sDomain = ($scopeOptions | Where-Object { $_.OptionId -eq 15 }).Value

                if ($null -ne $sDns) { $resolvedDns = [string[]]$sDns; $dnsSource = 'Scope' }
                else { $resolvedDns = [string[]]$serverDns; $dnsSource = 'Server' }

                if ($null -ne $sDomain) { $resolvedDomain = [string]($sDomain | Select-Object -First 1) }
                else { $resolvedDomain = [string]($serverDomain | Select-Object -First 1) }

                if ($null -ne $sRouter) { $resolvedRouter = [string[]]$sRouter }
                else { $resolvedRouter = [string[]]$serverRouter }

                [PSCustomObject]@{
                    ScopeId          = $scope.ScopeId.IPAddressToString
                    Name             = $scope.Name
                    State            = $scope.State.ToString()
                    SubnetMask       = $scope.SubnetMask.IPAddressToString
                    StartRange       = $scope.StartRange.IPAddressToString
                    EndRange         = $scope.EndRange.IPAddressToString
                    LeaseDuration    = $scope.LeaseDuration
                    DnsServers       = $resolvedDns
                    DnsServersSource = $dnsSource
                    DomainName       = $resolvedDomain
                    Router           = $resolvedRouter
                }
            }
        }
    }

    PROCESS {
        foreach ($computer in $ComputerName) {
            $isLocal = ($computer -eq $localName) -or ($computer -eq 'localhost') -or ($computer -eq '127.0.0.1')
            $rawScopes = $null

            try {
                if ($isLocal) {
                    $rawScopes = & $script:dhcpScriptBlock -FilterScopeIds $ScopeId -IncludeInactive $IncludeInactive.IsPresent
                } else {
                    $invokeParams = @{
                        ComputerName = $computer
                        ScriptBlock  = $script:dhcpScriptBlock
                        ArgumentList = @($ScopeId, $IncludeInactive.IsPresent)
                        ErrorAction  = 'Stop'
                    }
                    if ($PSBoundParameters.ContainsKey('Credential')) { $invokeParams['Credential'] = $Credential }
                    $rawScopes = Invoke-Command @invokeParams
                }

                foreach ($raw in $rawScopes) {
                    $obj = [PSATDhcpScope]::new(
                        $computer, $raw.ScopeId, $raw.Name, $raw.State, $raw.SubnetMask,
                        $raw.StartRange, $raw.EndRange, $raw.LeaseDuration, $raw.DnsServers,
                        $raw.DnsServersSource, $raw.DomainName, $raw.Router
                    )

                    if ($PSBoundParameters.ContainsKey('DnsServer')) {
                        if (-not $obj.HasAnyDnsServer($DnsServer)) { continue }
                    }
                    $obj
                }
            }
            catch {
                Write-Error "Failed to query DHCP server '$computer': $($_.Exception.Message)"
            }
        }
    }
    END { Write-Verbose "Ending Get-PSATDhcpScopeInfo" }
}
#EndRegion '.\Public\Get-PSATDhcpScopeInfo.ps1' 125
#Region '.\Public\Get-PSATDnsDebugLog.ps1' -1

function Get-PSATDnsDebugLog
{
    <#
    .SYNOPSIS
        Parses a Windows DNS Server debug log file into structured objects.

    .DESCRIPTION
        Reads a DNS debug log file produced by the Windows DNS Server service and
        converts each packet entry into a PSCustomObject with human-readable properties.

        The file can be read locally or from a remote server via PowerShell remoting
        (Invoke-Command). When -ComputerName is specified, the log file path refers to
        the path as seen on the remote server.

        Non-packet lines (headers, comments) are silently ignored.
        The encoded DNS label format (e.g. "(3)www(6)google(3)com(0)") is automatically
        decoded into a standard FQDN (e.g. "www.google.com").

        Optional filters allow narrowing results by time range, direction, record type,
        client IP, or query name.

    .PARAMETER Path
        Full path to the DNS debug log file as seen on the target server
        (e.g. C:\Windows\System32\dns\dns.log). Accepts pipeline input.

    .PARAMETER ComputerName
        Name or IP address of the remote DNS server to read the log from.
        Defaults to the local machine. Requires PowerShell remoting (WinRM) on the target.

    .PARAMETER Credential
        Credentials to connect to the remote server. Only used when -ComputerName
        specifies a remote machine.

    .PARAMETER StartTime
        Only return entries at or after this datetime.

    .PARAMETER EndTime
        Only return entries at or before this datetime.

    .PARAMETER Direction
        Filter by packet direction. 'Rcv' = received from client, 'Snd' = sent to client.

    .PARAMETER RecordType
        Filter by DNS record type (e.g. A, AAAA, MX, PTR, SRV, CNAME).

    .PARAMETER ClientIP
        Filter by exact client IP address.

    .PARAMETER QueryName
        Filter by query name. Supports wildcard patterns (e.g. '*.contoso.com').

    .EXAMPLE
        Get-PSATDnsDebugLog -Path 'C:\dns\dns.log'

        Parses all entries from the local log file.

    .EXAMPLE
        Get-PSATDnsDebugLog -Path 'C:\Windows\System32\dns\dns.log' -ComputerName 'dc01.contoso.com'

        Reads and parses the log directly from DC01 via PowerShell remoting.

    .EXAMPLE
        $cred = Get-Credential domain\adminuser
        Get-PSATDnsDebugLog -Path 'C:\dns\dns.log' -ComputerName 'dc01' -Credential $cred -Direction Rcv -RecordType A

        Reads inbound A record queries from a remote server using explicit credentials.

    .EXAMPLE
        Get-PSATDnsDebugLog -Path 'C:\dns\dns.log' -ClientIP '192.168.1.100' |
            Where-Object { $_.ResponseCode -eq 'NXDOMAIN' }

        Returns all failed lookups from a specific client.

    .EXAMPLE
        Get-PSATDnsDebugLog -Path 'C:\dns\dns.log' -StartTime (Get-Date).AddHours(-1)

        Returns entries from the last hour.

    .EXAMPLE
        'C:\dns\dc01.log','C:\dns\dc02.log' | Get-PSATDnsDebugLog -RecordType MX

        Parses MX queries from multiple local log files via the pipeline.

    .OUTPUTS
        PSCustomObject with the following properties:
        - Timestamp     [datetime]  : Date and time of the entry
        - Protocol      [string]    : Transport protocol (UDP or TCP)
        - Direction     [string]    : Rcv (received) or Snd (sent)
        - ClientIP      [string]    : Remote IP address
        - TransactionId [string]    : DNS transaction ID (XID) in hexadecimal
        - MessageType   [string]    : Query or Response
        - RecordType    [string]    : DNS record type (A, AAAA, MX, etc.)
        - QueryName     [string]    : Decoded fully qualified domain name
        - ResponseCode  [string]    : DNS response code (NOERROR, NXDOMAIN, SERVFAIL, etc.)
        - Flags         [string]    : DNS flags present in the packet
        - ThreadId      [string]    : Server thread ID in hexadecimal
        - SourceComputer [string]   : Hostname the log was read from

    .NOTES
        The DNS debug log must be enabled on the DNS server beforehand.
        Use Set-PSATDnsDebugLogging to enable it.

        Remote access requires WinRM to be enabled and configured on the target server.
        The account used must have permission to read the log file path on the remote machine.

        Log line format (Windows DNS Server):
        <Date> <Time> <ThreadId> PACKET <PacketId> <Protocol> <Direction> <ClientIP>
            <XID> <QR> [<Opcode> <Flags> <RCode>] <RecordType> <EncodedName>
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [datetime]$StartTime,

        [Parameter()]
        [datetime]$EndTime,

        [Parameter()]
        [ValidateSet('Rcv', 'Snd')]
        [string]$Direction,

        [Parameter()]
        [string]$RecordType,

        [Parameter()]
        [string]$ClientIP,

        [Parameter()]
        [string]$QueryName
    )

    BEGIN
    {
        Write-Verbose -Message "Starting $($MyInvocation.MyCommand.Name)"

        # Matches Windows DNS debug log packet lines.
        # Format: Date Time ThreadId PACKET PacketId Protocol Direction ClientIP XID QR [Flags] RecordType EncodedName
        $script:packetPattern = [regex](
            '^(?<Date>\d{1,2}/\d{1,2}/\d{4})\s+' +
            '(?<Time>\d{1,2}:\d{2}:\d{2}\s+[AP]M)\s+' +
            '(?<ThreadId>[0-9A-Fa-f]+)\s+PACKET\s+[0-9A-Fa-f]+\s+' +
            '(?<Protocol>UDP|TCP)\s+' +
            '(?<Direction>Rcv|Snd)\s+' +
            '(?<ClientIP>[\d.a-fA-F:]+)\s+' +
            '(?<XID>[0-9A-Fa-f]+)\s+' +
            '(?<QR>[QR])\s+' +
            '\[(?<Flags>[^\]]+)\]\s+' +
            '(?<RecordType>\S+)\s+' +
            '(?<QueryName>.+)$'
        )

        # Determine whether we are targeting the local machine.
        $localName = if ($null -ne $env:COMPUTERNAME) { $env:COMPUTERNAME } else { [System.Net.Dns]::GetHostName() }
        $script:isLocal = ($ComputerName -eq $localName) -or
                          ($ComputerName -eq 'localhost') -or
                          ($ComputerName -eq '127.0.0.1')

        # Build Invoke-Command parameter base for remote calls (reused per Path).
        if (-not $script:isLocal)
        {
            $script:invokeBase = @{
                ComputerName = $ComputerName
                ErrorAction  = 'Stop'
            }

            if ($PSBoundParameters.ContainsKey('Credential'))
            {
                $script:invokeBase['Credential'] = $Credential
            }

            Write-Verbose -Message "Remote mode: connecting to '$ComputerName' via PowerShell remoting"
        }
    }

    PROCESS
    {
        # Retrieve log lines — locally or via remoting.
        $lines = $null

        if ($script:isLocal)
        {
            if (-not (Test-Path -Path $Path -PathType Leaf))
            {
                Write-Error -Message "DNS debug log file not found: '$Path'"
                return
            }

            Write-Verbose -Message "Reading local log: '$Path'"

            try
            {
                $lines = [System.IO.File]::ReadLines($Path)
            }
            catch
            {
                Write-Error -Message "Failed to read '$Path': $($_.Exception.Message)"
                return
            }
        }
        else
        {
            Write-Verbose -Message "Reading remote log: '$Path' on '$ComputerName'"

            try
            {
                $remoteScriptBlock = {
                    param ($RemotePath)

                    if (-not (Test-Path -Path $RemotePath -PathType Leaf))
                    {
                        throw "File not found on remote host: '$RemotePath'"
                    }

                    Get-Content -Path $RemotePath -ErrorAction Stop
                }

                $invokeParams = $script:invokeBase.Clone()
                $invokeParams['ScriptBlock']  = $remoteScriptBlock
                $invokeParams['ArgumentList'] = $Path

                $lines = Invoke-Command @invokeParams
            }
            catch
            {
                Write-Error -Message "Failed to read '$Path' from '$ComputerName': $($_.Exception.Message)"
                return
            }
        }

        # Parse each line.
        foreach ($line in $lines)
        {
            $match = $script:packetPattern.Match($line)

            if (-not $match.Success)
            {
                continue
            }

            # Parse timestamp from date + time groups.
            try
            {
                $timestamp = [datetime]::Parse(
                    "$($match.Groups['Date'].Value) $($match.Groups['Time'].Value)"
                )
            }
            catch
            {
                Write-Warning -Message "Could not parse timestamp on line: $line"
                continue
            }

            # Apply time filters early to avoid unnecessary object creation.
            if ($PSBoundParameters.ContainsKey('StartTime') -and $timestamp -lt $StartTime)
            {
                continue
            }
            if ($PSBoundParameters.ContainsKey('EndTime') -and $timestamp -gt $EndTime)
            {
                continue
            }

            $entryDirection = $match.Groups['Direction'].Value
            if ($PSBoundParameters.ContainsKey('Direction') -and $entryDirection -ne $Direction)
            {
                continue
            }

            $entryRecordType = $match.Groups['RecordType'].Value
            if ($PSBoundParameters.ContainsKey('RecordType') -and $entryRecordType -ne $RecordType)
            {
                continue
            }

            $entryClientIP = $match.Groups['ClientIP'].Value
            if ($PSBoundParameters.ContainsKey('ClientIP') -and $entryClientIP -ne $ClientIP)
            {
                continue
            }

            # Decode DNS label-encoded name: (3)www(6)google(3)com(0) -> www.google.com
            $rawQueryName = $match.Groups['QueryName'].Value.Trim()
            $decodedName = ([regex]::Replace($rawQueryName, '\(\d+\)', '.')).Trim('.')

            if ($PSBoundParameters.ContainsKey('QueryName') -and $decodedName -notlike $QueryName)
            {
                continue
            }

            # Parse flags block: e.g. "0001   D   NOERROR" or "8081   DR  NOERROR"
            $flagTokens = ($match.Groups['Flags'].Value.Trim() -split '\s+') |
                Where-Object -FilterScript { $_ -ne '' }

            $responseCode = if ($flagTokens.Count -ge 1) { $flagTokens[-1] } else { '' }
            $flagChars = if ($flagTokens.Count -ge 3)
            {
                ($flagTokens[1..($flagTokens.Count - 2)]) -join ' '
            }
            else
            {
                ''
            }

            [PSCustomObject]@{
                Timestamp        = $timestamp
                Protocol         = $match.Groups['Protocol'].Value
                Direction        = $entryDirection
                ClientIP         = $entryClientIP
                TransactionId    = $match.Groups['XID'].Value.ToUpper()
                MessageType      = if ($match.Groups['QR'].Value -eq 'Q') { 'Query' } else { 'Response' }
                RecordType       = $entryRecordType
                QueryName        = $decodedName
                ResponseCode     = $responseCode
                Flags            = $flagChars
                ThreadId         = $match.Groups['ThreadId'].Value.ToUpper()
                SourceComputer   = $ComputerName
            }
        }
    }

    END
    {
        Write-Verbose -Message "Ending $($MyInvocation.MyCommand.Name)"
    }
}
#EndRegion '.\Public\Get-PSATDnsDebugLog.ps1' 339
#Region '.\Public\Set-PSATDnsDebugLogging.ps1' -1

function Set-PSATDnsDebugLogging
{
    <#
    .SYNOPSIS
        Enables or disables DNS Debug Logging on a DNS server.

    .DESCRIPTION
        Configures the DNS Debug Logging feature on a local or remote DNS server.
        When enabling, you can specify the log file path and its maximum size in bytes.
        Uses the DnsServer module (Set-DnsServerDiagnostics / Set-DnsServerDebugLogging).

    .PARAMETER ComputerName
        The DNS server to configure. Defaults to the local machine.

    .PARAMETER Enable
        Switch to enable DNS Debug Logging.

    .PARAMETER Disable
        Switch to disable DNS Debug Logging.

    .PARAMETER LogFilePath
        Full path and name of the debug log file (e.g. C:\Temp\dns.log).
        Required when -Enable is specified.

    .PARAMETER MaxLogFileSizeBytes
        Maximum size of the log file in bytes. Defaults to 500000000 (500 MB).
        Only used when -Enable is specified.

    .PARAMETER Credential
        Optional credentials to connect to the remote DNS server.

    .EXAMPLE
        Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log'

        Enables DNS debug logging on the local server with default max size (500 MB).

    .EXAMPLE
        Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log' -MaxLogFileSizeBytes 1000000000 -ComputerName 'DC01'

        Enables DNS debug logging on DC01 with a 1 GB max log size.

    .EXAMPLE
        Set-PSATDnsDebugLogging -Disable -ComputerName 'DC01'

        Disables DNS debug logging on DC01.

    .PARAMETER Credential
        Credentials used to connect to the remote DNS server via CimSession.
        Required when running from an admin workstation targeting a remote server.

    .NOTES
        Requires the DnsServer PowerShell module (available via RSAT on admin workstations).
        Credentials are passed through a CimSession, which is the only supported mechanism
        for Set-DnsServerDiagnostics remote authentication.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Enable')]
    [OutputType([void])]
    param
    (
        [Parameter(ParameterSetName = 'Enable')]
        [Parameter(ParameterSetName = 'Disable')]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true, ParameterSetName = 'Enable')]
        [switch]$Enable,

        [Parameter(Mandatory = $true, ParameterSetName = 'Disable')]
        [switch]$Disable,

        [Parameter(Mandatory = $true, ParameterSetName = 'Enable')]
        [ValidateNotNullOrEmpty()]
        [string]$LogFilePath,

        [Parameter(ParameterSetName = 'Enable')]
        [ValidateRange(1, [long]::MaxValue)]
        [long]$MaxLogFileSizeBytes = 500000000,

        [Parameter(ParameterSetName = 'Enable')]
        [Parameter(ParameterSetName = 'Disable')]
        [System.Management.Automation.PSCredential]$Credential
    )

    BEGIN
    {
        Write-Verbose -Message "Starting $($MyInvocation.MyCommand.Name)"

        if (-not (Get-Module -Name DnsServer -ListAvailable))
        {
            throw 'The DnsServer PowerShell module is not available on this system. Install RSAT DNS Server Tools.'
        }

        # Set-DnsServerDiagnostics does not support -Credential directly.
        # A CimSession is the correct way to pass credentials for remote management.
        $script:cimSession = $null

        try
        {
            $cimSessionParams = @{
                ComputerName = $ComputerName
                ErrorAction  = 'Stop'
            }

            if ($PSBoundParameters.ContainsKey('Credential'))
            {
                $cimSessionParams['Credential'] = $Credential
            }

            Write-Verbose -Message "Opening CimSession to '$ComputerName'"
            $script:cimSession = New-CimSession @cimSessionParams
        }
        catch [Microsoft.Management.Infrastructure.CimException]
        {
            throw "Cannot establish CimSession to '$ComputerName': $($_.Exception.Message)"
        }
        catch
        {
            throw "Failed to create CimSession to '$ComputerName': $($_.Exception.Message)"
        }
    }

    PROCESS
    {
        try
        {
            switch ($PSCmdlet.ParameterSetName)
            {
                'Enable'
                {
                    if ($PSCmdlet.ShouldProcess($ComputerName, "Enable DNS Debug Logging (LogFile: $LogFilePath, MaxSize: $MaxLogFileSizeBytes bytes)"))
                    {
                        Write-Verbose -Message "Enabling DNS Debug Logging on '$ComputerName'"
                        Write-Verbose -Message "  Log file   : $LogFilePath"
                        Write-Verbose -Message "  Max size   : $MaxLogFileSizeBytes bytes"

                        $diagParams = @{
                            CimSession             = $script:cimSession
                            Answers                = $true
                            EnableLogFileRollover  = $true
                            EnableLoggingForLocalLookupEvent     = $false
                            EnableLoggingForPluginDllEvent       = $false
                            EnableLoggingForRecursiveLookupEvent = $false
                            EnableLoggingForRemoteServerEvent    = $false
                            EnableLoggingForServerStartStopEvent = $false
                            EnableLoggingForTombstoneEvent       = $false
                            EnableLoggingForZoneDataWriteEvent   = $false
                            EnableLoggingForZoneLoadingEvent     = $false
                            EnableLoggingToFile    = $true
                            EventLogLevel          = 4
                            FullPackets            = $false
                            LogFilePath            = $LogFilePath
                            MaxMBFileSize          = [math]::Ceiling($MaxLogFileSizeBytes / 1MB)
                            Notifications          = $false
                            Queries                = $true
                            QuestionTransactions   = $true
                            ReceivePackets         = $true
                            SaveLogsToPersistentStorage = $true
                            SendPackets            = $true
                            TcpPackets             = $true
                            UdpPackets             = $true
                            UnmatchedResponse      = $false
                            Update                 = $true
                            UseSystemEventLog      = $true
                            WriteThrough           = $false
                            ErrorAction            = 'Stop'
                        }

                        Set-DnsServerDiagnostics @diagParams
                        Write-Verbose -Message "DNS Debug Logging successfully enabled on '$ComputerName'"
                    }
                }

                'Disable'
                {
                    if ($PSCmdlet.ShouldProcess($ComputerName, 'Disable DNS Debug Logging'))
                    {
                        Write-Verbose -Message "Disabling DNS Debug Logging on '$ComputerName'"

                        $diagParams = @{
                            CimSession          = $script:cimSession
                            All                 = $false
                            EnableLoggingToFile = $false
                            ErrorAction         = 'Stop'
                        }

                        Set-DnsServerDiagnostics @diagParams
                        Write-Verbose -Message "DNS Debug Logging successfully disabled on '$ComputerName'"
                    }
                }
            }
        }
        catch [Microsoft.Management.Infrastructure.CimException]
        {
            Write-Error -Message "CIM error while configuring DNS Debug Logging on '$ComputerName': $($_.Exception.Message)"
        }
        catch [System.UnauthorizedAccessException]
        {
            Write-Error -Message "Access denied while configuring DNS Debug Logging on '$ComputerName': $($_.Exception.Message)"
        }
        catch
        {
            Write-Error -Message "Failed to configure DNS Debug Logging on '$ComputerName': $($_.Exception.Message)"
        }
    }

    END
    {
        if ($null -ne $script:cimSession)
        {
            Write-Verbose -Message "Closing CimSession to '$ComputerName'"
            Remove-CimSession -CimSession $script:cimSession -ErrorAction SilentlyContinue
        }

        Write-Verbose -Message "Ending $($MyInvocation.MyCommand.Name)"
    }
}
#EndRegion '.\Public\Set-PSATDnsDebugLogging.ps1' 217
#Region '.\Public\Test-PSATNtpHealth.ps1' -1

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
#EndRegion '.\Public\Test-PSATNtpHealth.ps1' 285
