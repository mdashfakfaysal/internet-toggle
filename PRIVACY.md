# Privacy Policy

**Internet Switcher** · Last updated: 2026-08-28

## Summary

Internet Switcher is a local Windows utility. It does **not** collect browsing history, network credentials, Wi-Fi passwords, or packet contents.

## Data Stored Locally

| Data | Location | Purpose |
|------|----------|---------|
| Settings (startup, tray) | `%LOCALAPPDATA%\InternetToggle\settings.json` | User preferences |
| Pending adapter actions | `%LOCALAPPDATA%\InternetToggle\pending-action.json` | IPC to elevated task (temporary) |
| Diagnostic logs (optional) | `%LOCALAPPDATA%\InternetToggle\logs\app.log` | Troubleshooting |
| Error log | `%LOCALAPPDATA%\InternetToggle\error.log` | Crash diagnostics |

## What We Do NOT Collect

- Wi-Fi passwords or PSKs
- Authentication tokens
- License secrets (stored locally only when implemented)
- Websites visited or DNS queries
- Packet payloads
- Personal files

## Network Communication

**Default behavior:** The application does not send analytics or telemetry to any server.

**Optional future features:**

- "Check for Updates" may contact GitHub Releases API (version check only)
- Pro license validation may contact a licensing server (future; no secrets embedded in client)

## Logging

Local logs may contain:

- Timestamp
- App version
- Operation type (Enable/Disable/Switch)
- Adapter name
- Success/failure status
- Safe error messages

Logs do **not** contain passwords or traffic content. Diagnostic logging can be disabled in settings (Pro) when implemented.

## Third Parties

No third-party analytics SDKs are included. Dependencies are Microsoft .NET Framework and Windows system components.

## Contact

For privacy questions, open an issue at: https://github.com/mdashfakfaysal/internet-toggle/issues

## Changes

Material privacy policy changes will be noted in the repository CHANGELOG.
