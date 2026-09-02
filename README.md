# Link Priority

**One-click Ethernet enable/disable for Windows — with live adapter status.**

[![Release](https://img.shields.io/github/v/release/mdashfakfaysal/internet-toggle)](https://github.com/mdashfakfaysal/internet-toggle/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Repository:** [github.com/mdashfakfaysal/internet-toggle](https://github.com/mdashfakfaysal/internet-toggle)

![Link Priority](assets/logo.png)

> The main button toggles **Ethernet only**. Wi-Fi is not disabled by default. Priority-style actions (when used) can enable Wi-Fi, disable Ethernet, or disconnect active Wi-Fi sessions — see below.

## Primary control (v2.2)

| Button | What happens |
|--------|----------------|
| **Disable Ethernet** | Disables the detected Ethernet adapter (including USB dongles) |
| **Enable Ethernet** | Enables the Ethernet adapter |

## Priority behavior (PowerShell layer — unchanged)

| Action | What happens |
|--------|----------------|
| **Use Wi-Fi** | **Enables** Wi-Fi, then **disables** Ethernet |
| **Use Ethernet** | **Enables** Ethernet, then **`netsh wlan disconnect`**. Wi-Fi adapter **stays enabled** unless advanced setting is on |

**Advanced setting (off by default):** When prioritizing Ethernet, optionally **also disable** the Wi-Fi adapter.

## Features

- One large **Enable/Disable Ethernet** button with immediate feedback
- Adapter list for visibility (Ethernet, Wi-Fi, USB)
- System tray toggle
- Auto-detects Realtek, MediaTek, ASIX USB Ethernet, etc.
- Administrator approval explained before UAC; no silent failures

## Requirements

- Windows 10 or 11 (64-bit)
- USB Ethernet adapter if the PC has no built-in RJ45 port
- Windows UAC approval when changing adapters (normal for network control)

## Download & run

```powershell
cd path\to\internet-toggle
.\Internet Switcher.exe
```

The executable filename remains `Internet Switcher.exe` for compatibility; the app displays as **Link Priority**.

## Build

```powershell
.\scripts\New-EthernetToggleAssets.ps1
.\scripts\Build-Launcher.ps1
.\packaging\msix\Build-Msix.ps1
```

## Privacy

No telemetry — see [PRIVACY.md](PRIVACY.md)

## License

MIT — see [LICENSE](LICENSE)
