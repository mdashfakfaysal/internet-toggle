; Internet Switcher — Inno Setup Script (skeleton)
; Requires Inno Setup 6+ — https://jrsoftware.org/isinfo.php
; DO NOT generate fake signatures. Sign output EXE before commercial release.

#define AppName "Internet Switcher"
#define AppVersion "1.0.0"
#define AppPublisher "[TO BE PROVIDED]"
#define AppURL "https://github.com/mdashfakfaysal/internet-toggle"
#define AppExeName "Internet Switcher Free.exe"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
DefaultDirName={autopf}\Internet Switcher
DefaultGroupName=Internet Switcher
OutputDir=..\..\dist\free
OutputBaseFilename=InternetSwitcher-Free-Setup-x64-{#AppVersion}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "..\..\Internet Switcher Free.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\config.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\version.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\assets\*"; DestDir: "{app}\assets"; Flags: ignoreversion recursesubdirs
Source: "..\..\scripts\*"; DestDir: "{app}\scripts"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\Internet Switcher"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\Internet Switcher"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\Install-EthernetToggle.ps1"""; StatusMsg: "Configuring network permissions..."; Flags: runhidden

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\Uninstall-EthernetToggle.ps1"""; Flags: runhidden

[Code]
function InitializeSetup(): Boolean;
begin
  Result := True;
end;
