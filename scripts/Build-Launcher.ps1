#Requires -Version 5.1

param(
    [ValidateSet('Standard', 'Legacy', 'Free', 'Pro')]
    [string]$Edition = 'Standard'
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
    $versionInfo = [PSCustomObject]@{ version = '2.0.0' }
}

$cscPath = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$frameworkDir = Split-Path -Parent $cscPath

$excludeRelative = @(
    '\Pro\',
    '\UI\ProSettingsForm.cs',
    '\UI\ProfilesForm.cs',
    '\UI\HistoryForm.cs',
    '\UI\HotkeyCaptureForm.cs',
    '\UI\UpgradeDialog.cs'
)

$sourceFiles = Get-ChildItem -Path (Join-Path $repoRoot 'launcher') -Filter '*.cs' -Recurse |
    Where-Object {
        $full = $_.FullName
        $keep = $true
        foreach ($pattern in $excludeRelative) {
            if ($full -like "*$pattern*") {
                $keep = $false
                break
            }
        }
        $keep
    } |
    Sort-Object FullName |
    ForEach-Object { $_.FullName }

if (-not (Test-Path -LiteralPath $cscPath)) {
    throw "C# compiler not found: $cscPath"
}

$exeName = switch ($Edition) {
    'Pro' { 'Internet Switcher Pro' }
    'Free' { 'Internet Switcher Free' }
    'Legacy' { $config.exeName }
    default { 'Internet Switcher' }
}

$outputExe = Join-Path $repoRoot "$exeName.exe"
$tempExe = Join-Path $repoRoot "$exeName.build.tmp.exe"

$cscArgs = @(
    '/nologo'
    '/target:winexe'
    '/optimize+'
    '/define:TRACE'
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
        '/define:TRACE'
        "/win32icon:$($paths.IconPath)"
        "/out:$tempExe"
        "/reference:$frameworkDir\System.Management.dll"
        "/reference:$frameworkDir\System.Web.Extensions.dll"
        "/reference:$frameworkDir\System.Windows.Forms.dll"
        "/reference:$frameworkDir\System.Drawing.dll"
    ) + $sourceFiles
}

Write-Host "Building $exeName (v$($versionInfo.version)) -> $outputExe"
& $cscPath @cscArgs
if ($LASTEXITCODE -ne 0) {
    throw "C# compiler failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $tempExe)) {
    throw 'Failed to build launcher executable.'
}

@($exeName, 'Internet Switcher', 'Internet Switcher Free', 'Internet Switcher Pro', 'Internet Toggle') | ForEach-Object {
    Get-Process -Name $_ -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Stop-Process -Id $_.Id -Force -ErrorAction Stop
            Write-Host "Stopped running app: $_ ($($_.Id))"
        }
        catch {
            Write-Warning "Could not stop $_ (PID $($_.Id))."
        }
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

Write-Host "Built: $outputExe (v$($versionInfo.version))"

$aliases = @('Internet Toggle.exe', 'Internet Switcher Free.exe')
foreach ($aliasName in $aliases) {
    if ($aliasName -eq (Split-Path -Leaf $outputExe)) { continue }
    $aliasPath = Join-Path $repoRoot $aliasName
    try {
        Copy-Item -LiteralPath $outputExe -Destination $aliasPath -Force
        Write-Host "Updated alias: $aliasPath"
    }
    catch {
        Write-Warning "Could not update alias: $aliasPath"
    }
}
