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
        ActionDir   = Join-Path $env:LOCALAPPDATA 'EthernetToggle'
        ActionFile  = Join-Path $env:LOCALAPPDATA 'EthernetToggle\pending-action.txt'
        SignalFile  = Join-Path $env:LOCALAPPDATA 'EthernetToggle\show-window.signal'
    }
}

function Get-EthernetToggleConfig {
    param([string]$ConfigPath)

    $defaults = [PSCustomObject]@{
        adapterName = 'Ethernet'
        taskName    = 'ToggleEthernet'
        appName     = 'Ethernet Toggle'
    }

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        return $defaults
    }

    try {
        $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
        return [PSCustomObject]@{
            adapterName = if ($config.adapterName) { [string]$config.adapterName } else { $defaults.adapterName }
            taskName    = if ($config.taskName) { [string]$config.taskName } else { $defaults.taskName }
            appName     = if ($config.appName) { [string]$config.appName } else { $defaults.appName }
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
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Ethernet Toggle').Show($toast) | Out-Null
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
        [string]$Action
    )

    Set-Content -LiteralPath $ActionFile -Value $Action -Encoding ASCII -Force
    Start-Process -FilePath 'schtasks.exe' -ArgumentList @('/Run', '/TN', $TaskName) -WindowStyle Hidden -Wait:$false | Out-Null
}

function Resolve-EthernetToggleAction {
    param(
        [string]$ActionFile,
        [string]$DefaultAction
    )

    if (Test-Path -LiteralPath $ActionFile) {
        try {
            $pendingAction = (Get-Content -LiteralPath $ActionFile -Raw).Trim()
            Remove-Item -LiteralPath $ActionFile -Force -ErrorAction SilentlyContinue

            if ($pendingAction -in @('Toggle', 'Enable', 'Disable')) {
                return $pendingAction
            }
        }
        catch {
            Remove-Item -LiteralPath $ActionFile -Force -ErrorAction SilentlyContinue
        }
    }

    return $DefaultAction
}

function New-EthernetToggleFallbackIcon {
    param([bool]$IsOn)

    $bitmap = New-Object System.Drawing.Bitmap 16, 16
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $fillColor = if ($IsOn) {
        [System.Drawing.Color]::FromArgb(255, 46, 160, 67)
    }
    else {
        [System.Drawing.Color]::FromArgb(255, 140, 140, 140)
    }

    $brush = New-Object System.Drawing.SolidBrush $fillColor
    $graphics.FillEllipse($brush, 2, 2, 12, 12)
    $brush.Dispose()
    $graphics.Dispose()

    $iconHandle = $bitmap.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
    return ,@($icon, $bitmap, $iconHandle)
}

function Get-EthernetToggleTrayIcon {
    param(
        [string]$IconPath,
        [bool]$IsOn
    )

    if (Test-Path -LiteralPath $IconPath) {
        try {
            $baseIcon = New-Object System.Drawing.Icon($IconPath)
            $bitmap = $baseIcon.ToBitmap()
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

            $statusColor = if ($IsOn) {
                [System.Drawing.Color]::FromArgb(255, 46, 160, 67)
            }
            else {
                [System.Drawing.Color]::FromArgb(255, 140, 140, 140)
            }

            $brush = New-Object System.Drawing.SolidBrush $statusColor
            $graphics.FillEllipse($brush, 18, 18, 10, 10)
            $brush.Dispose()
            $graphics.Dispose()

            $iconHandle = $bitmap.GetHicon()
            $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
            $baseIcon.Dispose()
            return ,@($icon, $bitmap, $iconHandle)
        }
        catch {
            # Fall through to generated icon.
        }
    }

    return New-EthernetToggleFallbackIcon -IsOn $IsOn
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
