BeforeAll {
    $script:ModuleRoot = Resolve-Path -Path "$PSScriptRoot/../../../source"
    . "$script:ModuleRoot/Classes/02_PSATComputerDisk.ps1"
    . "$script:ModuleRoot/Classes/03_PSATComputer.ps1"
    . "$script:ModuleRoot/Classes/04_PSATServer.ps1"
    . "$script:ModuleRoot/Classes/05_PSATWorkstation.ps1"
    . "$script:ModuleRoot/Public/Get-PSATComputerInventory.ps1"

    # ------------------------------------------------------------------
    # AD computer stubs
    # ------------------------------------------------------------------
    $script:ADServer = [PSCustomObject]@{
        Name              = 'SRV01'
        DNSHostName       = 'SRV01.contoso.com'
        DistinguishedName = 'CN=SRV01,OU=Servers,DC=contoso,DC=com'
        Description       = 'Web server'
        Enabled           = $true
        LastLogonDate     = [datetime]'2026-04-01'
        Created           = [datetime]'2024-01-01'
        OperatingSystem   = 'Windows Server 2022 Standard'
    }

    $script:ADWorkstation = [PSCustomObject]@{
        Name              = 'PC01'
        DNSHostName       = 'PC01.contoso.com'
        DistinguishedName = 'CN=PC01,OU=Workstations,DC=contoso,DC=com'
        Description       = 'User laptop'
        Enabled           = $true
        LastLogonDate     = [datetime]'2026-04-09'
        Created           = [datetime]'2023-09-01'
        OperatingSystem   = 'Windows 11 Pro'
    }

    # ------------------------------------------------------------------
    # CIM raw result stub (returned by the script block via Invoke-Command)
    # ------------------------------------------------------------------
    $script:CimServer = [PSCustomObject]@{
        OperatingSystem      = 'Windows Server 2022 Standard'
        OSVersion            = '10.0.20348'
        OSBuild              = '20348'
        Architecture         = '64-bit'
        InstallDate          = [datetime]'2024-01-01'
        LastBootTime         = [datetime]'2026-04-01'
        Uptime               = [timespan]'9.00:00:00'
        ProductType          = 3
        IsDomainController   = $false
        IsVirtual            = $true
        Manufacturer         = 'VMware, Inc.'
        Model                = 'VMware Virtual Platform'
        ProcessorCount       = 2
        CoresPerProcessor    = 4
        TotalRAMGB           = 32.0
        IPAddresses          = [string[]]@('10.0.0.10')
        DnsServers           = [string[]]@('10.0.0.1', '10.0.0.2')
        DefaultGateway       = '10.0.0.254'
        RawDisks             = @(
            [PSCustomObject]@{ DriveLetter = 'C:'; Label = 'System'; FileSystem = 'NTFS'; TotalGB = 100.0; FreeGB = 60.0 }
        )
        PendingReboot        = $false
        ADSite               = 'Site-Paris'
        InstalledRoles       = [string[]]@('Web-Server')
        LastWindowsUpdate    = [datetime]'2026-03-15'
        WorkstationType      = ''
        CurrentLoggedOnUser  = ''
        LastLoggedOnUser     = ''
    }

    $script:CimWorkstation = [PSCustomObject]@{
        OperatingSystem      = 'Windows 11 Pro'
        OSVersion            = '10.0.22621'
        OSBuild              = '22621'
        Architecture         = '64-bit'
        InstallDate          = [datetime]'2023-09-01'
        LastBootTime         = [datetime]'2026-04-08'
        Uptime               = [timespan]'1.05:00:00'
        ProductType          = 1
        IsDomainController   = $false
        IsVirtual            = $false
        Manufacturer         = 'Dell Inc.'
        Model                = 'Latitude 5540'
        ProcessorCount       = 1
        CoresPerProcessor    = 8
        TotalRAMGB           = 16.0
        IPAddresses          = [string[]]@('192.168.1.50')
        DnsServers           = [string[]]@('10.0.0.1')
        DefaultGateway       = '192.168.1.1'
        RawDisks             = @(
            [PSCustomObject]@{ DriveLetter = 'C:'; Label = 'System'; FileSystem = 'NTFS'; TotalGB = 512.0; FreeGB = 200.0 }
        )
        PendingReboot        = $false
        ADSite               = 'Site-Lyon'
        InstalledRoles       = [string[]]@()
        LastWindowsUpdate    = $null
        WorkstationType      = 'Laptop'
        CurrentLoggedOnUser  = 'CONTOSO\jdupont'
        LastLoggedOnUser     = 'CONTOSO\jdupont'
    }

    Mock -CommandName Get-ADComputer -MockWith {
        param ($Identity, $Filter, $Properties, $SearchBase, $ErrorAction)
        if ($PSBoundParameters.ContainsKey('Identity'))
        {
            switch ($Identity)
            {
                'SRV01' { return $script:ADServer }
                'PC01'  { return $script:ADWorkstation }
                default { throw [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]::new("Cannot find an object with identity: '$Identity'") }
            }
        }
        else
        {
            $all = @($script:ADServer, $script:ADWorkstation)
            if ($Filter -like '*Server*')     { return @($script:ADServer) }
            if ($Filter -like '*notlike*')    { return @($script:ADWorkstation) }
            return $all
        }
    }

    Mock -CommandName Test-Connection -MockWith { return $true }

    Mock -CommandName Invoke-Command -MockWith {
        param ($ComputerName, $ScriptBlock, $ErrorAction, $Credential)
        switch ($ComputerName)
        {
            'SRV01' { return $script:CimServer }
            'PC01'  { return $script:CimWorkstation }
            default { throw [System.Exception]::new("WinRM connection failed") }
        }
    }
}

