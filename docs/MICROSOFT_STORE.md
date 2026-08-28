# Microsoft Store Guide

## Packaging Paths

| Path | Status | Notes |
|------|--------|-------|
| **MSIX (Path A)** | Template in `packaging/msix/` | Requires `runFullTrust` for adapter management |
| **Traditional EXE (Path B)** | Inno Setup skeleton | Primary GitHub distribution |

## Partner Center Checklist

Complete these manually in [Microsoft Partner Center](https://partner.microsoft.com/dashboard):

### Required Placeholders

| Field | Value |
|-------|-------|
| **Publisher Display Name** | `[TO BE PROVIDED]` |
| **Package Identity Name** | `[FROM PARTNER CENTER — e.g. MdAshfakFaysal.InternetSwitcherFree]` |
| **Publisher** | `[FROM PARTNER CENTER — CN=...]` |
| **Application Name (Free)** | Internet Switcher |
| **Application Name (Pro)** | Internet Switcher Pro |
| **Version** | 1.0.0 |
| **Architecture** | x64 |
| **Support URL** | `[TO BE PROVIDED]` |
| **Privacy URL** | `[TO BE PROVIDED — host PRIVACY.md]` |
| **Website** | `[TO BE PROVIDED]` |
| **GitHub** | https://github.com/mdashfakfaysal/internet-toggle |

### Before Final MSIX Generation

1. Create app in Partner Center (Free and/or Pro listings)
2. Copy **Package Identity Name** and **Publisher** into `packaging/msix/AppxManifest.xml`
3. Obtain code signing certificate for Store packaging
4. Replace placeholder icons in `packaging/msix/Assets/`
5. Build MSIX with Windows SDK `makeappx.exe` / Visual Studio packaging project

## Store Blockers

| Blocker | Mitigation |
|---------|------------|
| Elevation for adapter ops | Document in capabilities; use `runFullTrust` |
| Scheduled task at install | May require full-trust desktop bridge; document for reviewers |
| Publisher identity unknown | User must create Partner Center account |
| Code signing | Required before submission |
| Privacy URL | Must host `PRIVACY.md` publicly |

## Submission Steps (summary)

1. Build signed MSIX for Free edition
2. Upload to Partner Center → Packages
3. Complete Store listing (see `store-assets/store-listing.md`)
4. Upload screenshots per `store-assets/SCREENSHOT_PLAN.md`
5. Submit for certification

## Dual Product Strategy

- **Internet Switcher** (Free) — Microsoft Store free listing
- **Internet Switcher Pro** (Paid) — separate Store add-on or paid listing

See `docs/MICROSOFT_STORE_CAPABILITIES.md` for capability justifications.
