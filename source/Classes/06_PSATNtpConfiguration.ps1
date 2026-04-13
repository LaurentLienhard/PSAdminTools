class PSATNtpConfiguration
{
    #region <Properties>

    [string] $ComputerName
    [string] $NTPSource
    [string] $ConfigType
    [string] $ServiceStatus
    [bool]   $IsDC

    #endregion <Properties>

    #region <Constructor>

    PSATNtpConfiguration([PSCustomObject] $raw)
    {
        $this.ComputerName  = $raw.ComputerName
        $this.NTPSource     = $raw.NTPSource
        $this.ConfigType    = $raw.ConfigType
        $this.ServiceStatus = $raw.ServiceStatus
        $this.IsDC          = $raw.IsDC
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if NTP is actively configured (source is not N/A or Error).
    [bool] IsConfigured()
    {
        $unconfigured = @('N/A', 'Error', '')
        return $this.NTPSource -notin $unconfigured
    }

    # Returns $true if the W32Time service is in the Running state.
    [bool] IsServiceRunning()
    {
        return $this.ServiceStatus -eq 'Running'
    }

    # Returns a human-readable summary of the NTP configuration.
    [string] ToString()
    {
        $dcLabel = if ($this.IsDC) { 'DC' } else { 'Member' }
        return "[$dcLabel] $($this.ComputerName) — Source: $($this.NTPSource) — Type: $($this.ConfigType) — Service: $($this.ServiceStatus)"
    }

    #endregion <Methods>
}
