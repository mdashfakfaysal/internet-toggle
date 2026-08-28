#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'EthernetToggle.Common.ps1')

$paths = Get-EthernetTogglePaths -ScriptRoot $scriptRoot
$config = Get-EthernetToggleConfig -ConfigPath $paths.ConfigPath

$startupShortcutPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\$($config.appName).lnk"
$programsShortcutPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$($config.appName).lnk"
$taskbarShortcutPath = Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\$($config.appName).lnk"

$existingTask = Get-ScheduledTask -TaskName $config.taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Unregister-ScheduledTask -TaskName $config.taskName -Confirm:$false
    Write-Host "Removed scheduled task: $($config.taskName)"
}
else {
    Write-Host "Scheduled task not found: $($config.taskName)"
}

foreach ($shortcutPath in @($startupShortcutPath, $programsShortcutPath, $taskbarShortcutPath)) {
    if (Test-Path -LiteralPath $shortcutPath) {
        Remove-Item -LiteralPath $shortcutPath -Force
        Write-Host "Removed shortcut: $shortcutPath"
    }
}

Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -in @('powershell.exe', 'pwsh.exe') -and
        ($_.CommandLine -like '*Ethernet-Launcher.ps1*' -or $_.CommandLine -like '*Launch-EthernetToggle.ps1*')
    } |
    ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        Write-Host "Stopped process: $($_.ProcessId)"
    }

if (Test-Path -LiteralPath $paths.ActionDir) {
    Remove-Item -LiteralPath $paths.ActionDir -Recurse -Force
    Write-Host "Removed local state: $($paths.ActionDir)"
}

Write-Host "$($config.appName) uninstalled."