Describe 'Get-PSATComputerInventory' {

    Context 'Output type' {

        It 'Should return [PSATServer] for a server' {
            $result = Get-PSATComputerInventory -ComputerName 'SRV01'
            $result | Should -BeOfType [PSATServer]
        }

        It 'Should return [PSATWorkstation] for a workstation' {
            $result = Get-PSATComputerInventory -ComputerName 'PC01'
            $result | Should -BeOfType [PSATWorkstation]
        }

        It 'Should return objects that are also [PSATComputer] instances' {
            $result = Get-PSATComputerInventory -ComputerName 'SRV01'
            $result | Should -BeOfType [PSATComputer]
        }

        It 'Should return both server and workstation when querying AD without filter' {
            $result = Get-PSATComputerInventory
            ($result | Where-Object { $_ -is [PSATServer] })      | Should -Not -BeNullOrEmpty
            ($result | Where-Object { $_ -is [PSATWorkstation] }) | Should -Not -BeNullOrEmpty
        }
    }

    Context 'ComputerType filter' {

        It 'Should return only servers when -ComputerType Server is specified' {
            $result = Get-PSATComputerInventory -ComputerType 'Server'
            $result | ForEach-Object { $_ | Should -BeOfType [PSATServer] }
        }

        It 'Should skip a workstation when -ComputerType Server is specified by name' {
            $result = Get-PSATComputerInventory -ComputerName 'PC01' -ComputerType 'Server'
            $result | Should -BeNullOrEmpty
        }

        It 'Should return only workstations when -ComputerType Workstation is specified' {
            $result = Get-PSATComputerInventory -ComputerType 'Workstation'
            $result | ForEach-Object { $_ | Should -BeOfType [PSATWorkstation] }
        }
    }

    Context 'Data population — server' {

        It 'Should set ComputerName from AD' {
            (Get-PSATComputerInventory -ComputerName 'SRV01').ComputerName | Should -Be 'SRV01'
        }

        It 'Should set FQDN from AD' {
            (Get-PSATComputerInventory -ComputerName 'SRV01').FQDN | Should -Be 'SRV01.contoso.com'
        }

        It 'Should set OU from DistinguishedName' {
            (Get-PSATComputerInventory -ComputerName 'SRV01').OU | Should -Be 'OU=Servers,DC=contoso,DC=com'
        }

        It 'Should set OperatingSystem from CIM when online' {
            (Get-PSATComputerInventory -ComputerName 'SRV01').OperatingSystem | Should -Be 'Windows Server 2022 Standard'
        }

        It 'Should set IsVirtual from CIM' {
            (Get-PSATComputerInventory -ComputerName 'SRV01').IsVirtual | Should -BeTrue
        }

        It 'Should populate Disks from CIM' {
            (Get-PSATComputerInventory -ComputerName 'SRV01').Disks.Count | Should -Be 1
        }

        It 'Should set InstalledRoles from CIM' {
            (Get-PSATComputerInventory -ComputerName 'SRV01').InstalledRoles | Should -Contain 'Web-Server'
        }

        It 'Should set ADSite from the CIM script block' {
            (Get-PSATComputerInventory -ComputerName 'SRV01').ADSite | Should -Be 'Site-Paris'
        }
    }

    Context 'Data population — workstation' {

        It 'Should set WorkstationType from CIM' {
            (Get-PSATComputerInventory -ComputerName 'PC01').WorkstationType | Should -Be 'Laptop'
        }

        It 'Should set CurrentLoggedOnUser from CIM' {
            (Get-PSATComputerInventory -ComputerName 'PC01').CurrentLoggedOnUser | Should -Be 'CONTOSO\jdupont'
        }

        It 'Should set TotalRAMGB from CIM' {
            (Get-PSATComputerInventory -ComputerName 'PC01').TotalRAMGB | Should -Be 16.0
        }
    }

    Context 'Offline machine handling' {

        BeforeEach {
            Mock -CommandName Test-Connection -MockWith { return $false }
        }

        AfterEach {
            Mock -CommandName Test-Connection -MockWith { return $true }
        }

        It 'Should still return an object when the machine is offline' {
            $result = Get-PSATComputerInventory -ComputerName 'SRV01'
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should set IsOnline to $false for an offline machine' {
            (Get-PSATComputerInventory -ComputerName 'SRV01').IsOnline | Should -BeFalse
        }

        It 'Should fall back to AD OperatingSystem when offline' {
            (Get-PSATComputerInventory -ComputerName 'SRV01').OperatingSystem | Should -Be 'Windows Server 2022 Standard'
        }

        It 'Should not call Invoke-Command when machine is offline' {
            Get-PSATComputerInventory -ComputerName 'SRV01'
            Should -Invoke Invoke-Command -Times 0
        }
    }

    Context 'Remote access' {

        It 'Should call Invoke-Command for each online machine' {
            Get-PSATComputerInventory -ComputerName 'SRV01'
            Should -Invoke Invoke-Command -Times 1 -ParameterFilter { $ComputerName -eq 'SRV01' }
        }

        It 'Should pass Credential to Invoke-Command when provided' {
            $securePassword = ConvertTo-SecureString -String 'P@ssw0rd' -AsPlainText -Force
            $cred = [System.Management.Automation.PSCredential]::new('CONTOSO\admin', $securePassword)
            Get-PSATComputerInventory -ComputerName 'SRV01' -Credential $cred
            Should -Invoke Invoke-Command -Times 1 -ParameterFilter {
                $ComputerName -eq 'SRV01' -and $null -ne $Credential
            }
        }

        It 'Should not pass Credential when none is provided' {
            Get-PSATComputerInventory -ComputerName 'SRV01'
            Should -Invoke Invoke-Command -Times 1 -ParameterFilter {
                $ComputerName -eq 'SRV01' -and $null -eq $Credential
            }
        }
    }

    Context 'AD query' {

        It 'Should warn and skip when a computer is not found in AD' {
            Get-PSATComputerInventory -ComputerName 'UNKNOWN' -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            Should -Invoke Get-ADComputer -Times 1
        }

        It 'Should call Get-ADComputer with SearchBase when provided' {
            Get-PSATComputerInventory -SearchBase 'OU=Servers,DC=contoso,DC=com'
            Should -Invoke Get-ADComputer -Times 1 -ParameterFilter {
                $SearchBase -eq 'OU=Servers,DC=contoso,DC=com'
            }
        }

        It 'Should use a server OS filter when -ComputerType Server is used without ComputerName' {
            Get-PSATComputerInventory -ComputerType 'Server'
            Should -Invoke Get-ADComputer -Times 1 -ParameterFilter {
                $Filter -like '*Server*'
            }
        }
    }

    Context 'Pipeline input' {

        It 'Should accept ComputerName from the pipeline' {
            $result = 'SRV01' | Get-PSATComputerInventory
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should aggregate results from multiple computers via pipeline' {
            $result = 'SRV01', 'PC01' | Get-PSATComputerInventory
            $result.Count | Should -Be 2
        }

        It 'Should continue processing remaining computers when one fails CIM collection' {
            Mock -CommandName Invoke-Command -MockWith {
                param ($ComputerName)
                if ($ComputerName -eq 'SRV01') { throw [System.Exception]::new('WinRM failed') }
                return $script:CimWorkstation
            }

            $result = 'SRV01', 'PC01' | Get-PSATComputerInventory -WarningAction SilentlyContinue
            ($result | Where-Object { $_.ComputerName -eq 'SRV01' }) | Should -Not -BeNullOrEmpty
            ($result | Where-Object { $_.ComputerName -eq 'PC01' })  | Should -Not -BeNullOrEmpty

            Mock -CommandName Invoke-Command -MockWith {
                param ($ComputerName)
                switch ($ComputerName)
                {
                    'SRV01' { return $script:CimServer }
                    'PC01'  { return $script:CimWorkstation }
                }
            }
        }
    }

    Context 'PendingReboot flag' {

        It 'Should set PendingReboot to $true when CIM reports it' {
            Mock -CommandName Invoke-Command -MockWith {
                $cim = $script:CimServer.PSObject.Copy()
                $cim.PendingReboot = $true
                return $cim
            }

            (Get-PSATComputerInventory -ComputerName 'SRV01').PendingReboot | Should -BeTrue

            Mock -CommandName Invoke-Command -MockWith {
                param ($ComputerName)
                switch ($ComputerName)
                {
                    'SRV01' { return $script:CimServer }
                    'PC01'  { return $script:CimWorkstation }
                }
            }
        }
    }
}
