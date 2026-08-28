# Release Process

## Versioning

Semantic versioning: `MAJOR.MINOR.PATCH` in `version.json`.

## Tag Release

```powershell
git add -A
git commit -m "Release v1.0.0"
git tag v1.0.0
git push origin main --tags
```

GitHub Actions (`.github/workflows/release.yml`) builds Free + Pro zips and publishes a GitHub Release.

## Manual Release

```powershell
.\scripts\Build-Release.ps1 -Version 1.0.0
```

Upload artifacts from `dist/free/` and `dist/pro/` to GitHub Releases.

## Artifacts

| Artifact | Description |
|----------|-------------|
| `internet-switcher-free-x64-{version}.zip` | Portable Free package |
| `internet-switcher-pro-x64-{version}.zip` | Portable Pro package |
| `*.sha256` | SHA-256 checksum sidecar |

## Signing (future)

Code signing is **not** implemented. Before commercial distribution:

1. Authenticode-sign `Internet Switcher Free.exe` and `Internet Switcher Pro.exe`
2. Sign installer EXE/MSI
3. Sign MSIX package for Store

See `docs/INSTALLER.md` for files requiring signatures.

## Secrets

Never commit:

- Authenticode certificates
- Store publisher credentials
- Lemon Squeezy API secrets
- Partner Center tokens
