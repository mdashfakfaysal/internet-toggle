#Requires -Version 5.1

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)
$sourceLogo = Join-Path $repoRoot 'assets\logo.png'
$msixAssetsDir = Join-Path $scriptRoot 'Assets'

if (-not (Test-Path -LiteralPath $sourceLogo)) {
    & (Join-Path $repoRoot 'scripts\New-EthernetToggleAssets.ps1')
}

if (-not (Test-Path -LiteralPath $msixAssetsDir)) {
    New-Item -ItemType Directory -Path $msixAssetsDir -Force | Out-Null
}

function Save-LogoSize {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [int]$Size
    )

    $source = [System.Drawing.Image]::FromFile($SourcePath)
    try {
        $bitmap = New-Object System.Drawing.Bitmap $Size, $Size
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.Clear([System.Drawing.Color]::FromArgb(255, 30, 30, 30))
        $graphics.DrawImage($source, 0, 0, $Size, $Size)
        $graphics.Dispose()
        $bitmap.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
    }
    finally {
        $source.Dispose()
    }
}

Save-LogoSize -SourcePath $sourceLogo -DestinationPath (Join-Path $msixAssetsDir 'StoreLogo.png') -Size 50
Save-LogoSize -SourcePath $sourceLogo -DestinationPath (Join-Path $msixAssetsDir 'Square44x44Logo.png') -Size 44
Save-LogoSize -SourcePath $sourceLogo -DestinationPath (Join-Path $msixAssetsDir 'Square150x150Logo.png') -Size 150

function Save-WideLogo {
    param([string]$SourcePath, [string]$DestinationPath)
    $source = [System.Drawing.Image]::FromFile($SourcePath)
    try {
        $bitmap = New-Object System.Drawing.Bitmap 310, 150
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.Clear([System.Drawing.Color]::FromArgb(255, 30, 30, 30))
        $graphics.DrawImage($source, 80, 15, 150, 120)
        $graphics.Dispose()
        $bitmap.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
    }
    finally {
        $source.Dispose()
    }
}

Save-WideLogo -SourcePath $sourceLogo -DestinationPath (Join-Path $msixAssetsDir 'Wide310x150Logo.png')

Write-Host "Generated MSIX assets in $msixAssetsDir"
