# Ethernet Toggle

A tiny Windows utility to quickly enable or disable your Ethernet adapter from the system tray or a compact launcher window. Useful when dorm wired internet misbehaves and you want to switch to a mobile hotspot over Wi-Fi.

![Ethernet Toggle launcher](assets/logo.png)

## Features

- **One-click toggle** for your Ethernet adapter
- **System tray icon** with live on/off status
- **Compact launcher window** with logo, status, and action buttons
- **No UAC prompts** after a one-time admin install (uses a scheduled task)
- **Single-instance app** — launching again focuses the existing window
- **Configurable adapter name** via `config.json`

## Requirements

- Windows 10 or 11
- PowerShell 5.1 or later
- Administrator rights for **install only** (not for daily use)

## Download

Get the latest release from [GitHub Releases](https://github.com/mdashfakfaysal/ethernet-toggle-tray/releases):

1. Download `ethernet-toggle-tray-v1.0.0.zip`
2. Extract anywhere on your PC
3. Double-click **`Start Ethernet Toggle.bat`**

For silent toggles without UAC each time, run the one-time install (below) first.

## Quick Start

1. Clone or download this repo.
2. **Double-click** `Start Ethernet Toggle.bat` to launch the app.

For silent toggles without UAC each time, run the one-time install (step below) first.

## Install (one-time, admin)

Open PowerShell **as Administrator**, then run:

```powershell
cd path\to\ethernet-toggle-tray
.\scripts\Install-EthernetToggle.ps1
```

This will:

- Register an elevated scheduled task for adapter changes
- Add a startup shortcut so the app launches at logon
- Start the tray app immediately

## Daily use

| Action | How |
|--------|-----|
| Launch app | Double-click `Start Ethernet Toggle.bat` |
| Toggle Ethernet | Left-click tray icon, or use the big button in the window |
| Enable / Disable | Buttons in the window, or right-click tray icon |
| Hide window | Close button minimizes to tray |
| Exit completely | Right-click tray icon → **Exit** |

The tray icon lives near the clock (bottom-right). If hidden, click the `^` arrow in the taskbar to reveal it.

## Change adapter name

Edit `config.json` at the repo root:

```json
{
  "adapterName": "Ethernet",
  "taskName": "ToggleEthernet",
  "appName": "Ethernet Toggle"
}
```

Find your adapter name in PowerShell:

```powershell
Get-NetAdapter | Select-Object Name, Status
```

Re-run `Install-EthernetToggle.ps1` after changing `taskName` or paths.

## Uninstall

```powershell
.\scripts\Uninstall-EthernetToggle.ps1
```

## Project layout

```
ethernet-toggle-tray/
├── assets/
│   ├── logo.png          # App logo (256x256)
│   └── icon.ico          # Tray/window icon
├── config.json           # Adapter name and app settings
├── scripts/
│   ├── EthernetToggle.Common.ps1
│   ├── Ethernet-Launcher.ps1   # Main UI + tray app
│   ├── Launch-EthernetToggle.ps1
│   ├── Toggle-Ethernet.ps1     # Elevated toggle logic
│   ├── Install-EthernetToggle.ps1
│   ├── Uninstall-EthernetToggle.ps1
│   └── New-EthernetToggleAssets.ps1
├── Start Ethernet Toggle.bat
├── LICENSE
└── README.md
```

## Regenerate logo assets

```powershell
.\scripts\New-EthernetToggleAssets.ps1
```

## Build a release package

Maintainers can build the downloadable zip locally:

```powershell
.\scripts\Build-Release.ps1 -Version 1.0.0
```

Output: `dist/ethernet-toggle-tray-v1.0.0.zip`

Pushing a version tag (for example `v1.0.0`) triggers the GitHub Actions release workflow, which builds the zip and publishes a GitHub Release automatically.

## Upload to GitHub

`gh` is not required. From the project folder:

```powershell
git init -b main
git add -A
git commit -m "Initial commit: Ethernet Toggle tray utility"
```

Then on [github.com](https://github.com/new):

1. Create a new repository (e.g. `ethernet-toggle-tray`) — **do not** add a README or license (this repo already has them).
2. Run the commands GitHub shows, for example:

```powershell
git remote add origin https://github.com/YOUR_USERNAME/ethernet-toggle-tray.git
git push -u origin main
```

## License

MIT — see [LICENSE](LICENSE).
