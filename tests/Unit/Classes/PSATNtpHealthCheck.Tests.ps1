BeforeAll {
    $script:ModuleRoot = Resolve-Path -Path "$PSScriptRoot/../../../source"
    . "$script:ModuleRoot/Classes/08_PSATNtpHealthEvent.ps1"
    . "$script:ModuleRoot/Classes/09_PSATNtpHealthCheck.ps1"

    function New-TestHealthEvent
    {
        param (
            [string] $Level   = 'Information',
            [int]    $EventId = 35
        )
        [PSATNtpHealthEvent]::new([PSCustomObject]@{
            EventId     = $EventId
            Level       = $Level
            Message     = "Test event at level $Level"
            TimeCreated = Get-Date
        })
    }

    function New-TestHealthCheck
    {
        param (
            [string]               $ComputerName   = 'DC01',
            [bool]                 $IsHealthy      = $true,
            [PSATNtpHealthEvent[]] $Events          = @(),
            [object]               $LastSyncTime    = [datetime]'2026-04-13 07:00:00',
            [string]               $LastSyncSource  = 'time.windows.com'
        )
        [PSATNtpHealthCheck]::new([PSCustomObject]@{
            ComputerName   = $ComputerName
            IsHealthy      = $IsHealthy
            Events         = $Events
            LastSyncTime   = $LastSyncTime
            LastSyncSource = $LastSyncSource
            CheckedAt      = [datetime]'2026-04-13 08:00:00'
        })
    }
}

Describe 'PSATNtpHealthCheck' {

    Context 'Constructor' {

        It 'Should instantiate without error' {
            { New-TestHealthCheck } | Should -Not -Throw
        }

        It 'Should set ComputerName correctly' {
            (New-TestHealthCheck -ComputerName 'DC01').ComputerName | Should -Be 'DC01'
        }

        It 'Should set IsHealthy to $true' {
            (New-TestHealthCheck -IsHealthy $true).IsHealthy | Should -BeTrue
        }

        It 'Should set IsHealthy to $false' {
            (New-TestHealthCheck -IsHealthy $false).IsHealthy | Should -BeFalse
        }

        It 'Should set LastSyncSource correctly' {
            (New-TestHealthCheck -LastSyncSource 'time.windows.com').LastSyncSource | Should -Be 'time.windows.com'
        }

        It 'Should accept $null for LastSyncTime' {
            { New-TestHealthCheck -LastSyncTime $null } | Should -Not -Throw
        }

        It 'Should set CheckedAt as a datetime' {
            (New-TestHealthCheck).CheckedAt | Should -BeOfType [datetime]
        }
    }

    Context 'Method: HasErrors' {

        It 'Should return $false when Events is empty' {
            (New-TestHealthCheck -Events @()).HasErrors() | Should -BeFalse
        }

        It 'Should return $false when all events are Information' {
            $events = @(New-TestHealthEvent -Level 'Information')
            (New-TestHealthCheck -Events $events).HasErrors() | Should -BeFalse
        }

        It 'Should return $false when events are only Warnings' {
            $events = @(New-TestHealthEvent -Level 'Warning')
            (New-TestHealthCheck -Events $events).HasErrors() | Should -BeFalse
        }

        It 'Should return $true when at least one event is Error' {
            $events = @(
                New-TestHealthEvent -Level 'Information'
                New-TestHealthEvent -Level 'Error'
            )
            (New-TestHealthCheck -Events $events).HasErrors() | Should -BeTrue
        }

        It 'Should return $true when at least one event is Critical' {
            $events = @(New-TestHealthEvent -Level 'Critical')
            (New-TestHealthCheck -Events $events).HasErrors() | Should -BeTrue
        }
    }

    Context 'Method: HasWarnings' {

        It 'Should return $false when Events is empty' {
            (New-TestHealthCheck -Events @()).HasWarnings() | Should -BeFalse
        }

        It 'Should return $true when at least one event is Warning' {
            $events = @(New-TestHealthEvent -Level 'Warning')
            (New-TestHealthCheck -Events $events).HasWarnings() | Should -BeTrue
        }

        It 'Should return $false when events are only Information' {
            $events = @(New-TestHealthEvent -Level 'Information')
            (New-TestHealthCheck -Events $events).HasWarnings() | Should -BeFalse
        }
    }

    Context 'Method: GetErrors' {

        It 'Should return an empty array when there are no errors' {
            (New-TestHealthCheck -Events @()).GetErrors() | Should -BeNullOrEmpty
        }

        It 'Should return only Error and Critical events' {
            $events = @(
                New-TestHealthEvent -Level 'Information'
                New-TestHealthEvent -Level 'Warning'
                New-TestHealthEvent -Level 'Error'
                New-TestHealthEvent -Level 'Critical'
            )
            $errors = (New-TestHealthCheck -Events $events).GetErrors()
            $errors.Count | Should -Be 2
            $errors | ForEach-Object { $_.IsError() | Should -BeTrue }
        }
    }

    Context 'Method: GetWarnings' {

        It 'Should return an empty array when there are no warnings' {
            (New-TestHealthCheck -Events @()).GetWarnings() | Should -BeNullOrEmpty
        }

        It 'Should return only Warning events' {
            $events = @(
                New-TestHealthEvent -Level 'Error'
                New-TestHealthEvent -Level 'Warning'
                New-TestHealthEvent -Level 'Information'
            )
            $warnings = (New-TestHealthCheck -Events $events).GetWarnings()
            $warnings.Count | Should -Be 1
            $warnings[0].Level | Should -Be 'Warning'
        }
    }

    Context 'Method: ToString' {

        It 'Should return a non-empty string' {
            (New-TestHealthCheck).ToString() | Should -Not -BeNullOrEmpty
        }

        It 'Should indicate Healthy when IsHealthy is $true' {
            (New-TestHealthCheck -IsHealthy $true).ToString() | Should -Match 'Healthy'
        }

        It 'Should indicate Unhealthy when IsHealthy is $false' {
            (New-TestHealthCheck -IsHealthy $false).ToString() | Should -Match 'Unhealthy'
        }

        It 'Should include ComputerName in the output' {
            (New-TestHealthCheck -ComputerName 'DC01').ToString() | Should -Match 'DC01'
        }

        It 'Should include LastSyncSource in the output' {
            (New-TestHealthCheck -LastSyncSource 'time.windows.com').ToString() | Should -Match 'time\.windows\.com'
        }

        It 'Should show Unknown when LastSyncTime is null' {
            (New-TestHealthCheck -LastSyncTime $null).ToString() | Should -Match 'Unknown'
        }
    }
}
