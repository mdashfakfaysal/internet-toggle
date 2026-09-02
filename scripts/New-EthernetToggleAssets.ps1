#Requires -Version 5.1
# Generates Link Priority logo.png and icon.ico (BMP-based ICO for tray compatibility)

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

function New-LinkPriorityBitmap {
    param([int]$Size)

    $bitmap = New-Object System.Drawing.Bitmap $Size, $Size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::FromArgb(255, 30, 30, 30))

    $scale = $Size / 256.0
    $graphics.ScaleTransform($scale, $scale)

    $wifiPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 70, 160, 67)), 8
    $wifiPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $wifiPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawArc($wifiPen, 72, 64, 112, 112, 200, 140)
    $graphics.DrawArc($wifiPen, 88, 80, 80, 80, 200, 140)
    $graphics.DrawArc($wifiPen, 104, 96, 48, 48, 200, 140)
    $wifiPen.Dispose()

    $wifiDot = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 70, 160, 67))
    $graphics.FillEllipse($wifiDot, 120, 168, 16, 16)
    $wifiDot.Dispose()

    $portDark = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 45, 45, 45))
    $portAccent = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 70, 130, 220))
    $pinBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 180, 180, 180))
    $graphics.FillRectangle($portDark, 40, 168, 80, 56)
    $graphics.FillRectangle($portAccent, 48, 176, 64, 40)
    for ($i = 0; $i -lt 5; $i++) {
        $graphics.FillRectangle($pinBrush, 54 + ($i * 12), 184, 6, 18)
    }
    $portDark.Dispose()
    $portAccent.Dispose()
    $pinBrush.Dispose()

    $arrowPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 240, 192, 64)), 8
    $arrowPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $arrowPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawLine($arrowPen, 168, 88, 210, 88)
    $graphics.DrawLine($arrowPen, 200, 78, 210, 88)
    $graphics.DrawLine($arrowPen, 200, 98, 210, 88)
    $arrowPen.Dispose()

    $routeBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 240, 192, 64))
    $graphics.FillEllipse($routeBrush, 136, 74, 28, 28)
    $routeBrush.Dispose()

    $graphics.Dispose()
    return $bitmap
}

function Get-IconDibBytes {
    param([System.Drawing.Bitmap]$Bitmap)

    $memoryStream = New-Object System.IO.MemoryStream
    $Bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $bmpBytes = $memoryStream.ToArray()
    $memoryStream.Dispose()

    $dibBytes = New-Object byte[] ($bmpBytes.Length - 14)
    [Array]::Copy($bmpBytes, 14, $dibBytes, 0, $dibBytes.Length)
    return $dibBytes
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

        $dibBytes = Get-IconDibBytes -Bitmap $resized
        $resized.Dispose()
        $imageData.Add($dibBytes) | Out-Null

        $writer.Write([Byte]($size -band 0xFF))
        $writer.Write([Byte](($size -shr 8) -band 0xFF))
        $writer.Write([Byte]0)
        $writer.Write([Byte]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]32)
        $writer.Write([UInt32]$dibBytes.Length)
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

$logoBitmap = New-LinkPriorityBitmap -Size 256
$logoBitmap.Save($logoPath, [System.Drawing.Imaging.ImageFormat]::Png)
Save-IconFromBitmap -SourceBitmap $logoBitmap -DestinationPath $iconPath -Sizes @(16, 32, 48, 256)
$logoBitmap.Dispose()

Write-Host "Created $logoPath"
Write-Host "Created $iconPath"
