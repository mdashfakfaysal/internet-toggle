#Requires -Version 5.1

# Backward-compatible wrapper for older scheduled tasks.
& (Join-Path $PSScriptRoot 'Toggle-NetworkAdapter.ps1') @args
