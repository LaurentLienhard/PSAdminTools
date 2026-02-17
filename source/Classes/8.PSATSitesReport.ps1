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
