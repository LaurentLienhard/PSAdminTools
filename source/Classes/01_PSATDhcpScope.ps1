class PSATDhcpScope
{
    #region <Properties>

    [string]   $ComputerName
    [string]   $ScopeId
    [string]   $Name
    [string]   $State
    [string]   $SubnetMask
    [string]   $StartRange
    [string]   $EndRange
    [timespan] $LeaseDuration
    [string[]] $DnsServers
    [string]   $DnsServersSource
    [string]   $DomainName
    [string[]] $Router

    #endregion <Properties>

    #region <Constructor>

    PSATDhcpScope(
        [string]   $ComputerName,
        [string]   $ScopeId,
        [string]   $Name,
        [string]   $State,
        [string]   $SubnetMask,
        [string]   $StartRange,
        [string]   $EndRange,
        [timespan] $LeaseDuration,
        [string[]] $DnsServers,
        [string]   $DnsServersSource,
        [string]   $DomainName,
        [string[]] $Router
    )
    {
        $this.ComputerName     = $ComputerName
        $this.ScopeId          = $ScopeId
        $this.Name             = $Name
        $this.State            = $State
        $this.SubnetMask       = $SubnetMask
        $this.StartRange       = $StartRange
        $this.EndRange         = $EndRange
        $this.LeaseDuration    = $LeaseDuration
        $this.DnsServers       = $DnsServers
        $this.DnsServersSource = $DnsServersSource
        $this.DomainName       = $DomainName
        $this.Router           = $Router
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if the given IP address appears in the effective DNS server list.
    [bool] HasDnsServer([string] $IpAddress)
    {
        return $IpAddress -in $this.DnsServers
    }

    # Returns $true if at least one IP from the provided list appears in DnsServers.
    [bool] HasAnyDnsServer([string[]] $IpAddresses)
    {
        foreach ($ip in $IpAddresses)
        {
            if ($this.HasDnsServer($ip))
            {
                return $true
            }
        }
        return $false
    }

    # Returns a human-readable summary of the scope.
    [string] ToString()
    {
        return "[$($this.ComputerName)] $($this.ScopeId) ($($this.Name)) — State: $($this.State) — DNS: $($this.DnsServers -join ', ')"
    }

    #endregion <Methods>
}
