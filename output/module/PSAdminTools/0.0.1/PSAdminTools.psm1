#Region './Classes/1.class1.ps1' -1

class Class1
{
    [string]$Name = 'Class1'

    Class1()
    {
        #default Constructor
    }

    [String] ToString()
    {
        # Typo "calss" is intentional
        return ( 'This calss is {0}' -f $this.Name)
    }
}
#EndRegion './Classes/1.class1.ps1' 16
#Region './Classes/2.class2.ps1' -1

class Class2
{
    [string]$Name = 'Class2'

    Class2()
    {
        #default constructor
    }

    [String] ToString()
    {
        return ( 'This calss is {0}' -f $this.Name)
    }
}
#EndRegion './Classes/2.class2.ps1' 15
#Region './Classes/3.class11.ps1' -1

class Class11 : Class1
{
    [string]$Name = 'Class11'

    Class11 ()
    {
    }

    [String] ToString()
    {
        return ( 'This calss is {0}:{1}' -f $this.Name,'class1')
    }
}
#EndRegion './Classes/3.class11.ps1' 14
#Region './Classes/4.class12.ps1' -1

class Class12 : Class1
{
    [string]$Name = 'Class12'

    Class12 ()
    {
    }

    [String] ToString()
    {
        return ( 'This calss is {0}:{1}' -f $this.Name,'class1')
    }
}
#EndRegion './Classes/4.class12.ps1' 14
#Region './Classes/5.PSATSubnet.ps1' -1

class PSATSubnet
{
    #region <Properties>
    [string]$Name
    [string]$SiteName
    [string]$Location
    [string]$Description
    [string]$DistinguishedName
    #endregion <Properties>

    #region <Constructor>
    PSATSubnet ()
    {
    }

    PSATSubnet ([hashtable]$Properties)
    {
        $this.Name              = $Properties['Name']
        $this.SiteName          = $Properties['SiteName']
        $this.Location          = $Properties['Location']
        $this.Description       = $Properties['Description']
        $this.DistinguishedName = $Properties['DistinguishedName']
    }
    #endregion <Constructor>

    #region <Methods>
    [string] ToString ()
    {
        if ($this.SiteName)
        {
            return ('{0} (Site: {1})' -f $this.Name, $this.SiteName)
        }
        return $this.Name
    }
    #endregion <Methods>
}
#EndRegion './Classes/5.PSATSubnet.ps1' 37
#Region './Classes/6.PSATSiteLink.ps1' -1

class PSATSiteLink
{
    #region <Properties>
    [string]$Name
    [int]$Cost
    [int]$ReplicationFrequencyInMinutes
    [System.Collections.Generic.List[string]]$SitesIncluded
    [string]$TransportType
    [string]$Description
    HIDDEN [byte[]]$Schedule
    #endregion <Properties>

    #region <Constructor>
    PSATSiteLink ()
    {
        $this.SitesIncluded = [System.Collections.Generic.List[string]]::new()
    }

    PSATSiteLink ([hashtable]$Properties)
    {
        $this.SitesIncluded = [System.Collections.Generic.List[string]]::new()

        $this.Name                         = $Properties['Name']
        $this.Cost                         = $Properties['Cost']
        $this.ReplicationFrequencyInMinutes = $Properties['ReplicationFrequencyInMinutes']
        $this.TransportType                = $Properties['TransportType']
        $this.Description                  = $Properties['Description']

        if ($Properties.ContainsKey('Schedule'))
        {
            $this.Schedule = $Properties['Schedule']
        }

        if ($Properties.ContainsKey('SitesIncluded'))
        {
            foreach ($site in $Properties['SitesIncluded'])
            {
                $this.SitesIncluded.Add($site)
            }
        }
    }
    #endregion <Constructor>

    #region <Methods>
    [string] ToString ()
    {
        return ('{0} (Cost: {1}, Frequency: {2} min)' -f $this.Name, $this.Cost, $this.ReplicationFrequencyInMinutes)
    }
    #endregion <Methods>
}
#EndRegion './Classes/6.PSATSiteLink.ps1' 51
#Region './Classes/7.PSATSite.ps1' -1

class PSATSite
{
    #region <Properties>
    [string]$Name
    [string]$Description
    [string]$Location
    [System.Collections.Generic.List[string]]$Subnets
    [System.Collections.Generic.List[string]]$SiteLinks
    [System.Collections.Generic.List[string]]$DomainControllers
    [System.Collections.Generic.List[string]]$AdjacentSites
    #endregion <Properties>

    #region <Constructor>
    PSATSite ()
    {
        $this.Subnets           = [System.Collections.Generic.List[string]]::new()
        $this.SiteLinks         = [System.Collections.Generic.List[string]]::new()
        $this.DomainControllers = [System.Collections.Generic.List[string]]::new()
        $this.AdjacentSites     = [System.Collections.Generic.List[string]]::new()
    }

