#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
$passed = 0
$failed = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        Write-Host "[PASS] $Name" -ForegroundColor Green
        $script:passed++
    }
    else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        $script:failed++
    }
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$scriptsDir = Join-Path $repoRoot 'scripts'
. (Join-Path $scriptsDir 'EthernetToggle.Common.ps1')
. (Join-Path $scriptsDir 'AdapterValidation.ps1')

Write-Host "Running Internet Switcher tests..." -ForegroundColor Cyan

# Adapter validation
Assert-True (Test-ValidAdapterName 'Ethernet') 'Valid adapter: Ethernet'
Assert-True (Test-ValidAdapterName 'Wi-Fi') 'Valid adapter: Wi-Fi'
Assert-True (-not (Test-ValidAdapterName 'bad;cmd')) 'Reject shell metacharacters'
Assert-True (-not (Test-ValidAdapterName '')) 'Reject empty name'

# JSON request parsing
$temp = Join-Path $env:TEMP "is-test-$([guid]::NewGuid()).json"
try {
    @{ type = 'Enable'; adapter = 'Ethernet' } | ConvertTo-Json -Compress | Set-Content $temp
    $req = Resolve-NetworkToggleRequest -ActionFile $temp -DefaultAction 'Toggle' -DefaultAdapter 'Ethernet'
    Assert-True ($req.Type -eq 'Enable') 'Parse Enable request'
    Assert-True ($req.Adapter -eq 'Ethernet') 'Parse adapter name'
}
finally {
    Remove-Item $temp -Force -ErrorAction SilentlyContinue
}

$switchTemp = Join-Path $env:TEMP "is-switch-$([guid]::NewGuid()).json"
try {
    @{
        type    = 'Switch'
        enable  = @('Wi-Fi')
        disable = @('Ethernet')
        message = 'test'
    } | ConvertTo-Json -Compress | Set-Content $switchTemp
    $req = Resolve-NetworkToggleRequest -ActionFile $switchTemp -DefaultAction 'Toggle' -DefaultAdapter 'Ethernet'
    Assert-True ($req.Type -eq 'Switch') 'Parse Switch request'
    Assert-True ($req.Enable -contains 'Wi-Fi') 'Switch enable list'
    Assert-True ($req.Disable -contains 'Ethernet') 'Switch disable list'
}
finally {
    Remove-Item $switchTemp -Force -ErrorAction SilentlyContinue
}

# Config
$configPath = Join-Path $repoRoot 'config.json'
if (Test-Path $configPath) {
    $config = Get-EthernetToggleConfig -ConfigPath $configPath
    Assert-True ($null -ne $config.ethernetAdapterName) 'Config has ethernetAdapterName'
    Assert-True ($null -ne $config.wifiAdapterName) 'Config has wifiAdapterName'
}

# Version file
$versionPath = Join-Path $repoRoot 'version.json'
Assert-True (Test-Path $versionPath) 'version.json exists'
if (Test-Path $versionPath) {
    $version = Get-Content $versionPath -Raw | ConvertFrom-Json
    Assert-True ($version.version -match '^\d+\.\d+\.\d+$') 'Semantic version format'
}

# Build outputs
Assert-True (Test-Path (Join-Path $repoRoot 'launcher\Edition\EditionService.cs')) 'EditionService exists'
Assert-True (Test-Path (Join-Path $repoRoot 'docs\TECHNICAL_AUDIT.md')) 'Technical audit doc exists'

Write-Host ""
Write-Host "Results: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Red' })
if ($failed -gt 0) { exit 1 }
