#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Attempts to recover a wedged Wi-Fi PnP device without touching Ethernet.
#>

$ErrorActionPreference = 'Continue'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'EthernetToggle.Common.ps1')

Initialize-EthernetToggleState -ActionDir (Join-Path $env:LOCALAPPDATA 'InternetToggle')

$instanceId = 'PCI\VEN_14C3&DEV_7925&SUBSYS_E138105B&REV_00\6&3A12B95&0&00580011'
$interfaceDescription = 'MediaTek Wi-Fi 7 MT7925 Wireless LAN Card'

Write-Host 'Internet Switcher - Wi-Fi recovery (Ethernet will NOT be disabled)' -ForegroundColor Cyan

$eth = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -match 'Realtek' -and $_.Status -eq 'Up' } | Select-Object -First 1
if ($eth) {
    Write-Host "Ethernet still Up: $($eth.Name)" -ForegroundColor Green
}

# Step 1: Remove ghost Not Present Wi-Fi N profiles (keep canonical Wi-Fi name)
$ghosts = @(Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue | Where-Object {
    $_.InterfaceDescription -eq $interfaceDescription -and
    $_.Status -eq 'Not Present' -and
    $_.Name -match '^Wi-Fi\s+\d+$'
})
foreach ($ghost in $ghosts) {
    try {
        Remove-NetAdapter -Name $ghost.Name -Confirm:$false -ErrorAction Stop
        Write-ReliabilityLog 'Ghost' "Removed ghost adapter $($ghost.Name)"
        Write-Host "Removed ghost: $($ghost.Name)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "Could not remove ghost $($ghost.Name): $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

# Step 2-4: PnP recovery on physical device
$device = Get-PnpDevice -Class Net -ErrorAction SilentlyContinue |
    Where-Object { $_.FriendlyName -eq $interfaceDescription } |
    Select-Object -First 1

if ($device) {
    $instanceId = [string]$device.InstanceId
    Write-Host "PnP device: $instanceId status=$($device.Status)" -ForegroundColor Cyan
}

if (-not (Invoke-PnpNetDeviceRecovery -InterfaceDescription $interfaceDescription)) {
    Write-Host 'PnP enable/restart failed - trying remove-device + rescan...' -ForegroundColor Yellow
    try {
        pnputil.exe /remove-device $instanceId 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        pnputil.exe /scan-devices 2>&1 | Out-Null
        Start-Sleep -Seconds 5
    }
    catch {
        Write-Host "pnputil remove/scan failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Start-Sleep -Seconds 2
$pnp = Get-PnpDevice -InstanceId $instanceId -ErrorAction SilentlyContinue
$wifi = Find-BestNetAdapterByDescription -InterfaceDescription $interfaceDescription

Write-Host ''
Write-Host '--- Result ---' -ForegroundColor Cyan
if ($pnp) {
    Write-Host "PnP status: $($pnp.Status) problem=$($pnp.ConfigManagerErrorCode)"
}
if ($wifi) {
    Write-Host "Best adapter: $($wifi.Name) status=$($wifi.Status) admin=$($wifi.AdminStatus)"
}
else {
    Write-Host 'No Wi-Fi net adapter found after recovery.'
}

if ($pnp -and $pnp.Status -eq 'OK' -and $wifi -and $wifi.Status -ne 'Not Present') {
    Write-Host 'Wi-Fi appears recovered.' -ForegroundColor Green
    exit 0
}

Write-Host 'Wi-Fi not fully recovered. Try Device Manager uninstall + scan, reinstall MediaTek driver, or reboot.' -ForegroundColor Yellow
Write-Host 'Ethernet was not disabled during this recovery.' -ForegroundColor Green
exit 1
