# Store Assets

Assets required for Microsoft Partner Center submission.

## Required Assets

| Asset | Size | File (placeholder) |
|-------|------|-------------------|
| App icon | 256×256 | `assets/logo.png` |
| Store logo | 50×50 | `store-assets/store-logo-50.png` (generate from logo) |
| Square logo | 150×150 | `store-assets/square-150.png` |
| Screenshots | 1366×768 min | See `SCREENSHOT_PLAN.md` |
| Promotional hero (optional) | 1920×600 | `store-assets/hero-1920x600.png` |

## Source Artwork

Primary logo: `assets/logo.png`  
ICO for Windows: `assets/icon.ico`

## Generation

Run asset generation:

```powershell
.\scripts\New-EthernetToggleAssets.ps1
```

For Store-specific sizes, resize `assets/logo.png` to required dimensions before upload.

## Partner Center Upload Order

1. App icon + logos
2. Screenshots (4–6)
3. Store listing copy from `store-listing.md`
4. Privacy policy URL (host `PRIVACY.md`)
5. Support URL

See `docs/MICROSOFT_STORE.md` for Partner Center placeholders.
