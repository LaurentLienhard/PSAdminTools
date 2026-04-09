function Get-PSATDhcpScopeInfo
{
    <#
    .SYNOPSIS
        Retrieves DHCP scopes and their configured options from one or more DHCP servers.

    .DESCRIPTION
        Queries a local or remote Windows DHCP server to collect all IPv4 scopes along
        with their effective options: DNS servers (option 6), default gateway (option 3),
        and DNS domain name (option 15).

        Each result is returned as a [PSATDhcpScope] object. The class exposes helper
        methods to inspect DNS server assignment:
          - HasDnsServer([string])    : checks whether a single IP is in the DNS list
          - HasAnyDnsServer([string[]]) : checks whether any of the provided IPs is present

        For each scope, the effective DNS server list is resolved in priority order:
          1. Scope-level option 6 (if configured)
          2. Server-level option 6 (fallback)

        The DnsServersSource property indicates where the effective DNS list comes from.

        Use -DnsServer to find all scopes that have a specific IP address configured
        as a DNS server, regardless of whether it is set at scope or server level.

        Accepts multiple computer names from the pipeline to aggregate results across
        an entire DHCP infrastructure in a single call.

    .PARAMETER ComputerName
        Name or IP of the DHCP server(s) to query. Defaults to the local machine.
        Accepts pipeline input to query multiple servers.

    .PARAMETER Credential
        Credentials for connecting to remote servers via PowerShell remoting (WinRM).
        Only used when the target is not the local machine.

    .PARAMETER ScopeId
        One or more scope IDs (e.g. '192.168.1.0') to restrict the query.
        Returns all scopes when omitted.

    .PARAMETER DnsServer
        One or more DNS server IP addresses to filter by.
        Only scopes whose effective DNS servers list contains at least one of these
        IPs are returned.

    .PARAMETER IncludeInactive
        By default only Active scopes are returned. Use this switch to also include
        scopes in Inactive or other states.

    .EXAMPLE
        Get-PSATDhcpScopeInfo -ComputerName 'dhcp01.contoso.com'

        Returns all active scopes from dhcp01 as [PSATDhcpScope] objects.

    .EXAMPLE
        Get-PSATDhcpScopeInfo -ComputerName 'dhcp01' -DnsServer '10.0.0.1'

        Returns only scopes that have 10.0.0.1 as a (scope or server level) DNS server.

    .EXAMPLE
        Get-PSATDhcpScopeInfo -ComputerName 'dhcp01' -DnsServer '10.0.0.1','10.0.0.2'

        Returns scopes that have 10.0.0.1 OR 10.0.0.2 as a DNS server.

    .EXAMPLE
        $cred = Get-Credential domain\adminuser
        'dhcp01','dhcp02' | Get-PSATDhcpScopeInfo -Credential $cred -DnsServer '192.168.1.1'

        Aggregates results from two servers, filtered by DNS server IP.

    .EXAMPLE
        Get-PSATDhcpScopeInfo -ComputerName 'dhcp01' -ScopeId '192.168.10.0','192.168.20.0'

        Returns details for two specific scopes only.

    .EXAMPLE
        Get-PSATDhcpScopeInfo -ComputerName 'dhcp01' -IncludeInactive

        Returns all scopes including inactive ones.

    .OUTPUTS
        PSATDhcpScope

    .NOTES
        Requires the DhcpServer PowerShell module on the target machine (included in
        Windows Server with the DHCP Server role, or via RSAT on admin workstations).

        Remote access requires WinRM to be enabled and configured on the target server.
        The account used must have at minimum DHCP Auditors membership on the target server.
    #>
    [CmdletBinding()]
    [OutputType([PSATDhcpScope])]
    param
    (
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

    BEGIN
    {
        Write-Verbose -Message "Starting $($MyInvocation.MyCommand.Name)"

        $localName = if ($null -ne $env:COMPUTERNAME) { $env:COMPUTERNAME } else { [System.Net.Dns]::GetHostName() }

        # Script block executed on each target (locally or via Invoke-Command).
        # Returns raw PSCustomObjects; the [PSATDhcpScope] instantiation happens on
        # the caller side so the class definition does not need to exist on the remote host.
        $script:dhcpScriptBlock = {
            param (
                [string[]]$FilterScopeIds,
                [bool]$IncludeInactive
            )

            $module = Get-Module -Name DhcpServer -ListAvailable
            if ($null -eq $module)
            {
                throw 'The DhcpServer PowerShell module is not available on this system.'
            }

            Import-Module -Name DhcpServer -ErrorAction Stop

            # Collect server-level options as fallback for scopes that do not override them.
            $serverOptions = Get-DhcpServerv4OptionValue -ErrorAction SilentlyContinue
            $serverDns     = ($serverOptions | Where-Object -FilterScript { $_.OptionId -eq 6 }).Value
            $serverRouter  = ($serverOptions | Where-Object -FilterScript { $_.OptionId -eq 3 }).Value
            $serverDomain  = ($serverOptions | Where-Object -FilterScript { $_.OptionId -eq 15 }).Value

            $scopes = Get-DhcpServerv4Scope -ErrorAction Stop

            if (-not $IncludeInactive)
            {
                $scopes = $scopes | Where-Object -FilterScript { $_.State -eq 'Active' }
            }

            if ($null -ne $FilterScopeIds -and $FilterScopeIds.Count -gt 0)
            {
                $scopes = $scopes | Where-Object -FilterScript {
                    $_.ScopeId.IPAddressToString -in $FilterScopeIds
                }
            }

            foreach ($scope in $scopes)
            {
                $scopeOptions = Get-DhcpServerv4OptionValue -ScopeId $scope.ScopeId -ErrorAction SilentlyContinue

                $scopeDns    = ($scopeOptions | Where-Object -FilterScript { $_.OptionId -eq 6 }).Value
                $scopeRouter = ($scopeOptions | Where-Object -FilterScript { $_.OptionId -eq 3 }).Value
                $scopeDomain = ($scopeOptions | Where-Object -FilterScript { $_.OptionId -eq 15 }).Value

                $effectiveDns    = if ($null -ne $scopeDns)    { $scopeDns }    else { $serverDns }
                $effectiveRouter = if ($null -ne $scopeRouter) { $scopeRouter } else { $serverRouter }
                $effectiveDomain = if ($null -ne $scopeDomain) { $scopeDomain } else { $serverDomain }
                $dnsSource       = if ($null -ne $scopeDns)    { 'Scope' }      else { 'Server' }

                [PSCustomObject]@{
                    ScopeId          = $scope.ScopeId.IPAddressToString
                    Name             = $scope.Name
                    State            = $scope.State.ToString()
                    SubnetMask       = $scope.SubnetMask.IPAddressToString
                    StartRange       = $scope.StartRange.IPAddressToString
                    EndRange         = $scope.EndRange.IPAddressToString
                    LeaseDuration    = $scope.LeaseDuration
                    DnsServers       = [string[]]$effectiveDns
                    DnsServersSource = $dnsSource
                    DomainName       = [string]($effectiveDomain | Select-Object -First 1)
                    Router           = [string[]]$effectiveRouter
                }
            }
        }
    }

    PROCESS
    {
        foreach ($computer in $ComputerName)
        {
            Write-Verbose -Message "Querying DHCP server '$computer'"

            $isLocal = ($computer -eq $localName) -or
                       ($computer -eq 'localhost') -or
                       ($computer -eq '127.0.0.1')

            $rawScopes = $null

            try
            {
                if ($isLocal)
                {
                    Write-Verbose -Message "Using local execution for '$computer'"
                    $rawScopes = & $script:dhcpScriptBlock -FilterScopeIds $ScopeId -IncludeInactive $IncludeInactive.IsPresent
                }
                else
                {
                    Write-Verbose -Message "Using PowerShell remoting for '$computer'"

                    $invokeParams = @{
                        ComputerName = $computer
                        ScriptBlock  = $script:dhcpScriptBlock
                        ArgumentList = @($ScopeId, $IncludeInactive.IsPresent)
                        ErrorAction  = 'Stop'
                    }

                    if ($PSBoundParameters.ContainsKey('Credential'))
                    {
                        $invokeParams['Credential'] = $Credential
                    }

                    $rawScopes = Invoke-Command @invokeParams
                }
            }
            catch
            {
                Write-Error -Message "Failed to query DHCP server '$computer': $($_.Exception.Message)"
                continue
            }

            foreach ($raw in $rawScopes)
            {
                $scope = [PSATDhcpScope]::new(
                    $computer,
                    $raw.ScopeId,
                    $raw.Name,
                    $raw.State,
                    $raw.SubnetMask,
                    $raw.StartRange,
                    $raw.EndRange,
                    $raw.LeaseDuration,
                    $raw.DnsServers,
                    $raw.DnsServersSource,
                    $raw.DomainName,
                    $raw.Router
                )

                # Use the class method to apply -DnsServer filter.
                if ($PSBoundParameters.ContainsKey('DnsServer'))
                {
                    if (-not $scope.HasAnyDnsServer($DnsServer))
                    {
                        continue
                    }
                }

                $scope
            }
        }
    }

    END
    {
        Write-Verbose -Message "Ending $($MyInvocation.MyCommand.Name)"
    }
}
