# Internet Toggle

A tiny Windows utility to quickly enable, disable, or switch between your network adapters from a compact launcher window or system tray. Perfect when dorm wired internet misbehaves and you want to switch to a mobile hotspot over Wi-Fi.

**Repository:** [github.com/mdashfakfaysal/internet-toggle](https://github.com/mdashfakfaysal/internet-toggle)  
**Latest release:** [v1.4.0](https://github.com/mdashfakfaysal/internet-toggle/releases/latest)

![Internet Toggle launcher](assets/logo.png)

## Features

- **Dynamic adapter list** — discovers Ethernet, Wi-Fi, and other adapters automatically
- **Per-adapter Enable/Disable** — control each adapter individually
- **Quick switch presets**
  - **Switch to Ethernet** — disables Wi-Fi, enables Ethernet
  - **Switch to Wi-Fi** — disables Ethernet, enables Wi-Fi
- **Standalone Windows app** — `Internet Toggle.exe` with custom icon (no PowerShell in taskbar)
- **System tray** — live status summary, quick actions, hide-to-tray
- **Settings panel** — launch at startup, start minimized to tray
- **Tray-only startup by default** — no window flash on login; click tray icon to open
- **No UAC prompts** after one-time admin install (uses a scheduled task)
- **Single-instance app** — relaunching focuses the existing window
- **Configurable** via `config.json` (adapter names, exclusions for virtual/Hyper-V adapters)

## Requirements

- Windows 10 or 11
- PowerShell 5.1 or later (install only)
- Administrator rights for **install only** (not for daily use)

## Download

Get the latest release from [GitHub Releases](https://github.com/mdashfakfaysal/internet-toggle/releases):

1. Download the latest `internet-toggle-v*.zip`
2. Extract anywhere on your PC
3. Run **`scripts\Install-EthernetToggle.ps1`** once as Administrator
4. Launch from **Start search** (`Internet Toggle`), the **taskbar pin**, or **`Internet Toggle.exe`**

## Screenshots

| Launcher | System tray |
|----------|-------------|
| ![Internet Toggle main window](assets/logo.png) | Tray icon with live Ethernet/Wi-Fi status summary |

The main window shows adapter rows with status labels, quick-switch buttons, and a **Settings** button in the top-right header. On startup the app runs tray-only by default — left-click the tray icon to open the window.

## Quick Start

1. Clone or download this repo.
2. Run the **one-time install** (admin) — builds `Internet Toggle.exe` and registers shortcuts.
3. Open the app and use **Switch to Wi-Fi** or **Switch to Ethernet**.

## Install (one-time, admin)

```powershell
cd path\to\internet-toggle
.\scripts\Install-EthernetToggle.ps1
```

This will:

- Build **`Internet Toggle.exe`** (standalone app with your logo)
- Register an elevated scheduled task for adapter changes
- Add Start Menu, Startup, and taskbar shortcuts
- Write default settings (`startMinimizedToTray: true`) so login starts tray-only
- Remove legacy **Ethernet Toggle** / **Network Toggle** shortcuts
- Start the app immediately (tray only by default)

## Daily use

| Action | How |
|--------|-----|
| Launch app | Start search **Internet Toggle**, taskbar pin, or **`Internet Toggle.exe`** |
| Open window from tray | Left-click the tray icon |
| Change startup behavior | Click **Settings** in the app header |
| Switch to dorm hotspot | Click **Switch to Wi-Fi** |
| Switch back to wired | Click **Switch to Ethernet** |
| Toggle one adapter | Use **Enable** / **Disable** on its row |
| Hide window | Close button minimizes to tray |
| Exit completely | Right-click tray icon → **Exit** |

### Settings

Open **Settings** (top-right of the main window) to control:

- **Launch at Windows startup** — adds/removes the Startup folder shortcut immediately
- **Start minimized to tray** — on launch, show only the tray icon (applies on next launch)

Settings are saved to `%LOCALAPPDATA%\InternetToggle\settings.json`.

Virtual adapters (e.g. Hyper-V `vEthernet`) are hidden by default. Edit `excludePatterns` in `config.json` to change this.

## Configuration

Edit `config.json`:

```json
{
  "version": "1.4.0",
  "appName": "Internet Toggle",
  "exeName": "Internet Toggle",
  "taskName": "ToggleInternetAdapter",
  "ethernetAdapterName": "Ethernet",
  "wifiAdapterName": "Wi-Fi",
  "excludePatterns": ["vEthernet", "Hyper-V"],
  "launchAtStartup": true,
  "startMinimizedToTray": true
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
.\scripts\Build-Release.ps1 -Version 1.4.0
```

Pushing a version tag (e.g. `v1.4.0`) triggers GitHub Actions to publish a release zip automatically.

## About this repo

**Internet Toggle** — Windows tray app to enable, disable, and switch Ethernet/Wi-Fi adapters. Formerly `ethernet-toggle-tray`; old GitHub URLs redirect automatically.

## License

MIT — see [LICENSE](LICENSE).
