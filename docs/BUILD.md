# Build Guide

## Requirements

- Windows 10/11
- PowerShell 5.1+
- .NET Framework 4.x (`csc.exe` at `%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe`)

## Version Source

Edit `version.json` — propagates to release packages and UI at runtime.

## Build Commands

### Free edition

```powershell
cd path\to\internet-toggle
.\scripts\Build-Launcher.ps1 -Edition Free
```

Output: `Internet Switcher Free.exe` (+ legacy alias `Internet Toggle.exe`)

### Pro edition

```powershell
.\scripts\Build-Launcher.ps1 -Edition Pro
```

Output: `Internet Switcher Pro.exe`

### Full release packages (Free + Pro + checksums)

```powershell
.\scripts\Build-Release.ps1 -Version 1.0.0
```

Output:

```
dist/free/internet-switcher-free-x64-1.0.0.zip
dist/free/internet-switcher-free-x64-1.0.0.zip.sha256
dist/pro/internet-switcher-pro-x64-1.0.0.zip
dist/pro/internet-switcher-pro-x64-1.0.0.zip.sha256
```

### Microsoft Store MSIX (Free edition)

Requires Windows 10 SDK (`makeappx.exe`):

```powershell
winget install Microsoft.WindowsSDK.10.0.18362   # one-time
.\packaging\msix\Build-Msix.ps1
```

Output:

```
dist/store/InternetSwitcher-Free-Store-x64-1-0-0-0.msix
dist/store/InternetSwitcher-Free-Store-x64-1-0-0-0.msixupload
dist/store/InternetSwitcher-Free-Store-x64-1-0-0-0.msix.sha256
```

## Development Pro Testing (DEBUG builds only)

```powershell
$env:INTERNET_SWITCHER_DEV_PRO = '1'
.\scripts\Build-Launcher.ps1 -Edition Free
```

**Not available in Release/optimized builds.**

## Install Locally

```powershell
.\scripts\Install-EthernetToggle.ps1   # Run as Administrator
```

## Compile Defines

| Define | Meaning |
|--------|---------|
| `INTERNET_SWITCHER_FREE` | Free edition |
| `INTERNET_SWITCHER_PRO` | Pro edition |
| `DEBUG` | Enables dev license provider |
