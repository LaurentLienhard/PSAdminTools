Import-Module -FullyQualifiedName "./output\module\PSAdminTools\0.0.1\PSAdminTools.psm1"
Get-PSATDhcpScopeInfo -ComputerName dsddhcp02 -Credential (Get-Secret AdmAccount)


Get-PSATDhcpScopeInfo: C:\Users\llienhard\Documents\01-DEV\Github\PSAdminTools\test.ps1:2:1
Line |
   2 |  Get-PSATDhcpScopeInfo -ComputerName dsddhcp02 -Credential (Get-Secret …
     |  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Failed to query DHCP server 'dsddhcp02': Cannot find the Windows PowerShell data file 'DhcpServerMigration.psd1' in directory
     | 'C:\Windows\system32\WindowsPowerShell\v1.0\Modules\DhcpServer\fr-FR\', or in any parent culture directories.
PS C:\Users\llienhard\Documents\01-DEV\Github\PSAdminTools>
