$ErrorActionPreference = 'Stop'

$rulesPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'ShortcutRules.ps1'
. $rulesPath

$script:Passed = 0
$script:Failed = 0

function Assert-Equal($Expected, $Actual, [string]$Message) {
    if ($Expected -ne $Actual) {
        throw "$Message；期望=[$Expected]，实际=[$Actual]"
    }
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
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

function New-TestBinding([string]$Key) {
    return [pscustomobject]@{
        displayName = '测试'
        key = $Key
        ctrl = $true
        alt = $true
        shift = $false
        mouseButton = ''
    }
}

Invoke-Test 'V1.1共享绑定迁移为四个面板独立绑定' {
    $legacy = [pscustomobject]@{
        version = 3
        targetTitle = '模方ModelFun'
        bindings = [pscustomobject]@{
            backup = New-TestBinding 'Q'
            slot1 = New-TestBinding 'F9'
            undo = New-TestBinding 'U'
        }
    }

    $actual = ConvertTo-V4ShortcutConfig -Config $legacy
    Assert-Equal 5 $actual.version '迁移后版本错误'
    Assert-Equal 'zh-CN' $actual.language '迁移后默认语言错误'
    Assert-Equal 'Q' $actual.commonBindings.backup.key '通用备份未迁移'
    Assert-Equal 'F9' $actual.panelBindings.'道路置平'.slot1.key '道路置平未迁移'
    Assert-Equal 'F9' $actual.panelBindings.'表面置平'.slot1.key '表面置平未获得旧绑定'
    Assert-Equal 'U' $actual.panelBindings.'指定置平'.undo.key '指定置平撤销未迁移'
    Assert-True ($null -eq $actual.panelBindings.'道路置平'.slot2) '道路置平不应出现不存在的slot2'
}

Invoke-Test '修改一个面板不会影响其他面板' {
    $config = New-DefaultShortcutConfig -TargetTitle '模方ModelFun'
    $custom = New-TestBinding 'F9'
    Set-ActionBinding -Config $config -PanelTitle '道路置平' -ActionName 'slot1' -Binding $custom | Out-Null

    $actual = Get-ActionBinding -Config $config -PanelTitle '道路置平' -ActionName 'slot1'
    $surface = Get-ActionBinding -Config $config -PanelTitle '表面置平' -ActionName 'slot1'
    Assert-Equal 'F9' $actual.key '道路置平绑定未修改'
    Assert-Equal '1' $surface.key '表面置平被意外修改'
}

Invoke-Test '同一快捷键可在不同面板分别使用' {
    $config = New-DefaultShortcutConfig -TargetTitle '模方ModelFun'
    Set-ActionBinding -Config $config -PanelTitle '道路置平' -ActionName 'slot1' -Binding (New-TestBinding 'Q') | Out-Null
    Set-ActionBinding -Config $config -PanelTitle '表面置平' -ActionName 'slot1' -Binding (New-TestBinding 'Q') | Out-Null

    $scope = Get-ConflictScopeBindings -Config $config -PanelTitle '表面置平'
    $actual = Find-ShortcutConflict -ActionName 'slot1' -Candidate (New-TestBinding 'Q') -Bindings $scope -ModelConflicts @()
    Assert-True ($null -eq $actual) '不同面板使用同一快捷键不应冲突'
}

Invoke-Test '同一面板内部重复快捷键仍被阻止' {
    $config = New-DefaultShortcutConfig -TargetTitle '模方ModelFun'
    Set-ActionBinding -Config $config -PanelTitle '表面置平' -ActionName 'slot1' -Binding (New-TestBinding 'Q') | Out-Null
    Set-ActionBinding -Config $config -PanelTitle '表面置平' -ActionName 'slot2' -Binding (New-TestBinding 'Q') | Out-Null

    $scope = Get-ConflictScopeBindings -Config $config -PanelTitle '表面置平'
    $actual = Find-ShortcutConflict -ActionName 'slot1' -Candidate (New-TestBinding 'Q') -Bindings $scope -ModelConflicts @()
    Assert-Equal 'Internal' $actual.Kind '同一面板重复绑定未被识别'
}

Invoke-Test '面板按钮不能与全局备份快捷键冲突' {
    $config = New-DefaultShortcutConfig -TargetTitle '模方ModelFun'
    $backup = New-TestBinding 'B'
    Set-ActionBinding -Config $config -PanelTitle '' -ActionName 'backup' -Binding $backup | Out-Null

    $scope = Get-ConflictScopeBindings -Config $config -PanelTitle '补洞'
    $actual = Find-ShortcutConflict -ActionName 'slot1' -Candidate (New-TestBinding 'B') -Bindings $scope -ModelConflicts @()
    Assert-Equal 'Internal' $actual.Kind '面板按钮与全局备份冲突未被识别'
}

Invoke-Test '全局备份不能与任何面板按钮重复' {
    $config = New-DefaultShortcutConfig -TargetTitle '模方ModelFun'
    $candidate = New-TestBinding '1'
    $actual = Find-GlobalBackupConflict -Candidate $candidate -Config $config -ModelConflicts @()
    Assert-Equal 'Internal' $actual.Kind '全局备份未检查全部面板'
    Assert-True ($actual.Message.Contains('道路置平')) '冲突信息未指出面板名称'
}

Invoke-Test '默认配置使用V5并默认中文' {
    $config = New-DefaultShortcutConfig -TargetTitle '模方ModelFun'
    Assert-Equal 5 $config.version '默认配置版本错误'
    Assert-Equal 'zh-CN' $config.language '默认语言错误'
}

Invoke-Test 'V4配置迁移保留快捷键并增加语言字段' {
    $config = New-DefaultShortcutConfig -TargetTitle '模方ModelFun'
    $config.version = 4
    $config | Add-Member -NotePropertyName language -NotePropertyValue $null -Force
    $config.panelBindings.'道路置平'.slot1.key = 'F9'

    $actual = ConvertTo-V5ShortcutConfig -Config $config
    Assert-Equal 5 $actual.version '迁移后配置版本错误'
    Assert-Equal 'zh-CN' $actual.language '未获得默认语言'
    Assert-Equal 'F9' $actual.panelBindings.'道路置平'.slot1.key '迁移丢失快捷键'
}

Invoke-Test '语言设置可独立更新且不影响快捷键' {
    $config = New-DefaultShortcutConfig -TargetTitle '模方ModelFun'
    $config.panelBindings.'补洞'.cancel.key = 'F8'

    $actual = Set-ConfigLanguage -Config $config -Language 'en-US'
    Assert-Equal 'en-US' $actual.language '语言未更新'
    Assert-Equal 'F8' $actual.panelBindings.'补洞'.cancel.key '语言更新修改了快捷键'
}

Invoke-Test '配置校验拒绝非ModelFun目标窗口' {
    if (-not (Get-Command ConvertTo-ValidatedShortcutConfig -ErrorAction SilentlyContinue)) {
        throw '缺少ConvertTo-ValidatedShortcutConfig'
    }
    $config = New-DefaultShortcutConfig -TargetTitle 'Notepad'
    $failed = $false
    try {
        ConvertTo-ValidatedShortcutConfig -Config $config | Out-Null
    }
    catch {
        $failed = $true
    }
    Assert-True $failed '配置校验接受了非ModelFun目标窗口'
}

Invoke-Test '配置校验拒绝错误快捷键结构' {
    if (-not (Get-Command ConvertTo-ValidatedShortcutConfig -ErrorAction SilentlyContinue)) {
        throw '缺少ConvertTo-ValidatedShortcutConfig'
    }
    $config = New-DefaultShortcutConfig -TargetTitle '模方ModelFun'
    $config.commonBindings.backup = 'not-a-binding'
    $failed = $false
    try {
        ConvertTo-ValidatedShortcutConfig -Config $config | Out-Null
    }
    catch {
        $failed = $true
    }
    Assert-True $failed '配置校验接受了字符串形式的快捷键绑定'
}

Invoke-Test '新面板动作列表完整且无重复' {
    $facade = @(Get-PanelActionNames '立面修整')
    $deleteSmall = @(Get-PanelActionNames '删除小物件')
    Assert-Equal 28 $facade.Count '立面修整动作数量错误'
    Assert-Equal 6 $deleteSmall.Count '删除小物件动作数量错误'
    Assert-Equal $facade.Count (@($facade | Select-Object -Unique).Count) '立面修整动作有重复'
    Assert-True ($facade -contains 'next') '立面修整缺少下一个动作'
    Assert-True ($facade -contains 'toggle3') '立面修整缺少第三个融合选项'
    Assert-True ($deleteSmall -contains 'slot2') '删除小物件缺少显示所有碎片'
}

Invoke-Test '旧配置迁移会补齐新面板并保留原快捷键' {
    $config = New-DefaultShortcutConfig -TargetTitle '模方ModelFun'
    $config.panelBindings.PSObject.Properties.Remove('立面修整')
    $config.panelBindings.PSObject.Properties.Remove('删除小物件')
    $config.panelBindings.'道路置平'.slot1.key = 'F9'

    $actual = ConvertTo-V5ShortcutConfig -Config $config
    Assert-Equal 'F9' $actual.panelBindings.'道路置平'.slot1.key '迁移丢失原有快捷键'
    Assert-Equal '1' $actual.panelBindings.'立面修整'.slot1.key '立面修整未补齐默认绑定'
    Assert-Equal 'N' $actual.panelBindings.'立面修整'.next.key '立面修整未补齐下一个快捷键'
    Assert-Equal 'P' $actual.panelBindings.'立面修整'.toggle3.key '立面修整未补齐第三个选项'
    Assert-Equal '2' $actual.panelBindings.'删除小物件'.slot2.key '删除小物件未补齐默认绑定'
}

Write-Output "SUMMARY passed=$script:Passed failed=$script:Failed"
if ($script:Failed -gt 0) {
    exit 1
}
