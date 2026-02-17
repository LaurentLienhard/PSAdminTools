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
