$ErrorActionPreference = 'Stop'

$appDirectory = Split-Path -Parent $PSScriptRoot
$appScript = Join-Path $appDirectory 'RoadLevelHotkeys.ps1'
$powershell51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

if (-not (Test-Path -LiteralPath $powershell51)) {
    throw 'Windows PowerShell 5.1不存在'
}
if (-not (Test-Path -LiteralPath $appScript)) {
    throw "缺少主程序：$appScript"
}

$output = & $powershell51 `
    -NoLogo `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File $appScript `
    -UiSmokeTest 2>&1
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    $output | ForEach-Object { Write-Output $_ }
    throw "Windows PowerShell 5.1 UI启动测试失败，退出码=$exitCode"
}
if (($output -join "`n") -notmatch 'PASS Windows PowerShell UI initialization') {
    $output | ForEach-Object { Write-Output $_ }
    throw 'UI启动测试未返回PASS'
}

Write-Output 'PASS Windows PowerShell 5.1 creates and initializes the main window'
