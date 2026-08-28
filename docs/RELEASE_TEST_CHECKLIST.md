# Release Test Checklist

## Platforms

- [ ] Windows 10 x64
- [ ] Windows 11 x64

## Editions

- [ ] Internet Switcher Free
- [ ] Internet Switcher Pro

## Install / Uninstall

- [ ] Fresh install via `Install-EthernetToggle.ps1` (admin)
- [ ] Scheduled task registered
- [ ] Start Menu shortcut created with custom icon
- [ ] Startup shortcut respects settings
- [ ] Uninstall script removes task + shortcuts
- [ ] Upgrade over previous version preserves settings

## Core Functionality

- [ ] Adapter list populates (Ethernet, Wi-Fi)
- [ ] Virtual adapters excluded (vEthernet)
- [ ] Per-adapter Enable/Disable works
- [ ] Switch to Ethernet disables Wi-Fi, enables Ethernet
- [ ] Switch to Wi-Fi disables Ethernet, enables Wi-Fi
- [ ] Status shows Connected (not Connecting when connected)
- [ ] Disabled adapter shows single "Disabled" label

## UI / UX

- [ ] Window shows edition name and version
- [ ] About dialog opens, GitHub link works
- [ ] Settings: launch at startup toggles Startup folder
- [ ] Settings: start minimized to tray works
- [ ] Close (X) hides to tray, does not exit
- [ ] Tray Exit fully quits app
- [ ] Single instance: relaunch focuses existing window
- [ ] No clipped buttons/text at 100% DPI
- [ ] Ctrl+Alt+W switches to Wi-Fi (Free hotkey)

## Privilege / Security

- [ ] No UAC on daily toggle (after install)
- [ ] UAC shown during install only
- [ ] Invalid adapter name rejected in UI
- [ ] Invalid adapter name rejected in elevated script
- [ ] No PowerShell window flash on toggle

## Pro / Free Gating

- [ ] Free: Profiles button shows upgrade dialog
- [ ] Pro build: Profiles button acknowledges Pro enabled
- [ ] Release build: `INTERNET_SWITCHER_DEV_PRO` has no effect
- [ ] DEBUG build: dev Pro env var enables Pro features

## Startup

- [ ] Login starts tray-only (default)
- [ ] Left-click tray opens window
- [ ] Taskbar pin launches with custom icon

## Edge Cases

- [ ] Wi-Fi only machine
- [ ] Ethernet only machine
- [ ] Both adapters present
- [ ] Ethernet unplugged (Disconnected state)
- [ ] Wi-Fi disabled
- [ ] VPN adapter present (should not break list)
- [ ] Adapter renamed in Windows (update config.json)
- [ ] UAC cancelled at install → graceful failure message
- [ ] Windows restart → app auto-starts if enabled

## Release Artifacts

- [ ] Free zip builds and checksum validates
- [ ] Pro zip builds and checksum validates
- [ ] GitHub Actions release workflow succeeds on tag

## Do NOT Automate Without Consent

- Do not disable user's active network adapter in CI
- Use mocks for destructive network tests in automated suite
