# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-08-31

### Fixed — Microsoft Store certification (10.1.2.10, 10.1.1.1)

- Dynamic adapter discovery for renamed adapters (e.g. Ethernet 2)
- One-time in-app UAC setup for Store installs without admin install script
- Operation queue, retry+verify, hidden PowerShell, concurrency guard
- 150% DPI layout fixes (680px window, wider header)

See `docs/CERTIFICATION_FIXES.md`.

## [1.1.0] - 2026-08-28

### Added — Internet Switcher Pro features

- Network profiles with save/apply/delete and tray quick-apply menu
- Automatic failover when Ethernet or Wi-Fi disconnects
- Per-adapter rules (disable Wi-Fi when Ethernet connected, and reverse)
- Advanced configurable hotkeys (switch, toggle, apply profile 1/2)
- Daily schedules for switch or profile actions
- Connection history log (local JSON)
- Import/export of profiles, automation settings, and preferences
- Pro Settings tabbed UI and Profiles manager

### Changed

- Pro build enables Pro features by default via `ProLicenseProvider`
- Install script supports `-Edition Pro`

## [1.0.0] - 2026-08-28

### Added — Commercial Release

- **Internet Switcher Free** and **Internet Switcher Pro** editions from single codebase
- `EditionService` / `Feature` gating with `ILicenseProvider` abstraction
- Dev Pro testing via `INTERNET_SWITCHER_DEV_PRO=1` (DEBUG builds only)
- About dialog, upgrade dialog for Pro features, version display in UI
- Basic global hotkey: Ctrl+Alt+W → Switch to Wi-Fi
- `version.json` single source of truth for semantic versioning
- Adapter name validation (C# + PowerShell) to prevent shell injection
- Local diagnostic logging to `%LOCALAPPDATA%\InternetToggle\logs\`
- Free + Pro release packages with SHA-256 checksums
- GitHub Actions CI and release workflows
- Comprehensive documentation (`docs/`), Store assets, MSIX/Inno Setup skeletons
- `PRIVACY.md`, `THIRD_PARTY_NOTICES.md`

### Changed

- Product rebranded to **Internet Switcher** (Free/Pro)
- Free build: `Internet Switcher Free.exe` (+ legacy `Internet Toggle.exe` alias)
- Pro build: `Internet Switcher Pro.exe`
- Release zips: `internet-switcher-free-x64-*.zip`, `internet-switcher-pro-x64-*.zip`

## [1.4.0] - 2026-08-28

### Added

- **Settings panel** in the app header — control startup behavior from the UI
- **Launch at Windows startup** toggle (creates/removes Startup folder shortcut immediately)
- **Start minimized to tray** toggle (tray-only on launch; click tray icon to open window)
- User settings persisted to `%LOCALAPPDATA%\InternetToggle\settings.json`

### Changed

- **Default startup behavior is tray-only** — no main window on login/startup
- Install writes default settings (`launchAtStartup: true`, `startMinimizedToTray: true`)
- GitHub repository renamed to [internet-toggle](https://github.com/mdashfakfaysal/internet-toggle); release zips now use `internet-toggle-v*.zip`

## [1.3.1] - 2026-08-28

### Changed

- **Rebrand to Internet Toggle** — app name, executable (`Internet Toggle.exe`), shortcuts, tray, and toasts
- Scheduled task renamed to `ToggleInternetAdapter`
- Regenerated logo with globe badge for Internet Toggle branding
- Removed legacy **Ethernet Toggle** / **Network Toggle** shortcuts during install

### Fixed

- Adapter row buttons clipped on right edge
- Incorrect status labels (`Disabled · Disabled`, false `Connecting` state)

## [1.3.0] - 2026-08-28

### Added

- **Full network adapter toggle** — dynamic adapter list with per-row Enable/Disable
- **Quick switch presets**: Switch to Ethernet / Switch to Wi-Fi (simultaneous disable+enable)
- App renamed to **Network Toggle** (executable remains `Ethernet Toggle.exe` for compatibility)
- JSON action payload for elevated task (`pending-action.json`) supporting any adapter by name
- `config.json` fields: `ethernetAdapterName`, `wifiAdapterName`, `excludePatterns`, `exeName`
- Virtual/Hyper-V adapters excluded by default (`vEthernet`, `Hyper-V`)

### Changed

- Expanded UI (480×500) with scrollable adapter list, quick-switch buttons, status summary
- Scheduled task now runs `Toggle-NetworkAdapter.ps1`

### Fixed

- Adapter row buttons clipped on right edge — rows now use `TableLayoutPanel` with a single full-width Toggle button per adapter

## [1.2.1] - 2026-08-28

### Fixed

- Crash on launch (`ArgumentOutOfRangeException` in `Icon.BmpFrame`) caused by PNG-compressed `icon.ico`
- Tray icon now drawn programmatically from `logo.png` with green/gray fallback circle
- Regenerated `assets/icon.ico` as valid BMP-based multi-size ICO for shortcuts and the `.exe`

## [1.2.0] - 2026-08-28

### Changed

- **`Ethernet Toggle.exe` is now a full standalone WinForms app** — no PowerShell process in the taskbar
- Fixed launcher window layout: taller window, proper padding, all labels and buttons visible
- Tray icon and UI run entirely inside the `.exe` with your custom logo

## [1.1.0] - 2026-08-28

### Added

- **`Ethernet Toggle.exe`** — standalone launcher with embedded app icon (no PowerShell icon in Start/taskbar)
- `scripts/Build-Launcher.ps1` compiles the launcher from C# using built-in Windows `csc.exe`
- Install script now creates Start Menu, Startup, and taskbar shortcuts that target the `.exe`

### Changed

- Shortcuts no longer point at `powershell.exe`; Windows search and pinned taskbar show the custom logo
- `Start Ethernet Toggle.bat` launches the `.exe` when available

## [1.0.0] - 2026-08-28

### Added

- System tray toggle for Ethernet adapters with live on/off status
- Compact launcher window with logo, status, and Toggle / Enable / Disable buttons
- One-time admin install via scheduled task (no UAC on daily toggles)
- Single-instance app behavior (relaunch focuses existing window)
- Configurable adapter name via `config.json`
- `Start Ethernet Toggle.bat` for double-click launch
- Install and uninstall scripts
- Generated logo (`assets/logo.png`) and tray icon (`assets/icon.ico`)

### Requirements

- Windows 10 or 11
- PowerShell 5.1 or later

[1.4.0]: https://github.com/mdashfakfaysal/internet-toggle/releases/tag/v1.4.0
[1.3.1]: https://github.com/mdashfakfaysal/internet-toggle/releases/tag/v1.3.1
[1.3.0]: https://github.com/mdashfakfaysal/internet-toggle/releases/tag/v1.3.0
[1.2.1]: https://github.com/mdashfakfaysal/internet-toggle/releases/tag/v1.2.1
[1.2.0]: https://github.com/mdashfakfaysal/internet-toggle/releases/tag/v1.2.0
[1.1.0]: https://github.com/mdashfakfaysal/internet-toggle/releases/tag/v1.1.0
[1.0.0]: https://github.com/mdashfakfaysal/internet-toggle/releases/tag/v1.0.0
