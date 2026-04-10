BeforeAll {
    $script:ModuleRoot = Resolve-Path -Path "$PSScriptRoot/../../../source"
    . "$script:ModuleRoot/Classes/02_PSATComputerDisk.ps1"
    . "$script:ModuleRoot/Classes/03_PSATComputer.ps1"
    . "$script:ModuleRoot/Classes/04_PSATServer.ps1"

    function New-TestServerRaw
    {
        param (
            [bool]     $IsDomainController = $false,
            [string[]] $InstalledRoles     = @('Web-Server', 'FileAndStorage-Services'),
            [object]   $LastWindowsUpdate  = [datetime]'2026-03-15'
        )

        [PSCustomObject]@{
            ComputerName      = 'SRV01'
            FQDN              = 'SRV01.contoso.com'
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
            TotalRAMGB        = 32.0
            IPAddresses       = [string[]]@('10.0.0.10')
            DnsServers        = [string[]]@('10.0.0.1')
            DefaultGateway    = '10.0.0.254'
            Disks             = @([PSATComputerDisk]::new('C:', 'System', 'NTFS', 100.0, 50.0))
            IsOnline          = $true
            PendingReboot     = $false
            ComputerType      = 'Server'
            IsDomainController   = $IsDomainController
            InstalledRoles    = $InstalledRoles
            LastWindowsUpdate = $LastWindowsUpdate
            WorkstationType      = ''
            CurrentLoggedOnUser  = ''
            LastLoggedOnUser     = ''
        }
    }
}

Describe 'PSATServer' {

    Context 'Constructor' {

        It 'Should instantiate without error' {
            { [PSATServer]::new((New-TestServerRaw)) } | Should -Not -Throw
        }

        It 'Should inherit ComputerName from PSATComputer' {
            ([PSATServer]::new((New-TestServerRaw))).ComputerName | Should -Be 'SRV01'
        }

        It 'Should inherit OperatingSystem from PSATComputer' {
            ([PSATServer]::new((New-TestServerRaw))).OperatingSystem | Should -Be 'Windows Server 2022 Standard'
        }

        It 'Should set IsDomainController to $false for a member server' {
            ([PSATServer]::new((New-TestServerRaw -IsDomainController $false))).IsDomainController | Should -BeFalse
        }

        It 'Should set IsDomainController to $true for a DC' {
            ([PSATServer]::new((New-TestServerRaw -IsDomainController $true))).IsDomainController | Should -BeTrue
        }

        It 'Should set InstalledRoles correctly' {
            $s = [PSATServer]::new((New-TestServerRaw))
            $s.InstalledRoles | Should -Contain 'Web-Server'
            $s.InstalledRoles | Should -Contain 'FileAndStorage-Services'
        }

        It 'Should set LastWindowsUpdate correctly' {
            ([PSATServer]::new((New-TestServerRaw))).LastWindowsUpdate | Should -Be ([datetime]'2026-03-15')
        }

        It 'Should accept null for LastWindowsUpdate' {
            { [PSATServer]::new((New-TestServerRaw -LastWindowsUpdate $null)) } | Should -Not -Throw
        }

        It 'Should accept an empty InstalledRoles array' {
            { [PSATServer]::new((New-TestServerRaw -InstalledRoles @())) } | Should -Not -Throw
        }
    }

    Context 'Method: HasRole' {

        It 'Should return $true for an installed role' {
            ([PSATServer]::new((New-TestServerRaw))).HasRole('Web-Server') | Should -BeTrue
        }

        It 'Should return $false for a role that is not installed' {
            ([PSATServer]::new((New-TestServerRaw))).HasRole('DNS') | Should -BeFalse
        }

        It 'Should return $false when InstalledRoles is empty' {
            ([PSATServer]::new((New-TestServerRaw -InstalledRoles @()))).HasRole('Web-Server') | Should -BeFalse
        }

        It 'Should perform an exact match (case-sensitive)' {
            ([PSATServer]::new((New-TestServerRaw))).HasRole('web-server') | Should -BeFalse
        }
    }

    Context 'Method: ToString' {

        It 'Should return a non-empty string' {
            ([PSATServer]::new((New-TestServerRaw))).ToString() | Should -Not -BeNullOrEmpty
        }

        It 'Should contain ComputerName in the output' {
            ([PSATServer]::new((New-TestServerRaw))).ToString() | Should -Match 'SRV01'
        }

        It 'Should indicate MemberServer when IsDomainController is $false' {
            ([PSATServer]::new((New-TestServerRaw -IsDomainController $false))).ToString() | Should -Match 'MemberServer'
        }

        It 'Should indicate DC when IsDomainController is $true' {
            ([PSATServer]::new((New-TestServerRaw -IsDomainController $true))).ToString() | Should -Match 'DC'
        }

        It 'Should include role count in the output' {
            ([PSATServer]::new((New-TestServerRaw))).ToString() | Should -Match '2'
        }
    }

    Context 'Inherited methods' {

        It 'HasLowDiskSpace should work on PSATServer instances' {
            $raw  = New-TestServerRaw
            $raw.Disks = @([PSATComputerDisk]::new('C:', 'System', 'NTFS', 100.0, 5.0))
            ([PSATServer]::new($raw)).HasLowDiskSpace(20) | Should -BeTrue
        }
    }

    Context 'Type hierarchy' {

        It 'PSATServer should be an instance of PSATComputer' {
            [PSATServer]::new((New-TestServerRaw)) | Should -BeOfType [PSATComputer]
        }

        It 'PSATServer should be an instance of PSATServer' {
            [PSATServer]::new((New-TestServerRaw)) | Should -BeOfType [PSATServer]
        }
    }
}
