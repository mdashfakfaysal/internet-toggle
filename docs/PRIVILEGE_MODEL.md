# Privilege Model

## Principle

**Least privilege.** The main application runs as the logged-in user. Only predefined network adapter operations run elevated.

## Privilege Matrix

| Operation | User process | Elevated task |
|-----------|--------------|---------------|
| Show UI / tray | Yes | No |
| Enumerate adapters (WMI) | Yes | No |
| Enable adapter | Queue only | Yes |
| Disable adapter | Queue only | Yes |
| Switch Wi-Fi ↔ Ethernet | Queue only | Yes |
| Install scheduled task | Admin install script | N/A |

## Elevated Component

**Current:** Windows Scheduled Task `ToggleInternetAdapter` executes:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Toggle-NetworkAdapter.ps1
```

**Allowed actions (fixed set):**

- `Enable` / `Disable` / `Toggle` for a single validated adapter name
- `Switch` with explicit enable/disable adapter lists
- `Batch` with validated adapter/action pairs

**Rejected:**

- Arbitrary shell commands
- Arbitrary PowerShell from UI
- Unvalidated adapter names (must match `^[A-Za-z0-9 \-_\(\)\[\]\.#]+$`, max 128 chars)

## UAC Behavior

| Scenario | UAC |
|----------|-----|
| One-time install | Required |
| Daily toggles after install | Not shown (pre-registered task) |
| User cancels UAC at install | Install fails; app cannot toggle |

## Recommended Future Hardening

Replace broad PowerShell script with a **small fixed-op helper executable** that accepts only an operation enum + validated adapter name over a narrow IPC channel.

## User-Facing Explanation

> Internet Switcher changes network adapters only when you click a button. Windows requires administrator permission to enable or disable adapters. After the one-time install, these operations run through a pre-approved scheduled task so you are not prompted every time.
