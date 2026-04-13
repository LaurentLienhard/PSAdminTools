function Get-PSATADNtpDrift
{
    <#
    .SYNOPSIS
        Returns NTP time drift data in milliseconds compared to the PDC Emulator.
    .DESCRIPTION
        Outputs a PSCustomObject for each target containing drift values and status levels.
    .PARAMETER ComputerName
        List of computers to check. If empty, all DCs are targeted.
    .PARAMETER Credential
        Optional credentials for remote AD discovery.
    .EXAMPLE
        Get-PSATADNtpDrift | Out-GridView
    .EXAMPLE
        Get-PSATADNtpDrift -ComputerName "SRV01" | Export-Csv -Path "DriftReport.csv"
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string[]]$ComputerName,
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    process
    {
        try
        {
            $PDC = (Get-ADDomain).PDCEmulator

            $TargetList = @()
            if ($PSBoundParameters.ContainsKey('ComputerName'))
            {
                $TargetList = $ComputerName
            }
            else
            {
                $splat = @{ Filter = '*'; Server = $PDC }
                if ($Credential -ne [System.Management.Automation.PSCredential]::Empty)
                {
                    $splat.Add("Credential", $Credential)
                }
                $TargetList = Get-ADDomainController @splat | Select-Object -ExpandProperty HostName
            }

            # Thresholds (ms)
            $WarnThresh = 500
            $ErrThresh = 2000

            $Results = foreach ($Target in $TargetList)
            {
                if ($Target -match $PDC.Split('.')[0])
                {
                    continue
                }

                try
                {
                    $sample = w32tm /stripchart /computer:$PDC /samples:1 /dataonly | Select-Object -Last 1
                    if ($sample -match "error")
                    {
                        throw "W32Time communication error"
                    }

                    $rawOffset = ($sample -split ",")[1].Trim().Replace("s", "")
                    $offsetMs = [math]::Round(([double]$rawOffset * 1000), 2)
                    $absOffset = [math]::Abs($offsetMs)

                    $status = "OK"
                    if ($absOffset -gt $ErrThresh)
                    {
                        $status = "CRITICAL"
                    }
                    elseif ($absOffset -gt $WarnThresh)
                    {
                        $status = "WARNING"
                    }

                    [PSCustomObject]@{
                        ComputerName = $Target
                        Reference    = $PDC
                        DriftMs      = $offsetMs
                        AbsDriftMs   = $absOffset
                        Status       = $status
                        SyncMode     = if ($offsetMs -ge 0)
                        {
                            "Ahead"
                        }
                        else
                        {
                            "Behind"
                        }
                        Timestamp    = Get-Date
                    }
                }
                catch
                {
                    [PSCustomObject]@{
                        ComputerName = $Target
                        Reference    = $PDC
                        DriftMs      = $null
                        AbsDriftMs   = $null
                        Status       = "ERROR"
                        SyncMode     = "Unreachable"
                        Timestamp    = Get-Date
                    }
                }
            }

            return $Results
        }
        catch
        {
            Write-Error "Critical Error: $($_.Exception.Message)"
        }
    }
}
