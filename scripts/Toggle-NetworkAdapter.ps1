#Requires -Version 5.1

param(
    [ValidateSet('Toggle', 'Enable', 'Disable', 'Switch', 'Batch')]
    [string]$Action = 'Toggle',
    [string]$AdapterName = $null
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'EthernetToggle.Common.ps1')
. (Join-Path $scriptRoot 'AdapterValidation.ps1')

$paths = Get-EthernetTogglePaths -ScriptRoot $scriptRoot
$config = Get-EthernetToggleConfig -ConfigPath $paths.ConfigPath
Initialize-EthernetToggleState -ActionDir $paths.ActionDir

$request = Resolve-NetworkToggleRequest -ActionFile $paths.ActionFile -DefaultAction $Action -DefaultAdapter $config.adapterName

function Set-AdapterState {
    param(
        [string]$Name,
        [ValidateSet('Enable', 'Disable')]
        [string]$DesiredState
    )

    Assert-ValidAdapterName -Name $Name

    $adapter = Get-NetAdapter -Name $Name -ErrorAction SilentlyContinue
    if (-not $adapter) {
        Write-Warning "Adapter not found: $Name"
        return
    }

    $isUp = $adapter.AdminStatus -eq 'Up'
    if ($DesiredState -eq 'Enable' -and -not $isUp) {
        Enable-NetAdapter -Name $Name -Confirm:$false
    }
    elseif ($DesiredState -eq 'Disable' -and $isUp) {
        Disable-NetAdapter -Name $Name -Confirm:$false
    }
}

switch ($request.Type) {
    'Switch' {
        foreach ($name in $request.Disable) {
            Set-AdapterState -Name $name -DesiredState 'Disable'
        }
        foreach ($name in $request.Enable) {
            Set-AdapterState -Name $name -DesiredState 'Enable'
        }
        Show-EthernetToggleToast -Title 'Network switched' -Message ($request.Message)
    }
    'Batch' {
        foreach ($item in $request.Items) {
            Set-AdapterState -Name $item.Adapter -DesiredState $item.Action
        }
        Show-EthernetToggleToast -Title 'Adapters updated' -Message ($request.Message)
    }
    default {
        $target = if ($request.Adapter) { $request.Adapter } else { $config.adapterName }
        Assert-ValidAdapterName -Name $target
        $adapter = Get-NetAdapter -Name $target -ErrorAction SilentlyContinue
        if (-not $adapter) {
            Show-EthernetToggleToast -Title 'Adapter missing' -Message "Could not find `"$target`"."
            return
        }

        $isEnabled = $adapter.AdminStatus -eq 'Up'
        switch ($request.Type) {
            'Enable' {
                if (-not $isEnabled) {
                    Enable-NetAdapter -Name $target -Confirm:$false
                    Show-EthernetToggleToast -Title "$target enabled" -Message "The adapter is now active."
                }
                else {
                    Show-EthernetToggleToast -Title "$target already on" -Message 'The adapter is already enabled.'
                }
            }
            'Disable' {
                if ($isEnabled) {
                    Disable-NetAdapter -Name $target -Confirm:$false
                    Show-EthernetToggleToast -Title "$target disabled" -Message 'The adapter is now disabled.'
                }
                else {
                    Show-EthernetToggleToast -Title "$target already off" -Message 'The adapter is already disabled.'
                }
            }
            default {
                if ($isEnabled) {
                    Disable-NetAdapter -Name $target -Confirm:$false
                    Show-EthernetToggleToast -Title "$target disabled" -Message 'The adapter is now disabled.'
                }
                else {
                    Enable-NetAdapter -Name $target -Confirm:$false
                    Show-EthernetToggleToast -Title "$target enabled" -Message 'The adapter is now active.'
                }
            }
        }
    }
}
