BeforeAll {
    $script:ModuleRoot = Resolve-Path -Path "$PSScriptRoot/../../../source"
    . "$script:ModuleRoot/Classes/01_PSATDhcpScope.ps1"
    . "$script:ModuleRoot/Public/Get-PSATDhcpScopeInfo.ps1"

    # ------------------------------------------------------------------
    # Raw PSCustomObjects returned by the internal script block, as if
    # running on a real DHCP server via Invoke-Command.
    # ------------------------------------------------------------------
    $script:SampleRaw = @(
        [PSCustomObject]@{
            ScopeId          = '192.168.1.0'
            Name             = 'LAN - Site A'
            State            = 'Active'
            SubnetMask       = '255.255.255.0'
            StartRange       = '192.168.1.100'
            EndRange         = '192.168.1.200'
            LeaseDuration    = [timespan]'8.00:00:00'
            DnsServers       = [string[]]@('10.0.0.1', '10.0.0.2')
            DnsServersSource = 'Scope'
            DomainName       = 'contoso.com'
            Router           = [string[]]@('192.168.1.1')
        }
        [PSCustomObject]@{
            ScopeId          = '192.168.2.0'
            Name             = 'LAN - Site B'
            State            = 'Active'
            SubnetMask       = '255.255.255.0'
            StartRange       = '192.168.2.100'
            EndRange         = '192.168.2.200'
            LeaseDuration    = [timespan]'8.00:00:00'
            DnsServers       = [string[]]@('10.0.0.3')
            DnsServersSource = 'Server'
            DomainName       = 'contoso.com'
            Router           = [string[]]@('192.168.2.1')
        }
        [PSCustomObject]@{
            ScopeId          = '10.10.0.0'
            Name             = 'DMZ'
            State            = 'Inactive'
            SubnetMask       = '255.255.0.0'
            StartRange       = '10.10.0.100'
            EndRange         = '10.10.0.200'
            LeaseDuration    = [timespan]'1.00:00:00'
            DnsServers       = [string[]]@('10.0.0.1')
            DnsServersSource = 'Scope'
            DomainName       = 'dmz.contoso.com'
            Router           = [string[]]@('10.10.0.1')
        }
    )

    Mock -CommandName Invoke-Command -MockWith {
        param ($ComputerName, $ScriptBlock, $ArgumentList, $Credential, $ErrorAction)
        $includeInactive = if ($ArgumentList.Count -ge 2) { $ArgumentList[1] } else { $false }
        if ($includeInactive)
        {
            $script:SampleRaw
        }
        else
        {
            $script:SampleRaw | Where-Object -FilterScript { $_.State -eq 'Active' }
        }
    }
}

