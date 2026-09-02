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

function Move-ReplaceFile {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [int]$MaxAttempts = 8
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            if (Test-Path -LiteralPath $DestinationPath) {
                Remove-Item -LiteralPath $DestinationPath -Force -ErrorAction Stop
            }
            Move-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force -ErrorAction Stop
            return
        }
        catch {
            if ($attempt -eq $MaxAttempts) {
                throw
            }
            Start-Sleep -Milliseconds (200 * $attempt)
        }
    }
}

function New-LinkPriorityBitmap {
    param([int]$Size)

    $bitmap = $null
    $graphics = $null
    $wifiPen = $null
    $wifiDot = $null
    $portDark = $null
    $portAccent = $null
    $pinBrush = $null
    $arrowPen = $null
    $routeBrush = $null

    try {
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

        $wifiDot = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 70, 160, 67))
        $graphics.FillEllipse($wifiDot, 120, 168, 16, 16)

        $portDark = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 45, 45, 45))
        $portAccent = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 70, 130, 220))
        $pinBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 180, 180, 180))
        $graphics.FillRectangle($portDark, 40, 168, 80, 56)
        $graphics.FillRectangle($portAccent, 48, 176, 64, 40)
        for ($i = 0; $i -lt 5; $i++) {
            $graphics.FillRectangle($pinBrush, 54 + ($i * 12), 184, 6, 18)
        }

        $arrowPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 240, 192, 64)), 8
        $arrowPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $arrowPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $graphics.DrawLine($arrowPen, 168, 88, 210, 88)
        $graphics.DrawLine($arrowPen, 200, 78, 210, 88)
        $graphics.DrawLine($arrowPen, 200, 98, 210, 88)

        $routeBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 240, 192, 64))
        $graphics.FillEllipse($routeBrush, 136, 74, 28, 28)

        $clone = [System.Drawing.Bitmap]$bitmap.Clone()
        return $clone
    }
    finally {
        if ($routeBrush) { $routeBrush.Dispose() }
        if ($arrowPen) { $arrowPen.Dispose() }
        if ($pinBrush) { $pinBrush.Dispose() }
        if ($portAccent) { $portAccent.Dispose() }
        if ($portDark) { $portDark.Dispose() }
        if ($wifiDot) { $wifiDot.Dispose() }
        if ($wifiPen) { $wifiPen.Dispose() }
        if ($graphics) { $graphics.Dispose() }
        if ($bitmap) { $bitmap.Dispose() }
    }
}

function Get-IconDibBytes {
    param([System.Drawing.Bitmap]$Bitmap)

    $memoryStream = $null
    try {
        $memoryStream = New-Object System.IO.MemoryStream
        $Bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Bmp)
        $bmpBytes = $memoryStream.ToArray()
        $dibBytes = New-Object byte[] ($bmpBytes.Length - 14)
        [Array]::Copy($bmpBytes, 14, $dibBytes, 0, $dibBytes.Length)
        return $dibBytes
    }
    finally {
        if ($memoryStream) { $memoryStream.Dispose() }
    }
}

function Save-IconFromBitmap {
    param(
        [System.Drawing.Bitmap]$SourceBitmap,
        [string]$DestinationPath,
        [int[]]$Sizes
    )

    $memoryStream = $null
    $writer = $null
    $resizedList = New-Object System.Collections.Generic.List[System.Drawing.Bitmap]

    try {
        $memoryStream = New-Object System.IO.MemoryStream
        $writer = New-Object System.IO.BinaryWriter($memoryStream)

        $writer.Write([UInt16]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]$Sizes.Count)

        $imageData = New-Object System.Collections.Generic.List[byte[]]

        foreach ($size in $Sizes) {
            $resized = New-Object System.Drawing.Bitmap $size, $size
            $resGraphics = $null
            try {
                $resGraphics = [System.Drawing.Graphics]::FromImage($resized)
                $resGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $resGraphics.DrawImage($SourceBitmap, 0, 0, $size, $size)
            }
            finally {
                if ($resGraphics) { $resGraphics.Dispose() }
            }

            $resizedList.Add($resized) | Out-Null
            $imageData.Add((Get-IconDibBytes -Bitmap $resized)) | Out-Null

            $writer.Write([Byte]($size -band 0xFF))
            $writer.Write([Byte](($size -shr 8) -band 0xFF))
            $writer.Write([Byte]0)
            $writer.Write([Byte]0)
            $writer.Write([UInt16]1)
            $writer.Write([UInt16]32)
            $writer.Write([UInt32]$imageData[$imageData.Count - 1].Length)
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
    }
    finally {
        foreach ($resized in $resizedList) {
            if ($resized) { $resized.Dispose() }
        }
        if ($writer) { $writer.Dispose() }
        if ($memoryStream) { $memoryStream.Dispose() }
    }
}

$beforeLogoHash = if (Test-Path $logoPath) { (Get-FileHash $logoPath -Algorithm SHA256).Hash } else { $null }
$beforeIconHash = if (Test-Path $iconPath) { (Get-FileHash $iconPath -Algorithm SHA256).Hash } else { $null }

$tempLogo = Join-Path ([System.IO.Path]::GetTempPath()) ("linkpriority-logo-{0}.png" -f [Guid]::NewGuid().ToString('N'))
$tempIcon = Join-Path ([System.IO.Path]::GetTempPath()) ("linkpriority-icon-{0}.ico" -f [Guid]::NewGuid().ToString('N'))

$logoBitmap = $null
try {
    $logoBitmap = New-LinkPriorityBitmap -Size 256
    $logoBitmap.Save($tempLogo, [System.Drawing.Imaging.ImageFormat]::Png)
    Save-IconFromBitmap -SourceBitmap $logoBitmap -DestinationPath $tempIcon -Sizes @(16, 32, 48, 256)
}
finally {
    if ($logoBitmap) { $logoBitmap.Dispose() }
}

Move-ReplaceFile -SourcePath $tempLogo -DestinationPath $logoPath
Move-ReplaceFile -SourcePath $tempIcon -DestinationPath $iconPath

$afterLogoHash = (Get-FileHash $logoPath -Algorithm SHA256).Hash
$afterIconHash = (Get-FileHash $iconPath -Algorithm SHA256).Hash

Write-Host "Created $logoPath"
Write-Host "Created $iconPath"
Write-Host "logo.png SHA256 before: $beforeLogoHash"
Write-Host "logo.png SHA256 after:  $afterLogoHash"
Write-Host "icon.ico SHA256 before: $beforeIconHash"
Write-Host "icon.ico SHA256 after:  $afterIconHash"

if ($beforeLogoHash -and ($beforeLogoHash -eq $afterLogoHash)) {
    Write-Warning 'logo.png hash unchanged — verify artwork updated.'
}

$iconBytes = [System.IO.File]::ReadAllBytes($iconPath)
$pngMagic = [byte[]]@(0x89, 0x50, 0x4E, 0x47)
$containsPng = $false
for ($i = 0; $i -lt ($iconBytes.Length - 4); $i++) {
    if ($iconBytes[$i] -eq $pngMagic[0] -and $iconBytes[$i + 1] -eq $pngMagic[1] -and $iconBytes[$i + 2] -eq $pngMagic[2] -and $iconBytes[$i + 3] -eq $pngMagic[3]) {
        $containsPng = $true
        break
    }
}
if ($containsPng) {
    throw 'icon.ico appears to contain PNG-compressed frames — expected BMP-based ICO only.'
}

Write-Host 'icon.ico verified BMP-based (no embedded PNG frames).'
