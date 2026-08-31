# Internet Switcher

**Switch between Wi-Fi and Ethernet on Windows — one click from the system tray.**

[![Release](https://img.shields.io/github/v/release/mdashfakfaysal/internet-toggle)](https://github.com/mdashfakfaysal/internet-toggle/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Repository:** [github.com/mdashfakfaysal/internet-toggle](https://github.com/mdashfakfaysal/internet-toggle)

![Internet Switcher](assets/logo.png)

> Dorm Wi-Fi acting up? Use Ethernet. Need wireless? Use Wi-Fi. The app uses **safe switching** — it does not disable your Wi-Fi adapter unless you explicitly turn that on in Advanced settings.

## What it does

- **Use Wi-Fi** — enables Wi-Fi, then disables Ethernet (wired adapters recover reliably)
- **Use Ethernet** — enables Ethernet and disconnects Wi-Fi sessions without disabling the Wi-Fi driver (safer for fragile WLAN hardware)
- **Per-adapter Enable/Disable** — manual control for any detected adapter
- **System tray** — quick actions, live status, hide to tray
- **Auto-detect adapters** — finds Realtek Ethernet, MediaTek Wi-Fi, USB adapters like "Ethernet 2", etc.
- **No repeated UAC** after one-time admin setup
- **Rollback** — if a switch fails, restores your working adapter so you are not left offline

## Requirements

- Windows 10 or 11 (64-bit)
- PowerShell 5.1+ (install only)
- Administrator rights for **one-time setup only**

## Download

### GitHub Releases

1. Download from [GitHub Releases](https://github.com/mdashfakfaysal/internet-toggle/releases)
2. Extract and run `scripts\Install-EthernetToggle.ps1` as Administrator (registers elevated scheduled task)
3. Launch **Internet Switcher.exe**

### Microsoft Store

Partner Center app — see [docs/MICROSOFT_STORE.md](docs/MICROSOFT_STORE.md)

## Quick Start

```powershell
cd path\to\internet-toggle
.\scripts\Install-EthernetToggle.ps1   # Run as Administrator once
.\Internet Switcher.exe
```

## Usage

| Action | How |
|--------|-----|
| Use Wi-Fi | Click **Use Wi-Fi** in the window or tray menu |
| Use Ethernet | Click **Use Ethernet** in the window or tray menu |
| Toggle one adapter | Enable/Disable button on each adapter row |
| Settings | Launch at startup, start minimized, advanced Wi-Fi disable (off by default) |

**Hotkey:** Ctrl+Alt+W → Use Wi-Fi

## Safe switching (why v2.0 is different)

Older versions disabled both adapters during a switch. On some Wi-Fi chips (e.g. MediaTek MT7925), repeated `Disable-NetAdapter` on Wi-Fi can wedge the driver into **Not Present** / `CM_PROB_FAILED_START`.

v2.0 defaults to:

| Goal | What the app does |
|------|-------------------|
| Use Wi-Fi | Enable Wi-Fi → disable Ethernet only |
| Use Ethernet | Enable Ethernet → `netsh wlan disconnect` (Wi-Fi stays enabled) |

Optional **Advanced** setting: also disable the Wi-Fi adapter when using Ethernet (not recommended).

## Wi-Fi not working?

If Wi-Fi shows **Not Present** after a power outage:

```powershell
# Run as Administrator — does NOT disable Ethernet
.\scripts\Recover-WifiAdapter.ps1
```

Manual steps: Device Manager → uninstall MediaTek Wi-Fi device (keep driver) → Scan for hardware changes → reinstall driver if needed → reboot.

Logs: `%LOCALAPPDATA%\InternetToggle\reliability.log`

## Build

```powershell
.\scripts\Build-Launcher.ps1
.\packaging\msix\Build-Msix.ps1
```

## Privacy

No telemetry, no ads — see [PRIVACY.md](PRIVACY.md)

## License

MIT — see [LICENSE](LICENSE)
