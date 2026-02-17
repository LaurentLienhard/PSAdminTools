BeforeAll {
    $script:dscModuleName = 'PSAdminTools'

    # Ensure the module is loaded (it should be loaded by the build, but just in case)
    if (-not (Get-Module -Name $script:dscModuleName)) {
        Import-Module -Name $script:dscModuleName -ErrorAction SilentlyContinue
    }
}

Describe 'Get-PSATSitesReport' {
    BeforeAll {
        # Mock all AD cmdlets used by QueryAD
        Mock -CommandName Get-ADForest -ModuleName $script:dscModuleName {
            [PSCustomObject]@{
                Name                = 'contoso.com'
                PartitionsContainer = 'CN=Partitions,CN=Configuration,DC=contoso,DC=com'
            }
        }

        Mock -CommandName Get-ADReplicationSite -ModuleName $script:dscModuleName {
            @(
                [PSCustomObject]@{
                    Name        = 'Default-First-Site-Name'
                    Description = $null
                    Location    = $null
                }
            )
        }

        Mock -CommandName Get-ADReplicationSubnet -ModuleName $script:dscModuleName {
            @()
        }

        Mock -CommandName Get-ADReplicationSiteLink -ModuleName $script:dscModuleName {
            @()
        }

        Mock -CommandName Get-ADDomainController -ModuleName $script:dscModuleName {
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

            Should -Invoke -CommandName Get-ADForest -ModuleName $script:dscModuleName -ParameterFilter { $Server -eq 'dc01.contoso.com' }
        }

        It 'Should pass Credential parameter to AD cmdlets' {
            $testCred = [System.Management.Automation.PSCredential]::new(
                'testuser',
                (ConvertTo-SecureString 'password' -AsPlainText -Force)
            )

            Get-PSATSitesReport -Credential $testCred | Out-Null

            Should -Invoke -CommandName Get-ADForest -ModuleName $script:dscModuleName -ParameterFilter { $null -ne $Credential }
        }
    }

    Context 'Error handling - missing ActiveDirectory module' {
        It 'Should throw when ActiveDirectory module is not available' {
            Mock -CommandName Import-Module { throw [System.IO.FileNotFoundException]::new('Module not found') }

            { Get-PSATSitesReport -ErrorAction Stop } | Should -Throw '*ActiveDirectory module*'
        }
    }

    Context 'Error handling - AD query failure' {
        It 'Should throw on AD exception' {
            Mock -CommandName Get-ADForest -ModuleName $script:dscModuleName { throw [System.Exception]::new('AD server unavailable') }

            { Get-PSATSitesReport -ErrorAction Stop } | Should -Throw '*error*'
        }
    }

    Context 'Error handling - access denied' {
        It 'Should throw on unauthorized access' {
            Mock -CommandName Get-ADForest -ModuleName $script:dscModuleName { throw [System.UnauthorizedAccessException]::new('Access denied') }

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
