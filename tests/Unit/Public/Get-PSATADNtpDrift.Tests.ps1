BeforeAll {
    $script:ModuleRoot = Resolve-Path -Path "$PSScriptRoot/../../../source"
    . "$script:ModuleRoot/Classes/07_PSATNtpDrift.ps1"
    . "$script:ModuleRoot/Public/Get-PSATADNtpDrift.ps1"

    Mock -CommandName Get-ADDomain -MockWith {
        [PSCustomObject]@{ PDCEmulator = 'PDC01.contoso.com' }
    }

    Mock -CommandName Get-ADDomainController -MockWith {
        @(
            [PSCustomObject]@{ HostName = 'DC02.contoso.com' }
            [PSCustomObject]@{ HostName = 'DC03.contoso.com' }
        )
    }

    # Returns offset in seconds (double), as the script block would on the remote machine
    Mock -CommandName Invoke-Command -MockWith {
        param ($ComputerName, $ScriptBlock, $ArgumentList, $ErrorAction, $Credential)
        switch ($ComputerName)
        {
            'DC02.contoso.com'  { return [double] 0.120 }   # 120 ms ahead — OK
            'DC03.contoso.com'  { return [double] -0.600 }  # 600 ms behind — WARNING
            'CRITICAL01'        { return [double] 3.0 }     # 3000 ms — CRITICAL
            'OFFLINE01'         { throw [System.Exception]::new('WinRM connection refused') }
            default             { return [double] 0.050 }
        }
    }
}

