# Microsoft Store Guide

## Partner Center Identity (Configured)

| Field | Value |
|-------|-------|
| **Reserved Store Name** | Internet Switcher |
| **Package Identity Name** | `ITDoctor360.InternetSwitcher` |
| **Publisher (CN)** | `CN=A6C6CB6A-0869-4AEA-B7A2-1C3DE44E3CCD` |
| **Publisher Display Name** | IT Doctor 360 |
| **Package Family Name (PFN)** | `ITDoctor360.InternetSwitcher_mc2sshwaxxrnm` |
| **Store ID** | `9N5BNRI19F9K5` |
| **Store URL** | https://apps.microsoft.com/detail/9N5BNRI19F9K5 |
| **MSA App Id** | `aa46d996-6194-4429-ba13-248d50b6604d` |
| **Application Name** | Internet Switcher |
| **Version** | 1.0.0.0 |
| **Architecture** | x64 |

These values are set in `packaging/msix/AppxManifest.xml`.

## Build Store MSIX Package

### Prerequisites

- Windows 10 SDK (`makeappx.exe`) — install via:
  ```powershell
  winget install Microsoft.WindowsSDK.10.0.18362
  ```
- Release Free build (`Internet Switcher Free.exe`)

### Build Command

```powershell
cd path\to\internet-toggle
.\packaging\msix\Build-Msix.ps1
```

Optional signing (for sideload testing, not Store submission):

```powershell
.\packaging\msix\Build-Msix.ps1 -CertificatePath "cert.pfx" -CertificatePassword "password"
```

### Output

```
dist/store/InternetSwitcher-Free-Store-x64-1-0-0-0.msix
dist/store/InternetSwitcher-Free-Store-x64-1-0-0-0.msixupload
dist/store/InternetSwitcher-Free-Store-x64-1-0-0-0.msix.sha256
```

**Note:** Store submission packages are signed by Partner Center when uploaded through the dashboard. Local builds are unsigned test artifacts unless you provide a certificate.

## Upload to Partner Center

1. Go to [Partner Center](https://partner.microsoft.com/dashboard) → **Internet Switcher** (9N5BNRI19F9K5)
2. Navigate to **Packages** → create or update submission
3. Upload `InternetSwitcher-Free-Store-x64-*.msix`
4. Partner Center re-signs with your Store identity certificate
5. Complete Store listing (see `store-assets/store-listing.md`)
6. Submit for certification

## Remaining Placeholders

| Field | Status |
|-------|--------|
| Support URL | `[TO BE PROVIDED]` |
| Privacy URL | `[TO BE PROVIDED — host PRIVACY.md]` |
| Website | `[TO BE PROVIDED]` |
| GitHub | https://github.com/mdashfakfaysal/internet-toggle |

## Store Blockers

| Blocker | Status |
|---------|--------|
| Partner Center identity | **Configured** |
| MSIX manifest | **Configured** |
| MSIX build script | **Ready** |
| Code signing (local) | Optional — Store re-signs on upload |
| Privacy URL hosted | **Pending** |
| Support URL | **Pending** |
| Screenshots | See `store-assets/SCREENSHOT_PLAN.md` |

## Dual Product Strategy

- **Internet Switcher** (Free) — Store ID 9N5BNRI19F9K5
- **Internet Switcher Pro** (Paid) — separate listing (future)

See `docs/MICROSOFT_STORE_CAPABILITIES.md` for capability justifications.
