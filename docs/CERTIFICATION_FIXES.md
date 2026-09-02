# Microsoft Store Certification Fixes — v2.2.0

**Policy failure addressed:** 10.1.2.10 (Functionality — feature not responding)

---

## Root causes (v2.1.0 and earlier)

| # | Hypothesis | Finding | Code path |
|---|------------|---------|-----------|
| 1 | UAC / scheduled-task setup blocks reviewers | **Confirmed.** `TryEnqueue` wrote the queue then called `schtasks /Run` on a task that did not exist on a clean Store install. The queue was never processed — no lock, no error, no UI change after the first dialog. | `AdapterOperationQueue.TriggerScheduledTask` + mandatory `EnsureElevatedSetup` before enqueue |
| 2 | USB Ethernet not detected | **Not the primary issue.** `AdapterDiscovery.IsEthernet` matches `asix`, `usb`, `ethernet` — ASIX "Ethernet 2" is classified correctly when present. | `AdapterDiscovery.cs` lines 148–166 |
| 3 | No immediate UI feedback | **Confirmed.** `Thread.Sleep(1200)` on the UI thread after queueing; dual "Prioritize" buttons confused testers looking for a simple Ethernet toggle. | `SwitchToEthernet` / `SwitchToWifi` |
| 4 | Silent failure paths | **Confirmed.** Queue without task = silent no-op; `TryQueueOperation` returned false after setup dialog with no in-window status line. | `TryQueueOperation` → `EnsureElevatedSetup` → failed `schtasks /Run` |

---

## Fixes in v2.2.0

| Fix | Implementation |
|-----|----------------|
| One obvious control | Single primary button: **Disable Ethernet** / **Enable Ethernet**; tray menu matches |
| Immediate feedback | Button disables + "Disabling Ethernet…" within one UI frame; last-result label always updates |
| Off UI thread | Enqueue, elevation, and wait run on `ThreadPool`; no `Thread.Sleep` on UI thread |
| Per-click elevation | `ElevatedOperationHelper` — if scheduled task missing, one-shot elevated PowerShell runs `Register-ElevatedTask.ps1` (best effort) + `Toggle-NetworkAdapter.ps1` |
| UAC declined | Explicit dialog — adapter not changed; instructions to retry |
| No Ethernet | Button disabled: "No Ethernet adapter detected" |
| Accurate copy | Store/README text no longer claims Wi-Fi is never touched |

---

## Certification tester instructions (paste in Partner Center)

```
TEST ENVIRONMENT
• Device: Windows 11, build 26200 or later
• If the laptop has NO built-in Ethernet port, connect a USB Ethernet adapter before testing (for example ASIX AX88772B — may appear as "Ethernet 2").
• Use a clean user profile or reset the app between runs if needed.

INSTALL
1. Install Link Priority from the Store package (MSIX).
2. Launch Link Priority from Start.

PRIMARY TEST — ONE BUTTON
1. Open the main window (double-click tray icon if minimized).
2. Confirm the status line shows your Ethernet adapter name and state (for example "Ethernet 2: Connected").
3. Click the large blue button:
   • If Ethernet is enabled, it reads "Disable Ethernet".
   • If Ethernet is disabled, it reads "Enable Ethernet".
4. On first use, click Continue on the in-app dialog, then select YES on the Windows User Account Control (UAC) prompt.
   Windows requires administrator approval to change a network adapter — this is normal.
5. Within a few seconds:
   • The button label updates to the opposite state.
   • The status line shows Disabled or Enabled/Connected.
   • A "last result" line shows OK with a timestamp.
   • A notification balloon may appear.
6. Click the button again to toggle back. Repeat 3–5 times — the app must never freeze, hang, or stop responding.

TRAY MENU
1. Right-click the tray icon.
2. Use "Disable Ethernet" or "Enable Ethernet" — same behavior as the main button.
3. "Show Window" opens the main window; "Exit" closes the app.

IF UAC IS DECLINED
• The app shows a clear message that the adapter was NOT changed.
• Click the button again and approve UAC to retry.

IF NO ETHERNET ADAPTER
• The primary button is gray and reads "No Ethernet adapter detected".
• Connect a USB Ethernet adapter and reopen the app.

NOTE
• This app enables/disables the Ethernet adapter only via the primary button.
• Wi-Fi is not disabled by default. Advanced settings may optionally disable Wi-Fi when prioritizing Ethernet (off by default).
```

---

## Package version

- **App version:** 2.2.0
- **MSIX identity version:** 2.2.0.0
- **Partner Center identity:** unchanged (`ITDoctor360.InternetSwitcher`)

---

## Resubmission checklist

- [ ] Upload new MSIX `InternetSwitcher-Free-Store-x64-2-2-0-0.msix`
- [ ] Paste certification tester instructions above in Submission options
- [ ] Update "What's new" with v2.2.0 cert fix notes
- [ ] Test on clean VM: install → open → click button → approve UAC → observe toggle
