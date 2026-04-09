BeforeAll {
    $script:ModuleRoot = Resolve-Path -Path "$PSScriptRoot/../../../source"
    . "$script:ModuleRoot/Public/Set-PSATDnsDebugLogging.ps1"
}

Describe 'Set-PSATDnsDebugLogging' {

    Context 'Module prerequisite' {

        It 'Should throw if DnsServer module is not available' {
            Mock -CommandName Get-Module -MockWith { $null }
            Mock -CommandName New-CimSession -MockWith { [PSCustomObject]@{ Id = 1 } }

            { Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log' } |
                Should -Throw -ExpectedMessage '*DnsServer PowerShell module is not available*'
        }
    }

    Context 'CimSession management' {

        BeforeEach {
            Mock -CommandName Get-Module -MockWith { [PSCustomObject]@{ Name = 'DnsServer' } }
            Mock -CommandName New-CimSession -MockWith { [PSCustomObject]@{ Id = 1; ComputerName = 'DC01' } }
            Mock -CommandName Remove-CimSession -MockWith { }
            Mock -CommandName Set-DnsServerDiagnostics -MockWith { }
        }

        It 'Should create a CimSession to the target computer' {
            Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log' -ComputerName 'DC01'

            Should -Invoke New-CimSession -Times 1 -ParameterFilter {
                $ComputerName -eq 'DC01'
            }
        }

        It 'Should pass Credential to New-CimSession when provided' {
            $securePassword = ConvertTo-SecureString -String 'P@ssw0rd' -AsPlainText -Force
            $cred = [System.Management.Automation.PSCredential]::new('domain\user', $securePassword)

            Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log' -ComputerName 'DC01' -Credential $cred

            Should -Invoke New-CimSession -Times 1 -ParameterFilter {
                $ComputerName -eq 'DC01' -and $null -ne $Credential
            }
        }

        It 'Should close the CimSession after execution' {
            Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log' -ComputerName 'DC01'

            Should -Invoke Remove-CimSession -Times 1
        }

        It 'Should throw if CimSession cannot be established' {
            Mock -CommandName New-CimSession -MockWith {
                throw [Microsoft.Management.Infrastructure.CimException]::new('Connection refused')
            }

            { Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log' -ComputerName 'DC01' } |
                Should -Throw -ExpectedMessage '*Cannot establish CimSession*'
        }

        It 'Should pass CimSession to Set-DnsServerDiagnostics (not ComputerName directly)' {
            Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log' -ComputerName 'DC01'

            Should -Invoke Set-DnsServerDiagnostics -Times 1 -ParameterFilter {
                $null -ne $CimSession
            }
        }
    }

    Context 'Enable DNS Debug Logging' {

        BeforeEach {
            Mock -CommandName Get-Module -MockWith { [PSCustomObject]@{ Name = 'DnsServer' } }
            Mock -CommandName New-CimSession -MockWith { [PSCustomObject]@{ Id = 1 } }
            Mock -CommandName Remove-CimSession -MockWith { }
            Mock -CommandName Set-DnsServerDiagnostics -MockWith { }
        }

        It 'Should call Set-DnsServerDiagnostics with EnableLoggingToFile = $true' {
            Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log'

            Should -Invoke Set-DnsServerDiagnostics -Times 1 -ParameterFilter {
                $EnableLoggingToFile -eq $true -and $LogFilePath -eq 'C:\Temp\dns.log'
            }
        }

        It 'Should use default MaxLogFileSizeBytes of 500000000 when not specified' {
            Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log'

            $expectedMB = [math]::Ceiling(500000000 / 1MB)

            Should -Invoke Set-DnsServerDiagnostics -Times 1 -ParameterFilter {
                $MaxMBFileSize -eq $expectedMB
            }
        }

        It 'Should use provided MaxLogFileSizeBytes' {
            Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log' -MaxLogFileSizeBytes 1000000000

            $expectedMB = [math]::Ceiling(1000000000 / 1MB)

            Should -Invoke Set-DnsServerDiagnostics -Times 1 -ParameterFilter {
                $MaxMBFileSize -eq $expectedMB
            }
        }

        It 'Should not call Set-DnsServerDiagnostics when -WhatIf is specified' {
            Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log' -WhatIf

            Should -Invoke Set-DnsServerDiagnostics -Times 0
        }

        It 'Should write an error on CimException from Set-DnsServerDiagnostics' {
            Mock -CommandName Set-DnsServerDiagnostics -MockWith {
                throw [Microsoft.Management.Infrastructure.CimException]::new('CIM error')
            }

            { Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log' -ErrorAction Stop } |
                Should -Throw
        }

        It 'Should write an error on generic exception from Set-DnsServerDiagnostics' {
            Mock -CommandName Set-DnsServerDiagnostics -MockWith {
                throw [System.Exception]::new('Generic error')
            }

            { Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log' -ErrorAction Stop } |
                Should -Throw
        }
    }

    Context 'Disable DNS Debug Logging' {

        BeforeEach {
            Mock -CommandName Get-Module -MockWith { [PSCustomObject]@{ Name = 'DnsServer' } }
            Mock -CommandName New-CimSession -MockWith { [PSCustomObject]@{ Id = 1 } }
            Mock -CommandName Remove-CimSession -MockWith { }
            Mock -CommandName Set-DnsServerDiagnostics -MockWith { }
        }

        It 'Should call Set-DnsServerDiagnostics with EnableLoggingToFile = $false' {
            Set-PSATDnsDebugLogging -Disable

            Should -Invoke Set-DnsServerDiagnostics -Times 1 -ParameterFilter {
                $EnableLoggingToFile -eq $false
            }
        }

        It 'Should pass CimSession to Set-DnsServerDiagnostics' {
            Set-PSATDnsDebugLogging -Disable -ComputerName 'DC01'

            Should -Invoke Set-DnsServerDiagnostics -Times 1 -ParameterFilter {
                $null -ne $CimSession
            }
        }

        It 'Should not call Set-DnsServerDiagnostics when -WhatIf is specified' {
            Set-PSATDnsDebugLogging -Disable -WhatIf

            Should -Invoke Set-DnsServerDiagnostics -Times 0
        }

        It 'Should close the CimSession after disabling' {
            Set-PSATDnsDebugLogging -Disable -ComputerName 'DC01'

            Should -Invoke Remove-CimSession -Times 1
        }
    }

    Context 'Parameter validation' {

        It 'Should require LogFilePath when Enable is specified' {
            { Set-PSATDnsDebugLogging -Enable } | Should -Throw
        }

        It 'Should require either Enable or Disable' {
            { Set-PSATDnsDebugLogging -ComputerName 'DC01' } | Should -Throw
        }

        It 'Should reject MaxLogFileSizeBytes of 0' {
            { Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log' -MaxLogFileSizeBytes 0 } |
                Should -Throw
        }

        It 'Should reject empty LogFilePath' {
            { Set-PSATDnsDebugLogging -Enable -LogFilePath '' } | Should -Throw
        }
    }
}
