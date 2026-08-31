#Requires -Version 5.1

param(
    [ValidateSet('Toggle', 'Enable', 'Disable', 'Switch', 'Batch')]
    [string]$Action = 'Toggle',
    [string]$AdapterName = $null
)

$ErrorActionPreference = 'Continue'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'EthernetToggle.Common.ps1')
. (Join-Path $scriptRoot 'AdapterValidation.ps1')

$paths = Get-EthernetTogglePaths -ScriptRoot $scriptRoot
$config = Get-EthernetToggleConfig -ConfigPath $paths.ConfigPath
Initialize-EthernetToggleState -ActionDir $paths.ActionDir

Clear-StaleOperationLock -LockFile $paths.LockFile

if (-not (Enter-OperationLock -LockFile $paths.LockFile)) {
    Write-ReliabilityLog 'Skip' 'Operation already in progress'
    exit 0
}

try {
    do {
        $requests = @(Get-QueuedActionRequests -QueueFile $paths.QueueFile -LegacyActionFile $paths.ActionFile)
        if ($requests.Count -eq 0 -and $Action -ne 'Toggle') {
            $requests = @([PSCustomObject]@{ Type = $Action; Adapter = $AdapterName })
        }
        elseif ($requests.Count -eq 0) {
            break
        }

        foreach ($request in $requests) {
            Write-ReliabilityLog 'Process' ($request.Type)
            Invoke-NetworkToggleRequest -Request $request -Config $config
        }
    } while (Test-Path -LiteralPath $paths.QueueFile)
}
finally {
    Exit-OperationLock -LockFile $paths.LockFile
}
