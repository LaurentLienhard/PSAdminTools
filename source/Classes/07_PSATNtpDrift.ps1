class PSATNtpDrift
{
    #region <Properties>

    [string]   $ComputerName
    [string]   $Reference
    [object]   $DriftMs
    [object]   $AbsDriftMs
    [string]   $Status
    [string]   $SyncMode
    [datetime] $Timestamp

    #endregion <Properties>

    #region <Constructor>

    PSATNtpDrift([PSCustomObject] $raw)
    {
        $this.ComputerName = $raw.ComputerName
        $this.Reference    = $raw.Reference
        $this.DriftMs      = $raw.DriftMs
        $this.AbsDriftMs   = $raw.AbsDriftMs
        $this.Status       = $raw.Status
        $this.SyncMode     = $raw.SyncMode
        $this.Timestamp    = $raw.Timestamp
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if the drift is at WARNING level.
    [bool] IsWarning()
    {
        return $this.Status -eq 'WARNING'
    }

    # Returns $true if the drift is at CRITICAL level.
    [bool] IsCritical()
    {
        return $this.Status -eq 'CRITICAL'
    }

    # Returns $true if the target was unreachable or an error occurred.
    [bool] IsError()
    {
        return $this.Status -eq 'ERROR'
    }

    # Returns a human-readable summary of the drift measurement.
    [string] ToString()
    {
        if ($this.IsError())
        {
            return "[$($this.Status)] $($this.ComputerName) vs $($this.Reference) — Unreachable"
        }
        return "[$($this.Status)] $($this.ComputerName) vs $($this.Reference) — Drift: $($this.DriftMs) ms ($($this.SyncMode))"
    }

    #endregion <Methods>
}
