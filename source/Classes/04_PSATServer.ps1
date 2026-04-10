class PSATServer : PSATComputer
{
    #region <Properties>

    [bool]     $IsDomainController
    [string[]] $InstalledRoles
    [object]   $LastWindowsUpdate

    #endregion <Properties>

    #region <Constructor>

    PSATServer([PSCustomObject] $raw) : base($raw)
    {
        $this.IsDomainController = $raw.IsDomainController
        $this.InstalledRoles     = $raw.InstalledRoles
        $this.LastWindowsUpdate  = $raw.LastWindowsUpdate
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if the specified Windows role is installed.
    [bool] HasRole([string] $RoleName)
    {
        return $RoleName -in $this.InstalledRoles
    }

    # Returns a human-readable summary of the server.
    [string] ToString()
    {
        $dcLabel = if ($this.IsDomainController) { 'DC' } else { 'MemberServer' }
        return "[$dcLabel] $($this.ComputerName) — OS: $($this.OperatingSystem) — Online: $($this.IsOnline) — Roles: $($this.InstalledRoles.Count)"
    }

    #endregion <Methods>
}
