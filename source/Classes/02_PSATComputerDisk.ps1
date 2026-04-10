class PSATComputerDisk
{
    #region <Properties>

    [string] $DriveLetter
    [string] $Label
    [string] $FileSystem
    [double] $TotalGB
    [double] $FreeGB
    [double] $PercentFree

    #endregion <Properties>

    #region <Constructor>

    PSATComputerDisk(
        [string] $DriveLetter,
        [string] $Label,
        [string] $FileSystem,
        [double] $TotalGB,
        [double] $FreeGB
    )
    {
        $this.DriveLetter = $DriveLetter
        $this.Label       = $Label
        $this.FileSystem  = $FileSystem
        $this.TotalGB     = [Math]::Round($TotalGB, 2)
        $this.FreeGB      = [Math]::Round($FreeGB, 2)

        if ($TotalGB -gt 0)
        {
            $this.PercentFree = [Math]::Round(($FreeGB / $TotalGB) * 100, 1)
        }
        else
        {
            $this.PercentFree = 0
        }
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if free space is below the given percentage threshold.
    [bool] IsLowSpace([double] $ThresholdPercent)
    {
        return $this.PercentFree -lt $ThresholdPercent
    }

    # Returns a human-readable summary of the disk.
    [string] ToString()
    {
        return "$($this.DriveLetter) — $($this.FreeGB) GB free / $($this.TotalGB) GB ($($this.PercentFree)% free)"
    }

    #endregion <Methods>
}
