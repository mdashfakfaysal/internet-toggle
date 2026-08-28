# Microsoft Store Capabilities

**App:** Internet Switcher (ITDoctor360.InternetSwitcher)  
**Store ID:** 9N5BNRI19F9K5  
**PFN:** ITDoctor360.InternetSwitcher_mc2sshwaxxrnm

## Declared Capabilities (MSIX)

| Capability | Declared | Justification |
|------------|:--------:|---------------|
| `runFullTrust` | **Yes** | Internet Switcher is a classic Win32 desktop utility packaged via the Desktop Bridge. Full-trust execution is required to: (1) interact with Windows networking APIs (WMI/CIM, NetAdapter cmdlets) to enumerate and change network adapter state; (2) display a system-tray icon and WinForms UI; (3) register and invoke a user-consented scheduled task for adapter enable/disable operations. These behaviors cannot run within the MSIX sandbox. |

## Capabilities NOT Declared

| Capability | Declared | Reason |
|------------|:--------:|--------|
| `allowElevation` | **No** | This is not a standard MSIX manifest capability. Elevation for adapter changes is handled by a pre-registered Windows Scheduled Task (installed with explicit user consent during first-run setup), not by elevating the main application process. |
| `internetClient` | **No** | Core functionality does not require network access. Optional future update checks may add this. |
| `privateNetworkClientServer` | **No** | App does not listen on network ports. |
| Location, camera, microphone | **No** | Not used. |

## Certification Reviewer Notes

> **What this app does:** Internet Switcher is a system-tray utility that lets users enable, disable, or switch between Wi‑Fi and Ethernet network adapters on Windows.
>
> **Why full trust is needed:** The app uses Win32 APIs (WMI, Windows Forms, NotifyIcon) and must invoke elevated PowerShell cmdlets (`Enable-NetAdapter` / `Disable-NetAdapter`) to change adapter state — operations Windows restricts to administrators.
>
> **How elevation works:** During first-run setup, the user is prompted once (UAC) to register a scheduled task that performs only predefined adapter operations. After setup, toggling adapters does not show repeated UAC prompts. The app does not execute arbitrary commands, scripts, or shell strings from user input — adapter names are validated against a strict allowlist.
>
> **What this app does NOT do:** No packet inspection, no credential collection, no browsing history, no unrelated system modifications, no bundled software, no advertising.

## Validation Steps for Reviewers

1. Install from Microsoft Store (or sideload MSIX)
2. Run first-time setup when prompted (admin consent for scheduled task)
3. Observe tray icon appears near the clock
4. Open the main window — adapter list shows Ethernet and Wi-Fi
5. Click **Switch to Wi-Fi** — Ethernet disables, Wi-Fi enables
6. Click **Switch to Ethernet** — reverse
7. Uninstall via Settings → Apps — app removes cleanly

## Technical Implementation Reference

- User process: C# WinForms (`Internet Switcher Free.exe`) — not elevated
- Adapter enumeration: WMI `Win32_NetworkAdapter` + `MSFT_NetAdapter`
- Adapter mutation: elevated scheduled task → `Toggle-NetworkAdapter.ps1` → `Enable/Disable-NetAdapter`
- IPC: JSON file in `%LOCALAPPDATA%\InternetToggle\`
