#Requires -Version 5.1

param(
    [string]$Version = '1.0.0'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$distRoot = Join-Path $repoRoot 'dist'
$versionFile = Join-Path $repoRoot 'version.json'

if (Test-Path -LiteralPath $versionFile) {
    $versionJson = Get-Content -LiteralPath $versionFile -Raw | ConvertFrom-Json
    $versionJson.version = $Version
    $versionJson.assemblyVersion = "$Version.0"
    $versionJson.fileVersion = "$Version.0"
    $versionJson | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $versionFile -Encoding UTF8
}

& (Join-Path $repoRoot 'scripts\Build-Launcher.ps1') -Edition Free
& (Join-Path $repoRoot 'scripts\Build-Launcher.ps1') -Edition Pro

function New-EditionPackage {
    param(
        [string]$Edition,
        [string]$ExeName
    )

    $stagingDir = Join-Path $distRoot "$Edition\internet-switcher-$Edition-x64-$Version"
    $zipPath = Join-Path $distRoot "$Edition\internet-switcher-$Edition-x64-$Version.zip"

    if (Test-Path -LiteralPath $stagingDir) {
        Remove-Item -LiteralPath $stagingDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

    $includePaths = @(
        'assets',
        'launcher',
        'scripts',
        'docs',
        'store-assets',
        'config.json',
        'version.json',
        'README.md',
        'CHANGELOG.md',
        'LICENSE',
        'PRIVACY.md',
        'THIRD_PARTY_NOTICES.md',
        "$ExeName.exe",
        'Start Internet Toggle.bat'
    )

    foreach ($relativePath in $includePaths) {
        $sourcePath = Join-Path $repoRoot $relativePath
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            continue
        }

        $destinationPath = Join-Path $stagingDir $relativePath
        $destinationParent = Split-Path -Parent $destinationPath
        if (-not (Test-Path -LiteralPath $destinationParent)) {
            New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
        }

        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Recurse -Force
    }

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Compress-Archive -Path (Join-Path $stagingDir '*') -DestinationPath $zipPath -Force
    Remove-Item -LiteralPath $stagingDir -Recurse -Force

    $hash = Get-FileHash -LiteralPath $zipPath -Algorithm SHA256
    $checksumPath = "$zipPath.sha256"
    Set-Content -LiteralPath $checksumPath -Value ("{0}  {1}" -f $hash.Hash, (Split-Path -Leaf $zipPath)) -Encoding ASCII

    Write-Host "Created $zipPath"
    Write-Host "SHA256: $($hash.Hash)"
}

New-EditionPackage -Edition 'free' -ExeName 'Internet Switcher Free'
New-EditionPackage -Edition 'pro' -ExeName 'Internet Switcher Pro'

Write-Host "Release packages written to $distRoot"
