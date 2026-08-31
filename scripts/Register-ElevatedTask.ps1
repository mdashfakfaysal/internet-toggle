#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Registers the elevated scheduled task for Internet Switcher (one-time setup).
    Invoked from the app via UAC on first switch — no full install required.
#>

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
. (Join-Path $scriptRoot 'EthernetToggle.Common.ps1')

$paths = Get-EthernetTogglePaths -ScriptRoot $scriptRoot
$config = Get-EthernetToggleConfig -ConfigPath $paths.ConfigPath
$toggleScript = Join-Path $scriptRoot 'Toggle-NetworkAdapter.ps1'

if (-not (Test-Path -LiteralPath $toggleScript)) {
    throw "Missing script: $toggleScript"
}

$arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File `"$toggleScript`""

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $config.taskName `
    -Action $action `
    -Principal $principal `
    -Force | Out-Null

Write-Host "Registered scheduled task: $($config.taskName)"
