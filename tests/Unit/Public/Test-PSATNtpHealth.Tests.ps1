BeforeAll {
    $script:ModuleRoot = Resolve-Path -Path "$PSScriptRoot/../../../source"
    . "$script:ModuleRoot/Classes/08_PSATNtpHealthEvent.ps1"
    . "$script:ModuleRoot/Classes/09_PSATNtpHealthCheck.ps1"
    . "$script:ModuleRoot/Public/Test-PSATNtpHealth.ps1"

    # Raw result returned by Invoke-Command (simulates the script block output)
    $script:RawHealthy = [PSCustomObject]@{
        RawEvents      = @(
            [PSCustomObject]@{ EventId = 35; Level = 'Information'; Message = 'Synchronized with time.windows.com'; TimeCreated = [datetime]'2026-04-13 07:00:00' }
            [PSCustomObject]@{ EventId = 37; Level = 'Information'; Message = 'Receiving valid time from time.windows.com'; TimeCreated = [datetime]'2026-04-13 06:00:00' }
        )
        LastSyncTime   = [datetime]'2026-04-13 07:00:00'
        LastSyncSource = 'time.windows.com'
    }

    $script:RawWithWarning = [PSCustomObject]@{
        RawEvents      = @(
            [PSCustomObject]@{ EventId = 35; Level = 'Information'; Message = 'Synchronized with DC01.contoso.com'; TimeCreated = [datetime]'2026-04-13 05:00:00' }
            [PSCustomObject]@{ EventId = 36; Level = 'Warning';     Message = 'The time service has not been able to synchronize for 20 minutes.'; TimeCreated = [datetime]'2026-04-13 07:30:00' }
        )
        LastSyncTime   = [datetime]'2026-04-13 05:00:00'
        LastSyncSource = 'DC01.contoso.com'
    }

    $script:RawWithError = [PSCustomObject]@{
        RawEvents      = @(
            [PSCustomObject]@{ EventId = 29; Level = 'Error'; Message = 'NtpClient: No time sources are accessible.'; TimeCreated = [datetime]'2026-04-13 07:45:00' }
        )
        LastSyncTime   = $null
        LastSyncSource = ''
    }

    Mock -CommandName Get-ADDomain -MockWith {
        [PSCustomObject]@{ PDCEmulator = 'PDC01.contoso.com' }
    }

    Mock -CommandName Get-ADDomainController -MockWith {
        @(
            [PSCustomObject]@{ HostName = 'DC01.contoso.com' }
            [PSCustomObject]@{ HostName = 'DC02.contoso.com' }
        )
    }

    Mock -CommandName Invoke-Command -MockWith {
        param ($ComputerName, $ScriptBlock, $ArgumentList, $ErrorAction, $Credential)
        switch ($ComputerName)
        {
            'DC01.contoso.com'   { return $script:RawHealthy }
            'DC02.contoso.com'   { return $script:RawWithWarning }
            'SRV-ERROR'          { return $script:RawWithError }
            'OFFLINE01'          { throw [System.Exception]::new('WinRM connection refused') }
            default              { return $script:RawHealthy }
        }
    }
}

