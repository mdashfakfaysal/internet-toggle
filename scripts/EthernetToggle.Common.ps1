#Requires -Version 5.1

function Get-EthernetTogglePaths {
    param([string]$ScriptRoot)

    $repoRoot = Split-Path -Parent $ScriptRoot
    [PSCustomObject]@{
        RepoRoot    = $repoRoot
        ScriptRoot  = $ScriptRoot
        ConfigPath  = Join-Path $repoRoot 'config.json'
        LogoPath    = Join-Path $repoRoot 'assets\logo.png'
        IconPath    = Join-Path $repoRoot 'assets\icon.ico'
        ActionDir   = Join-Path $env:LOCALAPPDATA 'InternetToggle'
        ActionFile  = Join-Path $env:LOCALAPPDATA 'InternetToggle\pending-action.json'
        QueueFile   = Join-Path $env:LOCALAPPDATA 'InternetToggle\pending-action-queue.json'
        LockFile    = Join-Path $env:LOCALAPPDATA 'InternetToggle\operation.lock'
        SignalFile  = Join-Path $env:LOCALAPPDATA 'InternetToggle\show-window.signal'
    }
}

function Get-EthernetToggleConfig {
    param([string]$ConfigPath)

    $defaults = [PSCustomObject]@{
        adapterName         = 'Ethernet'
        ethernetAdapterName = 'Ethernet'
        wifiAdapterName     = 'Wi-Fi'
        taskName            = 'ToggleInternetAdapter'
        appName             = 'Internet Toggle'
        exeName             = 'Internet Toggle'
        excludePatterns     = @('vEthernet', 'Hyper-V')
    }

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        return $defaults
    }

    try {
        $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
        $exclude = @('vEthernet', 'Hyper-V')
        if ($config.excludePatterns) {
            $exclude = @($config.excludePatterns | ForEach-Object { [string]$_ })
        }

        return [PSCustomObject]@{
            adapterName         = if ($config.adapterName) { [string]$config.adapterName } elseif ($config.ethernetAdapterName) { [string]$config.ethernetAdapterName } else { $defaults.adapterName }
            ethernetAdapterName = if ($config.ethernetAdapterName) { [string]$config.ethernetAdapterName } elseif ($config.adapterName) { [string]$config.adapterName } else { $defaults.ethernetAdapterName }
            wifiAdapterName     = if ($config.wifiAdapterName) { [string]$config.wifiAdapterName } else { $defaults.wifiAdapterName }
            taskName            = if ($config.taskName) { [string]$config.taskName } else { $defaults.taskName }
            appName             = if ($config.appName) { [string]$config.appName } else { $defaults.appName }
            exeName             = if ($config.exeName) { [string]$config.exeName } else { $defaults.exeName }
            excludePatterns     = $exclude
        }
    }
    catch {
        return $defaults
    }
}

function Initialize-EthernetToggleState {
    param([string]$ActionDir)

    if (-not (Test-Path -LiteralPath $ActionDir)) {
        New-Item -ItemType Directory -Path $ActionDir -Force | Out-Null
    }
}

function Show-EthernetToggleToast {
    param(
        [string]$Title,
        [string]$Message
    )

    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        $escapedTitle = [System.Security.SecurityElement]::Escape($Title)
        $escapedMessage = [System.Security.SecurityElement]::Escape($Message)

        $template = @"
<toast activationType="foreground">
  <visual>
    <binding template="ToastText02">
      <text id="1">$escapedTitle</text>
      <text id="2">$escapedMessage</text>
    </binding>
  </visual>
</toast>
"@

        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Internet Toggle').Show($toast) | Out-Null
    }
    catch {
        Write-Host "$Title - $Message"
    }
}

function Get-EthernetAdapterEnabled {
    param([string]$AdapterName)

    try {
        $adapter = Get-NetAdapter -Name $AdapterName -ErrorAction Stop
        return $adapter.AdminStatus -eq 'Up'
    }
    catch {
        return $false
    }
}

function Invoke-EthernetToggleAction {
    param(
        [string]$TaskName,
        [string]$ActionFile,
        [ValidateSet('Toggle', 'Enable', 'Disable')]
        [string]$Action,
        [string]$AdapterName = $null
    )

    $payload = [ordered]@{
        type    = $Action
        adapter = $AdapterName
    }
    Set-Content -LiteralPath $ActionFile -Value ($payload | ConvertTo-Json -Compress) -Encoding UTF8 -Force
    Start-Process -FilePath 'schtasks.exe' -ArgumentList @('/Run', '/TN', $TaskName) -WindowStyle Hidden -Wait:$false | Out-Null
}

