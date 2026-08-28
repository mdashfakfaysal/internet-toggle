#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcherScript = Join-Path $scriptRoot 'Ethernet-Launcher.ps1'

if (-not (Test-Path -LiteralPath $launcherScript)) {
    throw "Missing launcher script: $launcherScript"
}

Start-Process -FilePath 'powershell.exe' `
    -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$launcherScript`"") `
    -WorkingDirectory $scriptRoot `
    -WindowStyle Hidden
