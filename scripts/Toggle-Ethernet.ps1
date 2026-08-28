#Requires -Version 5.1

param(
    [ValidateSet('Toggle', 'Enable', 'Disable')]
    [string]$Action = 'Toggle'
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'EthernetToggle.Common.ps1')

$paths = Get-EthernetTogglePaths -ScriptRoot $scriptRoot
$config = Get-EthernetToggleConfig -ConfigPath $paths.ConfigPath
Initialize-EthernetToggleState -ActionDir $paths.ActionDir

$Action = Resolve-EthernetToggleAction -ActionFile $paths.ActionFile -DefaultAction $Action

$adapter = Get-NetAdapter -Name $config.adapterName -ErrorAction Stop
$isEnabled = $adapter.AdminStatus -eq 'Up'

switch ($Action) {
    'Enable' {
        if (-not $isEnabled) {
            Enable-NetAdapter -Name $config.adapterName -Confirm:$false
            Show-EthernetToggleToast -Title 'Ethernet enabled' -Message 'The Ethernet adapter is now active.'
        }
        else {
            Show-EthernetToggleToast -Title 'Ethernet already on' -Message 'The Ethernet adapter is already enabled.'
        }
    }
    'Disable' {
        if ($isEnabled) {
            Disable-NetAdapter -Name $config.adapterName -Confirm:$false
            Show-EthernetToggleToast -Title 'Ethernet disabled' -Message 'The Ethernet adapter is now disabled.'
        }
        else {
            Show-EthernetToggleToast -Title 'Ethernet already off' -Message 'The Ethernet adapter is already disabled.'
        }
    }
    default {
        if ($isEnabled) {
            Disable-NetAdapter -Name $config.adapterName -Confirm:$false
            Show-EthernetToggleToast -Title 'Ethernet disabled' -Message 'The Ethernet adapter is now disabled.'
        }
        else {
            Enable-NetAdapter -Name $config.adapterName -Confirm:$false
            Show-EthernetToggleToast -Title 'Ethernet enabled' -Message 'The Ethernet adapter is now active.'
        }
    }
}
