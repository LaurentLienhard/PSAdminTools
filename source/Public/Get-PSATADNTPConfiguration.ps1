function Get-PSATADNTPConfiguration
{
    <#
    .SYNOPSIS
        Retrieves NTP configuration for specified computers or all Domain Controllers.
    .DESCRIPTION
        Queries the w32time service and registry. If no computers are specified,
        it automatically targets all Domain Controllers in the domain using the PDC Emulator.
    .PARAMETER ComputerName
        A list of computer names or FQDNs to query.
    .PARAMETER ADServer
        The DC used to discover the list of DCs (if ComputerName is empty). Defaults to the PDC Emulator.
    .PARAMETER Credential
        Optional credentials for remote access.
    .EXAMPLE
        Get-PSATADDomainNTPConfiguration -Verbose | Format-Table -AutoSize
    .EXAMPLE
        Get-PSATADDomainNTPConfiguration -ComputerName "MemberSrv01", "MemberSrv02" -Credential (Get-Credential)
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string[]]$ComputerName,
        [Parameter()]
        [string]$ADServer = $((Get-ADDomain).PDCEmulator),
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    process
    {
        try
        {
            $TargetList = @()

            if ($PSBoundParameters.ContainsKey('ComputerName'))
            {
                $TargetList = $ComputerName
                Write-Verbose "Targeting specific computers: $($TargetList -join ', ')"
            }
            else
            {
                Write-Verbose "No computers specified. Fetching all DCs from PDC: $ADServer"
                $splatAD = @{
                    Filter = '*'
                    Server = $ADServer
                }
                if ($Credential -ne [System.Management.Automation.PSCredential]::Empty)
                {
                    $splatAD.Add("Credential", $Credential)
                }
                $TargetList = Get-ADDomainController @splatAD | Select-Object -ExpandProperty HostName
            }

            if (-not $TargetList)
            {
                throw "Target list is empty."
            }

            Write-Verbose "Querying NTP configuration on $($TargetList.Count) targets..."

            $invokeParams = @{
                ComputerName = $TargetList
                ErrorAction  = 'SilentlyContinue'
                ScriptBlock  = {
                    try
                    {
                        $reg = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -ErrorAction Stop
                        $status = w32tm /query /status

                        $sourceMatch = $status | Select-String "Source:"
                        $source = if ($sourceMatch)
                        {
                            $sourceMatch.ToString().Split(":")[1].Trim()
                        }
                        else
                        {
                            "N/A"
                        }

                        $isDC = if (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\ProductOptions" -ErrorAction SilentlyContinue | Select-String "LanmanNT|ServerNT")
                        {
                            $true
                        }
                        else
                        {
                            $false
                        }

                        return [PSCustomObject]@{
                            ComputerName = $env:COMPUTERNAME
                            NTPSource    = $source
                            ConfigType   = $reg.Type
                            Service      = (Get-Service w32time).Status
                            IsDC         = $isDC
                        }
                    }
                    catch
                    {
                        return [PSCustomObject]@{
                            ComputerName = $env:COMPUTERNAME
                            NTPSource    = "Error/Unreachable"
                            ConfigType   = "N/A"
                            Service      = "N/A"
                            IsDC         = "Unknown"
                        }
                    }
                }
            }

            if ($Credential -ne [System.Management.Automation.PSCredential]::Empty)
            {
                $invokeParams.Add("Credential", $Credential)
            }

            $Results = Invoke-Command @invokeParams

            if ($Results)
            {
                return $Results | Select-Object ComputerName, NTPSource, ConfigType, Service, IsDC | Sort-Object ComputerName
            }
            else
            {
                Write-Verbose "No results returned. Ensure WinRM is enabled on targets."
            }
        }
        catch
        {
            Write-Error "Critical Error: $($_.Exception.Message)"
        }
    }
}
