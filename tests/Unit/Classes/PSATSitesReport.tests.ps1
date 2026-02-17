BeforeAll {
    $script:dscModuleName = 'PSAdminTools'

    # Ensure the module is loaded (it should be loaded by the build, but just in case)
    if (-not (Get-Module -Name $script:dscModuleName)) {
        Import-Module -Name $script:dscModuleName -ErrorAction SilentlyContinue
    }
}

Describe 'PSATSitesReport' {
    Context 'Constructor' {
        BeforeAll {
            $report = [PSATSitesReport]::new()
        }

        It 'Should create an instance' {
            $null -ne $report | Should -BeTrue
            $report.GetType().Name | Should -Be 'PSATSitesReport'
        }

        It 'Should set ReportDate to current time' {
            $report.ReportDate | Should -BeOfType 'datetime'
            ($report.ReportDate - [datetime]::Now).TotalSeconds | Should -BeLessThan 5
        }

        It 'Should initialize Sites as empty list' {
            $report.Sites.Count | Should -Be 0
        }

        It 'Should initialize Subnets as empty list' {
            $report.Subnets.Count | Should -Be 0
        }

        It 'Should initialize SiteLinks as empty list' {
            $report.SiteLinks.Count | Should -Be 0
        }

        It 'Should initialize health indicator lists as empty' {
            $report.SitesWithoutDC.Count | Should -Be 0
            $report.SitesWithoutSubnets.Count | Should -Be 0
            $report.SubnetsWithoutSites.Count | Should -Be 0
        }
    }

    Context 'ComputeSummary' {
        BeforeAll {
            $report = [PSATSitesReport]::new()
            $report.ForestName = 'contoso.com'

            # Site with DC and subnet
            $site1 = [PSATSite]::new(@{ Name = 'Paris' })
            $site1.DomainControllers.Add('DC01.contoso.com')
            $site1.DomainControllers.Add('DC02.contoso.com')
            $site1.Subnets.Add('10.0.1.0/24')
            $report.Sites.Add($site1)

            # Site without DC but with subnet
            $site2 = [PSATSite]::new(@{ Name = 'London' })
            $site2.Subnets.Add('10.0.2.0/24')
            $report.Sites.Add($site2)

            # Site without DC and without subnet
            $site3 = [PSATSite]::new(@{ Name = 'Berlin' })
            $report.Sites.Add($site3)

            # Subnets
            $report.Subnets.Add([PSATSubnet]::new(@{ Name = '10.0.1.0/24'; SiteName = 'Paris' }))
            $report.Subnets.Add([PSATSubnet]::new(@{ Name = '10.0.2.0/24'; SiteName = 'London' }))
            $report.Subnets.Add([PSATSubnet]::new(@{ Name = '10.0.3.0/24' }))

            # Site links
            $report.SiteLinks.Add([PSATSiteLink]::new(@{
                Name                         = 'Paris-London'
                Cost                         = 100
                ReplicationFrequencyInMinutes = 180
            }))

            $report.ComputeSummary()
        }

        It 'Should compute TotalSites' {
            $report.TotalSites | Should -Be 3
        }

        It 'Should compute TotalSubnets' {
            $report.TotalSubnets | Should -Be 3
        }

        It 'Should compute TotalSiteLinks' {
            $report.TotalSiteLinks | Should -Be 1
        }

        It 'Should compute TotalDomainControllers' {
            $report.TotalDomainControllers | Should -Be 2
        }

        It 'Should identify sites without domain controllers' {
            $report.SitesWithoutDC.Count | Should -Be 2
            $report.SitesWithoutDC | Should -Contain 'London'
            $report.SitesWithoutDC | Should -Contain 'Berlin'
        }

        It 'Should identify sites without subnets' {
            $report.SitesWithoutSubnets.Count | Should -Be 1
            $report.SitesWithoutSubnets | Should -Contain 'Berlin'
        }

        It 'Should identify subnets without sites' {
            $report.SubnetsWithoutSites.Count | Should -Be 1
            $report.SubnetsWithoutSites | Should -Contain '10.0.3.0/24'
        }
    }

    Context 'ComputeSummary with empty report' {
        It 'Should handle empty collections' {
            $report = [PSATSitesReport]::new()
            $report.ComputeSummary()

            $report.TotalSites | Should -Be 0
            $report.TotalSubnets | Should -Be 0
            $report.TotalSiteLinks | Should -Be 0
            $report.TotalDomainControllers | Should -Be 0
            $report.SitesWithoutDC.Count | Should -Be 0
            $report.SitesWithoutSubnets.Count | Should -Be 0
            $report.SubnetsWithoutSites.Count | Should -Be 0
        }
    }

    Context 'ComputeSummary idempotency' {
        It 'Should produce same results when called multiple times' {
            $report = [PSATSitesReport]::new()
            $site = [PSATSite]::new(@{ Name = 'TestSite' })
            $report.Sites.Add($site)

            $report.ComputeSummary()
            $report.ComputeSummary()

            $report.SitesWithoutDC.Count | Should -Be 1
            $report.SitesWithoutSubnets.Count | Should -Be 1
        }
    }

    Context 'ToString' {
        It 'Should return formatted summary string' {
            $report = [PSATSitesReport]::new()
            $report.ForestName = 'contoso.com'
            $report.TotalSites = 3
            $report.TotalSubnets = 5
            $report.TotalSiteLinks = 2
            $report.TotalDomainControllers = 4

            $report.ToString() | Should -Be 'AD Sites Report for contoso.com - 3 Sites, 5 Subnets, 2 Site Links, 4 DCs'
        }
    }

    Context 'QueryAD method' {
        BeforeAll {
            Mock -CommandName Get-ADForest -ModuleName $script:dscModuleName {
                [PSCustomObject]@{
                    Name                = 'contoso.com'
                    PartitionsContainer = 'CN=Partitions,CN=Configuration,DC=contoso,DC=com'
                }
            }

            Mock -CommandName Get-ADReplicationSite -ModuleName $script:dscModuleName {
                @(
                    [PSCustomObject]@{
                        Name        = 'Paris'
                        Description = 'Paris site'
                        Location    = 'FR'
                    },
                    [PSCustomObject]@{
                        Name        = 'London'
                        Description = 'London site'
                        Location    = 'UK'
                    }
                )
            }

            Mock -CommandName Get-ADReplicationSubnet -ModuleName $script:dscModuleName {
                @(
                    [PSCustomObject]@{
                        Name              = '10.0.1.0/24'
                        Site              = 'CN=Paris,CN=Sites,CN=Configuration,DC=contoso,DC=com'
                        Location          = 'FR'
                        Description       = 'Paris subnet'
                        DistinguishedName = 'CN=10.0.1.0/24,CN=Subnets,CN=Sites,CN=Configuration,DC=contoso,DC=com'
                    }
                )
            }

            Mock -CommandName Get-ADReplicationSiteLink -ModuleName $script:dscModuleName {
                @(
                    [PSCustomObject]@{
                        Name                         = 'Paris-London'
                        Cost                         = 100
                        ReplicationFrequencyInMinutes = 180
                        SitesIncluded                = @(
                            'CN=Paris,CN=Sites,CN=Configuration,DC=contoso,DC=com',
                            'CN=London,CN=Sites,CN=Configuration,DC=contoso,DC=com'
                        )
                        Description                  = 'Main link'
                        DistinguishedName            = 'CN=Paris-London,CN=IP,CN=Inter-Site Transports,CN=Sites,CN=Configuration,DC=contoso,DC=com'
                        Schedule                     = $null
                    }
                )
            }

            Mock -CommandName Get-ADDomainController -ModuleName $script:dscModuleName {
                @(
                    [PSCustomObject]@{
                        HostName = 'DC01.contoso.com'
                        Site     = 'Paris'
                    }
                )
            }
        }

        It 'Should populate report from AD data' {
            $report = [PSATSitesReport]::new()
            $report.QueryAD(@{})

            $report.ForestName | Should -Be 'contoso.com'
            $report.TotalSites | Should -Be 2
            $report.TotalSubnets | Should -Be 1
            $report.TotalSiteLinks | Should -Be 1
            $report.TotalDomainControllers | Should -Be 1
        }

        It 'Should assign DCs to correct sites' {
            $report = [PSATSitesReport]::new()
            $report.QueryAD(@{})

            $parisSite = $report.Sites | Where-Object { $_.Name -eq 'Paris' }
            $parisSite.DomainControllers | Should -Contain 'DC01.contoso.com'

            $londonSite = $report.Sites | Where-Object { $_.Name -eq 'London' }
            $londonSite.DomainControllers.Count | Should -Be 0
        }

        It 'Should assign subnets to correct sites' {
            $report = [PSATSitesReport]::new()
            $report.QueryAD(@{})

            $parisSite = $report.Sites | Where-Object { $_.Name -eq 'Paris' }
            $parisSite.Subnets | Should -Contain '10.0.1.0/24'
        }

        It 'Should assign site links to sites' {
            $report = [PSATSitesReport]::new()
            $report.QueryAD(@{})

            $parisSite = $report.Sites | Where-Object { $_.Name -eq 'Paris' }
            $parisSite.SiteLinks | Should -Contain 'Paris-London'

            $londonSite = $report.Sites | Where-Object { $_.Name -eq 'London' }
            $londonSite.SiteLinks | Should -Contain 'Paris-London'
        }

        It 'Should compute adjacent sites' {
            $report = [PSATSitesReport]::new()
            $report.QueryAD(@{})

            $parisSite = $report.Sites | Where-Object { $_.Name -eq 'Paris' }
            $parisSite.AdjacentSites | Should -Contain 'London'

            $londonSite = $report.Sites | Where-Object { $_.Name -eq 'London' }
            $londonSite.AdjacentSites | Should -Contain 'Paris'
        }

        It 'Should extract transport type from DN' {
            $report = [PSATSitesReport]::new()
            $report.QueryAD(@{})

            $report.SiteLinks[0].TransportType | Should -Be 'IP'
        }

        It 'Should identify health issues' {
            $report = [PSATSitesReport]::new()
            $report.QueryAD(@{})

            $report.SitesWithoutDC | Should -Contain 'London'
            $report.SitesWithoutSubnets | Should -Contain 'London'
        }

        It 'Should pass Server parameter to AD cmdlets' {
            $report = [PSATSitesReport]::new()
            $report.QueryAD(@{ Server = 'dc01.contoso.com' })

            Should -Invoke -CommandName Get-ADForest -ModuleName $script:dscModuleName -ParameterFilter { $Server -eq 'dc01.contoso.com' }
        }
    }
}
