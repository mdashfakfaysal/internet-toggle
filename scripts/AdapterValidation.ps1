# Adapter validation helpers used by tests and elevated script

function Test-ValidAdapterName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }

    if ($Name.Length -gt 128) {
        return $false
    }

    return $Name -match '^[A-Za-z0-9 \-_\(\)\[\]\.#]+$'
}

function Assert-ValidAdapterName {
    param([string]$Name)

    if (-not (Test-ValidAdapterName -Name $Name)) {
        throw "Invalid adapter name: $Name"
    }
}
