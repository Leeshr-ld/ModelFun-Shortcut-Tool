$ErrorActionPreference = 'Stop'

$appDirectory = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('RoadLevelStartupFailure_' + [guid]::NewGuid().ToString('N'))
$powerShell51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$runtimeFiles = @(
    'RoadLevelHotkeys.ps1',
    'DpiSupport.ps1',
    'Localization.ps1',
    'ConfigStorage.ps1',
    'SingleInstance.ps1',
    'ShortcutRules.ps1',
    'MouseAutomation.ps1',
    'BackupWorkflow.ps1',
    'VersionInfo.ps1',
    'LayoutPolicy.ps1',
    'model_shortcuts.json',
    'version.json'
)

try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    foreach ($fileName in $runtimeFiles) {
        Copy-Item -LiteralPath (Join-Path $appDirectory $fileName) -Destination (Join-Path $testRoot $fileName)
    }
    New-Item -ItemType Directory -Path (Join-Path $testRoot 'config-backups') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $testRoot 'config.json') -Value '{damaged-config' -Encoding UTF8

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $powerShell51 `
            -NoLogo `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File (Join-Path $testRoot 'RoadLevelHotkeys.ps1') `
            -UiSmokeTest `
            -UiSmokeLanguage 'en-US' 2>&1
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 1) {
        throw "Damaged startup returned $exitCode, expected 1"
    }
    if (($output -join "`n") -notmatch 'No valid configuration backup') {
        throw "Startup failure did not use the English recovery error: $($output -join ' ')"
    }

    Write-Output 'PASS startup failure returns a localized non-blocking error'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
