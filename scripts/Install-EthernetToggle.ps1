#Requires -RunAsAdministrator
#Requires -Version 5.1

param(
    [ValidateSet('Free', 'Pro', 'Legacy')]
    [string]$Edition = 'Free'
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
. (Join-Path $scriptRoot 'EthernetToggle.Common.ps1')

$paths = Get-EthernetTogglePaths -ScriptRoot $scriptRoot
$config = Get-EthernetToggleConfig -ConfigPath $paths.ConfigPath

$buildLauncherScript = Join-Path $scriptRoot 'Build-Launcher.ps1'
$toggleScript = Join-Path $scriptRoot 'Toggle-NetworkAdapter.ps1'
$startupShortcutName = "$($config.appName).lnk"
$startupFolder = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$startupShortcutPath = Join-Path $startupFolder $startupShortcutName
$programsShortcutPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$startupShortcutName"
$taskbarShortcutPath = Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\$startupShortcutName"
$launcherExe = switch ($Edition) {
    'Pro' { Join-Path $repoRoot 'Internet Switcher Pro.exe' }
    default { Join-Path $repoRoot 'Internet Switcher Free.exe' }
}
$legacyExe = Join-Path $repoRoot 'Internet Toggle.exe'

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

& (Join-Path $scriptRoot 'New-EthernetToggleAssets.ps1')
& $buildLauncherScript -Edition $Edition

if (-not (Test-Path -LiteralPath $launcherExe)) {
    throw "Launcher executable was not created: $launcherExe"
}

foreach ($legacyTaskName in @('ToggleEthernet', 'ToggleInternetAdapter')) {
    $existingTask = Get-ScheduledTask -TaskName $legacyTaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $legacyTaskName -Confirm:$false
        Write-Host "Removed scheduled task: $legacyTaskName"
    }
}

$adapter = Get-NetAdapter -Name $config.ethernetAdapterName -ErrorAction SilentlyContinue
if (-not $adapter) {
    Write-Warning "Adapter named `"$($config.ethernetAdapterName)`" was not found. Update config.json if your adapter uses a different name."
}

$arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File `"$toggleScript`""

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument $arguments

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
$shortcutDescription = "$($config.appName) - internet adapter control"

$settingsDir = Join-Path $env:LOCALAPPDATA 'InternetToggle'
$settingsPath = Join-Path $settingsDir 'settings.json'
if (-not (Test-Path -LiteralPath $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
}

$defaultSettings = @{
    launchAtStartup = $true
    startMinimizedToTray = $true
} | ConvertTo-Json -Compress
Set-Content -LiteralPath $settingsPath -Value $defaultSettings -Encoding UTF8
Write-Host "Default settings: $settingsPath"

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

$legacyNames = @('Ethernet Toggle', 'Network Toggle')
$legacyPaths = @(
    'C:\Users\Admin\Scripts\EthernetToggle\Ethernet Toggle.lnk',
    (Join-Path $repoRoot 'Start Ethernet Toggle.bat')
)

foreach ($legacyName in $legacyNames) {
    $legacyPaths += @(
        (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\$legacyName.lnk"),
        (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$legacyName.lnk"),
        (Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\$legacyName.lnk")
    )
}

Remove-LegacyShortcuts -ShortcutPaths $legacyPaths

Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -in @('Ethernet Toggle.exe', 'Internet Toggle.exe') -or
        ($_.Name -in @('powershell.exe', 'pwsh.exe') -and
            ($_.CommandLine -like '*Ethernet-Launcher.ps1*' -or $_.CommandLine -like '*Launch-EthernetToggle.ps1*'))
    } |
    ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        Write-Host "Stopped process: $($_.ProcessId)"
    }

if (Test-Path -LiteralPath $legacyExe) {
    Remove-Item -LiteralPath $legacyExe -Force -ErrorAction SilentlyContinue
    Write-Host "Removed legacy executable: $legacyExe"
}

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
