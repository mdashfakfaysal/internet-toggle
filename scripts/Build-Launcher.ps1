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
    "/out:$outputExe"
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
        "/out:$outputExe"
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

if (-not (Test-Path -LiteralPath $outputExe)) {
    throw "Failed to build launcher executable."
}

Write-Host "Built standalone app: $outputExe"
