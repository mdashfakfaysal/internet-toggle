# Network Toggle

A tiny Windows utility to quickly enable, disable, or switch between your network adapters from a compact launcher window or system tray. Perfect when dorm wired internet misbehaves and you want to switch to a mobile hotspot over Wi-Fi.

![Network Toggle launcher](assets/logo.png)

## Features

- **Dynamic adapter list** — discovers Ethernet, Wi-Fi, and other adapters automatically
- **Per-adapter Enable/Disable** — control each adapter individually
- **Quick switch presets**
  - **Switch to Ethernet** — disables Wi-Fi, enables Ethernet
  - **Switch to Wi-Fi** — disables Ethernet, enables Wi-Fi
- **Standalone Windows app** — `Ethernet Toggle.exe` with custom icon (no PowerShell in taskbar)
- **System tray** — live status summary, quick actions, hide-to-tray
- **No UAC prompts** after one-time admin install (uses a scheduled task)
- **Single-instance app** — relaunching focuses the existing window
- **Configurable** via `config.json` (adapter names, exclusions for virtual/Hyper-V adapters)

## Requirements

- Windows 10 or 11
- PowerShell 5.1 or later (install only)
- Administrator rights for **install only** (not for daily use)

## Download

Get the latest release from [GitHub Releases](https://github.com/mdashfakfaysal/ethernet-toggle-tray/releases):

1. Download the latest `ethernet-toggle-tray-v*.zip`
2. Extract anywhere on your PC
3. Run **`scripts\Install-EthernetToggle.ps1`** once as Administrator
4. Launch from **Start search** (`Network Toggle`), the **taskbar pin**, or **`Ethernet Toggle.exe`**

## Quick Start

1. Clone or download this repo.
2. Run the **one-time install** (admin) — builds `Ethernet Toggle.exe` and registers shortcuts.
3. Open the app and use **Switch to Wi-Fi** or **Switch to Ethernet**.

## Install (one-time, admin)

```powershell
cd path\to\ethernet-toggle-tray
.\scripts\Install-EthernetToggle.ps1
```

This will:

- Build **`Ethernet Toggle.exe`** (standalone app with your logo)
- Register an elevated scheduled task for adapter changes
- Add Start Menu, Startup, and taskbar shortcuts
- Start the app immediately

## Daily use

| Action | How |
|--------|-----|
| Launch app | Start search **Network Toggle**, taskbar pin, or **`Ethernet Toggle.exe`** |
| Switch to dorm hotspot | Click **Switch to Wi-Fi** |
| Switch back to wired | Click **Switch to Ethernet** |
| Toggle one adapter | Use **Enable** / **Disable** on its row |
| Hide window | Close button minimizes to tray |
| Exit completely | Right-click tray icon → **Exit** |

Virtual adapters (e.g. Hyper-V `vEthernet`) are hidden by default. Edit `excludePatterns` in `config.json` to change this.

## Configuration

Edit `config.json`:

```json
{
  "version": "1.3.0",
  "appName": "Network Toggle",
  "exeName": "Ethernet Toggle",
  "taskName": "ToggleEthernet",
  "ethernetAdapterName": "Ethernet",
  "wifiAdapterName": "Wi-Fi",
  "excludePatterns": ["vEthernet", "Hyper-V"]
}
```

Find your adapter names:

```powershell
Get-NetAdapter | Select-Object Name, Status, InterfaceDescription
```

Re-run `Install-EthernetToggle.ps1` after changing `taskName`.

## Uninstall

```powershell
.\scripts\Uninstall-EthernetToggle.ps1
```

## Build a release package

```powershell
.\scripts\Build-Release.ps1 -Version 1.3.0
```

Pushing a version tag (e.g. `v1.3.0`) triggers GitHub Actions to publish a release zip automatically.

## License

MIT — see [LICENSE](LICENSE).
