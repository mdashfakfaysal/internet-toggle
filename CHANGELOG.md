# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.1.0]: https://github.com/mdashfakfaysal/ethernet-toggle-tray/releases/tag/v1.1.0
[1.0.0]: https://github.com/mdashfakfaysal/ethernet-toggle-tray/releases/tag/v1.0.0
