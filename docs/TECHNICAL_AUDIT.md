# Technical Audit — Internet Toggle / Internet Switcher

**Audit date:** 2026-08-28  
**Repository:** `internet-toggle` (local path: `ethernet-toggle-tray`)  
**Auditor scope:** Phase 0 pre-commercialization review

---

## Executive Summary

Internet Toggle is a **working Windows desktop utility** built as a **single-file C# WinForms application** (`launcher/EthernetToggleApp.cs`, ~1,140 lines) compiled with **.NET Framework 4.x `csc.exe`** into `Internet Toggle.exe`. Privileged network operations are delegated to a **PowerShell scheduled task** (`Toggle-NetworkAdapter.ps1`) running at highest privileges on demand. The app provides tray UI, adapter listing, per-adapter enable/disable, Wi-Fi ↔ Ethernet quick switch, settings, and startup behavior.

The codebase is **suitable for incremental commercialization** without a framework rewrite. Primary gaps: edition/licensing abstraction, installer/MSIX packaging, privileged helper hardening, automated tests, and production documentation.

---

## Technology Stack

| Area | Current Implementation |
|------|------------------------|
| **Language** | C# (.NET Framework 4.x, `/target:winexe`) + PowerShell 5.1 |
| **UI framework** | Windows Forms (`System.Windows.Forms`) |
| **Build system** | PowerShell scripts (`Build-Launcher.ps1`, `Build-Release.ps1`) invoking `csc.exe` |
| **Entry point** | `Program.Main()` in `launcher/EthernetToggleApp.cs` |
| **Serialization** | `System.Web.Script.Serialization.JavaScriptSerializer` (JSON) |
| **Networking APIs** | WMI/CIM (`Win32_NetworkAdapter`, `MSFT_NetAdapter`), PowerShell `Get-NetAdapter` / `Enable-NetAdapter` / `Disable-NetAdapter` |
| **Elevation** | Windows Scheduled Task (`RunLevel Highest`) triggered via `schtasks.exe /Run` |
| **Config** | `config.json` (repo root, shipped with app) + `%LOCALAPPDATA%\InternetToggle\settings.json` |
| **IPC to elevated task** | JSON file `%LOCALAPPDATA%\InternetToggle\pending-action.json` |
| **Release CI** | GitHub Actions (`.github/workflows/release.yml`) on version tags |
| **License** | MIT |
| **Version** | `1.4.0` in `config.json` (not yet single authoritative source) |

---

## Application Architecture

```
Internet Toggle.exe (normal user, WinForms + tray)
        │
        │ writes pending-action.json
        │ schtasks /Run /TN ToggleInternetAdapter
        ▼
Scheduled Task (elevated PowerShell)
        │
        │ reads pending-action.json
        ▼
Toggle-NetworkAdapter.ps1
        │
        │ Get-NetAdapter / Enable-NetAdapter / Disable-NetAdapter
        ▼
Windows Network Stack
```

**Adapter enumeration (UI, non-elevated):** WMI `Win32_NetworkAdapter` + `MSFT_NetAdapter` in `AdapterHelper.GetAdapters()`.

**Adapter mutation (elevated):** PowerShell cmdlets only; no direct P/Invoke for enable/disable in C#.

---

## Existing Functionality

### Working today
- Dynamic adapter discovery (physical adapters; virtual excluded via `excludePatterns`)
- Per-adapter Enable/Disable (single toggle button per row)
- Quick switch: Switch to Ethernet / Switch to Wi-Fi (batch disable+enable)
- System tray with context menu and status summary
- Main window with logo, settings button, adapter list
- Settings: launch at startup, start minimized to tray
- Single-instance mutex (`Global\InternetToggleApp`)
- Close-to-tray (X hides window; Exit from tray menu)
- Toast notifications from elevated script
- One-time admin install registers scheduled task + shortcuts
- GitHub Releases zip build on tags

### Not implemented
- Free/Pro editions or licensing
- Global hotkeys
- Network profiles, failover, schedules, rules (Pro roadmap)
- Formal installer (MSI/EXE setup)
- MSIX / Microsoft Store package
- Auto-update
- About / Check for Updates UI
- Structured logging (only `error.log` on fatal crash)
- Telemetry (none — good)
- CLI
- Automated tests

---

## Privilege Model (Current)

| Operation | Requires Admin | How |
|-----------|----------------|-----|
| Install scheduled task | Yes | `Install-EthernetToggle.ps1` `#Requires -RunAsAdministrator` |
| Enable/Disable adapter | Yes | Elevated scheduled task |
| List adapter status | No | WMI from user process |
| UI / tray | No | Normal user |
| Daily toggle after install | No UAC prompt | Pre-registered task runs elevated silently |

**Concern:** Entire app does **not** run elevated (good). However, the elevated component executes a **full PowerShell script** with JSON-driven actions — not a minimal fixed-op helper. Adapter names flow from UI → JSON → PowerShell `-Name` parameter (lower injection risk than shell concatenation, but validation should be enforced).

