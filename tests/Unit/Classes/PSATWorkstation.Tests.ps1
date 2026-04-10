BeforeAll {
    $script:ModuleRoot = Resolve-Path -Path "$PSScriptRoot/../../../source"
    . "$script:ModuleRoot/Classes/02_PSATComputerDisk.ps1"
    . "$script:ModuleRoot/Classes/03_PSATComputer.ps1"
    . "$script:ModuleRoot/Classes/05_PSATWorkstation.ps1"

    function New-TestWorkstationRaw
    {
        param (
            [string] $WorkstationType      = 'Laptop',
            [string] $CurrentLoggedOnUser  = 'CONTOSO\jdupont',
            [string] $LastLoggedOnUser     = 'CONTOSO\jdupont'
        )

        [PSCustomObject]@{
            ComputerName      = 'PC01'
            FQDN              = 'PC01.contoso.com'
            OU                = 'OU=Workstations,DC=contoso,DC=com'
            ADSite            = 'Site-Lyon'
            Description       = 'Test workstation'
            IsEnabled         = $true
            LastLogonDate     = [datetime]'2026-04-09'
            ADCreationDate    = [datetime]'2023-09-01'
            OperatingSystem   = 'Windows 11 Pro'
            OSVersion         = '10.0.22621'
            OSBuild           = '22621'
            Architecture      = '64-bit'
            InstallDate       = [datetime]'2023-09-01'
            LastBootTime      = [datetime]'2026-04-08'
            Uptime            = [timespan]'1.05:00:00'
            IsVirtual         = $false
            Manufacturer      = 'Dell Inc.'
            Model             = 'Latitude 5540'
            ProcessorCount    = 1
            CoresPerProcessor = 8
            TotalRAMGB        = 16.0
            IPAddresses       = [string[]]@('192.168.1.50')
            DnsServers        = [string[]]@('10.0.0.1')
            DefaultGateway    = '192.168.1.1'
            Disks             = @([PSATComputerDisk]::new('C:', 'System', 'NTFS', 512.0, 200.0))
            IsOnline          = $true
            PendingReboot     = $false
            ComputerType      = 'Workstation'
            IsDomainController   = $false
            InstalledRoles    = [string[]]@()
            LastWindowsUpdate = $null
            WorkstationType      = $WorkstationType
            CurrentLoggedOnUser  = $CurrentLoggedOnUser
            LastLoggedOnUser     = $LastLoggedOnUser
        }
    }
}

Describe 'PSATWorkstation' {

    Context 'Constructor' {

        It 'Should instantiate without error' {
            { [PSATWorkstation]::new((New-TestWorkstationRaw)) } | Should -Not -Throw
        }

        It 'Should inherit ComputerName from PSATComputer' {
            ([PSATWorkstation]::new((New-TestWorkstationRaw))).ComputerName | Should -Be 'PC01'
        }

        It 'Should inherit OperatingSystem from PSATComputer' {
            ([PSATWorkstation]::new((New-TestWorkstationRaw))).OperatingSystem | Should -Be 'Windows 11 Pro'
        }

        It 'Should set WorkstationType correctly' {
            ([PSATWorkstation]::new((New-TestWorkstationRaw -WorkstationType 'Laptop'))).WorkstationType | Should -Be 'Laptop'
        }

        It 'Should set WorkstationType to Desktop' {
            ([PSATWorkstation]::new((New-TestWorkstationRaw -WorkstationType 'Desktop'))).WorkstationType | Should -Be 'Desktop'
        }

        It 'Should set WorkstationType to Virtual' {
            ([PSATWorkstation]::new((New-TestWorkstationRaw -WorkstationType 'Virtual'))).WorkstationType | Should -Be 'Virtual'
        }

        It 'Should set CurrentLoggedOnUser correctly' {
            ([PSATWorkstation]::new((New-TestWorkstationRaw))).CurrentLoggedOnUser | Should -Be 'CONTOSO\jdupont'
        }

        It 'Should set LastLoggedOnUser correctly' {
            ([PSATWorkstation]::new((New-TestWorkstationRaw))).LastLoggedOnUser | Should -Be 'CONTOSO\jdupont'
        }

        It 'Should accept empty string for CurrentLoggedOnUser' {
            { [PSATWorkstation]::new((New-TestWorkstationRaw -CurrentLoggedOnUser '')) } | Should -Not -Throw
        }
    }

    Context 'Method: HasActiveUser' {

        It 'Should return $true when a user is logged on' {
            ([PSATWorkstation]::new((New-TestWorkstationRaw -CurrentLoggedOnUser 'CONTOSO\jdupont'))).HasActiveUser() | Should -BeTrue
        }

        It 'Should return $false when no user is logged on' {
            ([PSATWorkstation]::new((New-TestWorkstationRaw -CurrentLoggedOnUser ''))).HasActiveUser() | Should -BeFalse
        }

        It 'Should return $false when CurrentLoggedOnUser is null' {
            ([PSATWorkstation]::new((New-TestWorkstationRaw -CurrentLoggedOnUser $null))).HasActiveUser() | Should -BeFalse
        }
    }

    Context 'Method: ToString' {

        It 'Should return a non-empty string' {
            ([PSATWorkstation]::new((New-TestWorkstationRaw))).ToString() | Should -Not -BeNullOrEmpty
        }

        It 'Should include ComputerName in the output' {
            ([PSATWorkstation]::new((New-TestWorkstationRaw))).ToString() | Should -Match 'PC01'
        }

        It 'Should include WorkstationType in the output' {
            ([PSATWorkstation]::new((New-TestWorkstationRaw -WorkstationType 'Laptop'))).ToString() | Should -Match 'Laptop'
        }

        It 'Should include CurrentLoggedOnUser in the output' {
            ([PSATWorkstation]::new((New-TestWorkstationRaw))).ToString() | Should -Match 'jdupont'
        }
    }

    Context 'Inherited methods' {

        It 'HasLowDiskSpace should work on PSATWorkstation instances' {
            $raw = New-TestWorkstationRaw
            $raw.Disks = @([PSATComputerDisk]::new('C:', 'System', 'NTFS', 512.0, 5.0))
            ([PSATWorkstation]::new($raw)).HasLowDiskSpace(10) | Should -BeTrue
        }
    }

    Context 'Type hierarchy' {

        It 'PSATWorkstation should be an instance of PSATComputer' {
            [PSATWorkstation]::new((New-TestWorkstationRaw)) | Should -BeOfType [PSATComputer]
        }

        It 'PSATWorkstation should be an instance of PSATWorkstation' {
            [PSATWorkstation]::new((New-TestWorkstationRaw)) | Should -BeOfType [PSATWorkstation]
        }
    }
}
