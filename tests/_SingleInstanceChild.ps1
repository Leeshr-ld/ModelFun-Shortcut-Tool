param(
    [string]$Name,
    [string]$ReadyPath,
    [int]$HoldMilliseconds = 0
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'SingleInstance.ps1'
. $modulePath

$guard = $null
try {
    $guard = New-SingleInstanceGuard -Name $Name
    if (-not $guard.Created) {
        exit 2
    }
    Set-Content -LiteralPath $ReadyPath -Value 'ready' -Encoding UTF8
    if ($HoldMilliseconds -gt 0) {
        Start-Sleep -Milliseconds $HoldMilliseconds
    }
    exit 0
}
catch {
    exit 3
}
finally {
    if ($null -ne $guard) {
        Close-SingleInstanceGuard -Guard $guard
    }
}