**Concern:** Scheduled task runs `powershell.exe -File Toggle-NetworkAdapter.ps1` with broad script surface area.

---

## Security Assessment

### Strengths
- Main UI runs as standard user
- No telemetry observed
- No secrets in repository
- Adapter operations use PowerShell cmdlets with `-Name` rather than raw `netsh` string building
- JSON IPC instead of arbitrary command strings from UI

### Risks / Improvements Needed
1. **Validate adapter names** in elevated script (allowlist pattern: alphanumeric, spaces, hyphen, parentheses — reject shell metacharacters)
2. **Shrink elevated surface** — long-term: small C# helper accepting fixed operation enum + validated adapter name
3. **Scheduled task path** — uses install-time absolute path; breaks if user moves folder (document or reinstall)
4. **Hardcoded dev paths** in install script (`C:\Users\Admin\Scripts\EthernetToggle\...` legacy cleanup)
5. **`schtasks` argument** — task name from config should be validated
6. **No secrets scan in CI** — add quality gate

### Secrets
- No API keys, tokens, or credentials found in repo
- GitHub Actions uses `GITHUB_TOKEN` only (standard)

---

## Packaging & Distribution

| Method | Status |
|--------|--------|
| GitHub Releases zip | Working (`Build-Release.ps1`) |
| Portable exe + bat | Working |
| Windows Installer (MSI/EXE) | **Not present** |
| MSIX / Store | **Not present** |
| Winget / Chocolatey | Placeholder in README only |

Install flow today: extract zip → run admin install script → shortcuts created.

---

## Microsoft Store Compatibility

**Blockers / considerations:**
- Networking adapter enable/disable requires **elevation** — MSIX sandbox may block unless `runFullTrust` + documented justification
- Scheduled task creation at install may not work inside sandboxed MSIX without full trust
- Publisher identity, signing certificate required for Store submission
- Current build is classic Win32 — MSIX packaging path viable with `runFullTrust` but requires Partner Center values

**Recommendation:** Prepare MSIX with `runFullTrust` documented; maintain traditional EXE installer as primary GitHub distribution path.

---

## Configuration & Data Storage

| File | Location | Purpose |
|------|----------|---------|
| `config.json` | App directory | Adapter names, task name, app branding, defaults |
| `settings.json` | `%LOCALAPPDATA%\InternetToggle\` | User startup preferences |
| `pending-action.json` | `%LOCALAPPDATA%\InternetToggle\` | IPC queue to elevated task |
| `show-window.signal` | `%LOCALAPPDATA%\InternetToggle\` | Single-instance focus signal |
| `error.log` | `%LOCALAPPDATA%\InternetToggle\` | Unhandled exception dump |

**Missing:** Config schema versioning, migration, Pro profile storage.

---

## Dependencies

| Dependency | Type | License |
|------------|------|---------|
| .NET Framework 4.x | OS/runtime | Microsoft |
| PowerShell 5.1+ | OS (install/elevated ops) | Microsoft |
| System.Management (WMI) | BCL | Microsoft |
| System.Web.Extensions | BCL (JSON) | Microsoft |

No NuGet packages. No third-party libraries.

---

## Versioning

- Current: `1.4.0` in `config.json` only
- Git tags: `v1.0.0` … `v1.4.0`
- exe file version metadata: **not set** by `csc` today
- **Needed:** `version.json` single source → propagate to UI, builds, installer, MSIX

---

## Recommended Modifications (Priority Order)

### P0 — Preserve & harden (before Pro features)
1. Create `version.json` single source of truth
2. Add adapter name validation in `Toggle-NetworkAdapter.ps1`
3. Add `EditionService` / `ILicenseProvider` abstraction (no behavior change for Free)
4. Document privilege model

### P1 — Productization
5. Free/Pro build configurations (`INTERNET_SWITCHER_FREE` / `INTERNET_SWITCHER_PRO` defines)
6. About dialog, version display, upgrade dialog for gated Pro UI
7. Basic global hotkey (Free)
8. Structured local logging + `PRIVACY.md`
9. Config schema versioning

### P2 — Distribution
10. Inno Setup or WiX installer skeleton (offline EXE)
11. MSIX manifest template + capability docs
12. GitHub Actions: build Free + Pro, checksums
13. `store-assets/` + listing copy

### P3 — Pro features (architecture first)
14. Profile storage schema (Pro)
15. Failover / rules engine hooks (Pro, feature-gated)

---

## Conclusion

**Do not rewrite.** The existing C# WinForms + elevated PowerShell task architecture works and matches the user's workflow. Commercialization should proceed via **incremental layering**: edition/licensing services, build variants, installer/MSIX packaging, documentation, and validated privileged IPC — while keeping the core adapter switching logic intact.
