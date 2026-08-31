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

    if ($type -eq 'UseWifi') {
        return [PSCustomObject]@{
            Type             = 'UseWifi'
            WiFiAdapter      = if ($Payload.wifiAdapter) { [string]$Payload.wifiAdapter } else { $null }
            EthernetAdapter  = if ($Payload.ethernetAdapter) { [string]$Payload.ethernetAdapter } else { $null }
            AlsoDisableOther = [bool]$Payload.alsoDisableOther
            Message          = if ($Payload.message) { [string]$Payload.message } else { 'Now using Wi-Fi.' }
        }
    }

    if ($type -eq 'UseEthernet') {
        return [PSCustomObject]@{
            Type             = 'UseEthernet'
            WiFiAdapter      = if ($Payload.wifiAdapter) { [string]$Payload.wifiAdapter } else { $null }
            EthernetAdapter  = if ($Payload.ethernetAdapter) { [string]$Payload.ethernetAdapter } else { $null }
            AlsoDisableOther = [bool]$Payload.alsoDisableOther
            Message          = if ($Payload.message) { [string]$Payload.message } else { 'Now using Ethernet.' }
        }
    }

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

function Get-AdapterPresenceScore {
    param($Adapter)
    switch ([string]$Adapter.Status) {
        'Up' { return 0 }
        'Disabled' { return 1 }
        'Disconnected' { return 2 }
        default { return 10 }
    }
}

function Get-AdapterGhostNameScore {
    param([string]$Name)
    if ($Name -eq 'Wi-Fi') { return 0 }
    if ($Name -match '^Wi-Fi\s+\d+$') { return 2 }
    return 1
}

function Sort-AdaptersByPreference {
    param($Adapters)
    return @($Adapters | Sort-Object { Get-AdapterPresenceScore $_ }, { Get-AdapterGhostNameScore $_.Name }, Name)
}

function Find-BestNetAdapterByDescription {
    param(
        [string]$InterfaceDescription,
        [string]$NameHint = $null
    )

    if ([string]::IsNullOrWhiteSpace($InterfaceDescription)) {
        return $null
    }

    $candidates = @(Get-PhysicalNetAdapters | Where-Object { $_.InterfaceDescription -eq $InterfaceDescription })
    if ($candidates.Count -eq 0) {
        return $null
    }

    if ($NameHint) {
        $hintMatch = $candidates | Where-Object { $_.Name -eq $NameHint -and $_.Status -ne 'Not Present' } | Select-Object -First 1
        if ($hintMatch) {
            return $hintMatch
        }
    }

    return (Sort-AdaptersByPreference $candidates | Select-Object -First 1)
}

function Get-PnpDeviceForNetAdapter {
    param([string]$InterfaceDescription)

    if ([string]::IsNullOrWhiteSpace($InterfaceDescription)) {
        return $null
    }

    return Get-PnpDevice -Class Net -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -eq $InterfaceDescription } |
        Sort-Object { if ($_.Status -eq 'OK') { 0 } else { 1 } }, InstanceId |
        Select-Object -First 1
}

function Invoke-PnpNetDeviceRecovery {
    param([string]$InterfaceDescription)

    $device = Get-PnpDeviceForNetAdapter -InterfaceDescription $InterfaceDescription
    if (-not $device) {
        Write-ReliabilityLog 'PnP' "No PnP device found for $InterfaceDescription"
        return $false
    }

    $problem = if ($null -ne $device.ConfigManagerErrorCode) { [string]$device.ConfigManagerErrorCode } else { 'none' }
    Write-ReliabilityLog 'PnP' "Device $($device.InstanceId) status=$($device.Status) problem=$problem"

    if ($device.Status -eq 'OK') {
        return $true
    }

    $steps = @(
        { Enable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Stop },
        {
            Disable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 1
            Enable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Stop
        },
        { pnputil.exe /restart-device $device.InstanceId 2>&1 | Out-Null }
    )

    foreach ($step in $steps) {
        try {
            & $step
            Start-Sleep -Seconds 3
            $device = Get-PnpDevice -InstanceId $device.InstanceId -ErrorAction SilentlyContinue
            if ($device -and $device.Status -eq 'OK') {
                Write-ReliabilityLog 'PnP' 'Device recovery succeeded'
                return $true
            }
        }
        catch {
            Write-ReliabilityLog 'PnP' "Recovery step failed: $($_.Exception.Message)"
        }
    }

    Write-ReliabilityLog 'PnP' 'Device recovery failed - adapter may need driver reinstall or reboot'
    return $false
}

