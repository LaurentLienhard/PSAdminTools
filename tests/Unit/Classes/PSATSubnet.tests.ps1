BeforeAll {
    $script:dscModuleName = 'PSAdminTools'

    # Ensure the module is loaded (it should be loaded by the build, but just in case)
    if (-not (Get-Module -Name $script:dscModuleName)) {
        Import-Module -Name $script:dscModuleName -ErrorAction SilentlyContinue
    }
}

Describe 'PSATSubnet' {
    Context 'Default constructor' {
        BeforeAll {
            $subnet = [PSATSubnet]::new()
        }

        It 'Should create an instance' {
            $null -ne $subnet | Should -BeTrue
            $subnet.GetType().Name | Should -Be 'PSATSubnet'
        }

        It 'Should have null or empty default properties' {
            $subnet.Name | Should -BeNullOrEmpty
            $subnet.SiteName | Should -BeNullOrEmpty
            $subnet.Location | Should -BeNullOrEmpty
            $subnet.Description | Should -BeNullOrEmpty
            $subnet.DistinguishedName | Should -BeNullOrEmpty
        }
    }

    Context 'Hashtable constructor' {
        BeforeAll {
            $properties = @{
                Name              = '10.0.1.0/24'
                SiteName          = 'Paris'
                Location          = 'FR-PAR-DC1'
                Description       = 'Paris office subnet'
                DistinguishedName = 'CN=10.0.1.0/24,CN=Subnets,CN=Sites,CN=Configuration,DC=contoso,DC=com'
            }
            $subnet = [PSATSubnet]::new($properties)
        }

        It 'Should set Name property' {
            $subnet.Name | Should -Be '10.0.1.0/24'
        }

        It 'Should set SiteName property' {
            $subnet.SiteName | Should -Be 'Paris'
        }

        It 'Should set Location property' {
            $subnet.Location | Should -Be 'FR-PAR-DC1'
        }

        It 'Should set Description property' {
            $subnet.Description | Should -Be 'Paris office subnet'
        }

        It 'Should set DistinguishedName property' {
            $subnet.DistinguishedName | Should -Be 'CN=10.0.1.0/24,CN=Subnets,CN=Sites,CN=Configuration,DC=contoso,DC=com'
        }
    }

    Context 'ToString method' {
        It 'Should return name with site when SiteName is set' {
            $subnet = [PSATSubnet]::new(@{
                Name     = '10.0.1.0/24'
                SiteName = 'Paris'
            })

            $subnet.ToString() | Should -Be '10.0.1.0/24 (Site: Paris)'
        }

        It 'Should return only name when SiteName is empty' {
            $subnet = [PSATSubnet]::new(@{
                Name = '10.0.2.0/24'
            })

            $subnet.ToString() | Should -Be '10.0.2.0/24'
        }
    }
}
