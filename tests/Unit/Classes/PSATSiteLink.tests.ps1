BeforeAll {
    $classFile = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', '..', 'source', 'Classes', '6.PSATSiteLink.ps1'
    . $classFile
}

Describe 'PSATSiteLink' {
    Context 'Default constructor' {
        BeforeAll {
            $siteLink = [PSATSiteLink]::new()
        }

        It 'Should create an instance' {
            $null -ne $siteLink | Should -BeTrue
            $siteLink.GetType().Name | Should -Be 'PSATSiteLink'
        }

        It 'Should have default property values' {
            $siteLink.Name | Should -BeNullOrEmpty
            $siteLink.Cost | Should -Be 0
            $siteLink.ReplicationFrequencyInMinutes | Should -Be 0
            $siteLink.TransportType | Should -BeNullOrEmpty
            $siteLink.Description | Should -BeNullOrEmpty
        }

        It 'Should initialize SitesIncluded as empty list' {
            $siteLink.SitesIncluded.Count | Should -Be 0
            $siteLink.SitesIncluded.GetType().Name | Should -Be 'List`1'
        }
    }

    Context 'Hashtable constructor' {
        BeforeAll {
            $properties = @{
                Name                         = 'Paris-London'
                Cost                         = 100
                ReplicationFrequencyInMinutes = 180
                SitesIncluded                = @('Paris', 'London')
                TransportType                = 'IP'
                Description                  = 'Link between Paris and London'
                Schedule                     = @([byte]0x01, [byte]0x02)
            }
            $siteLink = [PSATSiteLink]::new($properties)
        }

        It 'Should set Name property' {
            $siteLink.Name | Should -Be 'Paris-London'
        }

        It 'Should set Cost property' {
            $siteLink.Cost | Should -Be 100
        }

        It 'Should set ReplicationFrequencyInMinutes property' {
            $siteLink.ReplicationFrequencyInMinutes | Should -Be 180
        }

        It 'Should set TransportType property' {
            $siteLink.TransportType | Should -Be 'IP'
        }

        It 'Should set Description property' {
            $siteLink.Description | Should -Be 'Link between Paris and London'
        }

        It 'Should populate SitesIncluded list' {
            $siteLink.SitesIncluded.Count | Should -Be 2
            $siteLink.SitesIncluded[0] | Should -Be 'Paris'
            $siteLink.SitesIncluded[1] | Should -Be 'London'
        }

        It 'Should set Schedule as hidden property' {
            $siteLink.Schedule | Should -Not -BeNullOrEmpty
            $siteLink.Schedule.Count | Should -Be 2
        }
    }

    Context 'Hidden Schedule property' {
        BeforeAll {
            $siteLink = [PSATSiteLink]::new()
        }

        It 'Should not appear in default output' {
            $defaultProperties = $siteLink |
                Get-Member -MemberType Property |
                Where-Object { $_.Name -eq 'Schedule' }

            $defaultProperties | Should -BeNullOrEmpty
        }

        It 'Should be accessible via -Force' {
            $siteLinkWithSchedule = [PSATSiteLink]::new(@{
                Name     = 'Test'
                Schedule = @([byte]0xFF)
            })

            $hiddenProperty = $siteLinkWithSchedule |
                Get-Member -MemberType Property -Force |
                Where-Object { $_.Name -eq 'Schedule' }

            $null -ne $hiddenProperty | Should -BeTrue
        }
    }

    Context 'ToString method' {
        It 'Should return formatted string with cost and frequency' {
            $siteLink = [PSATSiteLink]::new(@{
                Name                         = 'Paris-London'
                Cost                         = 100
                ReplicationFrequencyInMinutes = 180
            })

            $siteLink.ToString() | Should -Be 'Paris-London (Cost: 100, Frequency: 180 min)'
        }
    }
}
