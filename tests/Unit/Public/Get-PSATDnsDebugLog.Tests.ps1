BeforeAll {
    $script:ModuleRoot = Resolve-Path -Path "$PSScriptRoot/../../../source"
    . "$script:ModuleRoot/Public/Get-PSATDnsDebugLog.ps1"

    # Sample DNS debug log content covering multiple scenarios.
    $script:SampleLogLines = @(
        'DNS Server log file creation at 4/9/2026 10:00:00 AM UTC'
        'Message logging key (for packets - sent and received):'
        ''
        '4/9/2026 10:15:23 AM 0B18 PACKET  00000001A2B3C4D5 UDP Rcv 192.168.1.100   0001 Q [0001   D   NOERROR] A      (3)www(6)google(3)com(0)'
        '4/9/2026 10:15:23 AM 0B18 PACKET  00000001A2B3C4D6 UDP Snd 192.168.1.100   0001 R [8081   DR  NOERROR] A      (3)www(6)google(3)com(0)'
        '4/9/2026 10:20:00 AM 0C20 PACKET  00000001A2B3C4D7 TCP Rcv 10.0.0.50       0002 Q [0001   D   NOERROR] AAAA   (6)server(7)contoso(3)com(0)'
        '4/9/2026 10:25:00 AM 0B18 PACKET  00000001A2B3C4D8 UDP Rcv 192.168.1.101   0003 Q [0001   D   NOERROR] MX     (7)contoso(3)com(0)'
        '4/9/2026 10:30:00 AM 0B18 PACKET  00000001A2B3C4D9 UDP Snd 192.168.1.101   0003 R [8081   DR  NXDOMAIN] MX    (7)contoso(3)com(0)'
        '4/9/2026 11:00:00 AM 0B18 PACKET  00000001A2B3C4DA UDP Rcv 192.168.1.100   0004 Q [0001   D   NOERROR] PTR    (3)100(3)168(3)192(7)in-addr(4)arpa(0)'
    )

    # Write a temporary log file for file-based tests.
    $script:TempLogPath = Join-Path -Path $TestDrive -ChildPath 'dns.log'
    $script:SampleLogLines | Set-Content -Path $script:TempLogPath -Encoding UTF8
}