function Resolve-NetworkToggleRequest {
    param(
        [string]$ActionFile,
        [string]$DefaultAction,
        [string]$DefaultAdapter
    )

    if (Test-Path -LiteralPath $ActionFile) {
        try {
            $raw = Get-Content -LiteralPath $ActionFile -Raw
            Remove-Item -LiteralPath $ActionFile -Force -ErrorAction SilentlyContinue

            if ($raw.Trim().StartsWith('{')) {
                $json = $raw | ConvertFrom-Json
                $type = if ($json.type) { [string]$json.type } else { $DefaultAction }

                if ($type -eq 'Switch') {
                    return [PSCustomObject]@{
                        Type    = 'Switch'
                        Enable  = @($json.enable | ForEach-Object { [string]$_ })
                        Disable = @($json.disable | ForEach-Object { [string]$_ })
                        Message = if ($json.message) { [string]$json.message } else { 'Network adapters updated.' }
                    }
                }

                if ($type -eq 'Batch') {
                    $items = @()
                    foreach ($entry in $json.items) {
                        $items += [PSCustomObject]@{
                            Adapter = [string]$entry.adapter
                            Action  = [string]$entry.action
                        }
                    }
                    return [PSCustomObject]@{
                        Type    = 'Batch'
                        Items   = $items
                        Message = if ($json.message) { [string]$json.message } else { 'Network adapters updated.' }
                    }
                }

                return [PSCustomObject]@{
                    Type    = $type
                    Adapter = if ($json.adapter) { [string]$json.adapter } else { $DefaultAdapter }
                }
            }

            $legacy = $raw.Trim()
            if ($legacy -match '^(Toggle|Enable|Disable)\|(.+)$') {
                return [PSCustomObject]@{
                    Type    = $Matches[1]
                    Adapter = $Matches[2]
                }
            }

            if ($legacy -in @('Toggle', 'Enable', 'Disable')) {
                return [PSCustomObject]@{
                    Type    = $legacy
                    Adapter = $DefaultAdapter
                }
            }
        }
        catch {
            Remove-Item -LiteralPath $ActionFile -Force -ErrorAction SilentlyContinue
        }
    }

    return [PSCustomObject]@{
        Type    = $DefaultAction
        Adapter = $DefaultAdapter
    }
}

function Write-ReliabilityLog {
    param([string]$Category, [string]$Detail)
    try {
        $logPath = Join-Path $env:LOCALAPPDATA 'InternetToggle\reliability.log'
        $line = "{0:yyyy-MM-dd HH:mm:ss.fff}`t{1}`t{2}" -f (Get-Date), $Category, $Detail
        Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    }
    catch { }
}

function Clear-StaleOperationLock {
    param([string]$LockFile, [int]$StaleSeconds = 120)
    if (-not (Test-Path -LiteralPath $LockFile)) { return }
    $age = ((Get-Date) - (Get-Item -LiteralPath $LockFile).LastWriteTime).TotalSeconds
    if ($age -gt $StaleSeconds) {
        Remove-Item -LiteralPath $LockFile -Force -ErrorAction SilentlyContinue
        Write-ReliabilityLog 'Recovery' 'Removed stale operation.lock'
    }
}

function Enter-OperationLock {
    param([string]$LockFile)
    if (Test-Path -LiteralPath $LockFile) { return $false }
    Set-Content -LiteralPath $LockFile -Value (Get-Date).ToString('o') -Encoding UTF8 -Force
    return $true
}

function Exit-OperationLock {
    param([string]$LockFile)
    if (Test-Path -LiteralPath $LockFile) {
        Remove-Item -LiteralPath $LockFile -Force -ErrorAction SilentlyContinue
    }
}

function Get-QueuedActionRequests {
    param(
        [string]$QueueFile,
        [string]$LegacyActionFile
    )

    $requests = @()

    if (Test-Path -LiteralPath $LegacyActionFile) {
        try {
            $legacy = Resolve-NetworkToggleRequest -ActionFile $LegacyActionFile -DefaultAction 'Toggle' -DefaultAdapter 'Ethernet'
            if ($legacy) { $requests += $legacy }
        }
        catch { }
    }

    if (Test-Path -LiteralPath $QueueFile) {
        try {
            $raw = Get-Content -LiteralPath $QueueFile -Raw
            Remove-Item -LiteralPath $QueueFile -Force -ErrorAction SilentlyContinue
            if ($raw -and $raw.Trim().Length -gt 2) {
                $items = @($raw | ConvertFrom-Json)
                foreach ($item in $items) {
                    $requests += ConvertFrom-QueuePayload -Payload $item
                }
            }
        }
        catch {
            Remove-Item -LiteralPath $QueueFile -Force -ErrorAction SilentlyContinue
        }
    }

    return $requests
}

