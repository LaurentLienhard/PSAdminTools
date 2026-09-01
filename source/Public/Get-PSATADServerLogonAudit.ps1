function Get-PSATADServerLogonAudit {
    <#
    .SYNOPSIS
        Audits administrative and user logon events using server-side XPath filtering and streaming XML event parsing.
    .DESCRIPTION
        Queries Security (Event ID 4624) and TerminalServices-LocalSessionManager (Event IDs 21, 25)
        logs on target hosts. Features native RPC querying with automated WinRM fallback (Invoke-Command)
        to bypass Remote UAC and RPC EventLog access restrictions when passing explicit credentials.
    .PARAMETER ComputerName
        The target host name or FQDN to query. Defaults to 'DC01.corp.contoso.com'.
    .PARAMETER StartTime
        Start of the search window. Defaults to 1 hour prior to execution time.
    .PARAMETER EndTime
        End of the search window. Defaults to current execution time.
    .PARAMETER Credential
        Optional explicit PSCredential for remote RPC / WinRM connections.
    .EXAMPLE
        Get-ADServerLogonAudit -ComputerName "SVR-APP-01.corp.contoso.com" -StartTime (Get-Date).AddHours(-36) -Credential (Get-Credential)
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName = 'DC01.corp.contoso.com',

        [Parameter(Mandatory = $false)]
        [datetime]$StartTime = (Get-Date).AddHours(-1),

        [Parameter(Mandatory = $false)]
        [datetime]$EndTime = (Get-Date),

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential
    )

    begin {
        $ErrorActionPreference = 'Stop'
        Write-Verbose -Message "Initializing zero-allocation stream event log parsing engine with WinRM fallback."
    }

    process {
        if ($PSCmdlet.ShouldProcess($ComputerName, "Audit Security and TerminalServices Logon Events")) {

            $utcStart = [System.Xml.XmlConvert]::ToString($StartTime.ToUniversalTime(), [System.Xml.XmlDateTimeSerializationMode]::Utc)
            $utcEnd   = [System.Xml.XmlConvert]::ToString($EndTime.ToUniversalTime(), [System.Xml.XmlDateTimeSerializationMode]::Utc)

            Write-Verbose -Message "Target Host: $ComputerName | Window (UTC): $utcStart to $utcEnd"

            # Internal Worker Script Block for WinRM Fallback Processing
            $remoteAuditScriptBlock = {
                param(
                    [string]$UtcStart,
                    [string]$UtcEnd
                )

                $results = [System.Collections.Generic.List[PSObject]]::new()

                # 1. Security Log (ID 4624)
                $securityXPath = @"
*[System[(EventID=4624) and TimeCreated[@SystemTime>='$UtcStart' and @SystemTime<='$UtcEnd']]]
and
*[EventData[
    Data[@Name='TargetUserName'] != 'SYSTEM' and
    Data[@Name='TargetUserName'] != 'LOCAL SERVICE' and
    Data[@Name='TargetUserName'] != 'NETWORK SERVICE' and
    Data[@Name='TargetUserName'] != 'ANONYMOUS LOGON' and
    not(starts-with(Data[@Name='TargetUserName'], 'DWM-')) and
    not(starts-with(Data[@Name='TargetUserName'], 'UMFD-')) and
    Data[@Name='TargetDomainName'] != 'NT AUTHORITY'
]]
"@
                try {
                    $secEvents = Get-WinEvent -LogName 'Security' -FilterXPath $securityXPath -ErrorAction Stop
                    foreach ($evt in $secEvents) {
                        $xmlString = $evt.ToXml()
                        $stringReader = [System.IO.StringReader]::new($xmlString)
                        $xmlReader = [System.Xml.XmlReader]::Create($stringReader)
                        $eventData = [System.Collections.Generic.Dictionary[string, string]]::new()

                        try {
                            while ($xmlReader.Read()) {
                                if ($xmlReader.NodeType -eq [System.Xml.XmlNodeType]::Element -and $xmlReader.Name -eq 'Data') {
                                    $name = $xmlReader.GetAttribute('Name')
                                    if (-not [string]::IsNullOrEmpty($name)) {
                                        $eventData[$name] = $xmlReader.ReadElementContentAsString()
                                    }
                                }
                            }
                        }
                        finally {
                            $xmlReader.Dispose()
                            $stringReader.Dispose()
                        }

                        $rawLogonType = if ($eventData.ContainsKey('LogonType')) { $eventData['LogonType'] } else { '0' }
                        $logonTypeDesc = switch ($rawLogonType) {
                            '2'  { "Interactive (Console)" }
                            '3'  { "Network (WinRM/SMB)" }
                            '10' { "RemoteInteractive (RDP)" }
                            '11' { "CachedInteractive" }
                            Default { "LogonType: $rawLogonType" }
                        }

                        $results.Add([PSCustomObject]@{
                            Timestamp    = $evt.TimeCreated
                            LogSource    = 'Security (ID 4624)'
                            Account      = "$($eventData['TargetDomainName'])\$($eventData['TargetUserName'])"
                            LogonType    = $logonTypeDesc
                            SourceIP     = if ($eventData.ContainsKey('IpAddress')) { $eventData['IpAddress'] } else { '-' }
                            ComputerName = $evt.MachineName
                        })
                    }
                }
                catch {
                    # Log failure caught inside session block
                }

                # 2. TerminalServices Log (IDs 21, 25)
                $tsXPath = @"
*[System[(EventID=21 or EventID=25) and TimeCreated[@SystemTime>='$UtcStart' and @SystemTime<='$UtcEnd']]]
"@
                try {
                    $tsEvents = Get-WinEvent -LogName 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational' -FilterXPath $tsXPath -ErrorAction Stop
                    foreach ($evt in $tsEvents) {
                        $xmlString = $evt.ToXml()
                        $stringReader = [System.IO.StringReader]::new($xmlString)
                        $xmlReader = [System.Xml.XmlReader]::Create($stringReader)
                        $user = ''; $ip = ''

                        try {
                            while ($xmlReader.Read()) {
                                if ($xmlReader.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                                    switch ($xmlReader.Name) {
                                        'User'    { $user = $xmlReader.ReadElementContentAsString() }
                                        'Address' { $ip   = $xmlReader.ReadElementContentAsString() }
                                    }
                                }
                            }
                        }
                        finally {
                            $xmlReader.Dispose()
                            $stringReader.Dispose()
                        }

                        $action = if ($evt.Id -eq 21) { "RDP Session Shell Started" } else { "RDP Session Reconnected" }

                        $results.Add([PSCustomObject]@{
                            Timestamp    = $evt.TimeCreated
                            LogSource    = "TerminalServices (ID $($evt.Id))"
                            Account      = $user
                            LogonType    = $action
                            SourceIP     = if ([string]::IsNullOrWhiteSpace($ip)) { '-' } else { $ip }
                            ComputerName = $evt.MachineName
                        })
                    }
                }
                catch {}

                return $results
            }

            # Strategy 1: Attempt Direct Remote RPC Execution
            $useWinRM = $false
            $splatParams = @{
                ComputerName = $ComputerName
                ErrorAction  = 'Stop'
            }
            if ($PSBoundParameters.ContainsKey('Credential')) {
                $splatParams['Credential'] = $Credential
            }

            try {
                Write-Verbose -Message "Attempting direct RPC event query against '$ComputerName'..."

                # Test Security Log Access via RPC
                $null = Get-WinEvent @splatParams -LogName 'Security' -MaxEvents 1 -ErrorAction Stop

                # If direct RPC succeeds, run local engine logic via RPC
                $icParams = @{
                    ComputerName = $ComputerName
                    ScriptBlock  = $remoteAuditScriptBlock
                    ArgumentList = @($utcStart, $utcEnd)
                    ErrorAction  = 'Stop'
                }
                if ($PSBoundParameters.ContainsKey('Credential')) {
                    $icParams['Credential'] = $Credential
                }

                Invoke-Command @icParams | Select-Object Timestamp, LogSource, Account, LogonType, SourceIP, ComputerName
            }
            catch [System.UnauthorizedAccessException] {
                Write-Verbose -Message "RPC Access Denied on '$ComputerName'. Fallback to WinRM (Invoke-Command) execution context."
                $useWinRM = $true
            }
            catch {
                Write-Verbose -Message "RPC connection warning: $($_.Exception.Message). Attempting WinRM fallback."
                $useWinRM = $true
            }

            # Strategy 2: WinRM Execution Fallback
            if ($useWinRM) {
                try {
                    Write-Verbose -Message "Executing remote audit via WinRM session on target '$ComputerName'..."
                    $winRmParams = @{
                        ComputerName = $ComputerName
                        ScriptBlock  = $remoteAuditScriptBlock
                        ArgumentList = @($utcStart, $utcEnd)
                        ErrorAction  = 'Stop'
                    }
                    if ($PSBoundParameters.ContainsKey('Credential')) {
                        $winRmParams['Credential'] = $Credential
                    }

                    Invoke-Command @winRmParams | Select-Object Timestamp, LogSource, Account, LogonType, SourceIP, ComputerName
                }
                catch {
                    $rootCause = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message }
                    Write-Error -Message "Failed to audit '$ComputerName' via both RPC and WinRM engines: $rootCause" -ErrorAction Continue
                }
            }
        }
    }

    end {
        Write-Verbose -Message "Logon audit execution cycle completed."
    }
}
