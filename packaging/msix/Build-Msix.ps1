#Requires -Version 5.1

<#
.SYNOPSIS
    Builds a Release MSIX package for Internet Switcher Free (Microsoft Store).

.DESCRIPTION
    Stages the MSIX layout, generates Store assets, and packs with makeappx.exe.
    Requires Windows 10 SDK (makeappx.exe). Output is UNSIGNED unless -CertificatePath is provided.

.PARAMETER Version
    Four-part package version (default from version.json, e.g. 1.0.0.0)

.PARAMETER CertificatePath
    Optional PFX for signtool signing (Store submission requires Partner Center signing)
#>

param(
    [string]$Version = '',
    [string]$CertificatePath = '',
    [string]$CertificatePassword = '',
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$msixRoot = Join-Path $repoRoot 'packaging\msix'
$distDir = Join-Path $repoRoot 'dist\store'
$stagingDir = Join-Path $distDir 'layout'
$versionFile = Join-Path $repoRoot 'version.json'

if (-not $Version) {
    if (Test-Path $versionFile) {
        $Version = (Get-Content $versionFile -Raw | ConvertFrom-Json).fileVersion
    }
    else {
        $Version = '1.0.0.0'
    }
}

function Find-MakeAppx {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\makeappx.exe",
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x86\makeappx.exe",
        "${env:ProgramFiles(x86)}\Windows Kits\8.1\bin\x64\makeappx.exe"
    )
    foreach ($pattern in $candidates) {
        $found = Get-Item $pattern -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

function Find-SignTool {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe",
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x86\signtool.exe"
    )
    foreach ($pattern in $candidates) {
        $found = Get-Item $pattern -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

function Update-ManifestVersion {
    param([string]$ManifestPath, [string]$PackageVersion)

    $content = Get-Content -LiteralPath $ManifestPath -Raw
    $content = [regex]::Replace(
        $content,
        '(<Identity[^>]*\sVersion=")[^"]+(")',
        "`${1}$PackageVersion`${2}",
        1
    )
    Set-Content -LiteralPath $ManifestPath -Value $content -Encoding UTF8 -NoNewline
}

Write-Host "Building Internet Switcher Free MSIX (v$Version)..." -ForegroundColor Cyan

# Build Free exe (skip if already built and -SkipBuild)
$freeExe = Join-Path $repoRoot 'Internet Switcher Free.exe'
if ($SkipBuild -and (Test-Path $freeExe)) {
    Write-Host "Skipping exe rebuild (using existing $freeExe)"
}
else {
    & (Join-Path $repoRoot 'scripts\Build-Launcher.ps1') -Edition Free
}

# Generate MSIX visual assets
& (Join-Path $msixRoot 'New-MsixAssets.ps1')

# Clean staging
if (Test-Path $stagingDir) {
    Remove-Item $stagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
New-Item -ItemType Directory -Path $distDir -Force | Out-Null

# Copy manifest (update version)
$manifestSource = Join-Path $msixRoot 'AppxManifest.xml'
$manifestDest = Join-Path $stagingDir 'AppxManifest.xml'
Copy-Item $manifestSource $manifestDest -Force
Update-ManifestVersion -ManifestPath $manifestDest -PackageVersion $Version

# Copy application files
$filesToCopy = @(
    @{ Source = 'Internet Switcher Free.exe'; Dest = 'Internet Switcher Free.exe' }
    @{ Source = 'config.json'; Dest = 'config.json' }
    @{ Source = 'version.json'; Dest = 'version.json' }
)

foreach ($item in $filesToCopy) {
    $src = Join-Path $repoRoot $item.Source
    if (-not (Test-Path $src)) {
        throw "Missing required file: $($item.Source)"
    }
    Copy-Item $src (Join-Path $stagingDir $item.Dest) -Force
}

# App runtime assets (lowercase path in package: assets\)
$appAssetsStaging = Join-Path $stagingDir 'app-assets'
Copy-Item (Join-Path $repoRoot 'assets') $appAssetsStaging -Recurse -Force

# MSIX visual assets (manifest expects capitalized Assets\)
$msixAssetsStaging = Join-Path $stagingDir 'msix-assets'
Copy-Item (Join-Path $msixRoot 'Assets') $msixAssetsStaging -Recurse -Force

# Scripts needed for elevated adapter operations (install registers scheduled task)
Copy-Item (Join-Path $repoRoot 'scripts') (Join-Path $stagingDir 'scripts') -Recurse -Force

function New-MsixMappingFile {
    param(
        [string]$ManifestPath,
        [string]$StagingRoot,
        [string]$MappingPath
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('[Files]')
    $lines.Add('"' + $ManifestPath + '" "AppxManifest.xml"')

    $packageEntries = @(
        @{ Source = (Join-Path $StagingRoot 'Internet Switcher Free.exe'); Package = 'Internet Switcher Free.exe' }
        @{ Source = (Join-Path $StagingRoot 'config.json'); Package = 'config.json' }
        @{ Source = (Join-Path $StagingRoot 'version.json'); Package = 'version.json' }
    )

    foreach ($file in Get-ChildItem -Path (Join-Path $StagingRoot 'app-assets') -Recurse -File) {
        $relative = $file.FullName.Substring((Join-Path $StagingRoot 'app-assets').Length + 1)
        $packageEntries += @{
            Source = $file.FullName
            Package = "assets\$relative"
        }
    }

    foreach ($file in Get-ChildItem -Path (Join-Path $StagingRoot 'msix-assets') -Recurse -File) {
        $relative = $file.FullName.Substring((Join-Path $StagingRoot 'msix-assets').Length + 1)
        $packageEntries += @{
            Source = $file.FullName
            Package = "Assets\$relative"
        }
    }

    foreach ($file in Get-ChildItem -Path (Join-Path $StagingRoot 'scripts') -Recurse -File) {
        $relative = $file.FullName.Substring((Join-Path $StagingRoot 'scripts').Length + 1)
        $packageEntries += @{
            Source = $file.FullName
            Package = "scripts\$relative"
        }
    }

    foreach ($entry in $packageEntries) {
        $lines.Add('"' + $entry.Source + '" "' + ($entry.Package -replace '/', '\') + '"')
    }

    [System.IO.File]::WriteAllLines($MappingPath, $lines, [System.Text.UTF8Encoding]::new($false))
}

# Validate manifest identity
$manifestXml = [xml](Get-Content $manifestDest -Raw)
$identity = $manifestXml.Package.Identity
Write-Host "Manifest Identity:"
Write-Host "  Name: $($identity.Name)"
Write-Host "  Publisher: $($identity.Publisher)"
Write-Host "  Version: $($identity.Version)"
Write-Host "  Architecture: $($identity.ProcessorArchitecture)"

$expectedName = 'ITDoctor360.InternetSwitcher'
$expectedPublisher = 'CN=A6C6CB6A-0869-4AEA-B7A2-1C3DE44E3CCD'
if ($identity.Name -ne $expectedName) { throw "Identity Name mismatch: $($identity.Name)" }
if ($identity.Publisher -ne $expectedPublisher) { throw "Publisher mismatch: $($identity.Publisher)" }

$makeAppx = Find-MakeAppx
if (-not $makeAppx) {
    throw @"
makeappx.exe not found. Install Windows 10 SDK:
  winget install Microsoft.WindowsSDK.10.0.18362
Then re-run: .\packaging\msix\Build-Msix.ps1
"@
}

$outputBase = "InternetSwitcher-Free-Store-x64-$($Version -replace '\.','-')"
$msixPath = Join-Path $distDir "$outputBase.msix"
$msixUploadPath = Join-Path $distDir "$outputBase.msixupload"
$mappingPath = Join-Path $distDir 'packaging.map'

if (Test-Path $msixPath) { Remove-Item $msixPath -Force }

New-MsixMappingFile -ManifestPath $manifestDest -StagingRoot $stagingDir -MappingPath $mappingPath

Write-Host "Packing with: $makeAppx"
Write-Host "Mapping: $mappingPath"
& $makeAppx pack /f $mappingPath /p $msixPath /o
if ($LASTEXITCODE -ne 0) {
    throw "makeappx pack failed with exit code $LASTEXITCODE"
}

Write-Host "Created: $msixPath" -ForegroundColor Green
Write-Host "Size: $((Get-Item $msixPath).Length) bytes"

# Optional signing
if ($CertificatePath -and (Test-Path $CertificatePath)) {
    $signTool = Find-SignTool
    if (-not $signTool) { throw 'signtool.exe not found' }
    $signArgs = @('sign', '/fd', 'SHA256', '/f', $CertificatePath, '/p', $CertificatePassword, $msixPath)
    & $signTool @signArgs
    if ($LASTEXITCODE -ne 0) { throw 'signtool sign failed' }
    Write-Host "Signed MSIX with certificate" -ForegroundColor Green
}
else {
    Write-Warning 'Package is UNSIGNED. Microsoft Store upload requires Partner Center signing or a valid code signing certificate.'
}

# Create .msixupload (MSIX + metadata for Store submission tool)
# For Partner Center web upload, .msix alone is often sufficient; .msixupload wraps for Store CLI
Copy-Item $msixPath $msixUploadPath -Force
Write-Host "Store upload copy: $msixUploadPath"

# Validate by unpacking
$validateDir = Join-Path $distDir 'validate-unpack'
if (Test-Path $validateDir) { Remove-Item $validateDir -Recurse -Force }
& $makeAppx unpack /p $msixPath /d $validateDir /o
if ($LASTEXITCODE -eq 0) {
    Write-Host "Validation: unpack succeeded" -ForegroundColor Green
    $unpackedManifest = [xml](Get-Content (Join-Path $validateDir 'AppxManifest.xml') -Raw)
    Write-Host "  Unpacked Identity: $($unpackedManifest.Package.Identity.Name) @ $($unpackedManifest.Package.Identity.Version)"
}
else {
    Write-Warning "Validation: unpack failed"
}

# SHA256 checksum
$hash = Get-FileHash $msixPath -Algorithm SHA256
$checksumPath = "$msixPath.sha256"
Set-Content $checksumPath -Value ("{0}  {1}" -f $hash.Hash, (Split-Path -Leaf $msixPath)) -Encoding ASCII
Write-Host "SHA256: $($hash.Hash)"

Write-Host ""
Write-Host "Partner Center:" -ForegroundColor Cyan
Write-Host "  Store ID: 9N5BNRI19F9K5"
Write-Host "  PFN: ITDoctor360.InternetSwitcher_mc2sshwaxxrnm"
Write-Host "  URL: https://apps.microsoft.com/detail/9N5BNRI19F9K5"
