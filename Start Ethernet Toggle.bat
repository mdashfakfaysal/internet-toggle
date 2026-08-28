@echo off
setlocal
cd /d "%~dp0"

if exist "%~dp0Ethernet Toggle.exe" (
    start "" "%~dp0Ethernet Toggle.exe"
    exit /b 0
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Launch-EthernetToggle.ps1"
