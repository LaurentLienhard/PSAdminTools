@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'DscResource.DocGenerator.psm1'

    # Version number of this module.
    ModuleVersion     = '0.13.0'

    GUID              = 'fa8b017d-8e6e-414d-9ab7-c8ab9cb9e9a4'

    # Author of this module
    Author            = 'DSC Community'

    # Company or vendor of this module
    CompanyName       = 'DSC Community'

    # Copyright statement for this module
    Copyright         = '(c) DSC Community contributors.'

    # Description of the functionality provided by this module
    Description       = 'Functionality to help generate documentation for modules.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.0'

    # RequiredModules = @('Sampler') # The Sampler Pack task does not support recursive pack yet.

    <#
        Functions to export from this module, for best performance, do not use
        wildcards and do not delete the entry, use an empty array if there are
        no functions to export.

        This will be automatically update by the build pipeline.
    #>
    FunctionsToExport = @('Add-NewLine','Edit-CommandDocumentation','Invoke-Git','New-DscResourcePowerShellHelp','New-DscResourceWikiPage','New-GitHubWikiSidebar','Publish-WikiContent','Remove-MarkdownMetadataBlock','Set-WikiModuleVersion')

    <#
        Cmdlets to export from this module, for best performance, do not use
        wildcards and do not delete the entry, use an empty array if there are
        no cmdlets to export.
    #>
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    <#
        Aliases to export from this module, for best performance, do not use
        wildcards and do not delete the entry, use an empty array if there are
        no aliases to export.

        This must be set to the aliases to export since there is no way to tell
        the module builder (build pipeline) which aliases to add.
    #>
    AliasesToExport   = @('Task.Clean_Markdown_Metadata','Task.Clean_Markdown_Of_Public_Commands','Task.Clean_WikiContent_For_GitHub_Publish','Task.Copy_Source_Wiki_Folder','Task.Create_Wiki_Output_Folder','Task.Generate_Conceptual_Help','Task.Generate_External_Help_File_For_Public_Commands','Task.Generate_Markdown_For_DSC_Resources','Task.Generate_Markdown_For_Public_Commands','Task.Generate_Wiki_Content','Task.Generate_Wiki_Sidebar','Task.Package_Wiki_Content','Task.Prepare_Markdown_Filenames_For_GitHub_Publish','Task.Publish_GitHub_Wiki_Content')

    # DSC resources to export from this module
    DscResourcesToExport = @()

    <#
        Private data to pass to the module specified in RootModule/ModuleToProcess.
        This may also contain a PSData hashtable with additional module metadata
        used by PowerShell.
    #>
    PrivateData       = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DSC', 'Modules', 'documentation')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/dsccommunity/DscResource.DocGenerator/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/dsccommunity/DscResource.DocGenerator'

            # ReleaseNotes of this module
            ReleaseNotes = '## [0.13.0] - 2025-02-28

### Removed

- Removed `build.psd1` as it is no longer required to build the project.
- Removed ClassAst functions
  - `Get-ClassResourceProperty`
  - `Get-ClassAst`
  - `Get-ClassResourceAst`

### Added

- Added a devcontainer for development.
- Added private function `ConvertTo-WikiSidebarLinkName` that converts a
  name to a format suitable for use as a Wiki sidebar link.
- New tasks:
  - `Prepare_Markdown_FileNames_For_GitHub_Publish` - This task will prepare
    the markdown file names for publishing to the GitHub Wiki by replacing
    hyphens with spaces and converting Unicode hyphens to standard hyphens.
    It can be controlled by parameter `ReplaceHyphen` in the task, which
    defaults to `$true`.
  - `Clean_WikiContent_For_GitHub_Publish` - This task will remove the top
    level header from any markdown file where the top level header equals the
    filename. The task will convert standard hyphens to spaces and Unicode
    hyphens to standard hyphens before comparison. The task can be controlled
    by parameter `RemoveTopLevelHeader` in the task, which defaults to `$true`.
- Added Helper functions as part of [#163] (https://github.com/dsccommunity/DscResource.DocGenerator/pull/163).
  - `Get-ClassPropertyCustomAttribute`
  - `Get-DscResourceAttributeProperty`
  - `Get-DscPropertyType`
  - `Test-ClassPropertyDscAttributeArgument`

### Changed

- `New-GitHubWikiSidebar`
  - Replaces ASCII hyphens for the Wiki sidebar.
  - Replaces Unicode hyphens with standard hyphens for the Wiki sidebar.
- Task `Generate_Wiki_Content`
  - Now calls `Prepare_Markdown_FileNames_For_GitHub_Publish` after the
    markdown files and external help file for command help has been generated.
  - Now calls `Clean_WikiContent_For_GitHub_Publish` as the last step to
    remove the top level header from any markdown file where the top level
    header equals the filename.
- Task `Generate_Markdown_For_Public_Commands`
  - Verbose output of the markdown files that was created.
- Task `Generate_Markdown_For_DSC_Resources`
  - Outputs a warning message if the old configuration key is used in the
    build configuration but keeps using the old configuration key.
- `New-DscClassResourcePage`
  - Remove using Ast to generate documentation. Fixes [#116](https://github.com/dsccommunity/DscResource.DocGenerator/issues/116).
  - Order properties correctly fixes [#126](https://github.com/dsccommunity/DscResource.DocGenerator/issues/126).

### Fixed

- Fix Dockerfile to include GitVersion alias for PowerShell Extension profile script.
- Fix `.vscode/settings.json` file to exclude unrecognized words.
- Fix pipeline issues on Windows PowerShell due to the issue https://github.com/PoshCode/ModuleBuilder/pull/136.


'

            # Prerelease string of this module
            Prerelease = ''
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}