    PSATSite ([hashtable]$Properties)
    {
        $this.Subnets           = [System.Collections.Generic.List[string]]::new()
        $this.SiteLinks         = [System.Collections.Generic.List[string]]::new()
        $this.DomainControllers = [System.Collections.Generic.List[string]]::new()
        $this.AdjacentSites     = [System.Collections.Generic.List[string]]::new()

        $this.Name        = $Properties['Name']
        $this.Description = $Properties['Description']
        $this.Location    = $Properties['Location']
    }
    #endregion <Constructor>

    #region <Methods>
    [bool] HasDomainControllers ()
    {
        return ($this.DomainControllers.Count -gt 0)
    }

    [string] ToString ()
    {
        return ('{0} (DCs: {1}, Subnets: {2})' -f $this.Name, $this.DomainControllers.Count, $this.Subnets.Count)
    }
    #endregion <Methods>
}
#EndRegion './Classes/7.PSATSite.ps1' 47
#Region './Classes/8.PSATSitesReport.ps1' -1

class PSATSitesReport
{
    #region <Properties>
    [string]$ForestName
    [datetime]$ReportDate
    [System.Collections.Generic.List[PSATSite]]$Sites
    [System.Collections.Generic.List[PSATSubnet]]$Subnets
    [System.Collections.Generic.List[PSATSiteLink]]$SiteLinks
    [int]$TotalSites
    [int]$TotalSubnets
    [int]$TotalSiteLinks
    [int]$TotalDomainControllers
    [System.Collections.Generic.List[string]]$SitesWithoutDC
    [System.Collections.Generic.List[string]]$SitesWithoutSubnets
    [System.Collections.Generic.List[string]]$SubnetsWithoutSites
    #endregion <Properties>

    #region <Constructor>
    PSATSitesReport ()
    {
        $this.ReportDate          = [datetime]::Now
        $this.Sites               = [System.Collections.Generic.List[PSATSite]]::new()
        $this.Subnets             = [System.Collections.Generic.List[PSATSubnet]]::new()
        $this.SiteLinks           = [System.Collections.Generic.List[PSATSiteLink]]::new()
        $this.SitesWithoutDC      = [System.Collections.Generic.List[string]]::new()
        $this.SitesWithoutSubnets = [System.Collections.Generic.List[string]]::new()
        $this.SubnetsWithoutSites = [System.Collections.Generic.List[string]]::new()
    }
    #endregion <Constructor>

