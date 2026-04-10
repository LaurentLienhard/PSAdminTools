BeforeAll {
    $script:ModuleRoot = Resolve-Path -Path "$PSScriptRoot/../../../source"
    . "$script:ModuleRoot/Classes/02_PSATComputerDisk.ps1"
    . "$script:ModuleRoot/Classes/03_PSATComputer.ps1"

    function New-TestDisk
    {
        [PSATComputerDisk]::new('C:', 'System', 'NTFS', 100.0, 40.0)
    }

    function New-TestRaw
    {
        param (
            [string]   $ComputerName    = 'SRV01',
            [string]   $ComputerType    = 'Server',
            [bool]     $IsOnline        = $true,
            [bool]     $PendingReboot   = $false,
            [double]   $TotalRAMGB      = 16.0,
            [object[]] $Disks           = @(New-TestDisk)
        )

        [PSCustomObject]@{
            ComputerName      = $ComputerName
            FQDN              = "$ComputerName.contoso.com"
            OU                = 'OU=Servers,DC=contoso,DC=com'
            ADSite            = 'Site-Paris'
            Description       = 'Test server'
            IsEnabled         = $true
            LastLogonDate     = [datetime]'2026-01-15'
            ADCreationDate    = [datetime]'2024-06-01'
            OperatingSystem   = 'Windows Server 2022 Standard'
            OSVersion         = '10.0.20348'
            OSBuild           = '20348'
            Architecture      = '64-bit'
            InstallDate       = [datetime]'2024-06-01'
            LastBootTime      = [datetime]'2026-04-01'
            Uptime            = [timespan]'9.00:00:00'
            IsVirtual         = $true
            Manufacturer      = 'VMware, Inc.'
            Model             = 'VMware Virtual Platform'
            ProcessorCount    = 2
            CoresPerProcessor = 4
            TotalRAMGB        = $TotalRAMGB
            IPAddresses       = [string[]]@('10.0.0.10')
            DnsServers        = [string[]]@('10.0.0.1', '10.0.0.2')
            DefaultGateway    = '10.0.0.254'
            Disks             = $Disks
            IsOnline          = $IsOnline
            PendingReboot     = $PendingReboot
            ComputerType      = $ComputerType
            IsDomainController   = $false
            InstalledRoles    = [string[]]@('Web-Server', 'FileAndStorage-Services')
            LastWindowsUpdate = [datetime]'2026-03-15'
            WorkstationType      = ''
            CurrentLoggedOnUser  = ''
            LastLoggedOnUser     = ''
        }
    }
}

