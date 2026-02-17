BeforeAll {
    $classFile = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', '..', 'source', 'Classes', '7.PSATSite.ps1'
    . $classFile
}

Describe 'PSATSite' {
    Context 'Default constructor' {
        BeforeAll {
            $site = [PSATSite]::new()
        }

        It 'Should create an instance' {
            $null -ne $site | Should -BeTrue
            $site.GetType().Name | Should -Be 'PSATSite'
        }

        It 'Should have empty string properties' {
            $site.Name | Should -BeNullOrEmpty
            $site.Description | Should -BeNullOrEmpty
            $site.Location | Should -BeNullOrEmpty
        }

        It 'Should initialize Subnets as empty list' {
            $site.Subnets.Count | Should -Be 0
        }

        It 'Should initialize SiteLinks as empty list' {
            $site.SiteLinks.Count | Should -Be 0
        }

        It 'Should initialize DomainControllers as empty list' {
            $site.DomainControllers.Count | Should -Be 0
        }

        It 'Should initialize AdjacentSites as empty list' {
            $site.AdjacentSites.Count | Should -Be 0
        }
    }

    Context 'Hashtable constructor' {
        BeforeAll {
            $properties = @{
                Name        = 'Paris'
                Description = 'Paris headquarters site'
                Location    = 'FR-PAR'
            }
            $site = [PSATSite]::new($properties)
        }

        It 'Should set Name property' {
            $site.Name | Should -Be 'Paris'
        }

        It 'Should set Description property' {
            $site.Description | Should -Be 'Paris headquarters site'
        }

        It 'Should set Location property' {
            $site.Location | Should -Be 'FR-PAR'
        }

        It 'Should initialize list properties as empty' {
            $site.Subnets.Count | Should -Be 0
            $site.SiteLinks.Count | Should -Be 0
            $site.DomainControllers.Count | Should -Be 0
            $site.AdjacentSites.Count | Should -Be 0
        }
    }

    Context 'HasDomainControllers method' {
        It 'Should return false when no domain controllers are assigned' {
            $site = [PSATSite]::new(@{ Name = 'EmptySite' })

            $site.HasDomainControllers() | Should -BeFalse
        }

        It 'Should return true when domain controllers are assigned' {
            $site = [PSATSite]::new(@{ Name = 'ActiveSite' })
            $site.DomainControllers.Add('DC01.contoso.com')

            $site.HasDomainControllers() | Should -BeTrue
        }

        It 'Should return true with multiple domain controllers' {
            $site = [PSATSite]::new(@{ Name = 'MultiDCSite' })
            $site.DomainControllers.Add('DC01.contoso.com')
            $site.DomainControllers.Add('DC02.contoso.com')

            $site.HasDomainControllers() | Should -BeTrue
        }
    }

    Context 'ToString method' {
        It 'Should return formatted string with DC and subnet counts' {
            $site = [PSATSite]::new(@{ Name = 'Paris' })
            $site.DomainControllers.Add('DC01.contoso.com')
            $site.Subnets.Add('10.0.1.0/24')
            $site.Subnets.Add('10.0.2.0/24')

            $site.ToString() | Should -Be 'Paris (DCs: 1, Subnets: 2)'
        }

        It 'Should show zero counts for empty site' {
            $site = [PSATSite]::new(@{ Name = 'EmptySite' })

            $site.ToString() | Should -Be 'EmptySite (DCs: 0, Subnets: 0)'
        }
    }
}
