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
