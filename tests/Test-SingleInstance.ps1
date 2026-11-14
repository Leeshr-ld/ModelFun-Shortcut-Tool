$ErrorActionPreference = 'Stop'

$singleInstancePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'SingleInstance.ps1'
. $singleInstancePath

$name = 'RoadLevelHotkeys.Test.' + [Guid]::NewGuid().ToString('N')
$first = $null
$second = $null
try {
    $first = New-SingleInstanceGuard -Name $name
    $second = New-SingleInstanceGuard -Name $name

    if (-not $first.Created) {
        throw 'First instance was not reported as created'
    }
    if ($second.Created) {
        throw 'Second instance was incorrectly reported as created'
    }

    Write-Output 'PASS named mutex detects duplicate application instances'
}
finally {
    if ($null -ne $second) {
        Close-SingleInstanceGuard -Guard $second
    }
    if ($null -ne $first) {
        Close-SingleInstanceGuard -Guard $first
    }
}
