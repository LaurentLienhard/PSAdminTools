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
#Region '.\Public\Get-PSATADNTPConfiguration.ps1' -1

function Get-PSATADNTPConfiguration
{
    <#
    .SYNOPSIS
        Retrieves NTP configuration for specified computers or all Domain Controllers.
    .DESCRIPTION
        Queries the w32time service and registry. If no computers are specified,
        it automatically targets all Domain Controllers in the domain using the PDC Emulator.
    .PARAMETER ComputerName
        A list of computer names or FQDNs to query.
    .PARAMETER ADServer
        The DC used to discover the list of DCs (if ComputerName is empty). Defaults to the PDC Emulator.
    .PARAMETER Credential
        Optional credentials for remote access.
    .EXAMPLE
        Get-PSATADDomainNTPConfiguration -Verbose | Format-Table -AutoSize
    .EXAMPLE
        Get-PSATADDomainNTPConfiguration -ComputerName "MemberSrv01", "MemberSrv02" -Credential (Get-Credential)
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string[]]$ComputerName,
        [Parameter()]
        [string]$ADServer = $((Get-ADDomain).PDCEmulator),
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    process
    {
        try
        {
            $TargetList = @()

            if ($PSBoundParameters.ContainsKey('ComputerName'))
            {
                $TargetList = $ComputerName
                Write-Verbose "Targeting specific computers: $($TargetList -join ', ')"
            }
            else
            {
                Write-Verbose "No computers specified. Fetching all DCs from PDC: $ADServer"
                $splatAD = @{
                    Filter = '*'
                    Server = $ADServer
                }
                if ($Credential -ne [System.Management.Automation.PSCredential]::Empty)
                {
                    $splatAD.Add("Credential", $Credential)
                }
                $TargetList = Get-ADDomainController @splatAD | Select-Object -ExpandProperty HostName
            }

            if (-not $TargetList)
            {
                throw "Target list is empty."
            }

            Write-Verbose "Querying NTP configuration on $($TargetList.Count) targets..."

            $invokeParams = @{
                ComputerName = $TargetList
                ErrorAction  = 'SilentlyContinue'
                ScriptBlock  = {
                    try
                    {
                        $reg = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -ErrorAction Stop
                        $status = w32tm /query /status

                        $sourceMatch = $status | Select-String "Source:"
                        $source = if ($sourceMatch)
                        {
                            $sourceMatch.ToString().Split(":")[1].Trim()
                        }
                        else
                        {
                            "N/A"
                        }

                        $isDC = if (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\ProductOptions" -ErrorAction SilentlyContinue | Select-String "LanmanNT|ServerNT")
                        {
                            $true
                        }
                        else
                        {
                            $false
                        }

                        return [PSCustomObject]@{
                            ComputerName = $env:COMPUTERNAME
                            NTPSource    = $source
                            ConfigType   = $reg.Type
                            Service      = (Get-Service w32time).Status
                            IsDC         = $isDC
                        }
                    }
                    catch
                    {
                        return [PSCustomObject]@{
                            ComputerName = $env:COMPUTERNAME
                            NTPSource    = "Error/Unreachable"
                            ConfigType   = "N/A"
                            Service      = "N/A"
                            IsDC         = "Unknown"
                        }
                    }
                }
            }

            if ($Credential -ne [System.Management.Automation.PSCredential]::Empty)
            {
                $invokeParams.Add("Credential", $Credential)
            }

            $Results = Invoke-Command @invokeParams

            if ($Results)
            {
                return $Results | Select-Object ComputerName, NTPSource, ConfigType, Service, IsDC | Sort-Object ComputerName
            }
            else
            {
                Write-Verbose "No results returned. Ensure WinRM is enabled on targets."
            }
        }
        catch
        {
            Write-Error "Critical Error: $($_.Exception.Message)"
        }
    }
}
#EndRegion '.\Public\Get-PSATADNTPConfiguration.ps1' 133
#Region '.\Public\Get-PSATADNtpDrift.ps1' -1

function Get-PSATADNtpDrift
{
    <#
    .SYNOPSIS
        Returns NTP time drift data in milliseconds compared to the PDC Emulator.
    .DESCRIPTION
        Outputs a PSCustomObject for each target containing drift values and status levels.
    .PARAMETER ComputerName
        List of computers to check. If empty, all DCs are targeted.
    .PARAMETER Credential
        Optional credentials for remote AD discovery.
    .EXAMPLE
        Get-PSATADNtpDrift | Out-GridView
    .EXAMPLE
        Get-PSATADNtpDrift -ComputerName "SRV01" | Export-Csv -Path "DriftReport.csv"
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string[]]$ComputerName,
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    process
    {
        try
        {
            $PDC = (Get-ADDomain).PDCEmulator

            $TargetList = @()
            if ($PSBoundParameters.ContainsKey('ComputerName'))
            {
                $TargetList = $ComputerName
            }
            else
            {
                $splat = @{ Filter = '*'; Server = $PDC }
                if ($Credential -ne [System.Management.Automation.PSCredential]::Empty)
                {
                    $splat.Add("Credential", $Credential)
                }
                $TargetList = Get-ADDomainController @splat | Select-Object -ExpandProperty HostName
            }

            # Thresholds (ms)
            $WarnThresh = 500
            $ErrThresh = 2000

            $Results = foreach ($Target in $TargetList)
            {
                if ($Target -match $PDC.Split('.')[0])
                {
                    continue
                }

                try
                {
                    $sample = w32tm /stripchart /computer:$PDC /samples:1 /dataonly | Select-Object -Last 1
                    if ($sample -match "error")
                    {
                        throw "W32Time communication error"
                    }

                    $rawOffset = ($sample -split ",")[1].Trim().Replace("s", "")
                    $offsetMs = [math]::Round(([double]$rawOffset * 1000), 2)
                    $absOffset = [math]::Abs($offsetMs)

                    $status = "OK"
                    if ($absOffset -gt $ErrThresh)
                    {
                        $status = "CRITICAL"
                    }
                    elseif ($absOffset -gt $WarnThresh)
                    {
                        $status = "WARNING"
                    }

                    [PSCustomObject]@{
                        ComputerName = $Target
                        Reference    = $PDC
                        DriftMs      = $offsetMs
                        AbsDriftMs   = $absOffset
                        Status       = $status
                        SyncMode     = if ($offsetMs -ge 0)
                        {
                            "Ahead"
                        }
                        else
                        {
                            "Behind"
                        }
                        Timestamp    = Get-Date
                    }
                }
                catch
                {
                    [PSCustomObject]@{
                        ComputerName = $Target
                        Reference    = $PDC
                        DriftMs      = $null
                        AbsDriftMs   = $null
                        Status       = "ERROR"
                        SyncMode     = "Unreachable"
                        Timestamp    = Get-Date
                    }
                }
            }

            return $Results
        }
        catch
        {
            Write-Error "Critical Error: $($_.Exception.Message)"
        }
    }
}
#EndRegion '.\Public\Get-PSATADNtpDrift.ps1' 118
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
