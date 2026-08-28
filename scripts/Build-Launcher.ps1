#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
. (Join-Path $scriptRoot 'EthernetToggle.Common.ps1')

$paths = Get-EthernetTogglePaths -ScriptRoot $scriptRoot
$config = Get-EthernetToggleConfig -ConfigPath $paths.ConfigPath

$sourceFile = Join-Path $repoRoot 'launcher\EthernetToggleApp.cs'
$cscPath = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$outputExe = Join-Path $repoRoot "$($config.exeName).exe"
$tempExe = Join-Path $repoRoot "$($config.exeName).build.tmp.exe"
$frameworkDir = Split-Path -Parent $cscPath

$systemManagement = Join-Path $frameworkDir 'System.Management.dll'
$systemWebExtensions = Join-Path $frameworkDir 'System.Web.Extensions.dll'

if (-not (Test-Path -LiteralPath $sourceFile)) {
    throw "Missing launcher source: $sourceFile"
}

if (-not (Test-Path -LiteralPath $cscPath)) {
    throw "C# compiler not found: $cscPath"
}

$cscArgs = @(
    '/nologo'
    '/target:winexe'
    "/out:$tempExe"
    "/reference:$systemManagement"
    "/reference:$systemWebExtensions"
    "/reference:$frameworkDir\System.Windows.Forms.dll"
    "/reference:$frameworkDir\System.Drawing.dll"
    $sourceFile
)

if (Test-Path -LiteralPath $paths.IconPath) {
    $cscArgs = @(
        '/nologo'
        '/target:winexe'
        "/win32icon:$($paths.IconPath)"
        "/out:$tempExe"
        "/reference:$systemManagement"
        "/reference:$systemWebExtensions"
        "/reference:$frameworkDir\System.Windows.Forms.dll"
        "/reference:$frameworkDir\System.Drawing.dll"
        $sourceFile
    )
}

& $cscPath @cscArgs
if ($LASTEXITCODE -ne 0) {
    throw "C# compiler failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $tempExe)) {
    throw "Failed to build launcher executable."
}

Get-Process -Name $config.exeName -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        Stop-Process -Id $_.Id -Force -ErrorAction Stop
        Write-Host "Stopped running app: $($_.Id)"
    }
    catch {
        Write-Warning "Could not stop $($config.exeName) (PID $($_.Id)). Close it manually if the swap fails."
    }
}

Start-Sleep -Milliseconds 500

if (Test-Path -LiteralPath $outputExe) {
    Remove-Item -LiteralPath $outputExe -Force -ErrorAction SilentlyContinue
}

Move-Item -LiteralPath $tempExe -Destination $outputExe -Force

Write-Host "Built standalone app: $outputExe"
