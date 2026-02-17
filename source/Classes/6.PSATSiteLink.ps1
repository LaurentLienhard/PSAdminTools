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
