#Region '.\Classes\01_PSATDhcpScope.ps1' -1

class PSATDhcpScope
{
    #region <Properties>

    [string]   $ComputerName
    [string]   $ScopeId
    [string]   $Name
    [string]   $State
    [string]   $SubnetMask
    [string]   $StartRange
    [string]   $EndRange
    [timespan] $LeaseDuration
    [string[]] $DnsServers
    [string]   $DnsServersSource
    [string]   $DomainName
    [string[]] $Router

    #endregion <Properties>

    #region <Constructor>

    PSATDhcpScope(
        [string]   $ComputerName,
        [string]   $ScopeId,
        [string]   $Name,
        [string]   $State,
        [string]   $SubnetMask,
        [string]   $StartRange,
        [string]   $EndRange,
        [timespan] $LeaseDuration,
        [string[]] $DnsServers,
        [string]   $DnsServersSource,
        [string]   $DomainName,
        [string[]] $Router
    )
    {
        $this.ComputerName     = $ComputerName
        $this.ScopeId          = $ScopeId
        $this.Name             = $Name
        $this.State            = $State
        $this.SubnetMask       = $SubnetMask
        $this.StartRange       = $StartRange
        $this.EndRange         = $EndRange
        $this.LeaseDuration    = $LeaseDuration
        $this.DnsServers       = $DnsServers
        $this.DnsServersSource = $DnsServersSource
        $this.DomainName       = $DomainName
        $this.Router           = $Router
    }

    #endregion <Constructor>

    #region <Methods>

    # Returns $true if the given IP address appears in the effective DNS server list.
    [bool] HasDnsServer([string] $IpAddress)
    {
        return $IpAddress -in $this.DnsServers
    }

    # Returns $true if at least one IP from the provided list appears in DnsServers.
    [bool] HasAnyDnsServer([string[]] $IpAddresses)
    {
        foreach ($ip in $IpAddresses)
        {
            if ($this.HasDnsServer($ip))
            {
                return $true
            }
        }
        return $false
    }

    # Returns a human-readable summary of the scope.
    [string] ToString()
    {
        return "[$($this.ComputerName)] $($this.ScopeId) ($($this.Name)) — State: $($this.State) — DNS: $($this.DnsServers -join ', ')"
    }

    #endregion <Methods>
}
#EndRegion '.\Classes\01_PSATDhcpScope.ps1' 82
#Region '.\Public\Get-PSATDhcpScopeInfo.ps1' -1

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
#EndRegion '.\Public\Get-PSATDhcpScopeInfo.ps1' 163
#Region '.\Public\Get-PSATDnsDebugLog.ps1' -1

