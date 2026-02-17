# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PSAdminTools is a PowerShell administration tools module. The repository is hosted at https://github.com/LaurentLienhard/PSAdminTools and licensed under MIT (Laurent LIENHARD, 2026).

## Current State

The project is in its initial setup phase — only a LICENSE file exists. No module manifest, source code, tests, or build automation have been created yet.

## PowerShell Module Conventions

When developing this module, follow standard PowerShell module structure:
- Module manifest: `PSAdminTools.psd1`
- Root module file: `PSAdminTools.psm1`
- Use Pester for testing
- Use PSScriptAnalyzer for linting

## Git Workflow

- **Le fichier README.md doit être mis à jour avant chaque `git commit` et `git push`** pour refléter les nouveautés (nouvelles fonctions, changements d'API, nouvelles dépendances, etc.)

## Code Style

### General Rules
- **All code, functions, and documentation must be written in English**
- Comment-based help must be placed **immediately after the function name** (inside the function, before `[CmdletBinding()]`)
- **Every function (Public and Private) and every class must have a corresponding Pester test file**
- Tests must use mocks for external dependencies (no real API/AD/network calls)
- Each function/class must achieve **minimum 85% code coverage**
- **Prefer `Write-Verbose` over `Write-Host` or `Write-Output`** for informational messages

### Function Structure
- Use **uppercase** for `BEGIN`, `PROCESS`, `END` blocks
- Use `[CmdletBinding()]` for all functions
- Use `[OutputType()]` attribute when returning specific types
- Support pipeline input with `ValueFromPipeline` and `ValueFromPipelineByPropertyName`
- Use `[Parameter()]` attribute with `Mandatory`, `HelpMessage`, `Position` as needed
- Use validation attributes: `[ValidateSet()]`, `[ValidateNotNullOrEmpty()]`, `[ValidateRange()]`

### Naming Conventions

#### Function Naming - REQUIRED MODULE PREFIX

**All public functions MUST be prefixed with `PSAT` to avoid naming conflicts.**

**Format**: `<Verb>-PSAT<Noun>`

**Examples:**
- `Get-PSATInfo`
- `Test-PSATHealth`
- `Set-PSATPermission`

All verbs must be from `Get-Verb` approved list.

#### Private Functions

Private functions (in `source/Private/`) may use simpler names without the full prefix but using the full `PSAT` prefix is recommended for consistency.

### Code Formatting

**Brace Placement:**
- Opening braces on **new line**: `OpenBraceOnSameLine = false`
- New line after opening brace: `true`
- New line after closing brace: `true`
- Whitespace before opening brace: `true`

**Spacing & Operators:**
- Whitespace before opening parenthesis: `true`
- Whitespace around operators: `true`
- Whitespace after separator: `true`
- Align property value pairs: `true`

**Pipeline Formatting:**
- Pipeline indentation style: `IncreaseIndentationAfterEveryPipeline`
- Single-line blocks ignored: `false`

**File Formatting:**
- Trim trailing whitespace: `true`
- Trim final newlines: `true`
- Insert final newline: `true`

**Example formatted code:**
```powershell
function Get-Example
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $result = Get-Content -Path $Name |
        Where-Object { $_ -match 'pattern' } |
        Select-Object -Property Property1, Property2

    return $result
}
```

### Coding Conventions
- Use **splatting** for commands with multiple parameters:
  ```powershell
  $params = @{
      ComputerName = $Computer
      ErrorAction  = 'Stop'
  }
  Invoke-Command @params
  ```
- Use `[PSCustomObject]@{}` for structured output objects
- Use `[System.Collections.Generic.List[T]]::new()` instead of `ArrayList` for collections
- Use `try/catch` blocks with specific exception types when possible
- Use `[SuppressMessageAttribute()]` to bypass PSScriptAnalyzer rules only when justified

### Parameter Patterns
- Credential parameter pattern (optional credentials):
  ```powershell
  [Parameter()]
  [System.Management.Automation.PSCredential]$Credential
  ```
- Check for credential with `$PSBoundParameters.ContainsKey('Credential')`

### Error Handling - REQUIRED

All functions MUST implement comprehensive error handling:
- **Catch specific exceptions first** before generic `[System.Exception]`
- **Set `-ErrorAction Stop`** on all external commands
- **Use try-catch-finally** for resource cleanup
- **Provide context in error messages** with relevant variable values
- Use `Write-Error` for terminating errors, `Write-Warning` for non-terminating issues

**Error message format:**
```powershell
# Contextual messages with variable values
Write-Error "Failed to process '$Name' in domain '$($env:USERDOMAIN)': $($_.Exception.Message)"
```

### Class Structure
- Use `#region` comments to organize sections: `#region <Properties>`, `#region <Constructor>`, `#region <Methods>`
- Prefix class files with numbers for load order (e.g., `01_Server.ps1`, `02_Service.ps1`)
- Use `HIDDEN` keyword for internal properties (e.g., credentials)

### Object-Oriented Design Philosophy

**Prefer classes over functions whenever possible.** Use classes for entities with multiple related properties or state. Functions are acceptable for simple stateless utilities, formatters, validators, or orchestration.

### PowerShell Compatibility

- **Minimum**: PowerShell 5.1 (Windows PowerShell)
- Use explicit null checks (`-eq $null`, `-ne $null`) instead of `??` or `?.`
- Use `if/else` instead of ternary operators
- Avoid `ForEach-Object -Parallel` (PowerShell 7+ only) for core functionality
- Use `Join-Path` for cross-platform path handling

### Performance

- Use `[System.Collections.Generic.List[T]]::new()` instead of array concatenation (`+=`)
- Use splatting for clean, maintainable code
- Prefer pipeline filtering over sequential loops
- Use strongly typed collections for better performance