Describe 'PSATComputer' {

    Context 'Constructor' {

        It 'Should instantiate without error' {
            { [PSATComputer]::new((New-TestRaw)) } | Should -Not -Throw
        }

        It 'Should set ComputerName correctly' {
            ([PSATComputer]::new((New-TestRaw))).ComputerName | Should -Be 'SRV01'
        }

        It 'Should set FQDN correctly' {
            ([PSATComputer]::new((New-TestRaw))).FQDN | Should -Be 'SRV01.contoso.com'
        }

        It 'Should set OU correctly' {
            ([PSATComputer]::new((New-TestRaw))).OU | Should -Be 'OU=Servers,DC=contoso,DC=com'
        }

        It 'Should set ADSite correctly' {
            ([PSATComputer]::new((New-TestRaw))).ADSite | Should -Be 'Site-Paris'
        }

        It 'Should set IsEnabled correctly' {
            ([PSATComputer]::new((New-TestRaw))).IsEnabled | Should -BeTrue
        }

        It 'Should set OperatingSystem correctly' {
            ([PSATComputer]::new((New-TestRaw))).OperatingSystem | Should -Be 'Windows Server 2022 Standard'
        }

        It 'Should set IsVirtual correctly' {
            ([PSATComputer]::new((New-TestRaw))).IsVirtual | Should -BeTrue
        }

        It 'Should set ProcessorCount correctly' {
            ([PSATComputer]::new((New-TestRaw))).ProcessorCount | Should -Be 2
        }

        It 'Should set TotalRAMGB correctly' {
            ([PSATComputer]::new((New-TestRaw))).TotalRAMGB | Should -Be 16.0
        }

        It 'Should set IPAddresses correctly' {
            ([PSATComputer]::new((New-TestRaw))).IPAddresses | Should -Contain '10.0.0.10'
        }

        It 'Should set DnsServers correctly' {
            $c = [PSATComputer]::new((New-TestRaw))
            $c.DnsServers | Should -Contain '10.0.0.1'
            $c.DnsServers | Should -Contain '10.0.0.2'
        }

        It 'Should set IsOnline correctly' {
            ([PSATComputer]::new((New-TestRaw -IsOnline $true))).IsOnline | Should -BeTrue
        }

        It 'Should set PendingReboot correctly' {
            ([PSATComputer]::new((New-TestRaw -PendingReboot $true))).PendingReboot | Should -BeTrue
        }

        It 'Should set ComputerType correctly' {
            ([PSATComputer]::new((New-TestRaw))).ComputerType | Should -Be 'Server'
        }

        It 'Should set Disks correctly' {
            ([PSATComputer]::new((New-TestRaw))).Disks.Count | Should -Be 1
        }

        It 'Should accept null for nullable date properties' {
            $raw = New-TestRaw
            $raw.LastBootTime = $null
            { [PSATComputer]::new($raw) } | Should -Not -Throw
        }
    }

    Context 'Method: HasLowDiskSpace' {

        It 'Should return $false when no disk is low on space' {
            $disk = [PSATComputerDisk]::new('C:', 'System', 'NTFS', 100.0, 50.0)
            $c = [PSATComputer]::new((New-TestRaw -Disks @($disk)))
            $c.HasLowDiskSpace(20) | Should -BeFalse
        }

        It 'Should return $true when at least one disk is low on space' {
            $disk = [PSATComputerDisk]::new('C:', 'System', 'NTFS', 100.0, 5.0)
            $c = [PSATComputer]::new((New-TestRaw -Disks @($disk)))
            $c.HasLowDiskSpace(20) | Should -BeTrue
        }

        It 'Should return $false when Disks is empty' {
            $c = [PSATComputer]::new((New-TestRaw -Disks @()))
            $c.HasLowDiskSpace(20) | Should -BeFalse
        }

        It 'Should return $true when only one of multiple disks is low' {
            $ok  = [PSATComputerDisk]::new('C:', 'System', 'NTFS', 100.0, 60.0)
            $low = [PSATComputerDisk]::new('D:', 'Data', 'NTFS', 500.0, 5.0)
            $c = [PSATComputer]::new((New-TestRaw -Disks @($ok, $low)))
            $c.HasLowDiskSpace(20) | Should -BeTrue
        }
    }

    Context 'Method: ToString' {

        It 'Should return a non-empty string' {
            ([PSATComputer]::new((New-TestRaw))).ToString() | Should -Not -BeNullOrEmpty
        }

        It 'Should include ComputerName in the output' {
            ([PSATComputer]::new((New-TestRaw))).ToString() | Should -Match 'SRV01'
        }

        It 'Should include ComputerType in the output' {
            ([PSATComputer]::new((New-TestRaw))).ToString() | Should -Match 'Server'
        }

        It 'Should include online status in the output' {
            ([PSATComputer]::new((New-TestRaw))).ToString() | Should -Match 'True'
        }
    }

    Context 'Property types' {

        It 'IPAddresses should be a string array' {
            ([PSATComputer]::new((New-TestRaw))).IPAddresses.GetType().IsArray | Should -BeTrue
        }

        It 'DnsServers should be a string array' {
            ([PSATComputer]::new((New-TestRaw))).DnsServers.GetType().IsArray | Should -BeTrue
        }

        It 'IsOnline should be a bool' {
            ([PSATComputer]::new((New-TestRaw))).IsOnline | Should -BeOfType [bool]
        }

        It 'TotalRAMGB should be a double' {
            ([PSATComputer]::new((New-TestRaw))).TotalRAMGB | Should -BeOfType [double]
        }
    }
}
