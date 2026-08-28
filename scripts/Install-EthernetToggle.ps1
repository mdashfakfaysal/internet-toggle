#Requires -RunAsAdministrator
#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
. (Join-Path $scriptRoot 'EthernetToggle.Common.ps1')

$paths = Get-EthernetTogglePaths -ScriptRoot $scriptRoot
$config = Get-EthernetToggleConfig -ConfigPath $paths.ConfigPath

$buildLauncherScript = Join-Path $scriptRoot 'Build-Launcher.ps1'
$toggleScript = Join-Path $scriptRoot 'Toggle-NetworkAdapter.ps1'
$startupShortcutName = "$($config.appName).lnk"
$legacyShortcutName = "$($config.exeName).lnk"
$startupFolder = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$startupShortcutPath = Join-Path $startupFolder $startupShortcutName
$programsShortcutPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$startupShortcutName"
$taskbarShortcutPath = Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\$startupShortcutName"
$launcherExe = Join-Path $repoRoot "$($config.exeName).exe"

function New-AppShortcut {
    param(
        [string]$ShortcutPath,
        [string]$TargetPath,
        [string]$WorkingDirectory,
        [string]$Description,
        [string]$IconLocation
    )

    $shortcutDirectory = Split-Path -Parent $ShortcutPath
    if (-not (Test-Path -LiteralPath $shortcutDirectory)) {
        New-Item -ItemType Directory -Path $shortcutDirectory -Force | Out-Null
    }

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = ''
    $shortcut.WorkingDirectory = $WorkingDirectory
    $shortcut.Description = $Description
    $shortcut.WindowStyle = 7
    $shortcut.IconLocation = $IconLocation
    $shortcut.Save()
}

function Remove-LegacyShortcuts {
    param([string[]]$ShortcutPaths)

    foreach ($shortcutPath in $ShortcutPaths) {
        if (Test-Path -LiteralPath $shortcutPath) {
            Remove-Item -LiteralPath $shortcutPath -Force
            Write-Host "Removed legacy shortcut: $shortcutPath"
        }
    }
}

if (-not (Test-Path -LiteralPath $toggleScript)) {
    throw "Missing script: $toggleScript"
}

& $buildLauncherScript

if (-not (Test-Path -LiteralPath $launcherExe)) {
    throw "Launcher executable was not created: $launcherExe"
}

$adapter = Get-NetAdapter -Name $config.ethernetAdapterName -ErrorAction SilentlyContinue
if (-not $adapter) {
    Write-Warning "Adapter named `"$($config.ethernetAdapterName)`" was not found. Update config.json if your adapter uses a different name."
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

$iconLocation = "$launcherExe,0"
$shortcutDescription = "$($config.appName) - network adapter control"

New-AppShortcut `
    -ShortcutPath $startupShortcutPath `
    -TargetPath $launcherExe `
    -WorkingDirectory $repoRoot `
    -Description $shortcutDescription `
    -IconLocation $iconLocation

New-AppShortcut `
    -ShortcutPath $programsShortcutPath `
    -TargetPath $launcherExe `
    -WorkingDirectory $repoRoot `
    -Description $shortcutDescription `
    -IconLocation $iconLocation

New-AppShortcut `
    -ShortcutPath $taskbarShortcutPath `
    -TargetPath $launcherExe `
    -WorkingDirectory $repoRoot `
    -Description $shortcutDescription `
    -IconLocation $iconLocation

Remove-LegacyShortcuts -ShortcutPaths @(
    'C:\Users\Admin\Scripts\EthernetToggle\Ethernet Toggle.lnk',
    (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\$legacyShortcutName"),
    (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$legacyShortcutName"),
    (Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\$legacyShortcutName")
)

Write-Host "$($config.appName) installed successfully."
Write-Host ''
Write-Host "App executable: $launcherExe"
Write-Host "Scheduled task: $($config.taskName)"
Write-Host "Startup shortcut: $startupShortcutPath"
Write-Host "Start menu shortcut: $programsShortcutPath"
Write-Host "Taskbar shortcut: $taskbarShortcutPath"
Write-Host ''
Write-Host 'Starting the app now...'

Start-Process -FilePath $launcherExe -WorkingDirectory $repoRoot -WindowStyle Hidden

Write-Host "Search for `"$($config.appName)`" in Start, or use the pinned taskbar icon."
