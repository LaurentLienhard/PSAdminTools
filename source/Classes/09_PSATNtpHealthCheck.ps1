class PSATNtpHealthCheck
{
    #region <Properties>

    [string]               $ComputerName
    [bool]                 $IsHealthy
    [PSATNtpHealthEvent[]] $Events
    [object]               $LastSyncTime
    [string]               $LastSyncSource
    [datetime]             $CheckedAt

    #endregion <Properties>

    #region <Constructor>

    PSATNtpHealthCheck([PSCustomObject] $raw)
    {
        $this.ComputerName    = $raw.ComputerName
        $this.IsHealthy       = $raw.IsHealthy
        $this.Events          = $raw.Events
        $this.LastSyncTime    = $raw.LastSyncTime
        $this.LastSyncSource  = $raw.LastSyncSource
        $this.CheckedAt       = $raw.CheckedAt
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if any event is at Error or Critical level.
    [bool] HasErrors()
    {
        foreach ($event in $this.Events)
        {
            if ($event.IsError())
            {
                return $true
            }
        }
        return $false
    }

    # Returns $true if any event is at Warning level.
    [bool] HasWarnings()
    {
        foreach ($event in $this.Events)
        {
            if ($event.IsWarning())
            {
                return $true
            }
        }
        return $false
    }

    # Returns all Error and Critical level events.
    [PSATNtpHealthEvent[]] GetErrors()
    {
        $errors = [System.Collections.Generic.List[PSATNtpHealthEvent]]::new()
        foreach ($event in $this.Events)
        {
            if ($event.IsError())
            {
                $errors.Add($event)
            }
        }
        return $errors.ToArray()
    }

    # Returns all Warning level events.
    [PSATNtpHealthEvent[]] GetWarnings()
    {
        $warnings = [System.Collections.Generic.List[PSATNtpHealthEvent]]::new()
        foreach ($event in $this.Events)
        {
            if ($event.IsWarning())
            {
                $warnings.Add($event)
            }
        }
        return $warnings.ToArray()
    }

    # Returns a human-readable summary of the health check result.
    [string] ToString()
    {
        $status  = if ($this.IsHealthy) { 'Healthy' } else { 'Unhealthy' }
        $errors  = ($this.Events | Where-Object { $_.IsError() }).Count
        $warns   = ($this.Events | Where-Object { $_.IsWarning() }).Count
        $sync    = if ($null -ne $this.LastSyncTime) { $this.LastSyncTime.ToString('yyyy-MM-dd HH:mm:ss') } else { 'Unknown' }
        return "[$status] $($this.ComputerName) — Errors: $errors — Warnings: $warns — LastSync: $sync ($($this.LastSyncSource))"
    }

    #endregion <Methods>
}