Describe 'Get-PSATDnsDebugLog' {

    Context 'File validation' {

        It 'Should write an error when the file does not exist' {
            $result = Get-PSATDnsDebugLog -Path 'C:\nonexistent\dns.log' -ErrorVariable err 2>&1
            $err | Should -Not -BeNullOrEmpty
        }

        It 'Should return no output when the file does not exist' {
            $result = Get-PSATDnsDebugLog -Path 'C:\nonexistent\dns.log' -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Line parsing' {

        It 'Should skip non-packet lines (headers, blank lines)' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            # 6 packet lines in the sample content
            $result | Should -HaveCount 6
        }

        It 'Should parse Timestamp as a datetime object' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[0].Timestamp | Should -BeOfType [datetime]
        }

        It 'Should parse Timestamp value correctly' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[0].Timestamp | Should -Be ([datetime]'4/9/2026 10:15:23 AM')
        }

        It 'Should detect UDP protocol' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[0].Protocol | Should -Be 'UDP'
        }

        It 'Should detect TCP protocol' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[2].Protocol | Should -Be 'TCP'
        }

        It 'Should parse Direction as Rcv for received packets' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[0].Direction | Should -Be 'Rcv'
        }

        It 'Should parse Direction as Snd for sent packets' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[1].Direction | Should -Be 'Snd'
        }

        It 'Should parse ClientIP correctly' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[0].ClientIP | Should -Be '192.168.1.100'
        }

        It 'Should parse TransactionId in uppercase hexadecimal' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[0].TransactionId | Should -Be '0001'
        }

        It 'Should set MessageType to Query for Q packets' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[0].MessageType | Should -Be 'Query'
        }

        It 'Should set MessageType to Response for R packets' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[1].MessageType | Should -Be 'Response'
        }

        It 'Should parse RecordType correctly' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[0].RecordType | Should -Be 'A'
            $result[2].RecordType | Should -Be 'AAAA'
            $result[3].RecordType | Should -Be 'MX'
        }

        It 'Should parse ResponseCode as NOERROR' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[0].ResponseCode | Should -Be 'NOERROR'
        }

        It 'Should parse ResponseCode as NXDOMAIN' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[4].ResponseCode | Should -Be 'NXDOMAIN'
        }

        It 'Should parse ThreadId in uppercase hexadecimal' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[0].ThreadId | Should -Be '0B18'
        }
    }

    Context 'QueryName decoding' {

        It 'Should decode a simple label-encoded name' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[0].QueryName | Should -Be 'www.google.com'
        }

        It 'Should decode a multi-label name' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[2].QueryName | Should -Be 'server.contoso.com'
        }

        It 'Should decode a PTR record reverse name' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[5].QueryName | Should -Be '100.168.192.in-addr.arpa'
        }
    }

    Context 'Filter: Direction' {

        It 'Should return only Rcv entries when -Direction Rcv' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath -Direction Rcv
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object { $_.Direction | Should -Be 'Rcv' }
        }

        It 'Should return only Snd entries when -Direction Snd' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath -Direction Snd
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object { $_.Direction | Should -Be 'Snd' }
        }

        It 'Should return fewer entries when filtering by direction' {
            $all = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $filtered = Get-PSATDnsDebugLog -Path $script:TempLogPath -Direction Rcv
            $filtered.Count | Should -BeLessThan $all.Count
        }
    }

    Context 'Filter: RecordType' {

        It 'Should return only A records when -RecordType A' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath -RecordType A
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object { $_.RecordType | Should -Be 'A' }
        }

        It 'Should return only MX records when -RecordType MX' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath -RecordType MX
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object { $_.RecordType | Should -Be 'MX' }
        }

        It 'Should return empty when RecordType does not match any entry' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath -RecordType SRV
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Filter: ClientIP' {

        It 'Should return only entries matching the specified ClientIP' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath -ClientIP '10.0.0.50'
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object { $_.ClientIP | Should -Be '10.0.0.50' }
        }

        It 'Should return empty when ClientIP does not match any entry' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath -ClientIP '1.2.3.4'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Filter: QueryName' {

        It 'Should return entries matching an exact QueryName' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath -QueryName 'www.google.com'
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object { $_.QueryName | Should -Be 'www.google.com' }
        }

        It 'Should support wildcard patterns in QueryName' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath -QueryName '*.contoso.com'
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object { $_.QueryName | Should -BeLike '*.contoso.com' }
        }

        It 'Should return empty when QueryName does not match' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath -QueryName '*.fabrikam.com'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Filter: StartTime / EndTime' {

        It 'Should exclude entries before StartTime' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath -StartTime ([datetime]'4/9/2026 10:20:00 AM')
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object { $_.Timestamp | Should -BeGreaterOrEqual ([datetime]'4/9/2026 10:20:00 AM') }
        }

        It 'Should exclude entries after EndTime' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath -EndTime ([datetime]'4/9/2026 10:20:00 AM')
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object { $_.Timestamp | Should -BeLessOrEqual ([datetime]'4/9/2026 10:20:00 AM') }
        }

        It 'Should return only entries within a time range' {
            $start = [datetime]'4/9/2026 10:20:00 AM'
            $end   = [datetime]'4/9/2026 10:25:00 AM'
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath -StartTime $start -EndTime $end
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object {
                $_.Timestamp | Should -BeGreaterOrEqual $start
                $_.Timestamp | Should -BeLessOrEqual $end
            }
        }

        It 'Should return empty when time range matches no entries' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath `
                -StartTime ([datetime]'1/1/2000 00:00:00') `
                -EndTime ([datetime]'1/1/2000 01:00:00')
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Pipeline input' {

        It 'Should accept Path from the pipeline' {
            $result = $script:TempLogPath | Get-PSATDnsDebugLog
            $result | Should -HaveCount 6
        }

        It 'Should process multiple files from the pipeline' {
            $secondLog = Join-Path -Path $TestDrive -ChildPath 'dns2.log'
            $script:SampleLogLines | Set-Content -Path $secondLog -Encoding UTF8

            $result = @($script:TempLogPath, $secondLog) | Get-PSATDnsDebugLog
            $result | Should -HaveCount 12
        }
    }

    Context 'Output object structure' {

        It 'Should return PSCustomObject instances' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $result[0] | Should -BeOfType [PSCustomObject]
        }

        It 'Should expose all expected properties' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $properties = $result[0].PSObject.Properties.Name
            $properties | Should -Contain 'Timestamp'
            $properties | Should -Contain 'Protocol'
            $properties | Should -Contain 'Direction'
            $properties | Should -Contain 'ClientIP'
            $properties | Should -Contain 'TransactionId'
            $properties | Should -Contain 'MessageType'
            $properties | Should -Contain 'RecordType'
            $properties | Should -Contain 'QueryName'
            $properties | Should -Contain 'ResponseCode'
            $properties | Should -Contain 'Flags'
            $properties | Should -Contain 'ThreadId'
            $properties | Should -Contain 'SourceComputer'
        }

        It 'Should set SourceComputer to local machine name when no ComputerName is specified' {
            $result = Get-PSATDnsDebugLog -Path $script:TempLogPath
            $expected = if ($null -ne $env:COMPUTERNAME) { $env:COMPUTERNAME } else { [System.Net.Dns]::GetHostName() }
            $result[0].SourceComputer | Should -Be $expected
        }
    }

    Context 'Remote access' {

        BeforeEach {
            Mock -CommandName Invoke-Command -MockWith {
                param ($ComputerName, $ScriptBlock, $ArgumentList, $Credential, $ErrorAction)
                # Simulate the remote Get-Content returning sample lines.
                $script:SampleLogLines
            }
        }

        It 'Should call Invoke-Command when ComputerName is a remote host' {
            Get-PSATDnsDebugLog -Path 'C:\dns\dns.log' -ComputerName 'DC01'

            Should -Invoke Invoke-Command -Times 1 -ParameterFilter {
                $ComputerName -eq 'DC01'
            }
        }

        It 'Should pass Credential to Invoke-Command when provided' {
            $securePassword = ConvertTo-SecureString -String 'P@ssw0rd' -AsPlainText -Force
            $cred = [System.Management.Automation.PSCredential]::new('domain\user', $securePassword)

            Get-PSATDnsDebugLog -Path 'C:\dns\dns.log' -ComputerName 'DC01' -Credential $cred

            Should -Invoke Invoke-Command -Times 1 -ParameterFilter {
                $ComputerName -eq 'DC01' -and $null -ne $Credential
            }
        }

        It 'Should parse lines returned by Invoke-Command' {
            $result = Get-PSATDnsDebugLog -Path 'C:\dns\dns.log' -ComputerName 'DC01'
            $result | Should -HaveCount 6
        }

        It 'Should set SourceComputer to the remote ComputerName' {
            $result = Get-PSATDnsDebugLog -Path 'C:\dns\dns.log' -ComputerName 'DC01'
            $result[0].SourceComputer | Should -Be 'DC01'
        }

        It 'Should write an error when Invoke-Command fails' {
            Mock -CommandName Invoke-Command -MockWith {
                throw [System.Exception]::new('Connection refused')
            }

            { Get-PSATDnsDebugLog -Path 'C:\dns\dns.log' -ComputerName 'DC01' -ErrorAction Stop } |
                Should -Throw
        }

        It 'Should not call Invoke-Command when ComputerName is localhost' {
            Get-PSATDnsDebugLog -Path $script:TempLogPath -ComputerName 'localhost'

            Should -Invoke Invoke-Command -Times 0
        }

        It 'Should not call Invoke-Command when ComputerName is 127.0.0.1' {
            Get-PSATDnsDebugLog -Path $script:TempLogPath -ComputerName '127.0.0.1'

            Should -Invoke Invoke-Command -Times 0
        }

        It 'Should apply filters on remotely retrieved lines' {
            $result = Get-PSATDnsDebugLog -Path 'C:\dns\dns.log' -ComputerName 'DC01' -RecordType A
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object { $_.RecordType | Should -Be 'A' }
        }
    }
}
