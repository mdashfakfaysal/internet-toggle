# Reliability Audit — Internet Switcher Adapter Operations

**Date:** 2026-08-31  
**Scope:** Elevated adapter enable/disable/switch pipeline (tray → JSON IPC → scheduled task → PowerShell → NetAdapter cmdlets)  
**Symptoms reported:** After 2–3 tray switches or power loss, adapters cannot be re-enabled; Wi-Fi sometimes vanishes from Network Connections; PowerShell window stays visible; operations appear to do nothing.

---

## Architecture (as audited)

```
Tray/UI (C#) ──write──► pending-action.json ──schtasks /Run──► Scheduled Task (Highest)
                                                                    │
                                                                    ▼
                                                         Toggle-NetworkAdapter.ps1
                                                                    │
                                                         Enable/Disable-NetAdapter
```

---

## Root causes (ranked)

### RC-1 — Race on single JSON file (CRITICAL)

**Finding:** `AdapterHelper.QueueRequest` overwrites `pending-action.json` on every click and immediately fires `schtasks /Run`. `Resolve-NetworkToggleRequest` **deletes** the file on read.

**Failure scenario:**
1. User clicks Switch to Wi-Fi → writes payload A → task starts
2. User clicks Switch to Ethernet before task reads file → **overwrites with payload B**
3. Two concurrent `schtasks /Run` instances start
4. Instance 1 reads B (wrong action) or instance 2 finds **empty/missing file** → falls back to default `Toggle` on `config.adapterName` (Ethernet only)
5. Adapters end up in inconsistent state; user perception: "nothing works"

**Likelihood:** High on rapid tray use (matches user report).

---

### RC-2 — Scheduled task launches visible PowerShell (HIGH)

**Finding:** Install script registers task as:
```powershell
-Execute 'powershell.exe' `
-Argument "-NoProfile -ExecutionPolicy Bypass -File `"$toggleScript`""
```
**Missing:** `-WindowStyle Hidden -NonInteractive`

**Result:** Console window visible and can remain open if script errors, waits, or `$ErrorActionPreference = 'Stop'` throws before exit.

**Likelihood:** High — matches "PowerShell window stays open".

---

### RC-3 — No post-operation verification or retry (HIGH)

**Finding:** `Set-AdapterState` calls `Enable-NetAdapter` / `Disable-NetAdapter` once with no verification loop. On failure it either throws (aborting mid-switch) or returns silently (`Write-Warning` when adapter "not found").

**Failure scenario:**
- Switch disables Wi-Fi successfully, Enable Ethernet fails transiently (driver busy after power event) → user stuck on Wi-Fi disabled
- Script still shows success toast for Switch

**Likelihood:** Medium–High after power loss or rapid toggling.

---

### RC-4 — No concurrency guard in C# or PowerShell (HIGH)

**Finding:** No mutex, lock file, or queue. Multiple `schtasks /Run` overlap freely. UI uses fixed `Thread.Sleep(900)` instead of waiting for completion.

**Likelihood:** High with Pro automation (2s timer) + tray clicks + failover rules stacking operations.

---

### RC-5 — Stale state after crash / power loss (MEDIUM)

**Finding:** No startup recovery. `pending-action.json` may remain on disk. `operation` lock file not used (did not exist pre-fix). Scheduled task is not verified on app launch — if task missing after OS repair, all operations no-op silently from UI perspective.

**Likelihood:** Medium after force shutdown.

---

### RC-6 — Pro automation amplifies race conditions (MEDIUM)

**Finding:** `OnTimerTick` every 2s calls `EvaluateAutomation()` which can fire Switch/Disable while user action in flight. Failover triggers on disconnect edges — rapid manual switching creates false "disconnect" edges.

**Likelihood:** Medium in Pro edition.

---

### RC-7 — "Adapter disappeared" from ncpa.cpl (MEDIUM / often misinterpreted)

**Finding:** Code uses `Disable-NetAdapter` only (not device removal). Disabled adapters **should** still appear in `ncpa.cpl` greyed out. True disappearance usually indicates:
- Driver reset / power management after abrupt shutdown
- Adapter name changed (e.g. "Wi-Fi" vs "Wi-Fi 2")
- User viewing before driver re-enumerates (~seconds after boot)

**Gap:** Code only queries `Get-NetAdapter -Name $Name` without `-IncludeHidden`, no fallback alias search, no `netsh interface show interface` fallback.

**Likelihood:** Medium after power events; may be transient or name mismatch.

---

### RC-8 — `$ErrorActionPreference = 'Stop'` aborts mid-batch (MEDIUM)

**Finding:** Single cmdlet failure in Switch/Batch aborts remaining enable/disable steps.

**Likelihood:** Medium under driver stress.

---

### RC-9 — Virtual adapters (LOW for this user)

**Finding:** `vEthernet`/Hyper-V excluded from UI but not from scheduled task if manually named in JSON. Unlikely cause for user's Realtek/MediaTek adapters.

---

## Failure scenarios matrix

| Scenario | Mechanism | User-visible result |
|----------|-----------|---------------------|
| Rapid tray switching | RC-1 + RC-4 | Wrong adapter toggled; one adapter left disabled |
| Power outage mid-switch | RC-3 + RC-5 | Stale JSON; partial switch; task may not complete |
| PowerShell window stuck | RC-2 | Console visible, appears hung |
| Wi-Fi missing in ncpa | RC-7 | Driver reenum delay or wrong adapter name |
| Pro failover + manual switch | RC-6 + RC-1 | Overlapping contradictory commands |
| Task unregistered | RC-5 | Clicks queue JSON but nothing executes |

---

## Recommended fixes (implemented in Phase 2)

| ID | Fix |
|----|-----|
| F1 | **Action queue** (`pending-action-queue.json`) — append, don't overwrite; process all sequentially in one task run |
| F2 | **Operation lock file** — prevent overlapping PowerShell instances; stale lock cleanup (>120s) on startup |
| F3 | **Hidden PowerShell** — `-WindowStyle Hidden -NonInteractive` on scheduled task |
| F4 | **Retry + verify** — poll `Get-NetAdapter` until expected AdminStatus or timeout; retry up to 3 times |
| F5 | **C# debounce + in-flight guard** — block stacking operations; min interval between tray actions |
| F6 | **Startup recovery** — clear stale files; migrate legacy single JSON to queue; verify task exists |
| F7 | **Failure toasts** — report partial switch failures with adapter name |
| F8 | **Automation cooldown** — skip auto rules for 5s after manual operation |
| F9 | **ErrorAction Continue** in adapter setter — complete batch even if one step fails |

**Status:** Implemented in v1.0.1 — see `docs/CERTIFICATION_FIXES.md`.

---

## Verification checklist

1. Rapid-click Switch Wi-Fi ↔ Ethernet 10 times from tray — both adapters recover
2. No visible PowerShell window during operations
3. Pull network cable / disable adapter — enable from tray succeeds within 15s
4. Kill `powershell.exe` mid-task — restart app; next switch works (lock cleared)
5. `%LOCALAPPDATA%\InternetToggle\reliability.log` shows queue/process/verify entries

---

## Out of scope / manual recovery

If adapter truly missing from Device Manager (not just disabled), user must:
- Device Manager → Scan for hardware changes
- Or reboot — outside app control

Document `netsh interface set interface name="Wi-Fi" admin=ENABLED` as manual fallback in troubleshooting docs.
