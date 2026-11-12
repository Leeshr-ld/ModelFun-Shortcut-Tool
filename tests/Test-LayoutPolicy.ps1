$ErrorActionPreference = 'Stop'

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'LayoutPolicy.ps1'
if (-not (Test-Path -LiteralPath $modulePath)) {
    throw "缺少待测文件：$modulePath"
}
. $modulePath

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

foreach ($size in @(
    @{ Width = 760; Height = 500 },
    @{ Width = 860; Height = 580 }
)) {
    $metrics = Get-MainLayoutMetrics -ClientWidth $size.Width -ClientHeight $size.Height

    Assert-True ($metrics.TitleHeight -ge 38) '标题高度不足'
    Assert-True ($metrics.SummaryTop -ge $metrics.TitleTop + $metrics.TitleHeight + 8) '标题与摘要间距不足'
    Assert-True ($metrics.SummaryHeight -ge 44) '摘要行高不足以显示两行'
    Assert-True ($metrics.StatusTop -ge $metrics.SummaryTop + $metrics.SummaryHeight) '摘要与状态行重叠'
    Assert-True ($metrics.GridTop -ge $metrics.StatusTop + $metrics.StatusHeight) '状态行与表格重叠'
    Assert-True ($metrics.NoticeHeight -ge 24) '提示行高不足'
    Assert-True ($metrics.ButtonTop -ge $metrics.NoticeTop + $metrics.NoticeHeight) '提示行与按钮区重叠'
    Assert-True ($metrics.HintTop -ge $metrics.ButtonTop + $metrics.ButtonPanelHeight) '按钮区与底部提示重叠'
    Assert-True ($metrics.HintTop + $metrics.HintHeight -le $size.Height) '底部提示超出窗口'
    Assert-True ($metrics.GridHeight -ge 100) '表格高度过小'
}

Write-Output 'PASS main layout avoids overlap at minimum and default sizes'
