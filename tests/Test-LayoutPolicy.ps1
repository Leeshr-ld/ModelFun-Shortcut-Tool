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

function Assert-Equal($Expected, $Actual, [string]$Message) {
    if ($Expected -ne $Actual) {
        throw "$Message；期望=[$Expected]，实际=[$Actual]"
    }
}

foreach ($size in @(
    @{ Width = 760; Height = 500 },
    @{ Width = 860; Height = 580 },
    @{ Width = 960; Height = 500 },
    @{ Width = 1280; Height = 720 },
    @{ Width = 1536; Height = 864 },
    @{ Width = 1920; Height = 1080 }
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
    Assert-True ($metrics.LanguageSelectorWidth -ge 120) '语言选择框宽度不足'
    Assert-True ($metrics.LanguageSelectorTop -ge $metrics.TitleTop) '语言选择框位置过高'
    Assert-True ($metrics.LanguageSelectorTop + $metrics.LanguageSelectorHeight -le $metrics.SummaryTop) '语言选择框挤压摘要区'
    Assert-True ($metrics.LanguageSelectorLeft + $metrics.LanguageSelectorWidth -le 20 + $metrics.ContentWidth) '语言选择框超出内容区'
    Assert-True ($metrics.TitleWidth -ge 320) '标题可用宽度不足'
}

$dipCases = @(
    @{ PixelWidth = 1280; PixelHeight = 720; Scale = 1.0; DipWidth = 1280; DipHeight = 720 },
    @{ PixelWidth = 1920; PixelHeight = 1080; Scale = 1.0; DipWidth = 1920; DipHeight = 1080 },
    @{ PixelWidth = 1920; PixelHeight = 1080; Scale = 1.25; DipWidth = 1536; DipHeight = 864 },
    @{ PixelWidth = 1920; PixelHeight = 1080; Scale = 1.5; DipWidth = 1280; DipHeight = 720 },
    @{ PixelWidth = 1920; PixelHeight = 1080; Scale = 2.0; DipWidth = 960; DipHeight = 540 },
    @{ PixelWidth = 2560; PixelHeight = 1440; Scale = 1.25; DipWidth = 2048; DipHeight = 1152 },
    @{ PixelWidth = 2560; PixelHeight = 1440; Scale = 1.75; DipWidth = 1463; DipHeight = 823 },
    @{ PixelWidth = 2560; PixelHeight = 1080; Scale = 1.5; DipWidth = 1707; DipHeight = 720 },
    @{ PixelWidth = 3840; PixelHeight = 1600; Scale = 2.0; DipWidth = 1920; DipHeight = 800 },
    @{ PixelWidth = 3840; PixelHeight = 2160; Scale = 2.5; DipWidth = 1536; DipHeight = 864 }
)
foreach ($case in $dipCases) {
    $actual = ConvertTo-DipSize -PixelWidth $case.PixelWidth -PixelHeight $case.PixelHeight -Scale $case.Scale
    Assert-Equal $case.DipWidth $actual.Width 'DPI宽度换算错误'
    Assert-Equal $case.DipHeight $actual.Height 'DPI高度换算错误'
}

$preferred = Get-PreferredClientSize -WorkingWidthDip 960 -WorkingHeightDip 500
Assert-True ($preferred.Width -le 920) '200%缩放下的窗口宽度超出工作区'
Assert-True ($preferred.Height -le 460) '200%缩放下的窗口高度超出工作区'
Assert-True ($preferred.Width -ge 720) '窗口宽度过小'
Assert-True ($preferred.Height -ge 420) '窗口高度过小'

$dialog = Get-ClampedDialogSize -WorkingWidthDip 960 -WorkingHeightDip 500 -DesiredWidth 700 -DesiredHeight 540 -Margin 20
Assert-Equal 700 $dialog.Width '弹窗宽度不应无谓缩小'
Assert-True ($dialog.Height -le 460) '高DPI下弹窗高度超出工作区'
Assert-True ($dialog.Height -ge 360) '弹窗高度过小'

$panelScale = Get-PanelScaleInfo -PanelWidth 411 -PanelHeight 606 -ReferenceWidth 274 -ReferenceHeight 404
Assert-True ([Math]::Abs($panelScale.ScaleX - 1.5) -lt 0.001) '面板X缩放错误'
Assert-True ([Math]::Abs($panelScale.ScaleY - 1.5) -lt 0.001) '面板Y缩放错误'
Assert-True $panelScale.IsReliable '正常等比缩放应判定为可靠'

$badScale = Get-PanelScaleInfo -PanelWidth 548 -PanelHeight 404 -ReferenceWidth 274 -ReferenceHeight 404
Assert-True (-not $badScale.IsReliable) '宽高比例严重失真的面板应判定为不可靠'

Write-Output 'PASS main layout avoids overlap and adapts to DPI/resolution'
