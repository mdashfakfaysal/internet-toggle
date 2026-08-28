# Partner Center Submission Guide — Internet Switcher

**Product:** Internet Switcher (Free)  
**Store ID:** `9N5BNRI19F9K5`  
**Publisher:** IT Doctor 360  
**Package:** `InternetSwitcher-Free-Store-x64-1-0-0-0.msix` (validated ✓)

**Already complete:** Pricing · Age ratings · Packages  
**Still incomplete:** Properties · Store listings · Submission options

Open: [Partner Center](https://partner.microsoft.com/dashboard) → **Internet Switcher** → your in-progress submission.

---

## 1. Properties

**Path:** Submission → **Properties**

### Category

| Field | Select |
|-------|--------|
| **Category** | **Utilities & tools** (primary) |
| **Subcategory** | Productivity (optional secondary if Partner Center allows a second category) |

> If only one category is allowed, choose **Utilities & tools**.

### System requirements

| Field | Value |
|-------|-------|
| **Operating systems** | Windows 10, Windows 11 |
| **Architecture** | x64 |
| **Minimum OS version** | Windows 10 version 1809 (build 17763) or later |
| **Keyboard** | Required |
| **Mouse** | Required |
| **Touch** | Not required |
| **DirectX** | Not required |

### Hardware requirements

| Field | Value |
|-------|-------|
| **Memory** | 512 MB RAM (recommended minimum) |
| **Storage** | 10 MB available disk space |
| **Special hardware** | None — standard network adapter (Wi-Fi and/or Ethernet) |

Leave GPU, sensors, and other hardware fields **empty / not required**.

### Supported languages

| Field | Value |
|-------|-------|
| **Default language** | English (United States) |
| **Additional languages** | None for v1.0.0 (add later if localized) |

### App type & framework

| Field | Value |
|-------|-------|
| **App type** | Desktop application |
| **Framework** | Win32 / Desktop Bridge (MSIX with `runFullTrust`) |

### Privacy policy URL (Properties section)

**You must host `PRIVACY.md` at a public HTTPS URL before submitting.**

Recommended options (pick one):

| Option | URL to paste |
|--------|----------------|
| **GitHub raw (easiest)** | `https://raw.githubusercontent.com/mdashfakfaysal/internet-toggle/main/PRIVACY.md` |
| **GitHub blob view** | `https://github.com/mdashfakfaysal/internet-toggle/blob/main/PRIVACY.md` |
| **GitHub Pages** | `https://mdashfakfaysal.github.io/internet-toggle/PRIVACY.html` (requires Pages setup) |

Verify the URL opens in a browser **without login** before pasting into Partner Center.

### Support contact

| Field | Value |
|-------|-------|
| **Support URL** | `https://github.com/mdashfakfaysal/internet-toggle/issues` |
| **Support email** | Your business contact email (Partner Center account email or support@itdoctor360.com if you have one) |

### Website (optional but recommended)

| Field | Value |
|-------|-------|
| **Website** | `https://github.com/mdashfakfaysal/internet-toggle` |

Click **Save** on Properties when all fields are green.

---

## 2. Store listings (English — United States)

**Path:** Submission → **Store listings** → **English (United States)** → **Add/Edit**

### Product name

```
Internet Switcher
```

(Do not include “Free” in the Store product name unless you want it visible in search — the reserved name is **Internet Switcher**.)

### Short description (100 characters max)

**Paste exactly (72 characters):**

```
Instantly switch between Wi-Fi and Ethernet on Windows — from your system tray.
```

### Description (full)

**Paste:**

```
Dorm Wi-Fi acting up? Need to jump to your phone hotspot? Internet Switcher gives you one-click control over your Windows network adapters.

Enable or disable Wi-Fi and Ethernet individually, or use quick-switch presets to move between connections instantly. The app runs in your system tray, can start at Windows login, and works without repeated administrator prompts after a one-time setup.

FEATURES
• Enable / disable network adapters individually
• Switch to Ethernet / Switch to Wi-Fi presets
• Live adapter status (Connected, Disconnected, Disabled)
• System tray with quick actions
• Launch at Windows startup
• Start minimized to tray
• Basic hotkey (Ctrl+Alt+W → Switch to Wi-Fi)

Lightweight. No ads. No telemetry. No speed-up claims — just reliable adapter control.

SUPPORTED SYSTEMS
• Windows 10 (64-bit)
• Windows 11 (64-bit)

SETUP NOTE
On first run, Windows may ask once for administrator approval to register a scheduled task that enables/disables adapters. After that one-time setup, everyday switching does not show repeated UAC prompts.

Privacy: settings are stored locally on your PC. The app does not collect browsing history, Wi-Fi passwords, or network traffic. See the privacy policy URL in this listing.
```

### Keywords (max 7, comma-separated)

**Paste:**

```
network, ethernet, wifi, adapter, switch, tray, hotspot
```

### Copyright and trademark

**Paste:**

```
© 2026 IT Doctor 360. Internet Switcher is a trademark of IT Doctor 360. All rights reserved.
```

### What's new in this version

**Paste:**

```
Initial Microsoft Store release (v1.0.0):
• Internet Switcher Free edition
• One-click Wi-Fi / Ethernet switching from the system tray
• Per-adapter enable/disable controls
• Settings for startup and minimize-to-tray
• Improved UI layout and adapter status labels
```

### Feature list (if Partner Center shows a separate Features field)

**Paste one per line or as bullet list:**

```
Enable / disable network adapters individually
Switch to Ethernet / Switch to Wi-Fi presets
Live adapter connection status
System tray quick actions
Launch at Windows startup
Start minimized to tray
Ctrl+Alt+W hotkey — Switch to Wi-Fi
```

### Store logos & images

| Asset | Requirement | Source |
|-------|-------------|--------|
| **Store logo** | 300×300 PNG | `packaging/msix/Assets/Square150x150Logo.png` (upscale) or `assets/logo.png` |
| **Hero image** | Optional | Not required for desktop utilities |
| **Screenshots** | Min 1, recommend 4–6 | Capture per `store-assets/SCREENSHOT_PLAN.md` |

**Screenshot size:** 1366×768 minimum (16:9). PNG or JPG.

### Screenshot captions (paste when uploading each image)

| # | File suggestion | Caption |
|---|-----------------|---------|
| 1 | `01-main-dashboard.png` | See all your network adapters and their connection status at a glance. |
| 2 | `02-quick-switch.png` | Switch between Ethernet and Wi-Fi with one click. |
| 3 | `03-system-tray.png` | Runs quietly in the system tray — open the window when you need it. |
| 4 | `04-settings.png` | Control startup behavior — launch at login and start minimized to tray. |
| 5 | `05-about.png` | Lightweight, transparent, and versioned. |

> **Do not upload** Pro-only screenshots unless Pro UI exists in this build. Skip screenshot #5 from SCREENSHOT_PLAN (Profiles/Pro) for the Free listing.

### Privacy policy URL (Store listing)

Same URL as Properties section — must be publicly accessible HTTPS.

---

## 3. Submission options

**Path:** Submission → **Submission options**

### Publishing

| Field | Recommendation |
|-------|----------------|
| **Publish timing** | Publish automatically after certification (or manual if you prefer review first) |
| **Rollout** | 100% (single package) |

### Visibility

| Field | Value |
|-------|-------|
| **Discoverable in Store** | Yes |
| **Hide from search** | No |

### Notes for certification (paste in “Notes for certification” / “Testing instructions”)

**Paste:**

```
Internet Switcher is a desktop utility that enables/disables Windows network adapters (Wi-Fi and Ethernet).

TEST STEPS
1. Install the app from the submission package.
2. On first launch, if prompted, approve the one-time administrator setup for the scheduled task (required to change adapter state on Windows).
3. Confirm a system tray icon appears near the clock.
4. Open the main window — Ethernet and Wi-Fi adapters should be listed with status.
5. Click "Switch to Wi-Fi" — Ethernet should disable and Wi-Fi should enable (or vice versa depending on current state).
6. Click "Switch to Ethernet" — reverse the switch.
7. Use Enable/Disable on an individual adapter row to confirm per-adapter control.
8. Close the window — app should remain in the tray (not exit).
9. Uninstall via Settings → Apps — app should remove cleanly.

TECHNICAL NOTES
• Declares runFullTrust (restricted capability) because this is a Win32 desktop app using WMI/CIM and Windows Forms for adapter enumeration and system tray UI.
• Adapter changes are performed by a pre-registered scheduled task (installed with explicit user consent), not by elevating the main UI process.
• The app does NOT collect browsing history, Wi-Fi passwords, or network traffic.
• No bundled software, advertising, or unrelated system modifications.

TEST ACCOUNT
Not required — no sign-in, subscription, or server authentication in v1.0.0 Free edition.
```

### Declarations (check these as applicable)

- [ ] App does not contain adult content
- [ ] App complies with Microsoft Store policies
- [ ] You have rights to distribute all content in the app
- [ ] Privacy policy URL is provided and accurate
- [ ] `runFullTrust` usage is justified (desktop networking utility — see `docs/MICROSOFT_STORE_CAPABILITIES.md`)

Click **Save** on Submission options.

---

## 4. Final submission checklist

### Done by you already ✓

- [x] MSIX package uploaded and validated
- [x] Pricing configured
- [x] Age ratings completed
- [x] Package identity matches Partner Center (`ITDoctor360.InternetSwitcher`)

### You must complete manually

| Item | Action | Status |
|------|--------|--------|
| **Privacy policy URL** | Confirm `PRIVACY.md` is reachable at public HTTPS URL | ☐ |
| **Support URL** | Paste GitHub Issues URL (or your support page) | ☐ |
| **Properties** | Category, OS, hardware, languages, privacy URL | ☐ |
| **Store listing text** | Short + full description, keywords, copyright, what's new | ☐ |
| **Screenshots** | Capture 4–5 images per `store-assets/SCREENSHOT_PLAN.md` and upload | ☐ |
| **Store logo** | Upload 300×300 PNG | ☐ |
| **Submission options** | Certification notes + publish timing | ☐ |
| **Submit for certification** | Review all sections green → **Submit to the Store** | ☐ |

### Optional improvements (not blocking)

| Item | Notes |
|------|-------|
| **Website** | GitHub repo URL or future landing page |
| **Promotional images** | Hero banner for Store discovery |
| **Localized listings** | Add Bengali/other languages later |

---

## 5. Quick navigation map

```
Partner Center
└── Internet Switcher (9N5BNRI19F9K5)
    └── Submissions → [current draft]
        ├── Packages ..................... ✓ Done
        ├── Pricing ...................... ✓ Done
        ├── Age ratings .................. ✓ Done
        ├── Properties ................... ← Section 1 above
        ├── Store listings (English) ..... ← Section 2 above
        └── Submission options ........... ← Section 3 above
```

After all sections show complete, click **Submit to the Store**. Certification typically takes 1–3 business days.

---

## Reference files in this repo

| File | Purpose |
|------|---------|
| `store-assets/store-listing.md` | Source copy for descriptions |
| `store-assets/SCREENSHOT_PLAN.md` | Screenshot capture guide |
| `PRIVACY.md` | Privacy policy (host publicly) |
| `docs/MICROSOFT_STORE.md` | Identity & build info |
| `docs/MICROSOFT_STORE_CAPABILITIES.md` | `runFullTrust` justification |
