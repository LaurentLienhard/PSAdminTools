function Get-PSATSitesReport
{
    <#
        .SYNOPSIS
        Generates a comprehensive Active Directory Sites and Services audit report.

        .DESCRIPTION
        Queries Active Directory to collect information about sites, subnets, site links,
        and domain controllers. Returns a PSATSitesReport object containing the full
        topology and health indicators such as sites without domain controllers,
        sites without subnets, and subnets without site assignments.

        .PARAMETER Server
        Specifies the Active Directory Domain Services instance to connect to.

        .PARAMETER Credential
        Specifies the credentials to use when connecting to Active Directory.

        .EXAMPLE
        Get-PSATSitesReport

        Returns a full AD Sites and Services report using the current user's credentials.

        .EXAMPLE
        Get-PSATSitesReport -Server 'dc01.contoso.com'

        Returns a report querying a specific domain controller.

        .EXAMPLE
        $cred = Get-Credential
        Get-PSATSitesReport -Credential $cred

        Returns a report using explicit credentials.

        .EXAMPLE
        $cred = Get-Credential
        Get-PSATSitesReport -Server 'dc01.contoso.com' -Credential $cred

        Returns a report from a remote domain controller using explicit credentials.
    #>
    [CmdletBinding()]
    [OutputType([PSATSitesReport])]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    BEGIN
    {
        Write-Verbose -Message 'Get-PSATSitesReport - Checking ActiveDirectory module availability.'

        try
        {
            $importParams = @{
                Name        = 'ActiveDirectory'
                ErrorAction = 'Stop'
            }
            Import-Module @importParams
        }
        catch [System.IO.FileNotFoundException]
        {
            $errorMessage = 'The ActiveDirectory module is not installed. Install RSAT tools or the ActiveDirectory module.'
            Write-Error -Message $errorMessage -ErrorAction Stop
            return
        }
    }

    PROCESS
    {
        $report = [PSATSitesReport]::new()

        $connectionParams = @{}
        $connectionInfo = @()

        if ($PSBoundParameters.ContainsKey('Server'))
        {
            $connectionParams['Server'] = $Server
            $connectionInfo += "server '$Server'"
        }

        if ($PSBoundParameters.ContainsKey('Credential'))
        {
            $connectionParams['Credential'] = $Credential
            $connectionInfo += "credential '$($Credential.UserName)'"
        }

        $verboseMessage = if ($connectionInfo.Count -gt 0)
        {
            'Get-PSATSitesReport - Querying Active Directory Sites and Services using {0}.' -f ($connectionInfo -join ' and ')
        }
        else
        {
            'Get-PSATSitesReport - Querying Active Directory Sites and Services using current user context.'
        }

        try
        {
            Write-Verbose -Message $verboseMessage
            $report.QueryAD($connectionParams)
        }
        catch [System.UnauthorizedAccessException]
        {
            Write-Error -Message ('Access denied when querying Active Directory: {0}' -f $_.Exception.Message) -ErrorAction Stop
            return
        }
        catch
        {
            $exTypeName = $_.Exception.GetType().FullName
            if ($exTypeName -eq 'Microsoft.ActiveDirectory.Management.ADException')
            {
                Write-Error -Message ('Active Directory query failed: {0}' -f $_.Exception.Message) -ErrorAction Stop
            }
            else
            {
                Write-Error -Message ('Unexpected error while generating AD Sites report: {0}' -f $_.Exception.Message) -ErrorAction Stop
            }
            return
        }

        Write-Verbose -Message ('Get-PSATSitesReport - Report generated: {0}' -f $report.ToString())
        $report
    }

    END
    {
    }
}
