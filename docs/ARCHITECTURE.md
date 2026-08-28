# Architecture

## Overview

Internet Switcher is a classic Windows desktop utility composed of:

1. **User-mode WinForms app** (`Internet Switcher Free.exe` / `Internet Switcher Pro.exe`)
2. **Elevated scheduled task** running `Toggle-NetworkAdapter.ps1`
3. **JSON IPC file** for queued adapter operations

## Components

| Component | Role |
|-----------|------|
| `launcher/EthernetToggleApp.cs` | Main UI, tray, settings, adapter display |
| `launcher/Edition/*` | Feature gating, license abstraction |
| `launcher/Core/*` | Version, logging, validation, hotkeys |
| `launcher/UI/*` | About, upgrade dialogs |
| `scripts/Toggle-NetworkAdapter.ps1` | Elevated adapter mutations |
| `scripts/Install-EthernetToggle.ps1` | One-time admin setup |

## Edition Model

Single codebase with compile-time edition defines:

- `INTERNET_SWITCHER_FREE` — default Free build
- `INTERNET_SWITCHER_PRO` — Pro build

Runtime feature checks go through `EditionService.CanUseFeature(Feature)`.

## Data Flow

```
UI action → validate adapter name → write pending-action.json → schtasks /Run
→ elevated PowerShell → validate again → Enable/Disable-NetAdapter
```

## Future Pro Modules (planned)

- Profile store (`%LOCALAPPDATA%\InternetSwitcher\profiles\`)
- Failover watcher service (Pro)
- Rule engine (Pro)
- License provider integrations (Store, Lemon Squeezy)
