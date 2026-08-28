#Requires -Version 5.1

BeforeDiscovery {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoScripts = Join-Path (Split-Path -Parent $scriptRoot) 'scripts'
    . (Join-Path $repoScripts 'EthernetToggle.Common.ps1')
    . (Join-Path $repoScripts 'AdapterValidation.ps1')
}

Describe 'Adapter name validation' {
    It 'Accepts valid adapter names' {
        Test-ValidAdapterName 'Ethernet' | Should -Be $true
        Test-ValidAdapterName 'Wi-Fi' | Should -Be $true
        Test-ValidAdapterName 'Ethernet 2' | Should -Be $true
    }

    It 'Rejects shell metacharacters' {
        Test-ValidAdapterName 'Ethernet; calc' | Should -Be $false
        Test-ValidAdapterName 'Wi-Fi & Ethernet' | Should -Be $false
        Test-ValidAdapterName 'test|whoami' | Should -Be $false
    }

    It 'Rejects empty names' {
        Test-ValidAdapterName '' | Should -Be $false
        Test-ValidAdapterName '   ' | Should -Be $false
    }
}

Describe 'Network toggle request parsing' {
    It 'Parses JSON toggle request' {
        $temp = Join-Path $env:TEMP "is-test-$([guid]::NewGuid()).json"
        try {
            @{ type = 'Enable'; adapter = 'Ethernet' } | ConvertTo-Json -Compress | Set-Content $temp
            Copy-Item $temp (Join-Path $env:TEMP 'pending-test.json')
            $req = Resolve-NetworkToggleRequest -ActionFile $temp -DefaultAction 'Toggle' -DefaultAdapter 'Ethernet'
            $req.Type | Should -Be 'Enable'
            $req.Adapter | Should -Be 'Ethernet'
        }
        finally {
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Parses switch request' {
        $temp = Join-Path $env:TEMP "is-switch-$([guid]::NewGuid()).json"
        try {
            @{
                type    = 'Switch'
                enable  = @('Wi-Fi')
                disable = @('Ethernet')
                message = 'test'
            } | ConvertTo-Json -Compress | Set-Content $temp
            $req = Resolve-NetworkToggleRequest -ActionFile $temp -DefaultAction 'Toggle' -DefaultAdapter 'Ethernet'
            $req.Type | Should -Be 'Switch'
            $req.Enable | Should -Contain 'Wi-Fi'
            $req.Disable | Should -Contain 'Ethernet'
        }
        finally {
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Configuration defaults' {
    It 'Loads config.json from repo root' {
        $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $configPath = Join-Path $repoRoot 'config.json'
        if (-not (Test-Path $configPath)) {
            Set-ItResult -Skipped -Because 'config.json not found'
            return
        }
        $config = Get-EthernetToggleConfig -ConfigPath $configPath
        $config.ethernetAdapterName | Should -Not -BeNullOrEmpty
        $config.wifiAdapterName | Should -Not -BeNullOrEmpty
    }
}
