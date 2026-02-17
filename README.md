# PSAdminTools

PowerShell module providing administration tools for system management.

## Status

**Version**: 0.0.1 (early development)

## Requirements

- PowerShell 7.0 or later
- ActiveDirectory module (RSAT) for AD-related functions
- Build dependencies are automatically resolved on first build

## Build & Test

This project uses the **Sampler/ModuleBuilder** build system.

```powershell
# Full build + tests (default)
./build.ps1

# Build only
./build.ps1 -Tasks build

# Run tests only
./build.ps1 -Tasks test

# Run a specific test file
./build.ps1 -Tasks test -PesterScript tests/Unit/Public/Get-Something.tests.ps1

# Package as NuGet
./build.ps1 -Tasks pack

# Publish to GitHub + PowerShell Gallery
./build.ps1 -Tasks publish
```

Code coverage threshold: **85%**

## Project Structure

```
source/
  ├── Public/           # Exported functions (Verb-PSAT<Noun>.ps1)
  ├── Private/          # Internal helper functions
  ├── Classes/          # PowerShell classes (numbered for load order)
  └── en-US/            # Localization / help files

tests/
  ├── Unit/
  │   ├── Public/       # Tests for public functions
  │   ├── Private/      # Tests for private functions
  │   └── Classes/      # Tests for classes
  └── QA/               # Module-level quality assurance tests

output/                 # Build artifacts (generated)
```

## Available Functions

### Get-PSATSitesReport

Generates a comprehensive Active Directory Sites and Services audit report.

Returns a `PSATSitesReport` object containing:
- **Sites**: All AD sites with their subnets, site links, domain controllers, and adjacent sites
- **Subnets**: All AD subnets with site assignments
- **Site Links**: All site links with cost, replication frequency, and transport type
- **Health Indicators**: Sites without DCs, sites without subnets, subnets without site assignments

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `-Server` | string | AD DS instance to connect to |
| `-Credential` | PSCredential | Credentials for the AD connection |

**Examples:**
```powershell
# Basic usage
Get-PSATSitesReport

# Query a specific domain controller
Get-PSATSitesReport -Server 'dc01.contoso.com'

# Use explicit credentials
$cred = Get-Credential
Get-PSATSitesReport -Credential $cred
```

## License

[MIT](LICENSE) - (c) Laurent LIENHARD
