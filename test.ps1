Import-Module -FullyQualifiedName "./output\module\PSAdminTools\0.0.1\PSAdminTools.psm1"
Get-PSATDhcpScopeInfo -ComputerName dsddhcp02 -Credential (Get-Secret AdmAccount)


Building Module to C:\Users\llienhard\Documents\01-DEV\Github\PSAdminTools\output\module\PSAdminTools...
ERROR: An item with the same key has already been added. Key: PSATDhcpScope
At C:\Users\llienhard\Documents\01-DEV\Github\PSAdminTools\output\RequiredModules\ModuleBuilder\3.1.8\ModuleBuilder.psm1:1130 char:17
+                 Get-Module $OutputManifest -ListAvailable
+                 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
At C:\Users\llienhard\Documents\01-DEV\Github\PSAdminTools\output\RequiredModules\Sampler\0.119.1\tasks\Build-Module.ModuleBuilder.build.ps1:41 char:1
+ Task Build_ModuleOutput_ModuleBuilder {
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Build FAILED. 4 tasks, 1 errors, 0 warnings 00:00:12.0191111
Get-Module: An item with the same key has already been added. Key: PSATDhcpScope