    #region <Methods>
    [void] QueryAD ([hashtable]$ConnectionParams)
    {
        # Build splatting hashtable for AD cmdlets
        $adParams = @{
            ErrorAction = 'Stop'
        }

        if ($ConnectionParams.ContainsKey('Server'))
        {
            $adParams['Server'] = $ConnectionParams['Server']
        }

        if ($ConnectionParams.ContainsKey('Credential'))
        {
            $adParams['Credential'] = $ConnectionParams['Credential']
        }

        # 1. Get forest name
        $forest = Get-ADForest @adParams
        $this.ForestName = $forest.Name

        $configNC = $forest.PartitionsContainer -replace 'CN=Partitions,', ''

        # 2. Get all AD replication sites
        $adSites = Get-ADReplicationSite -Filter * -Properties 'Description', 'Location' @adParams

        foreach ($adSite in $adSites)
        {
            $siteObj = [PSATSite]::new(@{
                Name        = $adSite.Name
                Description = $adSite.Description
                Location    = $adSite.Location
            })
            $this.Sites.Add($siteObj)
        }

        # 3. Get all AD replication subnets
        $adSubnets = Get-ADReplicationSubnet -Filter * -Properties 'Description', 'Location' @adParams

        foreach ($adSubnet in $adSubnets)
        {
            $siteName = $null
            if ($null -ne $adSubnet.Site)
            {
                $siteName = ($adSubnet.Site -split ',')[0] -replace 'CN=', ''
            }

            $subnetObj = [PSATSubnet]::new(@{
                Name              = $adSubnet.Name
                SiteName          = $siteName
                Location          = $adSubnet.Location
                Description       = $adSubnet.Description
                DistinguishedName = $adSubnet.DistinguishedName
            })
            $this.Subnets.Add($subnetObj)
        }

        # 4. Get all AD replication site links
        $adSiteLinks = Get-ADReplicationSiteLink -Filter * -Properties 'Description', 'Schedule' @adParams

        foreach ($adSiteLink in $adSiteLinks)
        {
            $siteLinkSites = [System.Collections.Generic.List[string]]::new()
            if ($null -ne $adSiteLink.SitesIncluded)
            {
                foreach ($siteDN in $adSiteLink.SitesIncluded)
                {
                    $extractedName = ($siteDN -split ',')[0] -replace 'CN=', ''
                    $siteLinkSites.Add($extractedName)
                }
            }

            $transport = 'IP'
            if ($null -ne $adSiteLink.DistinguishedName -and $adSiteLink.DistinguishedName -match 'CN=IP|CN=SMTP')
            {
                $transport = [regex]::Match($adSiteLink.DistinguishedName, 'CN=(IP|SMTP)').Groups[1].Value
            }

            $siteLinkObj = [PSATSiteLink]::new(@{
                Name                         = $adSiteLink.Name
                Cost                         = $adSiteLink.Cost
                ReplicationFrequencyInMinutes = $adSiteLink.ReplicationFrequencyInMinutes
                SitesIncluded                = $siteLinkSites
                TransportType                = $transport
                Description                  = $adSiteLink.Description
                Schedule                     = $adSiteLink.Schedule
            })
            $this.SiteLinks.Add($siteLinkObj)
        }

        # 5. Get all domain controllers and assign to sites
        $domainControllers = Get-ADDomainController -Filter * @adParams

        foreach ($dc in $domainControllers)
        {
            $matchingSite = $this.Sites |
                Where-Object { $_.Name -eq $dc.Site }

            if ($null -ne $matchingSite)
            {
                $matchingSite.DomainControllers.Add($dc.HostName)
            }
        }

        # 6. Cross-reference subnets to sites
        foreach ($subnet in $this.Subnets)
        {
            if ($subnet.SiteName)
            {
                $matchingSite = $this.Sites |
                    Where-Object { $_.Name -eq $subnet.SiteName }

                if ($null -ne $matchingSite)
                {
                    $matchingSite.Subnets.Add($subnet.Name)
                }
            }
        }

        # 7. Cross-reference site links to sites and build adjacent sites
        foreach ($siteLink in $this.SiteLinks)
        {
            foreach ($siteName in $siteLink.SitesIncluded)
            {
                $matchingSite = $this.Sites |
                    Where-Object { $_.Name -eq $siteName }

                if ($null -ne $matchingSite)
                {
                    $matchingSite.SiteLinks.Add($siteLink.Name)

                    # Add adjacent sites (other sites in this link)
                    foreach ($adjacentName in $siteLink.SitesIncluded)
                    {
                        if ($adjacentName -ne $siteName -and -not $matchingSite.AdjacentSites.Contains($adjacentName))
                        {
                            $matchingSite.AdjacentSites.Add($adjacentName)
                        }
                    }
                }
            }
        }

        # 8. Compute summary and health indicators
        $this.ComputeSummary()
    }

    [void] ComputeSummary ()
    {
        $this.TotalSites    = $this.Sites.Count
        $this.TotalSubnets  = $this.Subnets.Count
        $this.TotalSiteLinks = $this.SiteLinks.Count

        $dcCount = 0
        foreach ($site in $this.Sites)
        {
            $dcCount += $site.DomainControllers.Count
        }
        $this.TotalDomainControllers = $dcCount

        # Health indicators
        $this.SitesWithoutDC.Clear()
        $this.SitesWithoutSubnets.Clear()
        $this.SubnetsWithoutSites.Clear()

        foreach ($site in $this.Sites)
        {
            if (-not $site.HasDomainControllers())
            {
                $this.SitesWithoutDC.Add($site.Name)
            }

            if ($site.Subnets.Count -eq 0)
            {
                $this.SitesWithoutSubnets.Add($site.Name)
            }
        }

        foreach ($subnet in $this.Subnets)
        {
            if ([string]::IsNullOrEmpty($subnet.SiteName))
            {
                $this.SubnetsWithoutSites.Add($subnet.Name)
            }
        }
    }

    [string] ToString ()
    {
        return ('AD Sites Report for {0} - {1} Sites, {2} Subnets, {3} Site Links, {4} DCs' -f
            $this.ForestName,
            $this.TotalSites,
            $this.TotalSubnets,
            $this.TotalSiteLinks,
            $this.TotalDomainControllers
        )
    }
    #endregion <Methods>
}
#EndRegion './Classes/8.PSATSitesReport.ps1' 231
#Region './Private/Get-PrivateFunction.ps1' -1

function Get-PrivateFunction
{
    <#
      .SYNOPSIS
      This is a sample Private function only visible within the module.

      .DESCRIPTION
      This sample function is not exported to the module and only return the data passed as parameter.

      .EXAMPLE
      $null = Get-PrivateFunction -PrivateData 'NOTHING TO SEE HERE'

      .PARAMETER PrivateData
      The PrivateData parameter is what will be returned without transformation.

      #>
    [cmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter()]
        [String]
        $PrivateData
    )

    process
    {
        Write-Output $PrivateData
    }

}
#EndRegion './Private/Get-PrivateFunction.ps1' 32
#Region './Public/Get-PSATSitesReport.ps1' -1