function Get-PSATDnsDebugLog
{
    <#
    .SYNOPSIS
        Parses a Windows DNS Server debug log file into structured objects.

    .DESCRIPTION
        Reads a DNS debug log file produced by the Windows DNS Server service and
        converts each packet entry into a PSCustomObject with human-readable properties.

        The file can be read locally or from a remote server via PowerShell remoting
        (Invoke-Command). When -ComputerName is specified, the log file path refers to
        the path as seen on the remote server.

        Non-packet lines (headers, comments) are silently ignored.
        The encoded DNS label format (e.g. "(3)www(6)google(3)com(0)") is automatically
        decoded into a standard FQDN (e.g. "www.google.com").

        Optional filters allow narrowing results by time range, direction, record type,
        client IP, or query name.

    .PARAMETER Path
        Full path to the DNS debug log file as seen on the target server
        (e.g. C:\Windows\System32\dns\dns.log). Accepts pipeline input.

    .PARAMETER ComputerName
        Name or IP address of the remote DNS server to read the log from.
        Defaults to the local machine. Requires PowerShell remoting (WinRM) on the target.

    .PARAMETER Credential
        Credentials to connect to the remote server. Only used when -ComputerName
        specifies a remote machine.

    .PARAMETER StartTime
        Only return entries at or after this datetime.

    .PARAMETER EndTime
        Only return entries at or before this datetime.

    .PARAMETER Direction
        Filter by packet direction. 'Rcv' = received from client, 'Snd' = sent to client.

    .PARAMETER RecordType
        Filter by DNS record type (e.g. A, AAAA, MX, PTR, SRV, CNAME).

    .PARAMETER ClientIP
        Filter by exact client IP address.

    .PARAMETER QueryName
        Filter by query name. Supports wildcard patterns (e.g. '*.contoso.com').

    .EXAMPLE
        Get-PSATDnsDebugLog -Path 'C:\dns\dns.log'

        Parses all entries from the local log file.

    .EXAMPLE
        Get-PSATDnsDebugLog -Path 'C:\Windows\System32\dns\dns.log' -ComputerName 'dc01.contoso.com'

        Reads and parses the log directly from DC01 via PowerShell remoting.

    .EXAMPLE
        $cred = Get-Credential domain\adminuser
        Get-PSATDnsDebugLog -Path 'C:\dns\dns.log' -ComputerName 'dc01' -Credential $cred -Direction Rcv -RecordType A

        Reads inbound A record queries from a remote server using explicit credentials.

    .EXAMPLE
        Get-PSATDnsDebugLog -Path 'C:\dns\dns.log' -ClientIP '192.168.1.100' |
            Where-Object { $_.ResponseCode -eq 'NXDOMAIN' }

        Returns all failed lookups from a specific client.

    .EXAMPLE
        Get-PSATDnsDebugLog -Path 'C:\dns\dns.log' -StartTime (Get-Date).AddHours(-1)

        Returns entries from the last hour.

    .EXAMPLE
        'C:\dns\dc01.log','C:\dns\dc02.log' | Get-PSATDnsDebugLog -RecordType MX

        Parses MX queries from multiple local log files via the pipeline.

    .OUTPUTS
        PSCustomObject with the following properties:
        - Timestamp     [datetime]  : Date and time of the entry
        - Protocol      [string]    : Transport protocol (UDP or TCP)
        - Direction     [string]    : Rcv (received) or Snd (sent)
        - ClientIP      [string]    : Remote IP address
        - TransactionId [string]    : DNS transaction ID (XID) in hexadecimal
        - MessageType   [string]    : Query or Response
        - RecordType    [string]    : DNS record type (A, AAAA, MX, etc.)
        - QueryName     [string]    : Decoded fully qualified domain name
        - ResponseCode  [string]    : DNS response code (NOERROR, NXDOMAIN, SERVFAIL, etc.)
        - Flags         [string]    : DNS flags present in the packet
        - ThreadId      [string]    : Server thread ID in hexadecimal
        - SourceComputer [string]   : Hostname the log was read from

    .NOTES
        The DNS debug log must be enabled on the DNS server beforehand.
        Use Set-PSATDnsDebugLogging to enable it.

        Remote access requires WinRM to be enabled and configured on the target server.
        The account used must have permission to read the log file path on the remote machine.

        Log line format (Windows DNS Server):
        <Date> <Time> <ThreadId> PACKET <PacketId> <Protocol> <Direction> <ClientIP>
            <XID> <QR> [<Opcode> <Flags> <RCode>] <RecordType> <EncodedName>
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [datetime]$StartTime,

        [Parameter()]
        [datetime]$EndTime,

        [Parameter()]
        [ValidateSet('Rcv', 'Snd')]
        [string]$Direction,

        [Parameter()]
        [string]$RecordType,

        [Parameter()]
        [string]$ClientIP,

        [Parameter()]
        [string]$QueryName
    )

    BEGIN
    {
        Write-Verbose -Message "Starting $($MyInvocation.MyCommand.Name)"

        # Matches Windows DNS debug log packet lines.
        # Format: Date Time ThreadId PACKET PacketId Protocol Direction ClientIP XID QR [Flags] RecordType EncodedName
        $script:packetPattern = [regex](
            '^(?<Date>\d{1,2}/\d{1,2}/\d{4})\s+' +
            '(?<Time>\d{1,2}:\d{2}:\d{2}\s+[AP]M)\s+' +
            '(?<ThreadId>[0-9A-Fa-f]+)\s+PACKET\s+[0-9A-Fa-f]+\s+' +
            '(?<Protocol>UDP|TCP)\s+' +
            '(?<Direction>Rcv|Snd)\s+' +
            '(?<ClientIP>[\d.a-fA-F:]+)\s+' +
            '(?<XID>[0-9A-Fa-f]+)\s+' +
            '(?<QR>[QR])\s+' +
            '\[(?<Flags>[^\]]+)\]\s+' +
            '(?<RecordType>\S+)\s+' +
            '(?<QueryName>.+)$'
        )

        # Determine whether we are targeting the local machine.
        $localName = if ($null -ne $env:COMPUTERNAME) { $env:COMPUTERNAME } else { [System.Net.Dns]::GetHostName() }
        $script:isLocal = ($ComputerName -eq $localName) -or
                          ($ComputerName -eq 'localhost') -or
                          ($ComputerName -eq '127.0.0.1')

        # Build Invoke-Command parameter base for remote calls (reused per Path).
        if (-not $script:isLocal)
        {
            $script:invokeBase = @{
                ComputerName = $ComputerName
                ErrorAction  = 'Stop'
            }

            if ($PSBoundParameters.ContainsKey('Credential'))
            {
                $script:invokeBase['Credential'] = $Credential
            }

            Write-Verbose -Message "Remote mode: connecting to '$ComputerName' via PowerShell remoting"
        }
    }

    PROCESS
    {
        # Retrieve log lines — locally or via remoting.
        $lines = $null

        if ($script:isLocal)
        {
            if (-not (Test-Path -Path $Path -PathType Leaf))
            {
                Write-Error -Message "DNS debug log file not found: '$Path'"
                return
            }

            Write-Verbose -Message "Reading local log: '$Path'"

            try
            {
                $lines = [System.IO.File]::ReadLines($Path)
            }
            catch
            {
                Write-Error -Message "Failed to read '$Path': $($_.Exception.Message)"
                return
            }
        }
        else
        {
            Write-Verbose -Message "Reading remote log: '$Path' on '$ComputerName'"

            try
            {
                $remoteScriptBlock = {
                    param ($RemotePath)

                    if (-not (Test-Path -Path $RemotePath -PathType Leaf))
                    {
                        throw "File not found on remote host: '$RemotePath'"
                    }

                    Get-Content -Path $RemotePath -ErrorAction Stop
                }

                $invokeParams = $script:invokeBase.Clone()
                $invokeParams['ScriptBlock']  = $remoteScriptBlock
                $invokeParams['ArgumentList'] = $Path

                $lines = Invoke-Command @invokeParams
            }
            catch
            {
                Write-Error -Message "Failed to read '$Path' from '$ComputerName': $($_.Exception.Message)"
                return
            }
        }

        # Parse each line.
        foreach ($line in $lines)
        {
            $match = $script:packetPattern.Match($line)

            if (-not $match.Success)
            {
                continue
            }

            # Parse timestamp from date + time groups.
            try
            {
                $timestamp = [datetime]::Parse(
                    "$($match.Groups['Date'].Value) $($match.Groups['Time'].Value)"
                )
            }
            catch
            {
                Write-Warning -Message "Could not parse timestamp on line: $line"
                continue
            }

            # Apply time filters early to avoid unnecessary object creation.
            if ($PSBoundParameters.ContainsKey('StartTime') -and $timestamp -lt $StartTime)
            {
                continue
            }
            if ($PSBoundParameters.ContainsKey('EndTime') -and $timestamp -gt $EndTime)
            {
                continue
            }

            $entryDirection = $match.Groups['Direction'].Value
            if ($PSBoundParameters.ContainsKey('Direction') -and $entryDirection -ne $Direction)
            {
                continue
            }

            $entryRecordType = $match.Groups['RecordType'].Value
            if ($PSBoundParameters.ContainsKey('RecordType') -and $entryRecordType -ne $RecordType)
            {
                continue
            }

            $entryClientIP = $match.Groups['ClientIP'].Value
            if ($PSBoundParameters.ContainsKey('ClientIP') -and $entryClientIP -ne $ClientIP)
            {
                continue
            }

            # Decode DNS label-encoded name: (3)www(6)google(3)com(0) -> www.google.com
            $rawQueryName = $match.Groups['QueryName'].Value.Trim()
            $decodedName = ([regex]::Replace($rawQueryName, '\(\d+\)', '.')).Trim('.')

            if ($PSBoundParameters.ContainsKey('QueryName') -and $decodedName -notlike $QueryName)
            {
                continue
            }

            # Parse flags block: e.g. "0001   D   NOERROR" or "8081   DR  NOERROR"
            $flagTokens = ($match.Groups['Flags'].Value.Trim() -split '\s+') |
                Where-Object -FilterScript { $_ -ne '' }

            $responseCode = if ($flagTokens.Count -ge 1) { $flagTokens[-1] } else { '' }
            $flagChars = if ($flagTokens.Count -ge 3)
            {
                ($flagTokens[1..($flagTokens.Count - 2)]) -join ' '
            }
            else
            {
                ''
            }

            [PSCustomObject]@{
                Timestamp        = $timestamp
                Protocol         = $match.Groups['Protocol'].Value
                Direction        = $entryDirection
                ClientIP         = $entryClientIP
                TransactionId    = $match.Groups['XID'].Value.ToUpper()
                MessageType      = if ($match.Groups['QR'].Value -eq 'Q') { 'Query' } else { 'Response' }
                RecordType       = $entryRecordType
                QueryName        = $decodedName
                ResponseCode     = $responseCode
                Flags            = $flagChars
                ThreadId         = $match.Groups['ThreadId'].Value.ToUpper()
                SourceComputer   = $ComputerName
            }
        }
    }

    END
    {
        Write-Verbose -Message "Ending $($MyInvocation.MyCommand.Name)"
    }
}
#EndRegion '.\Public\Get-PSATDnsDebugLog.ps1' 339
#Region '.\Public\Set-PSATDnsDebugLogging.ps1' -1

