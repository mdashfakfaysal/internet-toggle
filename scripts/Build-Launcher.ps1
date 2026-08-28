#Requires -Version 5.1

param(
    [ValidateSet('Free', 'Pro', 'Legacy')]
    [string]$Edition = 'Free'
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
. (Join-Path $scriptRoot 'EthernetToggle.Common.ps1')

$paths = Get-EthernetTogglePaths -ScriptRoot $scriptRoot
$config = Get-EthernetToggleConfig -ConfigPath $paths.ConfigPath
$versionPath = Join-Path $repoRoot 'version.json'

if (Test-Path -LiteralPath $versionPath) {
    $versionInfo = Get-Content -LiteralPath $versionPath -Raw | ConvertFrom-Json
}
else {
    $versionInfo = [PSCustomObject]@{ version = '1.0.0' }
}

$cscPath = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$frameworkDir = Split-Path -Parent $cscPath
$sourceFiles = Get-ChildItem -Path (Join-Path $repoRoot 'launcher') -Filter '*.cs' -Recurse | Sort-Object FullName | ForEach-Object { $_.FullName }

if (-not (Test-Path -LiteralPath $cscPath)) {
    throw "C# compiler not found: $cscPath"
}

$exeName = switch ($Edition) {
    'Pro' { 'Internet Switcher Pro' }
    'Legacy' { $config.exeName }
    default { 'Internet Switcher Free' }
}

$outputExe = Join-Path $repoRoot "$exeName.exe"
$tempExe = Join-Path $repoRoot "$exeName.build.tmp.exe"

$defines = @('/define:TRACE')
switch ($Edition) {
    'Pro' { $defines += '/define:INTERNET_SWITCHER_PRO' }
    default { $defines += '/define:INTERNET_SWITCHER_FREE' }
}

$cscArgs = @(
    '/nologo'
    '/target:winexe'
    '/optimize+'
    $defines
    "/out:$tempExe"
    "/reference:$frameworkDir\System.Management.dll"
    "/reference:$frameworkDir\System.Web.Extensions.dll"
    "/reference:$frameworkDir\System.Windows.Forms.dll"
    "/reference:$frameworkDir\System.Drawing.dll"
) + $sourceFiles

if (Test-Path -LiteralPath $paths.IconPath) {
    $cscArgs = @(
        '/nologo'
        '/target:winexe'
        '/optimize+'
        $defines
        "/win32icon:$($paths.IconPath)"
        "/out:$tempExe"
        "/reference:$frameworkDir\System.Management.dll"
        "/reference:$frameworkDir\System.Web.Extensions.dll"
        "/reference:$frameworkDir\System.Windows.Forms.dll"
        "/reference:$frameworkDir\System.Drawing.dll"
    ) + $sourceFiles
}

Write-Host "Building $Edition edition -> $outputExe"
& $cscPath @cscArgs
if ($LASTEXITCODE -ne 0) {
    throw "C# compiler failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $tempExe)) {
    throw 'Failed to build launcher executable.'
}

Get-Process -Name $exeName -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        Stop-Process -Id $_.Id -Force -ErrorAction Stop
        Write-Host "Stopped running app: $($_.Id)"
    }
    catch {
        Write-Warning "Could not stop $exeName (PID $($_.Id))."
    }
}

Start-Sleep -Milliseconds 300

if (Test-Path -LiteralPath $outputExe) {
    Remove-Item -LiteralPath $outputExe -Force -ErrorAction SilentlyContinue
}

if (Test-Path -LiteralPath $outputExe) {
    try {
        Copy-Item -LiteralPath $tempExe -Destination $outputExe -Force
        Remove-Item -LiteralPath $tempExe -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Could not replace locked output: $outputExe"
        Write-Host "Fresh build available at: $tempExe" -ForegroundColor Yellow
    }
}
else {
    Move-Item -LiteralPath $tempExe -Destination $outputExe -Force
}
Write-Host "Built $Edition edition: $outputExe (v$($versionInfo.version))"

if ($Edition -eq 'Free') {
    $legacyExe = Join-Path $repoRoot 'Internet Toggle.exe'
    if ($legacyExe -ne $outputExe) {
        try {
            Copy-Item -LiteralPath $outputExe -Destination $legacyExe -Force
            Write-Host "Updated legacy alias: $legacyExe"
        }
        catch {
            Write-Warning "Could not update legacy alias (file may be in use): $legacyExe"
        }
    }
}