Describe 'Get-PSATADNtpDrift' {

    Context 'Output type' {

        It 'Should return [PSATNtpDrift] instances' {
            $result = Get-PSATADNtpDrift -ComputerName 'DC02.contoso.com'
            $result | Should -BeOfType [PSATNtpDrift]
        }

        It 'Should return one object per computer' {
            $result = Get-PSATADNtpDrift -ComputerName 'DC02.contoso.com', 'DC03.contoso.com'
            $result.Count | Should -Be 2
        }
    }

    Context 'Data population' {

        It 'Should set ComputerName correctly' {
            (Get-PSATADNtpDrift -ComputerName 'DC02.contoso.com').ComputerName | Should -Be 'DC02.contoso.com'
        }

        It 'Should set Reference to the PDC Emulator by default' {
            (Get-PSATADNtpDrift -ComputerName 'DC02.contoso.com').Reference | Should -Be 'PDC01.contoso.com'
        }

        It 'Should use the specified Reference when provided' {
            $result = Get-PSATADNtpDrift -ComputerName 'DC02.contoso.com' -Reference 'NTP.contoso.com'
            $result.Reference | Should -Be 'NTP.contoso.com'
        }

        It 'Should compute DriftMs in milliseconds' {
            (Get-PSATADNtpDrift -ComputerName 'DC02.contoso.com').DriftMs | Should -Be 120.0
        }

        It 'Should compute AbsDriftMs as the absolute value' {
            (Get-PSATADNtpDrift -ComputerName 'DC03.contoso.com').AbsDriftMs | Should -Be 600.0
        }

        It 'Should set SyncMode to Ahead when drift is positive' {
            (Get-PSATADNtpDrift -ComputerName 'DC02.contoso.com').SyncMode | Should -Be 'Ahead'
        }

        It 'Should set SyncMode to Behind when drift is negative' {
            (Get-PSATADNtpDrift -ComputerName 'DC03.contoso.com').SyncMode | Should -Be 'Behind'
        }

        It 'Should set a Timestamp' {
            (Get-PSATADNtpDrift -ComputerName 'DC02.contoso.com').Timestamp | Should -BeOfType [datetime]
        }
    }

    Context 'Status classification' {

        It 'Should return OK when drift is below the warn threshold' {
            (Get-PSATADNtpDrift -ComputerName 'DC02.contoso.com').Status | Should -Be 'OK'
        }

        It 'Should return WARNING when drift exceeds the warn threshold' {
            (Get-PSATADNtpDrift -ComputerName 'DC03.contoso.com').Status | Should -Be 'WARNING'
        }

        It 'Should return CRITICAL when drift exceeds the error threshold' {
            (Get-PSATADNtpDrift -ComputerName 'CRITICAL01').Status | Should -Be 'CRITICAL'
        }

        It 'Should return ERROR when the computer is unreachable' {
            $result = Get-PSATADNtpDrift -ComputerName 'OFFLINE01' -WarningAction SilentlyContinue
            $result.Status | Should -Be 'ERROR'
        }

        It 'Should respect custom WarnThresholdMs' {
            # DC02 has 120 ms drift — below default 500 ms but above custom 100 ms
            $result = Get-PSATADNtpDrift -ComputerName 'DC02.contoso.com' -WarnThresholdMs 100
            $result.Status | Should -Be 'WARNING'
        }

        It 'Should respect custom ErrorThresholdMs' {
            # DC03 has 600 ms drift — below default 2000 ms but above custom 400 ms
            $result = Get-PSATADNtpDrift -ComputerName 'DC03.contoso.com' -ErrorThresholdMs 400
            $result.Status | Should -Be 'CRITICAL'
        }
    }

    Context 'Unreachable machine' {

        It 'Should return an error object instead of throwing' {
            $result = Get-PSATADNtpDrift -ComputerName 'OFFLINE01' -WarningAction SilentlyContinue
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should set DriftMs to $null for an unreachable machine' {
            $result = Get-PSATADNtpDrift -ComputerName 'OFFLINE01' -WarningAction SilentlyContinue
            $null -eq $result.DriftMs | Should -BeTrue
        }

        It 'Should set SyncMode to Unreachable' {
            $result = Get-PSATADNtpDrift -ComputerName 'OFFLINE01' -WarningAction SilentlyContinue
            $result.SyncMode | Should -Be 'Unreachable'
        }
    }

    Context 'AD discovery (no ComputerName)' {

        It 'Should call Get-ADDomain to resolve the PDC Emulator' {
            Get-PSATADNtpDrift
            Should -Invoke Get-ADDomain -Times 1
        }

        It 'Should call Get-ADDomainController to discover DCs' {
            Get-PSATADNtpDrift
            Should -Invoke Get-ADDomainController -Times 1
        }

        It 'Should exclude the reference server from the target list' {
            # PDC01 is the reference — mock returns DC02 and DC03, not PDC01 — so 2 calls expected
            $result = Get-PSATADNtpDrift
            Should -Invoke Invoke-Command -Times 2
        }

        It 'Should use the specified ADServer for DC discovery' {
            Get-PSATADNtpDrift -ADServer 'DC01.contoso.com'
            Should -Invoke Get-ADDomainController -Times 1 -ParameterFilter {
                $Server -eq 'DC01.contoso.com'
            }
        }
    }

    Context 'Remote execution' {

        It 'Should call Invoke-Command on the target machine' {
            Get-PSATADNtpDrift -ComputerName 'DC02.contoso.com'
            Should -Invoke Invoke-Command -Times 1 -ParameterFilter {
                $ComputerName -eq 'DC02.contoso.com'
            }
        }

        It 'Should pass the Reference as ArgumentList to the script block' {
            Get-PSATADNtpDrift -ComputerName 'DC02.contoso.com' -Reference 'NTP.contoso.com'
            Should -Invoke Invoke-Command -Times 1 -ParameterFilter {
                $ArgumentList -contains 'NTP.contoso.com'
            }
        }

        It 'Should pass Credential to Invoke-Command when provided' {
            $securePassword = ConvertTo-SecureString -String 'P@ssw0rd' -AsPlainText -Force
            $cred = [System.Management.Automation.PSCredential]::new('CONTOSO\admin', $securePassword)
            Get-PSATADNtpDrift -ComputerName 'DC02.contoso.com' -Credential $cred
            Should -Invoke Invoke-Command -Times 1 -ParameterFilter {
                $null -ne $Credential
            }
        }
    }

    Context 'Pipeline input' {

        It 'Should accept ComputerName from the pipeline' {
            $result = 'DC02.contoso.com' | Get-PSATADNtpDrift
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should aggregate results from multiple pipeline computers' {
            $result = 'DC02.contoso.com', 'DC03.contoso.com' | Get-PSATADNtpDrift
            $result.Count | Should -Be 2
        }
    }

    Context 'Class method integration' {

        It 'IsCritical should return $true for a CRITICAL result' {
            (Get-PSATADNtpDrift -ComputerName 'CRITICAL01').IsCritical() | Should -BeTrue
        }

        It 'IsWarning should return $true for a WARNING result' {
            (Get-PSATADNtpDrift -ComputerName 'DC03.contoso.com').IsWarning() | Should -BeTrue
        }

        It 'IsError should return $true for an unreachable machine' {
            $result = Get-PSATADNtpDrift -ComputerName 'OFFLINE01' -WarningAction SilentlyContinue
            $result.IsError() | Should -BeTrue
        }
    }
}
