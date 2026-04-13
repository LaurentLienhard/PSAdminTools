BeforeAll {
    $script:ModuleRoot = Resolve-Path -Path "$PSScriptRoot/../../../source"
    . "$script:ModuleRoot/Classes/06_PSATNtpConfiguration.ps1"

    function New-TestNtpConfig
    {
        param (
            [string] $ComputerName  = 'DC01',
            [string] $NTPSource     = 'time.windows.com',
            [string] $ConfigType    = 'NTP',
            [string] $ServiceStatus = 'Running',
            [bool]   $IsDC          = $true
        )
        [PSATNtpConfiguration]::new([PSCustomObject]@{
            ComputerName  = $ComputerName
            NTPSource     = $NTPSource
            ConfigType    = $ConfigType
            ServiceStatus = $ServiceStatus
            IsDC          = $IsDC
        })
    }
}

Describe 'PSATNtpConfiguration' {

    Context 'Constructor' {

        It 'Should instantiate without error' {
            { New-TestNtpConfig } | Should -Not -Throw
        }

        It 'Should set ComputerName correctly' {
            (New-TestNtpConfig).ComputerName | Should -Be 'DC01'
        }

        It 'Should set NTPSource correctly' {
            (New-TestNtpConfig).NTPSource | Should -Be 'time.windows.com'
        }

        It 'Should set ConfigType correctly' {
            (New-TestNtpConfig).ConfigType | Should -Be 'NTP'
        }

        It 'Should set ServiceStatus correctly' {
            (New-TestNtpConfig).ServiceStatus | Should -Be 'Running'
        }

        It 'Should set IsDC to $true for a DC' {
            (New-TestNtpConfig -IsDC $true).IsDC | Should -BeTrue
        }

        It 'Should set IsDC to $false for a member server' {
            (New-TestNtpConfig -IsDC $false).IsDC | Should -BeFalse
        }
    }

    Context 'Method: IsConfigured' {

        It 'Should return $true when NTPSource is a valid address' {
            (New-TestNtpConfig -NTPSource 'time.windows.com').IsConfigured() | Should -BeTrue
        }

        It 'Should return $false when NTPSource is N/A' {
            (New-TestNtpConfig -NTPSource 'N/A').IsConfigured() | Should -BeFalse
        }

        It 'Should return $false when NTPSource is Error' {
            (New-TestNtpConfig -NTPSource 'Error').IsConfigured() | Should -BeFalse
        }

        It 'Should return $false when NTPSource is empty' {
            (New-TestNtpConfig -NTPSource '').IsConfigured() | Should -BeFalse
        }

        It 'Should return $true for an IP address as source' {
            (New-TestNtpConfig -NTPSource '10.0.0.1').IsConfigured() | Should -BeTrue
        }
    }

    Context 'Method: IsServiceRunning' {

        It 'Should return $true when ServiceStatus is Running' {
            (New-TestNtpConfig -ServiceStatus 'Running').IsServiceRunning() | Should -BeTrue
        }

        It 'Should return $false when ServiceStatus is Stopped' {
            (New-TestNtpConfig -ServiceStatus 'Stopped').IsServiceRunning() | Should -BeFalse
        }

        It 'Should return $false when ServiceStatus is Error' {
            (New-TestNtpConfig -ServiceStatus 'Error').IsServiceRunning() | Should -BeFalse
        }

        It 'Should return $false when ServiceStatus is N/A' {
            (New-TestNtpConfig -ServiceStatus 'N/A').IsServiceRunning() | Should -BeFalse
        }
    }

    Context 'Method: ToString' {

        It 'Should return a non-empty string' {
            (New-TestNtpConfig).ToString() | Should -Not -BeNullOrEmpty
        }

        It 'Should include ComputerName in the output' {
            (New-TestNtpConfig).ToString() | Should -Match 'DC01'
        }

        It 'Should include NTPSource in the output' {
            (New-TestNtpConfig).ToString() | Should -Match 'time\.windows\.com'
        }

        It 'Should include DC label when IsDC is $true' {
            (New-TestNtpConfig -IsDC $true).ToString() | Should -Match 'DC'
        }

        It 'Should include Member label when IsDC is $false' {
            (New-TestNtpConfig -IsDC $false).ToString() | Should -Match 'Member'
        }
    }

    Context 'Property types' {

        It 'ComputerName should be a string' {
            (New-TestNtpConfig).ComputerName | Should -BeOfType [string]
        }

        It 'IsDC should be a bool' {
            (New-TestNtpConfig).IsDC | Should -BeOfType [bool]
        }
    }
}
