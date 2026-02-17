BeforeAll {
    # Load classes in dependency order
    $classesPath = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', '..', 'source', 'Classes'
    . (Join-Path -Path $classesPath -ChildPath '5.PSATSubnet.ps1')
    . (Join-Path -Path $classesPath -ChildPath '6.PSATSiteLink.ps1')
    . (Join-Path -Path $classesPath -ChildPath '7.PSATSite.ps1')
    . (Join-Path -Path $classesPath -ChildPath '8.PSATSitesReport.ps1')

    # Load the function
    $functionFile = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', '..', 'source', 'Public', 'Get-PSATSitesReport.ps1'
    . $functionFile
}

Describe 'Get-PSATSitesReport' {
    BeforeAll {
        # Mock Import-Module to prevent actual module loading
        Mock Import-Module {}

        # Mock all AD cmdlets used by QueryAD
        function Get-ADForest
        {
            param ($ErrorAction, $Server, $Credential)
        }
        function Get-ADReplicationSite
        {
            param ($Filter, $Properties, $ErrorAction, $Server, $Credential)
        }
        function Get-ADReplicationSubnet
        {
            param ($Filter, $Properties, $ErrorAction, $Server, $Credential)
        }
        function Get-ADReplicationSiteLink
        {
            param ($Filter, $Properties, $ErrorAction, $Server, $Credential)
        }
        function Get-ADDomainController
        {
            param ($Filter, $ErrorAction, $Server, $Credential)
        }

        Mock Get-ADForest {
            [PSCustomObject]@{
                Name                = 'contoso.com'
                PartitionsContainer = 'CN=Partitions,CN=Configuration,DC=contoso,DC=com'
            }
        }

        Mock Get-ADReplicationSite {
            @(
                [PSCustomObject]@{
                    Name        = 'Default-First-Site-Name'
                    Description = $null
                    Location    = $null
                }
            )
        }

        Mock Get-ADReplicationSubnet {
            @()
        }

        Mock Get-ADReplicationSiteLink {
            @()
        }

        Mock Get-ADDomainController {
            @(
                [PSCustomObject]@{
                    HostName = 'DC01.contoso.com'
                    Site     = 'Default-First-Site-Name'
                }
            )
        }
    }

    Context 'Successful execution' {
        It 'Should return a PSATSitesReport object' {
            $result = Get-PSATSitesReport

            $result.GetType().Name | Should -Be 'PSATSitesReport'
        }

        It 'Should populate the report with AD data' {
            $result = Get-PSATSitesReport

            $result.ForestName | Should -Be 'contoso.com'
            $result.TotalSites | Should -Be 1
            $result.TotalDomainControllers | Should -Be 1
        }

        It 'Should import the ActiveDirectory module' {
            Get-PSATSitesReport | Out-Null

            Should -Invoke Import-Module -ParameterFilter { $Name -eq 'ActiveDirectory' }
        }
    }

    Context 'Parameter pass-through' {
        It 'Should pass Server parameter to AD cmdlets' {
            Get-PSATSitesReport -Server 'dc01.contoso.com' | Out-Null

            Should -Invoke Get-ADForest -ParameterFilter { $Server -eq 'dc01.contoso.com' }
        }

        It 'Should pass Credential parameter to AD cmdlets' {
            $testCred = [System.Management.Automation.PSCredential]::new(
                'testuser',
                (ConvertTo-SecureString 'password' -AsPlainText -Force)
            )

            Get-PSATSitesReport -Credential $testCred | Out-Null

            Should -Invoke Get-ADForest -ParameterFilter { $null -ne $Credential }
        }
    }

    Context 'Error handling - missing ActiveDirectory module' {
        It 'Should throw when ActiveDirectory module is not available' {
            Mock Import-Module { throw [System.IO.FileNotFoundException]::new('Module not found') }

            { Get-PSATSitesReport -ErrorAction Stop } | Should -Throw '*ActiveDirectory module*'
        }
    }

    Context 'Error handling - AD query failure' {
        It 'Should throw on AD exception' {
            Mock Import-Module {}
            Mock Get-ADForest { throw [System.Exception]::new('AD server unavailable') }

            { Get-PSATSitesReport -ErrorAction Stop } | Should -Throw '*error*'
        }
    }

    Context 'Error handling - access denied' {
        It 'Should throw on unauthorized access' {
            Mock Import-Module {}
            Mock Get-ADForest { throw [System.UnauthorizedAccessException]::new('Access denied') }

            { Get-PSATSitesReport -ErrorAction Stop } | Should -Throw '*Access denied*'
        }
    }

    Context 'Function metadata' {
        It 'Should have CmdletBinding attribute' {
            $command = Get-Command -Name Get-PSATSitesReport
            $command.CmdletBinding | Should -BeTrue
        }

        It 'Should have Server parameter' {
            $command = Get-Command -Name Get-PSATSitesReport
            $command.Parameters['Server'] | Should -Not -BeNullOrEmpty
        }

        It 'Should have Credential parameter' {
            $command = Get-Command -Name Get-PSATSitesReport
            $command.Parameters['Credential'] | Should -Not -BeNullOrEmpty
        }

        It 'Should have OutputType of PSATSitesReport' {
            $command = Get-Command -Name Get-PSATSitesReport
            $command.OutputType.Type.Name | Should -Contain 'PSATSitesReport'
        }
    }
}
