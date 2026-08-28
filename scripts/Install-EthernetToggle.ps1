#Requires -RunAsAdministrator
#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
. (Join-Path $scriptRoot 'EthernetToggle.Common.ps1')

$paths = Get-EthernetTogglePaths -ScriptRoot $scriptRoot
$config = Get-EthernetToggleConfig -ConfigPath $paths.ConfigPath

$toggleScript = Join-Path $scriptRoot 'Toggle-Ethernet.ps1'
$launchScript = Join-Path $scriptRoot 'Launch-EthernetToggle.ps1'
$startupShortcutName = "$($config.appName).lnk"
$startupFolder = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$startupShortcutPath = Join-Path $startupFolder $startupShortcutName
$programsShortcutPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$startupShortcutName"
$batPath = Join-Path $repoRoot 'Start Ethernet Toggle.bat'

function New-Shortcut {
    param(
        [string]$ShortcutPath,
        [string]$TargetPath,
        [string]$Arguments,
        [string]$WorkingDirectory,
        [string]$Description,
        [string]$IconLocation = $null
    )

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = $WorkingDirectory
    $shortcut.Description = $Description
    $shortcut.WindowStyle = 7
    if ($IconLocation) {
        $shortcut.IconLocation = $IconLocation
    }
    $shortcut.Save()
}

if (-not (Test-Path -LiteralPath $toggleScript)) {
    throw "Missing script: $toggleScript"
}

if (-not (Test-Path -LiteralPath $launchScript)) {
    throw "Missing script: $launchScript"
}

$adapter = Get-NetAdapter -Name $config.adapterName -ErrorAction SilentlyContinue
if (-not $adapter) {
    Write-Warning "Adapter named `"$($config.adapterName)`" was not found. Update config.json if your adapter uses a different name."
}

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$toggleScript`""

$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $config.taskName `
    -Action $action `
    -Principal $principal `
    -Force | Out-Null

$launchArguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$launchScript`""
$iconLocation = if (Test-Path -LiteralPath $paths.IconPath) { "$($paths.IconPath),0" } else { $null }

New-Shortcut `
    -ShortcutPath $startupShortcutPath `
    -TargetPath 'powershell.exe' `
    -Arguments $launchArguments `
    -WorkingDirectory $scriptRoot `
    -Description "$($config.appName) launcher" `
    -IconLocation $iconLocation

New-Shortcut `
    -ShortcutPath $programsShortcutPath `
    -TargetPath 'powershell.exe' `
    -Arguments $launchArguments `
    -WorkingDirectory $scriptRoot `
    -Description "$($config.appName) launcher" `
    -IconLocation $iconLocation

Write-Host "$($config.appName) installed successfully."
Write-Host ''
Write-Host "Scheduled task: $($config.taskName)"
Write-Host "Startup shortcut: $startupShortcutPath"
Write-Host "Start menu shortcut: $programsShortcutPath"
Write-Host "Quick launch: $batPath"
Write-Host ''
Write-Host 'Starting the app now...'

Start-Process -FilePath 'powershell.exe' -ArgumentList $launchArguments -WorkingDirectory $scriptRoot -WindowStyle Hidden

Write-Host 'Look for the tray icon near the clock, or double-click "Start Ethernet Toggle.bat".'
