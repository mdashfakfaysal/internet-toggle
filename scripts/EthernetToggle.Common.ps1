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
