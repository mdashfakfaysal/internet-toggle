# Link Priority

**Control which network connection Windows uses — by toggling your Ethernet adapter.**

[![Release](https://img.shields.io/github/v/release/mdashfakfaysal/internet-toggle)](https://github.com/mdashfakfaysal/internet-toggle/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Repository:** [github.com/mdashfakfaysal/internet-toggle](https://github.com/mdashfakfaysal/internet-toggle)

![Link Priority](assets/logo.png)

> This app is an **Ethernet adapter / network-priority switcher**, not a Wi-Fi off switch. Your Wi-Fi adapter stays enabled; Windows routes traffic based on which adapter is active.

## What it actually does

| Button | Default behavior |
|--------|------------------|
| **Prioritize Wi-Fi** | Enables Wi-Fi, then **disables the Ethernet adapter** |
| **Prioritize Ethernet** | **Enables Ethernet**, runs `netsh wlan disconnect` (ends active Wi-Fi sessions), Wi-Fi adapter **stays on** |

Windows prefers Ethernet when both are available, so enabling Ethernet routes traffic over wired. Disabling Ethernet lets Wi-Fi take over. The app does **not** disable Wi-Fi by default.

**Advanced setting (off by default):** When prioritizing Ethernet, optionally also disable the Wi-Fi adapter — not recommended for fragile WLAN drivers.

## Features

- Two primary actions: **Prioritize Wi-Fi** / **Prioritize Ethernet**
- Per-adapter Enable/Disable for manual control
- System tray with live adapter status
- Auto-detects Ethernet, Wi-Fi, USB adapters (e.g. "Ethernet 2")
- One-time admin setup; no repeated UAC prompts
- Rollback if a priority change fails (you are not left offline)

## Requirements

- Windows 10 or 11 (64-bit)
- PowerShell 5.1+ (install only)
- Administrator rights for **one-time setup only**

## Download & run

```powershell
cd path\to\internet-toggle
.\scripts\Install-EthernetToggle.ps1   # Administrator, once
.\Internet Switcher.exe
```

The executable filename remains `Internet Switcher.exe` for compatibility; the app displays as **Link Priority**.

## Hotkey

**Ctrl+Alt+W** → Prioritize Wi-Fi

## Build

```powershell
.\scripts\New-EthernetToggleAssets.ps1   # Regenerate logo + icon
.\scripts\Build-Launcher.ps1
.\packaging\msix\Build-Msix.ps1
```

## Privacy

No telemetry — see [PRIVACY.md](PRIVACY.md)

## License

MIT — see [LICENSE](LICENSE)
