BeforeAll {
    $script:ModuleRoot = Resolve-Path -Path "$PSScriptRoot/../../../source"
    . "$script:ModuleRoot/Classes/07_PSATNtpDrift.ps1"

    function New-TestDrift
    {
        param (
            [string] $ComputerName = 'DC02',
            [string] $Reference    = 'PDC01.contoso.com',
            [object] $DriftMs      = 120.5,
            [object] $AbsDriftMs   = 120.5,
            [string] $Status       = 'OK',
            [string] $SyncMode     = 'Ahead'
        )
        [PSATNtpDrift]::new([PSCustomObject]@{
            ComputerName = $ComputerName
            Reference    = $Reference
            DriftMs      = $DriftMs
            AbsDriftMs   = $AbsDriftMs
            Status       = $Status
            SyncMode     = $SyncMode
            Timestamp    = [datetime]'2026-04-13 08:00:00'
        })
    }
}

Describe 'PSATNtpDrift' {

    Context 'Constructor' {

        It 'Should instantiate without error' {
            { New-TestDrift } | Should -Not -Throw
        }

        It 'Should set ComputerName correctly' {
            (New-TestDrift).ComputerName | Should -Be 'DC02'
        }

        It 'Should set Reference correctly' {
            (New-TestDrift).Reference | Should -Be 'PDC01.contoso.com'
        }

        It 'Should set DriftMs correctly' {
            (New-TestDrift).DriftMs | Should -Be 120.5
        }

        It 'Should set AbsDriftMs correctly' {
            (New-TestDrift).AbsDriftMs | Should -Be 120.5
        }

        It 'Should set Status correctly' {
            (New-TestDrift).Status | Should -Be 'OK'
        }

        It 'Should set SyncMode correctly' {
            (New-TestDrift).SyncMode | Should -Be 'Ahead'
        }

        It 'Should set Timestamp correctly' {
            (New-TestDrift).Timestamp | Should -BeOfType [datetime]
        }

        It 'Should accept $null for DriftMs (error case)' {
            { New-TestDrift -DriftMs $null -AbsDriftMs $null -Status 'ERROR' -SyncMode 'Unreachable' } |
                Should -Not -Throw
        }
    }

    Context 'Method: IsWarning' {

        It 'Should return $true when Status is WARNING' {
            (New-TestDrift -Status 'WARNING').IsWarning() | Should -BeTrue
        }

        It 'Should return $false when Status is OK' {
            (New-TestDrift -Status 'OK').IsWarning() | Should -BeFalse
        }

        It 'Should return $false when Status is CRITICAL' {
            (New-TestDrift -Status 'CRITICAL').IsWarning() | Should -BeFalse
        }

        It 'Should return $false when Status is ERROR' {
            (New-TestDrift -Status 'ERROR').IsWarning() | Should -BeFalse
        }
    }

    Context 'Method: IsCritical' {

        It 'Should return $true when Status is CRITICAL' {
            (New-TestDrift -Status 'CRITICAL').IsCritical() | Should -BeTrue
        }

        It 'Should return $false when Status is OK' {
            (New-TestDrift -Status 'OK').IsCritical() | Should -BeFalse
        }

        It 'Should return $false when Status is WARNING' {
            (New-TestDrift -Status 'WARNING').IsCritical() | Should -BeFalse
        }
    }

    Context 'Method: IsError' {

        It 'Should return $true when Status is ERROR' {
            (New-TestDrift -Status 'ERROR').IsError() | Should -BeTrue
        }

        It 'Should return $false when Status is OK' {
            (New-TestDrift -Status 'OK').IsError() | Should -BeFalse
        }

        It 'Should return $false when Status is CRITICAL' {
            (New-TestDrift -Status 'CRITICAL').IsError() | Should -BeFalse
        }
    }

    Context 'Method: ToString' {

        It 'Should return a non-empty string' {
            (New-TestDrift).ToString() | Should -Not -BeNullOrEmpty
        }

        It 'Should include ComputerName in the output' {
            (New-TestDrift).ToString() | Should -Match 'DC02'
        }

        It 'Should include Status in the output' {
            (New-TestDrift -Status 'WARNING').ToString() | Should -Match 'WARNING'
        }

        It 'Should include drift value in the output for a successful measurement' {
            (New-TestDrift -DriftMs 120.5 -Status 'OK').ToString() | Should -Match '120'
        }

        It 'Should indicate Unreachable when Status is ERROR' {
            (New-TestDrift -Status 'ERROR' -DriftMs $null -AbsDriftMs $null -SyncMode 'Unreachable').ToString() |
                Should -Match 'Unreachable'
        }
    }

    Context 'Status levels' {

        It 'Only one status method should return $true at a time — OK' {
            $d = New-TestDrift -Status 'OK'
            $d.IsWarning()  | Should -BeFalse
            $d.IsCritical() | Should -BeFalse
            $d.IsError()    | Should -BeFalse
        }

        It 'Only one status method should return $true at a time — WARNING' {
            $d = New-TestDrift -Status 'WARNING'
            $d.IsWarning()  | Should -BeTrue
            $d.IsCritical() | Should -BeFalse
            $d.IsError()    | Should -BeFalse
        }

        It 'Only one status method should return $true at a time — CRITICAL' {
            $d = New-TestDrift -Status 'CRITICAL'
            $d.IsWarning()  | Should -BeFalse
            $d.IsCritical() | Should -BeTrue
            $d.IsError()    | Should -BeFalse
        }
    }
}
