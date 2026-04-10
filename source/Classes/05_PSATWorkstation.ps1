class PSATWorkstation : PSATComputer
{
    #region <Properties>

    [string] $WorkstationType
    [string] $CurrentLoggedOnUser
    [string] $LastLoggedOnUser

    #endregion <Properties>

    #region <Constructor>

    PSATWorkstation([PSCustomObject] $raw) : base($raw)
    {
        $this.WorkstationType     = $raw.WorkstationType
        $this.CurrentLoggedOnUser = $raw.CurrentLoggedOnUser
        $this.LastLoggedOnUser    = $raw.LastLoggedOnUser
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if a user is currently logged on interactively.
    [bool] HasActiveUser()
    {
        return -not [string]::IsNullOrEmpty($this.CurrentLoggedOnUser)
    }

    # Returns a human-readable summary of the workstation.
    [string] ToString()
    {
        return "[$($this.WorkstationType)] $($this.ComputerName) — OS: $($this.OperatingSystem) — Online: $($this.IsOnline) — User: $($this.CurrentLoggedOnUser)"
    }

    #endregion <Methods>
}