function Get-PSATSitesReport
{
    <#
        .SYNOPSIS
        Generates a comprehensive Active Directory Sites and Services audit report.

        .DESCRIPTION
        Queries Active Directory to collect information about sites, subnets, site links,
        and domain controllers. Returns a PSATSitesReport object containing the full
        topology and health indicators such as sites without domain controllers,
        sites without subnets, and subnets without site assignments.

        .PARAMETER Server
        Specifies the Active Directory Domain Services instance to connect to.

        .PARAMETER Credential
        Specifies the credentials to use when connecting to Active Directory.

        .EXAMPLE
        Get-PSATSitesReport

        Returns a full AD Sites and Services report using the current user's credentials.

        .EXAMPLE
        Get-PSATSitesReport -Server 'dc01.contoso.com'

        Returns a report querying a specific domain controller.

        .EXAMPLE
        $cred = Get-Credential
        Get-PSATSitesReport -Credential $cred

        Returns a report using explicit credentials.

        .EXAMPLE
        $cred = Get-Credential
        Get-PSATSitesReport -Server 'dc01.contoso.com' -Credential $cred

        Returns a report from a remote domain controller using explicit credentials.
    #>
    [CmdletBinding()]
    [OutputType([PSATSitesReport])]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    BEGIN
    {
        Write-Verbose -Message 'Get-PSATSitesReport - Checking ActiveDirectory module availability.'

        try
        {
            $importParams = @{
                Name        = 'ActiveDirectory'
                ErrorAction = 'Stop'
            }
            Import-Module @importParams
        }
        catch [System.IO.FileNotFoundException]
        {
            $errorMessage = 'The ActiveDirectory module is not installed. Install RSAT tools or the ActiveDirectory module.'
            Write-Error -Message $errorMessage -ErrorAction Stop
            return
        }
    }

    PROCESS
    {
        $report = [PSATSitesReport]::new()

        $connectionParams = @{}
        $connectionInfo = @()

        if ($PSBoundParameters.ContainsKey('Server'))
        {
            $connectionParams['Server'] = $Server
            $connectionInfo += "server '$Server'"
        }

        if ($PSBoundParameters.ContainsKey('Credential'))
        {
            $connectionParams['Credential'] = $Credential
            $connectionInfo += "credential '$($Credential.UserName)'"
        }

        $verboseMessage = if ($connectionInfo.Count -gt 0)
        {
            'Get-PSATSitesReport - Querying Active Directory Sites and Services using {0}.' -f ($connectionInfo -join ' and ')
        }
        else
        {
            'Get-PSATSitesReport - Querying Active Directory Sites and Services using current user context.'
        }

        try
        {
            Write-Verbose -Message $verboseMessage
            $report.QueryAD($connectionParams)
        }
        catch [System.UnauthorizedAccessException]
        {
            Write-Error -Message ('Access denied when querying Active Directory: {0}' -f $_.Exception.Message) -ErrorAction Stop
            return
        }
        catch
        {
            $exTypeName = $_.Exception.GetType().FullName
            if ($exTypeName -eq 'Microsoft.ActiveDirectory.Management.ADException')
            {
                Write-Error -Message ('Active Directory query failed: {0}' -f $_.Exception.Message) -ErrorAction Stop
            }
            else
            {
                Write-Error -Message ('Unexpected error while generating AD Sites report: {0}' -f $_.Exception.Message) -ErrorAction Stop
            }
            return
        }

        Write-Verbose -Message ('Get-PSATSitesReport - Report generated: {0}' -f $report.ToString())
        $report
    }

    END
    {
    }
}
#EndRegion './Public/Get-PSATSitesReport.ps1' 133
#Region './Public/Get-Something.ps1' -1

function Get-Something
{
    <#
      .SYNOPSIS
      Sample Function to return input string.

      .DESCRIPTION
      This function is only a sample Advanced function that returns the Data given via parameter Data.

      .EXAMPLE
      Get-Something -Data 'Get me this text'


      .PARAMETER Data
      The Data parameter is the data that will be returned without transformation.

    #>
    [cmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Low'
    )]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String]
        $Data
    )

    process
    {
        if ($pscmdlet.ShouldProcess($Data))
        {
            Write-Verbose -Message ('Returning the data: {0}' -f $Data)
            Get-PrivateFunction -PrivateData $Data
        }
        else
        {
            Write-Verbose -Message 'oh dear'
        }
    }
}
#EndRegion './Public/Get-Something.ps1' 42
