$ErrorActionPreference = 'Stop'

$appDirectory = Split-Path -Parent $PSScriptRoot
$powershell51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $powershell51)) {
    throw 'Windows PowerShell 5.1不存在'
}

$output = & $powershell51 -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '_DpiAwarenessChild.ps1') 2>&1
$exitCode = $LASTEXITCODE
Write-Output $output
if ($exitCode -ne 0) {
    exit $exitCode
}
if (($output -join "`n") -notmatch 'AWARENESS=2') {
    throw '进程未切换到PerMonitorV2 DPI感知'
}

Write-Output 'PASS Windows PowerShell 5.1 initializes PerMonitorV2 before creating windows'