function Get-NotPresentUserMessage {
    param([string]$AdapterName)

    $adapter = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
    $desc = if ($adapter) { [string]$adapter.InterfaceDescription } else { [string]$AdapterName }

    if ($desc -match 'MediaTek') {
        return 'Wi-Fi adapter is not present. Check hardware Wi-Fi switch / airplane mode, or reinstall the MediaTek Wi-Fi 7 driver.'
    }

    return "Wi-Fi adapter is not present. Check airplane mode, hardware radio switch, or reinstall the wireless driver."
}

function Resolve-PreferredAdapters {
    param($Config)
    $physical = Get-PhysicalNetAdapters -ExcludePatterns $Config.excludePatterns

    $wifiCandidates = @($physical | Where-Object { Test-AdapterIsWiFi $_.Name $_.InterfaceDescription })
    $ethCandidates = @($physical | Where-Object { Test-AdapterIsEthernet $_.Name $_.InterfaceDescription })

    $wifiHint = $physical | Where-Object { $_.Name -eq $Config.wifiAdapterName -and $_.Status -ne 'Not Present' } | Select-Object -First 1
    $ethHint = $physical | Where-Object { $_.Name -eq $Config.ethernetAdapterName -and $_.Status -ne 'Not Present' } | Select-Object -First 1

    $wifi = if ($wifiHint) { $wifiHint } else { Sort-AdaptersByPreference $wifiCandidates | Select-Object -First 1 }
    $eth = if ($ethHint) { $ethHint } else { Sort-AdaptersByPreference $ethCandidates | Select-Object -First 1 }

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

    $adapter = Get-NetAdapter -Name $Name -ErrorAction SilentlyContinue
    if (-not $adapter) {
        Write-ReliabilityLog 'Fail' "$DesiredState $Name failed: adapter not found"
        return $false
    }

    $pnpRecovered = $false
    if ($DesiredState -eq 'Enable' -and [string]$adapter.Status -eq 'Not Present') {
        Write-ReliabilityLog 'NotPresent' "$Name is Not Present - attempting PnP recovery for $($adapter.InterfaceDescription)"
        if (-not (Invoke-PnpNetDeviceRecovery -InterfaceDescription $adapter.InterfaceDescription)) {
            Write-ReliabilityLog 'Fail' "Enable $Name failed: Not Present and PnP recovery failed"
            return $false
        }
        $pnpRecovered = $true
        Start-Sleep -Seconds 2
        $resolved = Find-BestNetAdapterByDescription -InterfaceDescription $adapter.InterfaceDescription -NameHint $Name
        if ($resolved) {
            $Name = [string]$resolved.Name
            $adapter = $resolved
            Write-ReliabilityLog 'PnP' "Resolved adapter after recovery: $Name status=$($adapter.Status)"
        }
        if (-not $adapter -or [string]$adapter.Status -eq 'Not Present') {
            Write-ReliabilityLog 'Fail' "Enable failed: adapter still Not Present after PnP recovery"
            return $false
        }
    }

    $attempts = if ($pnpRecovered) { 2 } else { $MaxAttempts }

    for ($attempt = 1; $attempt -le $attempts; $attempt++) {
        $adapter = Get-NetAdapter -Name $Name -ErrorAction SilentlyContinue
        if (-not $adapter) {
            Write-ReliabilityLog 'Fail' "$DesiredState $Name failed: adapter not found"
            return $false
        }

        if ($DesiredState -eq 'Enable' -and [string]$adapter.Status -eq 'Not Present') {
            Write-ReliabilityLog 'Fail' "Enable $Name failed: adapter Not Present (Enable-NetAdapter cannot recover)"
            return $false
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

    Write-ReliabilityLog 'Fail' "$DesiredState $Name failed after $attempts attempts"
    return $false
}

function Invoke-WlanDisconnect {
    try {
        $null = netsh wlan disconnect 2>&1
        Write-ReliabilityLog 'Wlan' 'Disconnected Wi-Fi session (netsh wlan disconnect)'
        return $true
    }
    catch {
        Write-ReliabilityLog 'Wlan' "wlan disconnect failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-UseWifi {
    param($Request, $Config)

    $resolved = Resolve-PreferredAdapters -Config $Config
    $wifiName = if ($Request.WiFiAdapter) { [string]$Request.WiFiAdapter } elseif ($resolved.WiFi) { [string]$resolved.WiFi.Name } else { $null }
    $ethName = if ($Request.EthernetAdapter) { [string]$Request.EthernetAdapter } elseif ($resolved.Ethernet) { [string]$resolved.Ethernet.Name } else { $null }

    if (-not $wifiName) {
        Show-EthernetToggleToast -Title 'Wi-Fi unavailable' -Message 'No Wi-Fi adapter detected on this PC.'
        return
    }

    # Safe order: enable Wi-Fi FIRST while Ethernet still provides connectivity
    if (-not (Set-AdapterStateReliable -Name $wifiName -DesiredState 'Enable')) {
        $detail = Get-NotPresentUserMessage -AdapterName $wifiName
        Show-EthernetToggleToast -Title 'Could not use Wi-Fi' -Message $detail
        return
    }

    $ethDisabled = $false
    if ($ethName) {
        if (Set-AdapterStateReliable -Name $ethName -DesiredState 'Disable') {
            $ethDisabled = $true
            Write-ReliabilityLog 'UseWifi' "Disabled Ethernet adapter $ethName"
        }
        else {
            Write-ReliabilityLog 'UseWifi' "Could not disable $ethName - Wi-Fi is enabled, Ethernet may still be active"
        }
    }

    $wifi = Get-NetAdapter -Name $wifiName -ErrorAction SilentlyContinue
    if ($wifi -and $wifi.AdminStatus -eq 'Up') {
        Show-EthernetToggleToast -Title 'Using Wi-Fi' -Message ($Request.Message)
        return
    }

    if ($ethDisabled -and $ethName) {
        Write-ReliabilityLog 'Rollback' "Wi-Fi not verified Up - restoring $ethName"
        Set-AdapterStateReliable -Name $ethName -DesiredState 'Enable' | Out-Null
        Show-EthernetToggleToast -Title 'Switch failed' -Message "Wi-Fi could not be verified. $ethName restored."
    }
}

function Invoke-UseEthernet {
    param($Request, $Config)

    $resolved = Resolve-PreferredAdapters -Config $Config
    $wifiName = if ($Request.WiFiAdapter) { [string]$Request.WiFiAdapter } elseif ($resolved.WiFi) { [string]$resolved.WiFi.Name } else { $null }
    $ethName = if ($Request.EthernetAdapter) { [string]$Request.EthernetAdapter } elseif ($resolved.Ethernet) { [string]$resolved.Ethernet.Name } else { $null }

    if (-not $ethName) {
        Show-EthernetToggleToast -Title 'Ethernet unavailable' -Message 'No Ethernet adapter detected on this PC.'
        return
    }

    if (-not (Set-AdapterStateReliable -Name $ethName -DesiredState 'Enable')) {
        Show-EthernetToggleToast -Title 'Could not use Ethernet' -Message "Could not enable `"$ethName`". Check cable connection."
        return
    }

    if ($wifiName) {
        Invoke-WlanDisconnect | Out-Null
        if ($Request.AlsoDisableOther) {
            Write-ReliabilityLog 'UseEthernet' "Advanced: disabling Wi-Fi adapter $wifiName"
            if (-not (Set-AdapterStateReliable -Name $wifiName -DesiredState 'Disable')) {
                Write-ReliabilityLog 'UseEthernet' "Advanced Wi-Fi disable failed - Ethernet is still enabled"
            }
        }
    }

    Show-EthernetToggleToast -Title 'Using Ethernet' -Message ($Request.Message)
}

function Invoke-NetworkToggleRequest {
    param($Request, $Config)

    $failures = @()

    switch ($Request.Type) {
        'UseWifi' {
            Invoke-UseWifi -Request $Request -Config $Config
            return
        }
        'UseEthernet' {
            Invoke-UseEthernet -Request $Request -Config $Config
            return
        }
        'Switch' {
            $disabledOk = @()
            foreach ($name in @($Request.Disable)) {
                if (Set-AdapterStateReliable -Name $name -DesiredState 'Disable') {
                    $disabledOk += $name
                }
                else {
                    $failures += "Disable $name"
                }
            }

            $enableOk = $true
            foreach ($name in @($Request.Enable)) {
                if (-not (Set-AdapterStateReliable -Name $name -DesiredState 'Enable')) {
                    $enableOk = $false
                    $failures += "Enable $name"
                }
            }

            if (-not $enableOk -and $disabledOk.Count -gt 0) {
                Write-ReliabilityLog 'Rollback' ("Restoring connectivity: " + ($disabledOk -join ', '))
                foreach ($name in $disabledOk) {
                    if (Set-AdapterStateReliable -Name $name -DesiredState 'Enable') {
                        Write-ReliabilityLog 'Rollback' "Restored $name"
                    }
                    else {
                        Write-ReliabilityLog 'Rollback' "FAILED to restore $name"
                    }
                }

                $primaryEnable = @($Request.Enable) | Select-Object -First 1
                $detail = Get-NotPresentUserMessage -AdapterName $primaryEnable
                $restored = ($disabledOk -join ', ')
                Show-EthernetToggleToast -Title 'Switch failed' -Message "Could not enable target adapter. $restored restored. $detail"
            }
            elseif ($failures.Count -gt 0) {
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
