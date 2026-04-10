class PSATComputer
{
    #region <Properties>

    # Identity / AD
    [string] $ComputerName
    [string] $FQDN
    [string] $OU
    [string] $ADSite
    [string] $Description
    [bool]   $IsEnabled
    [object] $LastLogonDate
    [object] $ADCreationDate

    # Operating System
    [string] $OperatingSystem
    [string] $OSVersion
    [string] $OSBuild
    [string] $Architecture
    [object] $InstallDate
    [object] $LastBootTime
    [object] $Uptime

    # Hardware
    [bool]   $IsVirtual
    [string] $Manufacturer
    [string] $Model
    [int]    $ProcessorCount
    [int]    $CoresPerProcessor
    [double] $TotalRAMGB

    # Network
    [string[]] $IPAddresses
    [string[]] $DnsServers
    [string]   $DefaultGateway

    # Storage
    [PSATComputerDisk[]] $Disks

    # Health
    [bool]   $IsOnline
    [bool]   $PendingReboot

    # Classification
    [string] $ComputerType

    #endregion <Properties>

    #region <Constructor>

    PSATComputer([PSCustomObject] $raw)
    {
        $this.ComputerName    = $raw.ComputerName
        $this.FQDN            = $raw.FQDN
        $this.OU              = $raw.OU
        $this.ADSite          = $raw.ADSite
        $this.Description     = $raw.Description
        $this.IsEnabled       = $raw.IsEnabled
        $this.LastLogonDate   = $raw.LastLogonDate
        $this.ADCreationDate  = $raw.ADCreationDate

        $this.OperatingSystem = $raw.OperatingSystem
        $this.OSVersion       = $raw.OSVersion
        $this.OSBuild         = $raw.OSBuild
        $this.Architecture    = $raw.Architecture
        $this.InstallDate     = $raw.InstallDate
        $this.LastBootTime    = $raw.LastBootTime
        $this.Uptime          = $raw.Uptime

        $this.IsVirtual          = $raw.IsVirtual
        $this.Manufacturer       = $raw.Manufacturer
        $this.Model              = $raw.Model
        $this.ProcessorCount     = $raw.ProcessorCount
        $this.CoresPerProcessor  = $raw.CoresPerProcessor
        $this.TotalRAMGB         = $raw.TotalRAMGB

        $this.IPAddresses    = $raw.IPAddresses
        $this.DnsServers     = $raw.DnsServers
        $this.DefaultGateway = $raw.DefaultGateway

        $this.Disks = $raw.Disks

        $this.IsOnline      = $raw.IsOnline
        $this.PendingReboot = $raw.PendingReboot
        $this.ComputerType  = $raw.ComputerType
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if any disk is below the given free-space percentage threshold.
    [bool] HasLowDiskSpace([double] $ThresholdPercent)
    {
        foreach ($disk in $this.Disks)
        {
            if ($disk.IsLowSpace($ThresholdPercent))
            {
                return $true
            }
        }
        return $false
    }

    # Returns a human-readable summary of the computer.
    [string] ToString()
    {
        return "[$($this.ComputerType)] $($this.ComputerName) — OS: $($this.OperatingSystem) — Online: $($this.IsOnline)"
    }

    #endregion <Methods>
}
