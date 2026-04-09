Import-Module -FullyQualifiedName "./output\module\PSAdminTools\0.0.1\PSAdminTools.psm1"
Get-PSATDhcpScopeInfo -ComputerName dsddhcp02 -Credential (Get-Secret AdmAccount)


Get-PSATDhcpScopeInfo: C:\Users\llienhard\Documents\01-DEV\Github\PSAdminTools\test.ps1:2:1
Line |
   2 |  Get-PSATDhcpScopeInfo -ComputerName dsddhcp02 -Credential (Get-Secret …
     |  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Failed to query DHCP server 'dsddhcp02': The term 'if' is not recognized as the name of a cmdlet, function, script file, or operable program. Check the spelling of the name, or if a
     | path was included, verify that the path is correct and try again.
