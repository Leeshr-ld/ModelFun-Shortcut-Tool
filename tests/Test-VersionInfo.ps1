$ErrorActionPreference = 'Stop'

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'VersionInfo.ps1'
$dataPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'version.json'
if (-not (Test-Path -LiteralPath $modulePath)) {
    throw "缺少待测文件：$modulePath"
}
if (-not (Test-Path -LiteralPath $dataPath)) {
    throw "缺少版本数据：$dataPath"
}
. $modulePath

$script:Passed = 0
$script:Failed = 0

function Assert-Equal($Expected, $Actual, [string]$Message) {
    if ($Expected -ne $Actual) {
        throw "$Message；期望=[$Expected]，实际=[$Actual]"
    }
}

function Assert-Contains([string]$Text, [string]$Value, [string]$Message) {
    if (-not $Text.Contains($Value)) {
        throw "$Message；未找到=[$Value]"
    }
}

function Invoke-Test([string]$Name, [scriptblock]$Body) {
    try {
        & $Body
        $script:Passed++
        Write-Output "PASS $Name"
    }
    catch {
        $script:Failed++
        Write-Output "FAIL $Name"
        Write-Output "     $($_.Exception.Message)"
    }
}

Invoke-Test '当前版本作者和版本链正确' {
    $actual = Get-AppVersionInfo -Path $dataPath
    Assert-Equal 'V1.3.0' $actual.version '当前版本错误'
    Assert-Equal 'shijye' $actual.author '作者错误'
    Assert-Equal 'V1.3.0|V1.2.0|V1.1|V1.0|V0.0' (($actual.history | ForEach-Object version) -join '|') '版本历史顺序错误'
}

Invoke-Test '关于文本包含GPL-3.0开源许可' {
    $info = Get-AppVersionInfo -Path $dataPath
    $actual = Get-AboutText -Info $info
    Assert-Contains $actual 'shijye' '关于文本缺少作者'
    Assert-Contains $actual 'GPL-3.0' '关于文本缺少开源许可证'
    Assert-Contains $actual 'V1.3.0' '关于文本缺少当前版本'
    Assert-Contains $actual 'V0.0' '关于文本缺少原始版本'
    if ($actual.Contains('禁止商业化销售')) {
        throw '完全开源版本仍包含禁止商业化条款'
    }
}

Invoke-Test '关于文本支持英文版本历史' {
    $info = Get-AppVersionInfo -Path $dataPath
    $actual = Get-AboutText -Info $info -Language 'en-US'
    Assert-Contains $actual 'Author: shijye' '英文关于文本缺少作者'
    Assert-Contains $actual 'Version History' '英文关于文本缺少版本历史标题'
    Assert-Contains $actual 'Current version: V1.3.0' '英文关于文本缺少当前版本'
    if ($actual.Contains('版本历史')) {
        throw '英文关于文本仍包含中文版本历史标题'
    }
}

Write-Output "SUMMARY passed=$script:Passed failed=$script:Failed"
if ($script:Failed -gt 0) {
    exit 1
}
