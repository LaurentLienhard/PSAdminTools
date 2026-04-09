Voici le code complet et corrigé. J'ai intégré la définition de la classe PSATDhcpScope (indispensable pour que le constructeur ::new() fonctionne) et j'ai corrigé le bloc d'importation du module pour éviter l'erreur de fichier de langue fr-FR manquante.

PowerShell
# 1. Définition de la classe (doit être définie avant la fonction)
class PSATDhcpScope {
    [string]$ServerName
    [string]$ScopeId
    [string]$Name
    [string]$State
    [string]$SubnetMask
    [string]$StartRange
    [string]$EndRange
    [timespan]$LeaseDuration
    [string[]]$DnsServers
    [string]$DnsServersSource
    [string]$DomainName
    [string[]]$Router

    PSATDhcpScope(
        [string]$Server, [string]$Id, [string]$Name, [string]$State,
        [string]$Mask, [string]$Start, [string]$End, [timespan]$Lease,
        [string[]]$Dns, [string]$Source, [string]$Domain, [string[]]$Router
    ) {
        $this.ServerName       = $Server
        $this.ScopeId         = $Id
        $this.Name            = $Name
        $this.State           = $State
        $this.SubnetMask      = $Mask
        $this.StartRange      = $Start
        $this.EndRange        = $End
        $this.LeaseDuration   = $Lease
        $this.DnsServers      = $Dns
        $this.DnsServersSource = $Source
        $this.DomainName      = $Domain
        $this.Router          = $Router
    }

    [bool]HasDnsServer([string]$Ip) {
        return $this.DnsServers -contains $Ip
    }

    [bool]HasAnyDnsServer([string[]]$Ips) {
        foreach ($ip in $Ips) {
            if ($this.DnsServers -contains $ip) { return $true }
        }
        return $false
    }
}

# 2. La fonction principale
function Get-PSATDhcpScopeInfo {
    [CmdletBinding()]
    [OutputType([PSATDhcpScope])]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName = @($env:COMPUTERNAME),

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [string[]]$ScopeId,

        [Parameter()]
        [string[]]$DnsServer,

        [Parameter()]
        [switch]$IncludeInactive
    )

    BEGIN {
        Write-Verbose "Starting $($MyInvocation.MyCommand.Name)"
        $localName = if ($null -ne $env:COMPUTERNAME) { $env:COMPUTERNAME } else { [System.Net.Dns]::GetHostName() }

        # Script block de collecte (exécuté sur le serveur cible)
        $script:dhcpScriptBlock = {
            param ([string[]]$FilterScopeIds, [bool]$IncludeInactive)

            # --- CORRECTIF ERREUR fr-FR / DhcpServerMigration.psd1 ---
            $modulePath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules\DhcpServer\DhcpServer.psd1"
            if (Test-Path $modulePath) {
                Import-Module -Name $modulePath -ErrorAction SilentlyContinue
            } else {
                Import-Module -Name DhcpServer -ErrorAction Stop
            }
            # ---------------------------------------------------------

            $serverOptions = Get-DhcpServerv4OptionValue -ErrorAction SilentlyContinue
            $serverDns     = ($serverOptions | Where-Object { $_.OptionId -eq 6 }).Value
            $serverRouter  = ($serverOptions | Where-Object { $_.OptionId -eq 3 }).Value
            $serverDomain  = ($serverOptions | Where-Object { $_.OptionId -eq 15 }).Value

            $scopes = Get-DhcpServerv4Scope -ErrorAction Stop
            if (-not $IncludeInactive) { $scopes = $scopes | Where-Object { $_.State -eq 'Active' } }

            if ($null -ne $FilterScopeIds -and $FilterScopeIds.Count -gt 0) {
                $scopes = $scopes | Where-Object { $_.ScopeId.IPAddressToString -in $FilterScopeIds }
            }

            foreach ($scope in $scopes) {
                $scopeOptions = Get-DhcpServerv4OptionValue -ScopeId $scope.ScopeId -ErrorAction SilentlyContinue
                $sDns    = ($scopeOptions | Where-Object { $_.OptionId -eq 6 }).Value
                $sRouter = ($scopeOptions | Where-Object { $_.OptionId -eq 3 }).Value
                $sDomain = ($scopeOptions | Where-Object { $_.OptionId -eq 15 }).Value

                [PSCustomObject]@{
                    ScopeId          = $scope.ScopeId.IPAddressToString
                    Name             = $scope.Name
                    State            = $scope.State.ToString()
                    SubnetMask       = $scope.SubnetMask.IPAddressToString
                    StartRange       = $scope.StartRange.IPAddressToString
                    EndRange         = $scope.EndRange.IPAddressToString
                    LeaseDuration    = $scope.LeaseDuration
                    DnsServers       = if ($null -ne $sDns) { [string[]]$sDns } else { [string[]]$serverDns }
                    DnsServersSource = if ($null -ne $sDns) { 'Scope' } else { 'Server' }
                    DomainName       = [string]((if ($null -ne $sDomain) { $sDomain } else { $serverDomain }) | Select-Object -First 1)
                    Router           = if ($null -ne $sRouter) { [string[]]$sRouter } else { [string[]]$serverRouter }
                }
            }
        }
    }

    PROCESS {
        foreach ($computer in $ComputerName) {
            $isLocal = ($computer -eq $localName) -or ($computer -eq 'localhost') -or ($computer -eq '127.0.0.1')
            $rawScopes = $null

            try {
                if ($isLocal) {
                    $rawScopes = & $script:dhcpScriptBlock -FilterScopeIds $ScopeId -IncludeInactive $IncludeInactive.IsPresent
                } else {
                    $invokeParams = @{
                        ComputerName = $computer
                        ScriptBlock  = $script:dhcpScriptBlock
                        ArgumentList = @($ScopeId, $IncludeInactive.IsPresent)
                        ErrorAction  = 'Stop'
                    }
                    if ($PSBoundParameters.ContainsKey('Credential')) { $invokeParams['Credential'] = $Credential }
                    $rawScopes = Invoke-Command @invokeParams
                }

                foreach ($raw in $rawScopes) {
                    $obj = [PSATDhcpScope]::new(
                        $computer, $raw.ScopeId, $raw.Name, $raw.State, $raw.SubnetMask,
                        $raw.StartRange, $raw.EndRange, $raw.LeaseDuration, $raw.DnsServers,
                        $raw.DnsServersSource, $raw.DomainName, $raw.Router
                    )

                    if ($PSBoundParameters.ContainsKey('DnsServer')) {
                        if (-not $obj.HasAnyDnsServer($DnsServer)) { continue }
                    }
                    $obj
                }
            }
            catch {
                Write-Error "Erreur sur '$computer': $($_.Exception.Message)"
            }
        }
    }
    END { Write-Verbose "Ending Get-PSATDhcpScopeInfo" }
}
