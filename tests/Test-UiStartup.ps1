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

foreach ($language in @('zh-CN', 'en-US')) {
    $screenshotPath = Join-Path $PSScriptRoot "ui-$language.png"
    if (Test-Path -LiteralPath $screenshotPath) {
        Remove-Item -LiteralPath $screenshotPath -Force
    }
    $output = & $powershell51 `
        -NoLogo `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $appScript `
        -UiSmokeTest `
        -UiSmokeLanguage $language `
        -UiSmokeScreenshotPath $screenshotPath 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $output | ForEach-Object { Write-Output $_ }
        throw "Windows PowerShell 5.1 UI启动测试失败：$language，退出码=$exitCode"
    }
    $expectedText = "PASS Windows PowerShell UI initialization ($language)"
    if (($output -join "`n") -notmatch [regex]::Escape($expectedText)) {
        $output | ForEach-Object { Write-Output $_ }
        throw "UI启动测试未返回PASS：$language"
    }
    if (-not (Test-Path -LiteralPath $screenshotPath -PathType Leaf)) {
        throw "UI启动测试未生成截图：$language"
    }
    if ((Get-Item -LiteralPath $screenshotPath).Length -lt 1000) {
        throw "UI截图内容异常：$language"
    }
}

Write-Output 'PASS Windows PowerShell 5.1 initializes the main window in Chinese and English'
