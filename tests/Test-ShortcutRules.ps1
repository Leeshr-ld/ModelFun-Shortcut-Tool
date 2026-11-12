$ErrorActionPreference = 'Stop'

$rulesPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'ShortcutRules.ps1'
if (-not (Test-Path -LiteralPath $rulesPath)) {
    throw "缺少待测文件：$rulesPath"
}
. $rulesPath

$script:Passed = 0
$script:Failed = 0

function Assert-Equal($Expected, $Actual, [string]$Message) {
    if ($Expected -ne $Actual) {
        throw "$Message；期望=[$Expected]，实际=[$Actual]"
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

function New-TestBinding([string]$Key, [bool]$Ctrl = $true, [bool]$Alt = $true, [string]$Mouse = '') {
    return [pscustomobject]@{
        displayName = '测试'
        key = $Key
        ctrl = $Ctrl
        alt = $Alt
        shift = $false
        mouseButton = $Mouse
    }
}

Invoke-Test '数字键规范化为D1' {
    $actual = Get-ShortcutSignature (New-TestBinding '1')
    Assert-Equal 'Ctrl+Alt+D1' $actual '数字1签名错误'
}

Invoke-Test 'Backspace规范化为Back' {
    $actual = Get-ShortcutSignature (New-TestBinding 'Backspace')
    Assert-Equal 'Ctrl+Alt+Back' $actual '退格键签名错误'
}

Invoke-Test '检测模方原版快捷键冲突' {
    $candidate = New-TestBinding '1'
    $conflicts = @(
        [pscustomobject]@{
            signature = 'Ctrl+Alt+D1'
            action = '导出OSGB/OBJ'
        }
    )
    $actual = Find-ShortcutConflict -ActionName 'slot1' -Candidate $candidate -Bindings ([pscustomobject]@{}) -ModelConflicts $conflicts
    Assert-Equal 'Model' $actual.Kind '未识别为模方原版冲突'
    Assert-Equal '导出OSGB/OBJ' $actual.ActionName '原版功能名称错误'
}

Invoke-Test '检测助手内部重复绑定' {
    $candidate = New-TestBinding 'Z'
    $bindings = [pscustomobject]@{
        undo = New-TestBinding 'Z'
    }
    $actual = Find-ShortcutConflict -ActionName 'slot1' -Candidate $candidate -Bindings $bindings -ModelConflicts @()
    Assert-Equal 'Internal' $actual.Kind '未识别为内部重复'
    Assert-Equal 'undo' $actual.ActionName '重复动作名称错误'
}

Invoke-Test '恢复默认保留目标标题并替换全部绑定' {
    $changed = [pscustomobject]@{
        version = 2
        targetTitle = '测试模方'
        bindings = [pscustomobject]@{
            slot1 = New-TestBinding 'F9'
        }
    }
    $actual = Reset-ShortcutBindings -Config $changed
    Assert-Equal '测试模方' $actual.targetTitle '重置后目标标题未保留'
    Assert-Equal '1' $actual.bindings.slot1.key 'slot1未恢复默认'
    Assert-Equal 'Z' $actual.bindings.undo.key '撤销未恢复默认'
    Assert-Equal 'XButton1' $actual.bindings.undo.mouseButton '撤销鼠标键未恢复默认'
    Assert-Equal 15 @($actual.bindings.PSObject.Properties).Count '默认绑定数量错误'
}

Invoke-Test '同时返回键盘和鼠标冲突不发生动态绑定异常' {
    $bindings = Get-DefaultBindings
    $candidate = New-TestBinding 'Z' $true $true 'XButton1'
    $actual = @(Get-BindingConflictList -ActionName 'slot1' -Binding $candidate -Bindings $bindings -ModelConflicts @())
    Assert-Equal 2 $actual.Count '应返回键盘和鼠标两个重复冲突'
}

Invoke-Test '默认设置包含通用备份快捷键' {
    $actual = Get-DefaultBindings
    Assert-Equal 'B' $actual.backup.key '备份快捷键未恢复默认'
    Assert-Equal '备份当前工程瓦片' $actual.backup.displayName '备份动作名称错误'
}

Write-Output "SUMMARY passed=$script:Passed failed=$script:Failed"
if ($script:Failed -gt 0) {
    exit 1
}
