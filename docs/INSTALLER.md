# Installer Guide

## Current State

Portable distribution via zip + admin install script. **Offline installer skeleton** provided in `packaging/inno/InternetSwitcher.iss`.

## Planned Installer Outputs

```
dist/free/InternetSwitcher-Free-Setup-x64-1.0.0.exe
dist/pro/InternetSwitcher-Pro-Setup-x64-1.0.0.exe
```

## Normal Install (future Inno Setup build)

1. Run `InternetSwitcher-Free-Setup-x64-{version}.exe`
2. Accept license
3. Choose install location (default: `%ProgramFiles%\Internet Switcher\`)
4. Installer registers scheduled task (requires admin)
5. Creates Start Menu shortcut
6. Optionally creates desktop shortcut

## Silent Install (planned)

```cmd
InternetSwitcher-Free-Setup-x64-1.0.0.exe /VERYSILENT /NORESTART
```

## Uninstall (planned)

Via Settings → Apps, or:

```cmd
"C:\Program Files\Internet Switcher\unins000.exe" /VERYSILENT
```

## Upgrade Behavior

- Same edition: overwrite binaries, preserve `%LOCALAPPDATA%\InternetToggle\settings.json`
- Free → Pro: install Pro alongside or upgrade via Pro installer (future)

## Files Requiring Authenticode Signing (before commercial release)

| File | Priority |
|------|----------|
| `Internet Switcher Free.exe` | High |
| `Internet Switcher Pro.exe` | High |
| `InternetSwitcher-*-Setup-*.exe` | High |
| MSIX package | Required for Store |

**Do not generate fake signatures.** Document signing in release checklist.

## Build Installer (when Inno Setup installed)

```powershell
# Requires Inno Setup 6+
iscc packaging\inno\InternetSwitcher.iss
```

See `packaging/inno/InternetSwitcher.iss` for placeholders.
