BeforeAll {
    $script:ModuleRoot = Resolve-Path -Path "$PSScriptRoot/../../../source"
    . "$script:ModuleRoot/Classes/06_PSATNtpConfiguration.ps1"
    . "$script:ModuleRoot/Public/Get-PSATADNTPConfiguration.ps1"

    # Stub raw result returned by Invoke-Command (simulates the script block output)
    $script:RawDC01 = [PSCustomObject]@{
        ComputerName  = 'DC01'
        NTPSource     = 'time.windows.com'
        ConfigType    = 'NTP'
        ServiceStatus = 'Running'
        IsDC          = $true
    }

    $script:RawSRV01 = [PSCustomObject]@{
        ComputerName  = 'SRV01'
        NTPSource     = 'DC01.contoso.com'
        ConfigType    = 'NT5DS'
        ServiceStatus = 'Running'
        IsDC          = $false
    }

    $script:RawError = [PSCustomObject]@{
        ComputerName  = 'OFFLINE01'
        NTPSource     = 'Error'
        ConfigType    = 'Error'
        ServiceStatus = 'Error'
        IsDC          = $false
    }

    Mock -CommandName Get-ADDomain -MockWith {
        [PSCustomObject]@{ PDCEmulator = 'PDC01.contoso.com' }
    }

    Mock -CommandName Get-ADDomainController -MockWith {
        @(
            [PSCustomObject]@{ HostName = 'DC01.contoso.com' }
            [PSCustomObject]@{ HostName = 'DC02.contoso.com' }
        )
    }

    Mock -CommandName Invoke-Command -MockWith {
        param ($ComputerName, $ScriptBlock, $ErrorAction, $Credential)
        switch ($ComputerName)
        {
            'DC01'       { return $script:RawDC01 }
            'SRV01'      { return $script:RawSRV01 }
            'OFFLINE01'  { throw [System.Exception]::new('WinRM connection refused') }
            default      { return $script:RawDC01 }
        }
    }
}

Describe 'Get-PSATADNTPConfiguration' {

    Context 'Output type' {

        It 'Should return [PSATNtpConfiguration] instances' {
            $result = Get-PSATADNTPConfiguration -ComputerName 'DC01'
            $result | Should -BeOfType [PSATNtpConfiguration]
        }

        It 'Should return one object per computer' {
            $result = Get-PSATADNTPConfiguration -ComputerName 'DC01', 'SRV01'
            $result.Count | Should -Be 2
        }
    }

    Context 'Data population' {

        It 'Should set ComputerName correctly' {
            (Get-PSATADNTPConfiguration -ComputerName 'DC01').ComputerName | Should -Be 'DC01'
        }

        It 'Should set NTPSource from the script block result' {
            (Get-PSATADNTPConfiguration -ComputerName 'DC01').NTPSource | Should -Be 'time.windows.com'
        }

        It 'Should set ConfigType correctly' {
            (Get-PSATADNTPConfiguration -ComputerName 'SRV01').ConfigType | Should -Be 'NT5DS'
        }

        It 'Should set ServiceStatus correctly' {
            (Get-PSATADNTPConfiguration -ComputerName 'DC01').ServiceStatus | Should -Be 'Running'
        }

        It 'Should set IsDC correctly' {
            (Get-PSATADNTPConfiguration -ComputerName 'DC01').IsDC | Should -BeTrue
        }
    }

    Context 'AD discovery (no ComputerName)' {

        It 'Should call Get-ADDomain to resolve the PDC Emulator' {
            Get-PSATADNTPConfiguration
            Should -Invoke Get-ADDomain -Times 1
        }

        It 'Should call Get-ADDomainController to discover DCs' {
            Get-PSATADNTPConfiguration
            Should -Invoke Get-ADDomainController -Times 1
        }

        It 'Should use the specified ADServer for DC discovery' {
            Get-PSATADNTPConfiguration -ADServer 'DC01.contoso.com'
            Should -Invoke Get-ADDomainController -Times 1 -ParameterFilter {
                $Server -eq 'DC01.contoso.com'
            }
        }

        It 'Should not call Get-ADDomainController when ComputerName is provided' {
            Get-PSATADNTPConfiguration -ComputerName 'DC01'
            Should -Invoke Get-ADDomainController -Times 0
        }
    }

    Context 'Remote access' {

        It 'Should call Invoke-Command for each target' {
            Get-PSATADNTPConfiguration -ComputerName 'DC01', 'SRV01'
            Should -Invoke Invoke-Command -Times 2
        }

        It 'Should pass Credential to Invoke-Command when provided' {
            $securePassword = ConvertTo-SecureString -String 'P@ssw0rd' -AsPlainText -Force
            $cred = [System.Management.Automation.PSCredential]::new('CONTOSO\admin', $securePassword)
            Get-PSATADNTPConfiguration -ComputerName 'DC01' -Credential $cred
            Should -Invoke Invoke-Command -Times 1 -ParameterFilter {
                $null -ne $Credential
            }
        }

        It 'Should not pass Credential when none is provided' {
            Get-PSATADNTPConfiguration -ComputerName 'DC01'
            Should -Invoke Invoke-Command -Times 1 -ParameterFilter {
                $null -eq $Credential
            }
        }
    }

    Context 'Error handling' {

        It 'Should return an error object when WinRM fails instead of throwing' {
            $result = Get-PSATADNTPConfiguration -ComputerName 'OFFLINE01' -WarningAction SilentlyContinue
            $result | Should -Not -BeNullOrEmpty
            $result.NTPSource | Should -Be 'Error'
        }

        It 'Should continue processing remaining computers when one fails' {
            $result = Get-PSATADNTPConfiguration -ComputerName 'OFFLINE01', 'DC01' -WarningAction SilentlyContinue
            ($result | Where-Object { $_.ComputerName -eq 'DC01' }) | Should -Not -BeNullOrEmpty
        }

        It 'Should write an error when Get-ADDomain fails and no ADServer is provided' {
            Mock -CommandName Get-ADDomain -MockWith { throw [System.Exception]::new('AD unavailable') }
            { Get-PSATADNTPConfiguration -ErrorAction Stop } | Should -Throw
            Mock -CommandName Get-ADDomain -MockWith {
                [PSCustomObject]@{ PDCEmulator = 'PDC01.contoso.com' }
            }
        }
    }

    Context 'Pipeline input' {

        It 'Should accept ComputerName from the pipeline' {
            $result = 'DC01' | Get-PSATADNTPConfiguration
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should process multiple computers from the pipeline' {
            $result = 'DC01', 'SRV01' | Get-PSATADNTPConfiguration
            $result.Count | Should -Be 2
        }
    }

    Context 'Class method integration' {

        It 'IsConfigured should return $true on a properly configured result' {
            (Get-PSATADNTPConfiguration -ComputerName 'DC01').IsConfigured() | Should -BeTrue
        }

        It 'IsServiceRunning should return $true when service is Running' {
            (Get-PSATADNTPConfiguration -ComputerName 'DC01').IsServiceRunning() | Should -BeTrue
        }
    }
}
