# Changelog

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