Describe 'Get-PSATDhcpScopeInfo' {

    Context 'Output type' {

        It 'Should return [PSATDhcpScope] instances' {
            $result = Get-PSATDhcpScopeInfo -ComputerName 'DHCP01'
            $result[0] | Should -BeOfType [PSATDhcpScope]
        }

        It 'Should return only [PSATDhcpScope] objects (no raw PSCustomObject)' {
            $result = Get-PSATDhcpScopeInfo -ComputerName 'DHCP01'
            $result | ForEach-Object { $_ | Should -BeOfType [PSATDhcpScope] }
        }

        It 'Should set ComputerName on each returned scope' {
            $result = Get-PSATDhcpScopeInfo -ComputerName 'DHCP01'
            $result | ForEach-Object { $_.ComputerName | Should -Be 'DHCP01' }
        }
    }

    Context 'Remote access' {

        It 'Should call Invoke-Command for a non-local ComputerName' {
            Get-PSATDhcpScopeInfo -ComputerName 'DHCP01'

            Should -Invoke Invoke-Command -Times 1 -ParameterFilter {
                $ComputerName -eq 'DHCP01'
            }
        }

        It 'Should pass Credential to Invoke-Command when provided' {
            $securePassword = ConvertTo-SecureString -String 'P@ssw0rd' -AsPlainText -Force
            $cred = [System.Management.Automation.PSCredential]::new('domain\user', $securePassword)

            Get-PSATDhcpScopeInfo -ComputerName 'DHCP01' -Credential $cred

            Should -Invoke Invoke-Command -Times 1 -ParameterFilter {
                $ComputerName -eq 'DHCP01' -and $null -ne $Credential
            }
        }

        It 'Should write an error when Invoke-Command fails' {
            Mock -CommandName Invoke-Command -MockWith { throw [System.Exception]::new('Connection refused') }

            { Get-PSATDhcpScopeInfo -ComputerName 'DHCP01' -ErrorAction Stop } | Should -Throw

            Mock -CommandName Invoke-Command -MockWith {
                param ($ComputerName, $ScriptBlock, $ArgumentList, $Credential, $ErrorAction)
                $includeInactive = if ($ArgumentList.Count -ge 2) { $ArgumentList[1] } else { $false }
                if ($includeInactive) { $script:SampleRaw }
                else { $script:SampleRaw | Where-Object -FilterScript { $_.State -eq 'Active' } }
            }
        }

        It 'Should not call Invoke-Command for localhost' {
            Mock -CommandName Invoke-Command -MockWith { }
            Get-PSATDhcpScopeInfo -ComputerName 'localhost' -ErrorAction SilentlyContinue
            Should -Invoke Invoke-Command -Times 0
        }
    }

    Context 'Active / Inactive filtering' {

        It 'Should return only Active scopes by default' {
            $result = Get-PSATDhcpScopeInfo -ComputerName 'DHCP01'
            $result | ForEach-Object { $_.State | Should -Be 'Active' }
        }

        It 'Should return inactive scopes when -IncludeInactive is set' {
            $result = Get-PSATDhcpScopeInfo -ComputerName 'DHCP01' -IncludeInactive
            $result.State | Should -Contain 'Inactive'
        }

        It 'Should return more scopes with -IncludeInactive than without' {
            $active = Get-PSATDhcpScopeInfo -ComputerName 'DHCP01'
            $all    = Get-PSATDhcpScopeInfo -ComputerName 'DHCP01' -IncludeInactive
            $all.Count | Should -BeGreaterThan $active.Count
        }
    }

    Context 'Filter: -DnsServer' {

        It 'Should return only scopes containing the specified DNS server IP' {
            $result = Get-PSATDhcpScopeInfo -ComputerName 'DHCP01' -DnsServer '10.0.0.1'
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object { $_.HasDnsServer('10.0.0.1') | Should -BeTrue }
        }

        It 'Should return scopes matching any of the specified DNS server IPs' {
            $result = Get-PSATDhcpScopeInfo -ComputerName 'DHCP01' -DnsServer '10.0.0.2', '10.0.0.3'
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object {
                $_.HasAnyDnsServer(@('10.0.0.2', '10.0.0.3')) | Should -BeTrue
            }
        }

        It 'Should return empty when no scope has the specified DNS server' {
            $result = Get-PSATDhcpScopeInfo -ComputerName 'DHCP01' -DnsServer '1.2.3.4'
            $result | Should -BeNullOrEmpty
        }

        It 'Should find DNS server inherited from server level (DnsServersSource = Server)' {
            $result = Get-PSATDhcpScopeInfo -ComputerName 'DHCP01' -DnsServer '10.0.0.3'
            $result | Should -Not -BeNullOrEmpty
            ($result | Where-Object { $_.ScopeId -eq '192.168.2.0' }) | Should -Not -BeNullOrEmpty
        }

        It 'Should also search inactive scopes when -IncludeInactive is combined with -DnsServer' {
            $result = Get-PSATDhcpScopeInfo -ComputerName 'DHCP01' -IncludeInactive -DnsServer '10.0.0.1'
            $result.ScopeId | Should -Contain '10.10.0.0'
        }
    }

    Context 'Filter: -ScopeId' {

        It 'Should pass ScopeId filter to the remote script block' {
            Get-PSATDhcpScopeInfo -ComputerName 'DHCP01' -ScopeId '192.168.1.0'

            Should -Invoke Invoke-Command -Times 1 -ParameterFilter {
                $ArgumentList[0] -contains '192.168.1.0'
            }
        }
    }

    Context 'Pipeline input' {

        It 'Should accept ComputerName from the pipeline' {
            $result = 'DHCP01' | Get-PSATDhcpScopeInfo
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should aggregate results from multiple servers passed via pipeline' {
            $result = 'DHCP01', 'DHCP02' | Get-PSATDhcpScopeInfo
            ($result | Where-Object { $_.ComputerName -eq 'DHCP01' }) | Should -Not -BeNullOrEmpty
            ($result | Where-Object { $_.ComputerName -eq 'DHCP02' }) | Should -Not -BeNullOrEmpty
        }

        It 'Should continue processing remaining servers when one fails' {
            Mock -CommandName Invoke-Command -MockWith {
                param ($ComputerName, $ScriptBlock, $ArgumentList, $Credential, $ErrorAction)
                if ($ComputerName -eq 'DHCP-BROKEN') { throw [System.Exception]::new('Connection refused') }
                $script:SampleRaw | Where-Object -FilterScript { $_.State -eq 'Active' }
            }

            $result = 'DHCP-BROKEN', 'DHCP01' | Get-PSATDhcpScopeInfo -ErrorAction SilentlyContinue
            ($result | Where-Object { $_.ComputerName -eq 'DHCP01' }) | Should -Not -BeNullOrEmpty

            Mock -CommandName Invoke-Command -MockWith {
                param ($ComputerName, $ScriptBlock, $ArgumentList, $Credential, $ErrorAction)
                $includeInactive = if ($ArgumentList.Count -ge 2) { $ArgumentList[1] } else { $false }
                if ($includeInactive) { $script:SampleRaw }
                else { $script:SampleRaw | Where-Object -FilterScript { $_.State -eq 'Active' } }
            }
        }
    }

    Context 'Class method integration' {

        It 'HasDnsServer should work on returned objects' {
            $result = Get-PSATDhcpScopeInfo -ComputerName 'DHCP01'
            $scope  = $result | Where-Object { $_.ScopeId -eq '192.168.1.0' }
            $scope.HasDnsServer('10.0.0.1') | Should -BeTrue
            $scope.HasDnsServer('9.9.9.9')  | Should -BeFalse
        }

        It 'HasAnyDnsServer should work on returned objects' {
            $result = Get-PSATDhcpScopeInfo -ComputerName 'DHCP01'
            $scope  = $result | Where-Object { $_.ScopeId -eq '192.168.1.0' }
            $scope.HasAnyDnsServer(@('9.9.9.9', '10.0.0.2')) | Should -BeTrue
        }

        It 'ToString should return a meaningful string on returned objects' {
            $result = Get-PSATDhcpScopeInfo -ComputerName 'DHCP01'
            $result[0].ToString() | Should -Match 'DHCP01'
        }
    }
}
