# Microsoft Store Certification Fixes — v1.0.1

**Policy failures addressed:** 10.1.2.10 (Functionality), 10.1.1.1 (150% DPI scaling)

---

## 10.1.2.10 — Switch / Enable / Disable not responding

### Root cause

1. **Hardcoded adapter names** (`Ethernet`, `Wi-Fi`) in `config.json` — cert machine had `Ethernet 2` (ASIX USB). Summary showed `n/a` while list showed the real adapter; switch commands targeted non-existent names.
2. **No scheduled task on Store install** — cert testers do not run `Install-EthernetToggle.ps1` as admin; elevated task never registered → all operations no-op.
3. **Race on `pending-action.json`** — rapid tray clicks overwrote IPC payload; concurrent `schtasks /Run` caused lost/wrong commands.
4. **Visible PowerShell** — scheduled task missing `-WindowStyle Hidden -NonInteractive`.
5. **No retry/verify** — single `Enable-NetAdapter` call with no state confirmation.

### Fixes (v1.0.1)

| Fix | Implementation |
|-----|----------------|
| Dynamic adapter discovery | `AdapterDiscovery.cs` — classifies Wi-Fi/Ethernet by interface description; hints from config are fallback only |
| Summary matches reality | Shows `Ethernet (Ethernet 2): Connected` not `Ethernet: n/a` |
| One-time in-app setup | `ElevatedSetupHelper` + `Register-ElevatedTask.ps1` — UAC prompt on first switch |
| Operation queue | `AdapterOperationQueue.cs` + `pending-action-queue.json` |
| Retry + verify | `Set-AdapterStateReliable` in PowerShell with 15s poll timeout |
| Hidden PowerShell | Task args: `-WindowStyle Hidden -NonInteractive` |
| Failure toasts | Partial switch reports which adapter failed |

### Certification tester instructions (paste in Partner Center)

```
FIRST RUN — ONE-TIME SETUP
1. Install from Store package
2. Launch Internet Switcher
3. Click "Switch to Wi-Fi" or "Switch to Ethernet"
4. Approve the UAC prompt ("One-Time Setup Required") — registers elevated scheduled task
5. After setup, all switch/enable/disable buttons work without further UAC prompts

TEST STEPS
1. Open main window — adapter list shows all physical adapters (may be named "Ethernet 2", not "Ethernet")
2. Summary line shows detected adapter names and status (not n/a when adapter present)
3. Click Switch to Wi-Fi — Wi-Fi enables, Ethernet disables
4. Click Switch to Ethernet — reverse
5. Click Enable/Disable on individual adapter rows
6. Repeat steps 3–5 several times rapidly — operations should remain reliable

NOTE: App auto-detects Wi-Fi and Ethernet adapters; config names are hints only.
```

---

## 10.1.1.1 — 150% DPI scaling (1920×1080)

### Root cause

Header button column too narrow (228px) for About / Settings / Profiles at 150% scaling; title font too large.

### Fixes

- Form width increased to **680×580** client pixels
- Header action column **290px**
- Title font **13pt** (was 14pt)
- `AutoScaleMode.Dpi` retained
- Button margin/spacing adjusted

---

## Package version

- **MSIX identity version:** 1.0.1.0
- **Partner Center identity:** unchanged (`ITDoctor360.InternetSwitcher`)

---

## Resubmission checklist

- [ ] Upload new MSIX `InternetSwitcher-Free-Store-x64-1-0-1-0.msix`
- [ ] Update "What's new" with cert fix notes
- [ ] Paste certification tester instructions (above) in Submission options
- [ ] Confirm privacy URL still valid
- [ ] Test on clean VM without pre-install script
