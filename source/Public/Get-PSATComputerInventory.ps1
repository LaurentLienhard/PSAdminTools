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
