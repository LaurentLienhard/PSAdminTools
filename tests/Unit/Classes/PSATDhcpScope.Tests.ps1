BeforeAll {
    $script:ModuleRoot = Resolve-Path -Path "$PSScriptRoot/../../../source"
    . "$script:ModuleRoot/Classes/01_PSATDhcpScope.ps1"

    # Helper: create a default scope instance for tests.
    function New-TestScope
    {
        param (
            [string[]]$DnsServers       = @('10.0.0.1', '10.0.0.2'),
            [string]  $DnsServersSource = 'Scope',
            [string]  $State            = 'Active'
        )

        [PSATDhcpScope]::new(
            'DHCP01',
            '192.168.1.0',
            'LAN - Site A',
            $State,
            '255.255.255.0',
            '192.168.1.100',
            '192.168.1.200',
            [timespan]'8.00:00:00',
            $DnsServers,
            $DnsServersSource,
            'contoso.com',
            [string[]]@('192.168.1.1')
        )
    }
}

Describe 'PSATDhcpScope' {

    Context 'Constructor' {

        It 'Should instantiate without error' {
            { New-TestScope } | Should -Not -Throw
        }

        It 'Should set ComputerName correctly' {
            (New-TestScope).ComputerName | Should -Be 'DHCP01'
        }

        It 'Should set ScopeId correctly' {
            (New-TestScope).ScopeId | Should -Be '192.168.1.0'
        }

        It 'Should set Name correctly' {
            (New-TestScope).Name | Should -Be 'LAN - Site A'
        }

        It 'Should set State correctly' {
            (New-TestScope).State | Should -Be 'Active'
        }

        It 'Should set SubnetMask correctly' {
            (New-TestScope).SubnetMask | Should -Be '255.255.255.0'
        }

        It 'Should set StartRange correctly' {
            (New-TestScope).StartRange | Should -Be '192.168.1.100'
        }

        It 'Should set EndRange correctly' {
            (New-TestScope).EndRange | Should -Be '192.168.1.200'
        }

        It 'Should set LeaseDuration as a TimeSpan' {
            (New-TestScope).LeaseDuration | Should -BeOfType [timespan]
        }

        It 'Should set DnsServers correctly' {
            $scope = New-TestScope
            $scope.DnsServers | Should -Contain '10.0.0.1'
            $scope.DnsServers | Should -Contain '10.0.0.2'
        }

        It 'Should set DnsServersSource correctly' {
            (New-TestScope).DnsServersSource | Should -Be 'Scope'
        }

        It 'Should set DomainName correctly' {
            (New-TestScope).DomainName | Should -Be 'contoso.com'
        }

        It 'Should set Router correctly' {
            (New-TestScope).Router | Should -Contain '192.168.1.1'
        }
    }

    Context 'Method: HasDnsServer' {

        It 'Should return $true when the IP is in DnsServers' {
            (New-TestScope).HasDnsServer('10.0.0.1') | Should -BeTrue
        }

        It 'Should return $true for the second DNS server' {
            (New-TestScope).HasDnsServer('10.0.0.2') | Should -BeTrue
        }

        It 'Should return $false when the IP is not in DnsServers' {
            (New-TestScope).HasDnsServer('1.2.3.4') | Should -BeFalse
        }

        It 'Should return $false for an empty DnsServers list' {
            $scope = New-TestScope -DnsServers @()
            $scope.HasDnsServer('10.0.0.1') | Should -BeFalse
        }

        It 'Should perform an exact match (not partial)' {
            (New-TestScope).HasDnsServer('10.0.0') | Should -BeFalse
        }
    }

    Context 'Method: HasAnyDnsServer' {

        It 'Should return $true when at least one IP matches' {
            (New-TestScope).HasAnyDnsServer(@('10.0.0.1', '9.9.9.9')) | Should -BeTrue
        }

        It 'Should return $true when all IPs match' {
            (New-TestScope).HasAnyDnsServer(@('10.0.0.1', '10.0.0.2')) | Should -BeTrue
        }

        It 'Should return $false when no IP matches' {
            (New-TestScope).HasAnyDnsServer(@('1.1.1.1', '9.9.9.9')) | Should -BeFalse
        }

        It 'Should return $false for an empty input list' {
            (New-TestScope).HasAnyDnsServer(@()) | Should -BeFalse
        }

        It 'Should return $false when DnsServers is empty' {
            $scope = New-TestScope -DnsServers @()
            $scope.HasAnyDnsServer(@('10.0.0.1')) | Should -BeFalse
        }
    }

    Context 'Method: ToString' {

        It 'Should return a non-empty string' {
            (New-TestScope).ToString() | Should -Not -BeNullOrEmpty
        }

        It 'Should include ComputerName in the output' {
            (New-TestScope).ToString() | Should -Match 'DHCP01'
        }

        It 'Should include ScopeId in the output' {
            (New-TestScope).ToString() | Should -Match '192\.168\.1\.0'
        }

        It 'Should include State in the output' {
            (New-TestScope).ToString() | Should -Match 'Active'
        }

        It 'Should include DNS servers in the output' {
            (New-TestScope).ToString() | Should -Match '10\.0\.0\.1'
        }
    }

    Context 'Property types' {

        It 'DnsServers should be a string array' {
            (New-TestScope).DnsServers.GetType().IsArray | Should -BeTrue
        }

        It 'Router should be a string array' {
            (New-TestScope).Router.GetType().IsArray | Should -BeTrue
        }

        It 'LeaseDuration should be a TimeSpan' {
            (New-TestScope).LeaseDuration | Should -BeOfType [timespan]
        }
    }
}