function Set-PSATDnsDebugLogging
{
    <#
    .SYNOPSIS
        Enables or disables DNS Debug Logging on a DNS server.

    .DESCRIPTION
        Configures the DNS Debug Logging feature on a local or remote DNS server.
        When enabling, you can specify the log file path and its maximum size in bytes.
        Uses the DnsServer module (Set-DnsServerDiagnostics / Set-DnsServerDebugLogging).

    .PARAMETER ComputerName
        The DNS server to configure. Defaults to the local machine.

    .PARAMETER Enable
        Switch to enable DNS Debug Logging.

    .PARAMETER Disable
        Switch to disable DNS Debug Logging.

    .PARAMETER LogFilePath
        Full path and name of the debug log file (e.g. C:\Temp\dns.log).
        Required when -Enable is specified.

    .PARAMETER MaxLogFileSizeBytes
        Maximum size of the log file in bytes. Defaults to 500000000 (500 MB).
        Only used when -Enable is specified.

    .PARAMETER Credential
        Optional credentials to connect to the remote DNS server.

    .EXAMPLE
        Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log'

        Enables DNS debug logging on the local server with default max size (500 MB).

    .EXAMPLE
        Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log' -MaxLogFileSizeBytes 1000000000 -ComputerName 'DC01'

        Enables DNS debug logging on DC01 with a 1 GB max log size.

    .EXAMPLE
        Set-PSATDnsDebugLogging -Disable -ComputerName 'DC01'

        Disables DNS debug logging on DC01.

    .PARAMETER Credential
        Credentials used to connect to the remote DNS server via CimSession.
        Required when running from an admin workstation targeting a remote server.

    .NOTES
        Requires the DnsServer PowerShell module (available via RSAT on admin workstations).
        Credentials are passed through a CimSession, which is the only supported mechanism
        for Set-DnsServerDiagnostics remote authentication.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Enable')]
    [OutputType([void])]
    param
    (
        [Parameter(ParameterSetName = 'Enable')]
        [Parameter(ParameterSetName = 'Disable')]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true, ParameterSetName = 'Enable')]
        [switch]$Enable,

        [Parameter(Mandatory = $true, ParameterSetName = 'Disable')]
        [switch]$Disable,

        [Parameter(Mandatory = $true, ParameterSetName = 'Enable')]
        [ValidateNotNullOrEmpty()]
        [string]$LogFilePath,

        [Parameter(ParameterSetName = 'Enable')]
        [ValidateRange(1, [long]::MaxValue)]
        [long]$MaxLogFileSizeBytes = 500000000,

        [Parameter(ParameterSetName = 'Enable')]
        [Parameter(ParameterSetName = 'Disable')]
        [System.Management.Automation.PSCredential]$Credential
    )

    BEGIN
    {
        Write-Verbose -Message "Starting $($MyInvocation.MyCommand.Name)"

        if (-not (Get-Module -Name DnsServer -ListAvailable))
        {
            throw 'The DnsServer PowerShell module is not available on this system. Install RSAT DNS Server Tools.'
        }

        # Set-DnsServerDiagnostics does not support -Credential directly.
        # A CimSession is the correct way to pass credentials for remote management.
        $script:cimSession = $null

        try
        {
            $cimSessionParams = @{
                ComputerName = $ComputerName
                ErrorAction  = 'Stop'
            }

            if ($PSBoundParameters.ContainsKey('Credential'))
            {
                $cimSessionParams['Credential'] = $Credential
            }

            Write-Verbose -Message "Opening CimSession to '$ComputerName'"
            $script:cimSession = New-CimSession @cimSessionParams
        }
        catch [Microsoft.Management.Infrastructure.CimException]
        {
            throw "Cannot establish CimSession to '$ComputerName': $($_.Exception.Message)"
        }
        catch
        {
            throw "Failed to create CimSession to '$ComputerName': $($_.Exception.Message)"
        }
    }

    PROCESS
    {
        try
        {
            switch ($PSCmdlet.ParameterSetName)
            {
                'Enable'
                {
                    if ($PSCmdlet.ShouldProcess($ComputerName, "Enable DNS Debug Logging (LogFile: $LogFilePath, MaxSize: $MaxLogFileSizeBytes bytes)"))
                    {
                        Write-Verbose -Message "Enabling DNS Debug Logging on '$ComputerName'"
                        Write-Verbose -Message "  Log file   : $LogFilePath"
                        Write-Verbose -Message "  Max size   : $MaxLogFileSizeBytes bytes"

                        $diagParams = @{
                            CimSession             = $script:cimSession
                            Answers                = $true
                            EnableLogFileRollover  = $true
                            EnableLoggingForLocalLookupEvent     = $false
                            EnableLoggingForPluginDllEvent       = $false
                            EnableLoggingForRecursiveLookupEvent = $false
                            EnableLoggingForRemoteServerEvent    = $false
                            EnableLoggingForServerStartStopEvent = $false
                            EnableLoggingForTombstoneEvent       = $false
                            EnableLoggingForZoneDataWriteEvent   = $false
                            EnableLoggingForZoneLoadingEvent     = $false
                            EnableLoggingToFile    = $true
                            EventLogLevel          = 4
                            FullPackets            = $false
                            LogFilePath            = $LogFilePath
                            MaxMBFileSize          = [math]::Ceiling($MaxLogFileSizeBytes / 1MB)
                            Notifications          = $false
                            Queries                = $true
                            QuestionTransactions   = $true
                            ReceivePackets         = $true
                            SaveLogsToPersistentStorage = $true
                            SendPackets            = $true
                            TcpPackets             = $true
                            UdpPackets             = $true
                            UnmatchedResponse      = $false
                            Update                 = $true
                            UseSystemEventLog      = $true
                            WriteThrough           = $false
                            ErrorAction            = 'Stop'
                        }

                        Set-DnsServerDiagnostics @diagParams
                        Write-Verbose -Message "DNS Debug Logging successfully enabled on '$ComputerName'"
                    }
                }

                'Disable'
                {
                    if ($PSCmdlet.ShouldProcess($ComputerName, 'Disable DNS Debug Logging'))
                    {
                        Write-Verbose -Message "Disabling DNS Debug Logging on '$ComputerName'"

                        $diagParams = @{
                            CimSession          = $script:cimSession
                            All                 = $false
                            EnableLoggingToFile = $false
                            ErrorAction         = 'Stop'
                        }

                        Set-DnsServerDiagnostics @diagParams
                        Write-Verbose -Message "DNS Debug Logging successfully disabled on '$ComputerName'"
                    }
                }
            }
        }
        catch [Microsoft.Management.Infrastructure.CimException]
        {
            Write-Error -Message "CIM error while configuring DNS Debug Logging on '$ComputerName': $($_.Exception.Message)"
        }
        catch [System.UnauthorizedAccessException]
        {
            Write-Error -Message "Access denied while configuring DNS Debug Logging on '$ComputerName': $($_.Exception.Message)"
        }
        catch
        {
            Write-Error -Message "Failed to configure DNS Debug Logging on '$ComputerName': $($_.Exception.Message)"
        }
    }

    END
    {
        if ($null -ne $script:cimSession)
        {
            Write-Verbose -Message "Closing CimSession to '$ComputerName'"
            Remove-CimSession -CimSession $script:cimSession -ErrorAction SilentlyContinue
        }

        Write-Verbose -Message "Ending $($MyInvocation.MyCommand.Name)"
    }
}
#EndRegion '.\Public\Set-PSATDnsDebugLogging.ps1' 217
