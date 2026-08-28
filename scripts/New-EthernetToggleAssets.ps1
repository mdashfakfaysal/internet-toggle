#Requires -Version 5.1

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$assetsDir = Join-Path $repoRoot 'assets'
$logoPath = Join-Path $assetsDir 'logo.png'
$iconPath = Join-Path $assetsDir 'icon.ico'

if (-not (Test-Path -LiteralPath $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
}

function New-LogoBitmap {
    param([int]$Size)

    $bitmap = New-Object System.Drawing.Bitmap $Size, $Size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::FromArgb(255, 30, 30, 30))

    $accentBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 70, 130, 220))
    $portBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 46, 160, 67))
    $cableBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 180, 180, 180))
    $darkBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 45, 45, 45))

    $scale = $Size / 256.0
    $graphics.ScaleTransform($scale, $scale)

    # Ethernet port body
    $graphics.FillRectangle($darkBrush, 72, 96, 112, 64)
    $graphics.FillRectangle($accentBrush, 80, 104, 96, 48)

    # Port pins
    for ($i = 0; $i -lt 8; $i++) {
        $x = 92 + ($i * 10)
        $graphics.FillRectangle($cableBrush, $x, 112, 4, 24)
    }

    # Cable
    $graphics.FillRectangle($cableBrush, 184, 118, 48, 20)
    $graphics.FillEllipse($portBrush, 228, 114, 20, 28)

    $portBrush.Dispose()
    $cableBrush.Dispose()
    $accentBrush.Dispose()
    $darkBrush.Dispose()
    $graphics.Dispose()

    return $bitmap
}

function Save-IconFromBitmap {
    param(
        [System.Drawing.Bitmap]$SourceBitmap,
        [string]$DestinationPath,
        [int[]]$Sizes
    )

    $memoryStream = New-Object System.IO.MemoryStream
    $writer = New-Object System.IO.BinaryWriter($memoryStream)

    $writer.Write([UInt16]0)
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]$Sizes.Count)

    $imageData = New-Object System.Collections.Generic.List[byte[]]

    foreach ($size in $Sizes) {
        $resized = New-Object System.Drawing.Bitmap $size, $size
        $resGraphics = [System.Drawing.Graphics]::FromImage($resized)
        $resGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $resGraphics.DrawImage($SourceBitmap, 0, 0, $size, $size)
        $resGraphics.Dispose()

        $pngStream = New-Object System.IO.MemoryStream
        $resized.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
        $pngBytes = $pngStream.ToArray()
        $pngStream.Dispose()
        $resized.Dispose()

        $imageData.Add($pngBytes) | Out-Null

        $writer.Write([Byte]($size -band 0xFF))
        $writer.Write([Byte](($size -shr 8) -band 0xFF))
        $writer.Write([Byte]0)
        $writer.Write([Byte]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]32)
        $writer.Write([UInt32]$pngBytes.Length)
        $writer.Write([UInt32]0)
    }

    $offset = 6 + (16 * $Sizes.Count)
    for ($index = 0; $index -lt $Sizes.Count; $index++) {
        $memoryStream.Position = 6 + (16 * $index) + 12
        $writer.Write([UInt32]$offset)
        $offset += $imageData[$index].Length
    }

    foreach ($bytes in $imageData) {
        $writer.Write($bytes)
    }

    [System.IO.File]::WriteAllBytes($DestinationPath, $memoryStream.ToArray())
    $writer.Dispose()
    $memoryStream.Dispose()
}

$logoBitmap = New-LogoBitmap -Size 256
$logoBitmap.Save($logoPath, [System.Drawing.Imaging.ImageFormat]::Png)
Save-IconFromBitmap -SourceBitmap $logoBitmap -DestinationPath $iconPath -Sizes @(16, 32, 48, 256)
$logoBitmap.Dispose()

Write-Host "Created $logoPath"
Write-Host "Created $iconPath"
