# Changelog

## 2.2.0 — 2026-09-03

**Store cert fix (10.1.2.10):** Single Enable/Disable Ethernet button; immediate UI feedback; per-click elevation fallback when scheduled task is missing (no silent no-op); USB Ethernet detection unchanged. Accurate Wi-Fi copy. New artwork regen.

## 2.1.1 — 2026-09-03

**Artwork fix:** Regenerated Link Priority logo/icon with lock-safe asset scripts; MSIX ships new artwork. Copy audit: clarified that Prioritize Wi-Fi enables Wi-Fi and Prioritize Ethernet runs `netsh wlan disconnect` (Wi-Fi adapter not disabled by default).

## 2.1.0 — 2026-09-03

**Rebrand:** Outward-facing identity renamed to **Link Priority** with honest copy describing Ethernet-adapter priority control (Wi-Fi adapter stays on by default). New icon/logo. No functional or adapter-control logic changes. Store identity `ITDoctor360.InternetSwitcher` unchanged.

## 2.0.0 — 2026-08-31

**Breaking simplification:** single edition, safe switching strategy, Pro features removed from build.

### Architecture
- One product: **Internet Switcher** (no Free/Pro split in daily use)
- **Safe switching:** Use Wi-Fi disables Ethernet only; Use Ethernet enables Ethernet + `netsh wlan disconnect` (Wi-Fi adapter stays enabled unless advanced setting is on)
- **No network changes at launch** — startup no longer auto-disables adapters
- Pro automation (failover, rules, schedules, profiles) removed from compiled app

### Reliability
- Enable Wi-Fi **before** disabling Ethernet (never strand user offline)
- PnP recovery for Not Present adapters
- Switch rollback when enable fails
- Ghost Wi-Fi profile filtering (`Wi-Fi 2/3/4/5` deprioritized)

### UI
- Two primary buttons: **Use Wi-Fi** / **Use Ethernet**
- Settings: launch at startup, start minimized, advanced "also disable Wi-Fi adapter" (off by default)

### Recovery
- Added `scripts/Recover-WifiAdapter.ps1` for wedged MediaTek / PnP error states

## 1.0.3
- Not Present adapter detection, PnP recovery, switch rollback

## 1.0.2
- Fix debounce blocking first tray click

## 1.0.1
- Store certification reliability fixes

## 1.0.0
- Initial Store release
