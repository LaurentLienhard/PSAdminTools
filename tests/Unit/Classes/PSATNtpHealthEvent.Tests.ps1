BeforeAll {
    $script:ModuleRoot = Resolve-Path -Path "$PSScriptRoot/../../../source"
    . "$script:ModuleRoot/Classes/08_PSATNtpHealthEvent.ps1"

    function New-TestEvent
    {
        param (
            [int]    $EventId     = 36,
            [string] $Level       = 'Warning',
            [string] $Message     = 'The time service has not been able to synchronize.',
            [datetime] $TimeCreated = [datetime]'2026-04-13 08:00:00'
        )
        [PSATNtpHealthEvent]::new([PSCustomObject]@{
            EventId     = $EventId
            Level       = $Level
            Message     = $Message
            TimeCreated = $TimeCreated
        })
    }
}

Describe 'PSATNtpHealthEvent' {

    Context 'Constructor' {

        It 'Should instantiate without error' {
            { New-TestEvent } | Should -Not -Throw
        }

        It 'Should set EventId correctly' {
            (New-TestEvent -EventId 29).EventId | Should -Be 29
        }

        It 'Should set Level correctly' {
            (New-TestEvent -Level 'Error').Level | Should -Be 'Error'
        }

        It 'Should set Message correctly' {
            (New-TestEvent -Message 'Test message').Message | Should -Be 'Test message'
        }

        It 'Should set TimeCreated correctly' {
            (New-TestEvent).TimeCreated | Should -BeOfType [datetime]
        }
    }

    Context 'Method: IsError' {

        It 'Should return $true when Level is Error' {
            (New-TestEvent -Level 'Error').IsError() | Should -BeTrue
        }

        It 'Should return $true when Level is Critical' {
            (New-TestEvent -Level 'Critical').IsError() | Should -BeTrue
        }

        It 'Should return $false when Level is Warning' {
            (New-TestEvent -Level 'Warning').IsError() | Should -BeFalse
        }

        It 'Should return $false when Level is Information' {
            (New-TestEvent -Level 'Information').IsError() | Should -BeFalse
        }
    }

    Context 'Method: IsWarning' {

        It 'Should return $true when Level is Warning' {
            (New-TestEvent -Level 'Warning').IsWarning() | Should -BeTrue
        }

        It 'Should return $false when Level is Error' {
            (New-TestEvent -Level 'Error').IsWarning() | Should -BeFalse
        }

        It 'Should return $false when Level is Information' {
            (New-TestEvent -Level 'Information').IsWarning() | Should -BeFalse
        }

        It 'Should return $false when Level is Critical' {
            (New-TestEvent -Level 'Critical').IsWarning() | Should -BeFalse
        }
    }

    Context 'Method: ToString' {

        It 'Should return a non-empty string' {
            (New-TestEvent).ToString() | Should -Not -BeNullOrEmpty
        }

        It 'Should include the Level in the output' {
            (New-TestEvent -Level 'Warning').ToString() | Should -Match 'Warning'
        }

        It 'Should include the EventId in the output' {
            (New-TestEvent -EventId 36).ToString() | Should -Match '36'
        }

        It 'Should include the date in the output' {
            (New-TestEvent).ToString() | Should -Match '2026-04-13'
        }

        It 'Should only include the first line of a multi-line message' {
            $msg = "First line$([System.Environment]::NewLine)Second line"
            $result = (New-TestEvent -Message $msg).ToString()
            $result | Should -Match 'First line'
            $result | Should -Not -Match 'Second line'
        }
    }

    Context 'Property types' {

        It 'EventId should be an int' {
            (New-TestEvent).EventId | Should -BeOfType [int]
        }

        It 'Level should be a string' {
            (New-TestEvent).Level | Should -BeOfType [string]
        }

        It 'TimeCreated should be a datetime' {
            (New-TestEvent).TimeCreated | Should -BeOfType [datetime]
        }
    }
}
