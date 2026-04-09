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
