Describe 'Get-PSATADServerLogonAudit Remote Fallback Unit Test Suite' {
    BeforeAll {
        . $PSScriptRoot/Get-PSATADServerLogonAudit.ps1
    }

    Context 'RPC Failure and WinRM Fallback Engine' {
        It 'Should seamlessly fail over to Invoke-Command when RPC throws Access Denied' {
            Mock -CommandName Get-WinEvent -MockWith {
                throw [System.UnauthorizedAccessException]::new("Attempted to perform an unauthorized operation.")
            }

            Mock -CommandName Invoke-Command -MockWith {
                return @(
                    [PSCustomObject]@{
                        Timestamp    = (Get-Date)
                        LogSource    = 'TerminalServices (ID 25)'
                        Account      = 'CORP\adm_jsmith'
                        LogonType    = 'RDP Session Reconnected'
                        SourceIP     = '10.0.4.50'
                        ComputerName = 'SVR-APP-01.corp.contoso.com'
                    }
                )
            } -Verifiable

            $results = Get-PSATADServerLogonAudit -ComputerName 'SVR-APP-01.corp.contoso.com'

            Assert-MockCalled -CommandName Invoke-Command -Times 1 -Scope It
            $results.Count | Should -Be 1
            $results[0].Account | Should -Be 'CORP\adm_jsmith'
        }
    }
}
