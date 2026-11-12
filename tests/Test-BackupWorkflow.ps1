$ErrorActionPreference = 'Stop'

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'BackupWorkflow.ps1'
if (-not (Test-Path -LiteralPath $modulePath)) {
    throw "缺少待测文件：$modulePath"
}
. $modulePath

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

Invoke-Test '备份窗口按钮坐标随窗口缩放' {
    $bounds = [pscustomobject]@{
        Left = 100
        Top = 200
        Right = 655
        Bottom = 703
    }
    $actual = Get-BackupDialogPoints -Bounds $bounds
    Assert-Equal 409 $actual.SelectAllX '全选X坐标错误'
    Assert-Equal 607 $actual.SelectAllY '全选Y坐标错误'
    Assert-Equal 149 $actual.BackupNowX '立即备份X坐标错误'
    Assert-Equal 340 $actual.BackupNowY '立即备份Y坐标错误'
}

Invoke-Test '备份流程按按钮全选立即备份顺序执行' {
    $script:steps = New-Object System.Collections.Generic.List[string]
    $dialog = [pscustomobject]@{ Left = 0; Top = 0; Right = 555; Bottom = 503 }
    Invoke-BackupWorkflowSteps `
        -ClickBackupButton { [void]$script:steps.Add('backup-button') } `
        -WaitForDialog { [void]$script:steps.Add('wait-dialog'); return $dialog } `
        -ClickSelectAll { param($bounds) [void]$script:steps.Add("select-all:$($bounds.Right)") } `
        -ClickBackupNow { param($bounds) [void]$script:steps.Add("backup-now:$($bounds.Bottom)") }
    Assert-Equal 'backup-button|wait-dialog|select-all:555|backup-now:503' ($script:steps -join '|') '备份流程顺序错误'
}

Write-Output "SUMMARY passed=$script:Passed failed=$script:Failed"
if ($script:Failed -gt 0) {
    exit 1
}
