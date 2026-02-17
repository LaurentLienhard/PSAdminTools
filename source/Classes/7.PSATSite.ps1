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