function ConvertFrom-QueuePayload {
    param($Payload)
    $type = if ($Payload.type) { [string]$Payload.type } else { 'Toggle' }

    if ($type -eq 'Switch') {
        return [PSCustomObject]@{
            Type    = 'Switch'
            Enable  = @($Payload.enable | ForEach-Object { [string]$_ })
            Disable = @($Payload.disable | ForEach-Object { [string]$_ })
            Message = if ($Payload.message) { [string]$Payload.message } else { 'Network adapters updated.' }
        }
    }

    if ($type -eq 'Batch') {
        $items = @()
        foreach ($entry in $Payload.items) {
            $items += [PSCustomObject]@{
                Adapter = [string]$entry.adapter
                Action  = [string]$entry.action
            }
        }
        return [PSCustomObject]@{
            Type    = 'Batch'
            Items   = $items
            Message = if ($Payload.message) { [string]$Payload.message } else { 'Network adapters updated.' }
        }
    }

    return [PSCustomObject]@{
        Type    = $type
        Adapter = if ($Payload.adapter) { [string]$Payload.adapter } else { $null }
    }
}

function Test-AdapterIsWiFi {
    param([string]$Name, [string]$Description)
    $combined = ("$Name $Description").ToLowerInvariant()
    return $combined -match 'wi-fi|wifi|wireless|wlan|802\.11'
}

function Test-AdapterIsEthernet {
    param([string]$Name, [string]$Description)
    if ($Name -like 'vEthernet*') { return $false }
    $combined = ("$Name $Description").ToLowerInvariant()
    if ($combined -match 'wi-fi|wifi|wireless|wlan|802\.11|virtual') { return $false }
    return $combined -match 'ethernet|gbe|gigabit|realtek|asix|usb'
}

function Get-PhysicalNetAdapters {
    param([string[]]$ExcludePatterns = @('vEthernet', 'Hyper-V'))

    $adapters = @()
    foreach ($adapter in Get-NetAdapter -ErrorAction SilentlyContinue) {
        $name = [string]$adapter.Name
        $desc = [string]$adapter.InterfaceDescription
        $combined = "$name $desc"
        $skip = $false
        foreach ($pattern in $ExcludePatterns) {
            if ($combined -like "*$pattern*") { $skip = $true; break }
        }
        if ($skip) { continue }
        if ($adapter.Virtual) { continue }
        $adapters += $adapter
    }
    return $adapters
}

function Resolve-PreferredAdapters {
    param($Config)
    $physical = Get-PhysicalNetAdapters -ExcludePatterns $Config.excludePatterns
    $wifi = $physical | Where-Object { $_.Name -eq $Config.wifiAdapterName } | Select-Object -First 1
    $eth = $physical | Where-Object { $_.Name -eq $Config.ethernetAdapterName } | Select-Object -First 1

    if (-not $wifi) {
        $wifi = $physical | Where-Object { Test-AdapterIsWiFi $_.Name $_.InterfaceDescription } |
            Sort-Object { if ($_.Status -eq 'Up') { 0 } else { 1 } }, Name | Select-Object -First 1
    }
    if (-not $eth) {
        $eth = $physical | Where-Object { Test-AdapterIsEthernet $_.Name $_.InterfaceDescription } |
            Sort-Object { if ($_.Status -eq 'Up') { 0 } else { 1 } }, Name | Select-Object -First 1
    }

    return [PSCustomObject]@{
        WiFi     = $wifi
        Ethernet = $eth
    }
}

