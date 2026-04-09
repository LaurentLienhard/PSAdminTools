# PSAdminTools

PowerShell module providing administration tools for system management.

## Status

**Version**: 0.0.1 (early development)

## Requirements

- PowerShell 7.0 or later
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

### Set-PSATDnsDebugLogging

Enables or disables DNS Debug Logging on a local or remote DNS server.
Uses a CimSession for remote authentication, allowing execution from an admin workstation.

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `-Enable` | switch | Enable DNS debug logging (mutually exclusive with -Disable) |
| `-Disable` | switch | Disable DNS debug logging (mutually exclusive with -Enable) |
| `-LogFilePath` | string | Full path of the debug log file (required with -Enable) |
| `-MaxLogFileSizeBytes` | long | Maximum log file size in bytes (default: 500000000) |
| `-ComputerName` | string | Target DNS server (default: local machine) |
| `-Credential` | PSCredential | Credentials for remote connection via CimSession |

**Examples:**
```powershell
# Enable on a remote DNS server from admin workstation
$cred = Get-Credential domain\adminuser
Set-PSATDnsDebugLogging -Enable -LogFilePath 'C:\Temp\dns.log' `
    -MaxLogFileSizeBytes 500000000 -ComputerName 'dc01.contoso.com' -Credential $cred

# Disable debug logging
Set-PSATDnsDebugLogging -Disable -ComputerName 'dc01.contoso.com' -Credential $cred
```

**Requirements:** DnsServer PowerShell module (RSAT DNS Server Tools)

### Get-PSATDnsDebugLog

Parses a Windows DNS Server debug log file into structured PowerShell objects.
Non-packet lines (headers, comments) are silently ignored.
The DNS label-encoded format (e.g. `(3)www(6)google(3)com(0)`) is automatically decoded to a standard FQDN.

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `-Path` | string | Path to the DNS debug log file as seen on the target server (pipeline-capable) |
| `-ComputerName` | string | Remote DNS server to read the log from (default: local machine) |
| `-Credential` | PSCredential | Credentials for the remote connection (WinRM) |
| `-StartTime` | datetime | Only return entries at or after this time |
| `-EndTime` | datetime | Only return entries at or before this time |
| `-Direction` | string | Filter by `Rcv` (received) or `Snd` (sent) |
| `-RecordType` | string | Filter by DNS record type (A, AAAA, MX, PTR, SRV…) |
| `-ClientIP` | string | Filter by exact client IP address |
| `-QueryName` | string | Filter by query name, supports wildcards (e.g. `*.contoso.com`) |

**Output properties per entry:** `Timestamp`, `Protocol`, `Direction`, `ClientIP`, `TransactionId`, `MessageType`, `RecordType`, `QueryName`, `ResponseCode`, `Flags`, `ThreadId`, `SourceComputer`

**Examples:**
```powershell
# Parse all entries locally
Get-PSATDnsDebugLog -Path 'C:\dns\dns.log'

# Read from a remote DNS server
$cred = Get-Credential domain\adminuser
Get-PSATDnsDebugLog -Path 'C:\Windows\System32\dns\dns.log' -ComputerName 'dc01.contoso.com' -Credential $cred

# Only inbound A record queries on a remote server
Get-PSATDnsDebugLog -Path 'C:\dns\dns.log' -ComputerName 'dc01' -Direction Rcv -RecordType A

# All failed lookups from a specific client
Get-PSATDnsDebugLog -Path 'C:\dns\dns.log' -ClientIP '192.168.1.100' |
    Where-Object { $_.ResponseCode -eq 'NXDOMAIN' }

# Last hour of traffic
Get-PSATDnsDebugLog -Path 'C:\dns\dns.log' -StartTime (Get-Date).AddHours(-1)

# Aggregate from multiple local log files
'C:\dns\dc01.log','C:\dns\dc02.log' | Get-PSATDnsDebugLog -RecordType MX
```

**Requirements:** WinRM must be enabled on the remote server for remote log access.

### Get-PSATDhcpScopeInfo

Retrieves IPv4 DHCP scopes and their configured options from one or more DHCP servers.
For each scope, the effective DNS server list is resolved by priority: scope-level option 6 first, then server-level fallback.
The `DnsServersSource` property indicates where the effective DNS list comes from.
Use `-DnsServer` to find all scopes that have a specific IP configured as a DNS server.

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `-ComputerName` | string[] | DHCP server(s) to query — pipeline-capable, default: local machine |
| `-Credential` | PSCredential | Credentials for remote connection (WinRM) |
| `-ScopeId` | string[] | Restrict query to one or more specific scope IDs (e.g. `192.168.1.0`) |
| `-DnsServer` | string[] | Filter: only return scopes whose effective DNS list contains at least one of these IPs |
| `-IncludeInactive` | switch | Also return inactive scopes (default: active only) |

**Output properties per scope:** `ComputerName`, `ScopeId`, `Name`, `State`, `SubnetMask`, `StartRange`, `EndRange`, `LeaseDuration`, `DnsServers`, `DnsServersSource`, `DomainName`, `Router`

**Examples:**
```powershell
# All active scopes from a remote DHCP server
Get-PSATDhcpScopeInfo -ComputerName 'dhcp01.contoso.com'

# Find scopes pointing to a specific DNS server (e.g. old DNS being decommissioned)
Get-PSATDhcpScopeInfo -ComputerName 'dhcp01' -DnsServer '10.0.0.1'

# Search across the entire DHCP infrastructure
$cred = Get-Credential domain\adminuser
'dhcp01', 'dhcp02' | Get-PSATDhcpScopeInfo -Credential $cred -DnsServer '10.0.0.1', '10.0.0.2'

# Include inactive scopes
Get-PSATDhcpScopeInfo -ComputerName 'dhcp01' -IncludeInactive

# Query specific scopes only
Get-PSATDhcpScopeInfo -ComputerName 'dhcp01' -ScopeId '192.168.10.0', '192.168.20.0'
```

**Requirements:** DhcpServer PowerShell module on the target server (included with the DHCP Server role, or via RSAT). WinRM required for remote access.

## License

[MIT](LICENSE) - (c) Laurent LIENHARD
