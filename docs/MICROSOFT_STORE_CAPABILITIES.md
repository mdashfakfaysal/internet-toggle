# Microsoft Store Capabilities

## Declared Capabilities (MSIX)

| Capability | Required? | Justification |
|------------|-----------|---------------|
| `runFullTrust` | **Likely yes** | Classic Win32 desktop networking utility. Must interact with Windows networking APIs and installed network adapters to perform user-requested adapter enable/disable operations. |

## Restricted Capabilities

| Capability | Required? | Justification |
|------------|-----------|---------------|
| `allowElevation` | **Evaluate per package** | Adapter enable/disable requires elevated privileges on Windows. Elevation is limited to predefined networking operations triggered explicitly by the user — not used for unrelated system modification. |

## What the App Does NOT Require

- `internetClient` for core functionality (optional only if update check enabled)
- Broad file system access beyond `%LOCALAPPDATA%`
- Camera, microphone, location, contacts

## Reviewer Notes

> Internet Switcher is a system tray utility that lets users enable, disable, or switch between Wi-Fi and Ethernet adapters. Windows requires administrator privileges to change adapter state. The app uses a pre-registered scheduled task (installed with user consent during setup) to perform these operations without repeated UAC prompts. The app does not inspect network traffic, collect credentials, or modify unrelated system settings.

## Validation Steps for Reviewers

1. Install the app
2. Observe tray icon appears
3. Click "Switch to Wi-Fi" — Ethernet disables, Wi-Fi enables
4. Click "Switch to Ethernet" — reverse
5. Uninstall removes shortcuts and scheduled task

## Technical Accuracy Statement

These declarations are based on the actual implementation:

- WMI/CIM for adapter enumeration (user process)
- PowerShell `Enable-NetAdapter` / `Disable-NetAdapter` (elevated scheduled task)
- No kernel drivers, no LSP injection, no packet inspection
