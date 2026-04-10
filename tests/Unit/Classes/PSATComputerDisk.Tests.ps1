BeforeAll {
    $script:ModuleRoot = Resolve-Path -Path "$PSScriptRoot/../../../source"
    . "$script:ModuleRoot/Classes/02_PSATComputerDisk.ps1"

    function New-TestDisk
    {
        param (
            [string] $DriveLetter = 'C:',
            [string] $Label       = 'System',
            [string] $FileSystem  = 'NTFS',
            [double] $TotalGB     = 100.0,
            [double] $FreeGB      = 40.0
        )
        [PSATComputerDisk]::new($DriveLetter, $Label, $FileSystem, $TotalGB, $FreeGB)
    }
}

Describe 'PSATComputerDisk' {

    Context 'Constructor' {

        It 'Should instantiate without error' {
            { New-TestDisk } | Should -Not -Throw
        }

        It 'Should set DriveLetter correctly' {
            (New-TestDisk).DriveLetter | Should -Be 'C:'
        }

        It 'Should set Label correctly' {
            (New-TestDisk).Label | Should -Be 'System'
        }

        It 'Should set FileSystem correctly' {
            (New-TestDisk).FileSystem | Should -Be 'NTFS'
        }

        It 'Should set TotalGB correctly' {
            (New-TestDisk).TotalGB | Should -Be 100.0
        }

        It 'Should set FreeGB correctly' {
            (New-TestDisk).FreeGB | Should -Be 40.0
        }

        It 'Should compute PercentFree correctly' {
            (New-TestDisk).PercentFree | Should -Be 40.0
        }

        It 'Should set PercentFree to 0 when TotalGB is 0' {
            $disk = New-TestDisk -TotalGB 0.0 -FreeGB 0.0
            $disk.PercentFree | Should -Be 0
        }

        It 'Should round TotalGB to 2 decimal places' {
            $disk = New-TestDisk -TotalGB 99.9999
            $disk.TotalGB | Should -Be 100.0
        }

        It 'Should round FreeGB to 2 decimal places' {
            $disk = New-TestDisk -FreeGB 39.9999
            $disk.FreeGB | Should -Be 40.0
        }
    }

    Context 'Method: IsLowSpace' {

        It 'Should return $true when free space is below the threshold' {
            $disk = New-TestDisk -TotalGB 100 -FreeGB 10
            $disk.IsLowSpace(20) | Should -BeTrue
        }

        It 'Should return $false when free space equals the threshold' {
            $disk = New-TestDisk -TotalGB 100 -FreeGB 20
            $disk.IsLowSpace(20) | Should -BeFalse
        }

        It 'Should return $false when free space is above the threshold' {
            $disk = New-TestDisk -TotalGB 100 -FreeGB 50
            $disk.IsLowSpace(20) | Should -BeFalse
        }

        It 'Should return $true for a nearly full disk' {
            $disk = New-TestDisk -TotalGB 100 -FreeGB 1
            $disk.IsLowSpace(10) | Should -BeTrue
        }
    }

    Context 'Method: ToString' {

        It 'Should return a non-empty string' {
            (New-TestDisk).ToString() | Should -Not -BeNullOrEmpty
        }

        It 'Should include the drive letter in the output' {
            (New-TestDisk).ToString() | Should -Match 'C:'
        }

        It 'Should include FreeGB in the output' {
            (New-TestDisk).ToString() | Should -Match '40'
        }

        It 'Should include TotalGB in the output' {
            (New-TestDisk).ToString() | Should -Match '100'
        }

        It 'Should include PercentFree in the output' {
            (New-TestDisk).ToString() | Should -Match '40'
        }
    }

    Context 'Property types' {

        It 'DriveLetter should be a string' {
            (New-TestDisk).DriveLetter | Should -BeOfType [string]
        }

        It 'TotalGB should be a double' {
            (New-TestDisk).TotalGB | Should -BeOfType [double]
        }

        It 'FreeGB should be a double' {
            (New-TestDisk).FreeGB | Should -BeOfType [double]
        }

        It 'PercentFree should be a double' {
            (New-TestDisk).PercentFree | Should -BeOfType [double]
        }
    }
}