function Set-AdapterStateReliable {
    param(
        [string]$Name,
        [ValidateSet('Enable', 'Disable')]
        [string]$DesiredState,
        [int]$MaxAttempts = 3,
        [int]$VerifyTimeoutSec = 15
    )

    Assert-ValidAdapterName -Name $Name

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $adapter = Get-NetAdapter -Name $Name -ErrorAction SilentlyContinue
        if (-not $adapter) {
            Start-Sleep -Milliseconds 400
            continue
        }

        $isUp = $adapter.AdminStatus -eq 'Up'
        try {
            if ($DesiredState -eq 'Enable' -and -not $isUp) {
                Enable-NetAdapter -Name $Name -Confirm:$false -ErrorAction Stop
            }
            elseif ($DesiredState -eq 'Disable' -and $isUp) {
                Disable-NetAdapter -Name $Name -Confirm:$false -ErrorAction Stop
            }
            else {
                return $true
            }
        }
        catch {
            Write-ReliabilityLog 'Retry' "Attempt $attempt $DesiredState $Name failed: $($_.Exception.Message)"
            Start-Sleep -Milliseconds 500
        }

        $deadline = (Get-Date).AddSeconds($VerifyTimeoutSec)
        while ((Get-Date) -lt $deadline) {
            $adapter = Get-NetAdapter -Name $Name -ErrorAction SilentlyContinue
            if ($adapter) {
                $ok = ($DesiredState -eq 'Enable' -and $adapter.AdminStatus -eq 'Up') -or
                      ($DesiredState -eq 'Disable' -and $adapter.AdminStatus -ne 'Up')
                if ($ok) {
                    Write-ReliabilityLog 'Verify' "$DesiredState $Name OK"
                    return $true
                }
            }
            Start-Sleep -Milliseconds 350
        }
    }

    Write-ReliabilityLog 'Fail' "$DesiredState $Name failed after $MaxAttempts attempts"
    return $false
}

function Invoke-NetworkToggleRequest {
    param($Request, $Config)

    $failures = @()

    switch ($Request.Type) {
        'Switch' {
            foreach ($name in $Request.Disable) {
                if (-not (Set-AdapterStateReliable -Name $name -DesiredState 'Disable')) {
                    $failures += "Disable $name"
                }
            }
            foreach ($name in $Request.Enable) {
                if (-not (Set-AdapterStateReliable -Name $name -DesiredState 'Enable')) {
                    $failures += "Enable $name"
                }
            }
            if ($failures.Count -gt 0) {
                Show-EthernetToggleToast -Title 'Switch incomplete' -Message ($failures -join '; ')
            }
            else {
                Show-EthernetToggleToast -Title 'Network switched' -Message ($Request.Message)
            }
        }
        'Batch' {
            foreach ($item in $Request.Items) {
                if (-not (Set-AdapterStateReliable -Name $item.Adapter -DesiredState $item.Action)) {
                    $failures += "$($item.Action) $($item.Adapter)"
                }
            }
            if ($failures.Count -gt 0) {
                Show-EthernetToggleToast -Title 'Update incomplete' -Message ($failures -join '; ')
            }
            else {
                Show-EthernetToggleToast -Title 'Adapters updated' -Message ($Request.Message)
            }
        }
        default {
            $target = if ($Request.Adapter) { $Request.Adapter } else { $Config.adapterName }
            $action = switch ($Request.Type) { 'Enable' { 'Enable' } 'Disable' { 'Disable' } default { 'Toggle' } }
            if ($action -eq 'Toggle') {
                $adapter = Get-NetAdapter -Name $target -ErrorAction SilentlyContinue
                if (-not $adapter) {
                    Show-EthernetToggleToast -Title 'Adapter missing' -Message "Could not find `"$target`"."
                    return
                }
                $action = if ($adapter.AdminStatus -eq 'Up') { 'Disable' } else { 'Enable' }
            }
            if (Set-AdapterStateReliable -Name $target -DesiredState $action) {
                Show-EthernetToggleToast -Title "$target updated" -Message "Adapter $action completed."
            }
            else {
                Show-EthernetToggleToast -Title "$target failed" -Message "Could not $action `"$target`". Open reliability.log for details."
            }
        }
    }
}

function Request-EthernetToggleWindowFocus {
    param([string]$SignalFile)

    $signalDir = Split-Path -Parent $SignalFile
    if (-not (Test-Path -LiteralPath $signalDir)) {
        New-Item -ItemType Directory -Path $signalDir -Force | Out-Null
    }

    Set-Content -LiteralPath $SignalFile -Value '1' -Encoding ASCII -Force
}

function Test-EthernetToggleFocusSignal {
    param([string]$SignalFile)

    if (Test-Path -LiteralPath $SignalFile) {
        Remove-Item -LiteralPath $SignalFile -Force -ErrorAction SilentlyContinue
        return $true
    }

    return $false
}
