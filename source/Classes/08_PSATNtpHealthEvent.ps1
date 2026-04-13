class PSATNtpHealthEvent
{
    #region <Properties>

    [int]      $EventId
    [string]   $Level
    [string]   $Message
    [datetime] $TimeCreated

    #endregion <Properties>

    #region <Constructor>

    PSATNtpHealthEvent([PSCustomObject] $raw)
    {
        $this.EventId     = $raw.EventId
        $this.Level       = $raw.Level
        $this.Message     = $raw.Message
        $this.TimeCreated = $raw.TimeCreated
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if this event is at Error or Critical level.
    [bool] IsError()
    {
        return $this.Level -in @('Error', 'Critical')
    }

    # Returns $true if this event is at Warning level.
    [bool] IsWarning()
    {
        return $this.Level -eq 'Warning'
    }

    # Returns a human-readable summary of the event.
    [string] ToString()
    {
        return "[$($this.Level)] $($this.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')) — EventId: $($this.EventId) — $($this.Message.Split([System.Environment]::NewLine)[0])"
    }

    #endregion <Methods>
}