Describe 'Test-PSATNtpHealth' {

    Context 'Output type' {

        It 'Should return [PSATNtpHealthCheck] instances' {
            $result = Test-PSATNtpHealth -ComputerName 'DC01.contoso.com'
            $result | Should -BeOfType [PSATNtpHealthCheck]
        }

        It 'Should return one object per computer' {
            $result = Test-PSATNtpHealth -ComputerName 'DC01.contoso.com', 'DC02.contoso.com'
            $result.Count | Should -Be 2
        }
    }

    Context 'Healthy machine' {

        It 'Should set IsHealthy to $true when no error events exist' {
            (Test-PSATNtpHealth -ComputerName 'DC01.contoso.com').IsHealthy | Should -BeTrue
        }

        It 'Should set LastSyncTime correctly' {
            (Test-PSATNtpHealth -ComputerName 'DC01.contoso.com').LastSyncTime | Should -Be ([datetime]'2026-04-13 07:00:00')
        }

        It 'Should set LastSyncSource correctly' {
            (Test-PSATNtpHealth -ComputerName 'DC01.contoso.com').LastSyncSource | Should -Be 'time.windows.com'
        }

        It 'Should populate Events from the script block result' {
            (Test-PSATNtpHealth -ComputerName 'DC01.contoso.com').Events.Count | Should -Be 2
        }

        It 'Events should be [PSATNtpHealthEvent] instances' {
            $result = Test-PSATNtpHealth -ComputerName 'DC01.contoso.com'
            $result.Events | ForEach-Object { $_ | Should -BeOfType [PSATNtpHealthEvent] }
        }
    }

    Context 'Machine with warnings' {

        It 'Should remain healthy when only warning events exist' {
            (Test-PSATNtpHealth -ComputerName 'DC02.contoso.com').IsHealthy | Should -BeTrue
        }

        It 'HasWarnings should return $true' {
            (Test-PSATNtpHealth -ComputerName 'DC02.contoso.com').HasWarnings() | Should -BeTrue
        }

        It 'HasErrors should return $false' {
            (Test-PSATNtpHealth -ComputerName 'DC02.contoso.com').HasErrors() | Should -BeFalse
        }
    }

    Context 'Machine with errors' {

        It 'Should set IsHealthy to $false when error events exist' {
            (Test-PSATNtpHealth -ComputerName 'SRV-ERROR').IsHealthy | Should -BeFalse
        }

        It 'HasErrors should return $true' {
            (Test-PSATNtpHealth -ComputerName 'SRV-ERROR').HasErrors() | Should -BeTrue
        }

        It 'GetErrors should return the error events' {
            $errors = (Test-PSATNtpHealth -ComputerName 'SRV-ERROR').GetErrors()
            $errors.Count | Should -BeGreaterThan 0
            $errors | ForEach-Object { $_.IsError() | Should -BeTrue }
        }
    }

    Context 'Unreachable machine' {

        It 'Should return an object instead of throwing' {
            $result = Test-PSATNtpHealth -ComputerName 'OFFLINE01' -WarningAction SilentlyContinue
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should set IsHealthy to $false for an unreachable machine' {
            $result = Test-PSATNtpHealth -ComputerName 'OFFLINE01' -WarningAction SilentlyContinue
            $result.IsHealthy | Should -BeFalse
        }

        It 'Should set Events to empty array for an unreachable machine' {
            $result = Test-PSATNtpHealth -ComputerName 'OFFLINE01' -WarningAction SilentlyContinue
            $result.Events.Count | Should -Be 0
        }
    }

    Context 'AD discovery (no ComputerName)' {

        It 'Should call Get-ADDomain to resolve the PDC Emulator' {
            Test-PSATNtpHealth
            Should -Invoke Get-ADDomain -Times 1
        }

        It 'Should call Get-ADDomainController to discover DCs' {
            Test-PSATNtpHealth
            Should -Invoke Get-ADDomainController -Times 1
        }

        It 'Should not call Get-ADDomainController when ComputerName is provided' {
            Test-PSATNtpHealth -ComputerName 'DC01.contoso.com'
            Should -Invoke Get-ADDomainController -Times 0
        }

        It 'Should use the specified ADServer for DC discovery' {
            Test-PSATNtpHealth -ADServer 'DC01.contoso.com'
            Should -Invoke Get-ADDomainController -Times 1 -ParameterFilter {
                $Server -eq 'DC01.contoso.com'
            }
        }
    }

    Context 'Remote access' {

        It 'Should call Invoke-Command on the target machine' {
            Test-PSATNtpHealth -ComputerName 'DC01.contoso.com'
            Should -Invoke Invoke-Command -Times 1 -ParameterFilter {
                $ComputerName -eq 'DC01.contoso.com'
            }
        }

        It 'Should pass Hours as ArgumentList to the script block' {
            Test-PSATNtpHealth -ComputerName 'DC01.contoso.com' -Hours 48
            Should -Invoke Invoke-Command -Times 1 -ParameterFilter {
                $ArgumentList -contains 48
            }
        }

        It 'Should pass Credential to Invoke-Command when provided' {
            $securePassword = ConvertTo-SecureString -String 'P@ssw0rd' -AsPlainText -Force
            $cred = [System.Management.Automation.PSCredential]::new('CONTOSO\admin', $securePassword)
            Test-PSATNtpHealth -ComputerName 'DC01.contoso.com' -Credential $cred
            Should -Invoke Invoke-Command -Times 1 -ParameterFilter { $null -ne $Credential }
        }
    }

    Context 'Pipeline input' {

        It 'Should accept ComputerName from the pipeline' {
            $result = 'DC01.contoso.com' | Test-PSATNtpHealth
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should process multiple computers from the pipeline' {
            $result = 'DC01.contoso.com', 'DC02.contoso.com' | Test-PSATNtpHealth
            $result.Count | Should -Be 2
        }

        It 'Should continue processing remaining computers when one fails' {
            $result = 'OFFLINE01', 'DC01.contoso.com' | Test-PSATNtpHealth -WarningAction SilentlyContinue
            ($result | Where-Object { $_.ComputerName -eq 'DC01.contoso.com' }) | Should -Not -BeNullOrEmpty
        }
    }

    Context 'CheckedAt timestamp' {

        It 'Should set CheckedAt as a datetime' {
            (Test-PSATNtpHealth -ComputerName 'DC01.contoso.com').CheckedAt | Should -BeOfType [datetime]
        }
    }
}
