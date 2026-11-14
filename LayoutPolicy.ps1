function Get-MainLayoutMetrics {
    param(
        [int]$ClientWidth,
        [int]$ClientHeight
    )

    $contentWidth = [Math]::Max(520, $ClientWidth - 40)
    $titleTop = 16
    $titleHeight = 38
    $summaryTop = 64
    $summaryHeight = 44
    $statusTop = 114
    $statusHeight = 28
    $gridTop = 150
    $noticeHeight = 24
    $buttonPanelHeight = 82
    $hintHeight = 24
    $hintTop = $ClientHeight - 32
    $buttonTop = $hintTop - 90
    $noticeTop = $buttonTop - 28
    $gridHeight = [Math]::Max(100, $noticeTop - $gridTop - 6)

    return [pscustomobject]@{
        ContentWidth = $contentWidth
        TitleTop = $titleTop
        TitleHeight = $titleHeight
        SummaryTop = $summaryTop
        SummaryHeight = $summaryHeight
        StatusTop = $statusTop
        StatusHeight = $statusHeight
        GridTop = $gridTop
        GridHeight = $gridHeight
        NoticeTop = $noticeTop
        NoticeHeight = $noticeHeight
        ButtonTop = $buttonTop
        ButtonPanelHeight = $buttonPanelHeight
        HintTop = $hintTop
        HintHeight = $hintHeight
    }
}

function ConvertTo-DipSize {
    param(
        [int]$PixelWidth,
        [int]$PixelHeight,
        [double]$Scale = 1.0
    )

    if ($Scale -le 0) {
        throw 'DPI缩放比例必须大于0。'
    }

    return [pscustomobject]@{
        Width = [int][Math]::Round($PixelWidth / $Scale)
        Height = [int][Math]::Round($PixelHeight / $Scale)
    }
}

function Get-PreferredClientSize {
    param(
        [int]$WorkingWidthDip,
        [int]$WorkingHeightDip,
        [int]$DefaultWidth = 860,
        [int]$DefaultHeight = 580,
        [int]$Margin = 40
    )

    $maxWidth = [Math]::Max(320, $WorkingWidthDip - $Margin)
    $maxHeight = [Math]::Max(320, $WorkingHeightDip - $Margin)
    $preferredWidth = [Math]::Min($DefaultWidth, $maxWidth)
    $preferredHeight = [Math]::Min($DefaultHeight, $maxHeight)

    return [pscustomobject]@{
        Width = [Math]::Max(320, $preferredWidth)
        Height = [Math]::Max(320, $preferredHeight)
    }
}

function Get-ClampedDialogSize {
    param(
        [int]$WorkingWidthDip,
        [int]$WorkingHeightDip,
        [int]$DesiredWidth,
        [int]$DesiredHeight,
        [int]$Margin = 20,
        [int]$MinimumWidth = 360,
        [int]$MinimumHeight = 320
    )

    $maxWidth = [Math]::Max(240, $WorkingWidthDip - $Margin * 2)
    $maxHeight = [Math]::Max(240, $WorkingHeightDip - $Margin * 2)

    return [pscustomobject]@{
        Width = [Math]::Max($MinimumWidth, [Math]::Min($DesiredWidth, $maxWidth))
        Height = [Math]::Max($MinimumHeight, [Math]::Min($DesiredHeight, $maxHeight))
    }
}

function Get-PanelScaleInfo {
    param(
        [int]$PanelWidth,
        [int]$PanelHeight,
        [int]$ReferenceWidth,
        [int]$ReferenceHeight,
        [double]$MaxAspectDeviation = 0.25
    )

    if ($ReferenceWidth -le 0 -or $ReferenceHeight -le 0) {
        throw '面板参考尺寸必须大于0。'
    }

    $scaleX = [double]$PanelWidth / [double]$ReferenceWidth
    $scaleY = [double]$PanelHeight / [double]$ReferenceHeight
    $aspectDeviation = 0.0
    if ($scaleX -gt 0 -and $scaleY -gt 0) {
        $aspectDeviation = [Math]::Abs(($scaleX / $scaleY) - 1.0)
    }

    $isReliable = (
        $scaleX -ge 0.45 -and $scaleX -le 3.5 -and
        $scaleY -ge 0.45 -and $scaleY -le 3.5 -and
        $aspectDeviation -le $MaxAspectDeviation
    )

    return [pscustomobject]@{
        ScaleX = $scaleX
        ScaleY = $scaleY
        AspectDeviation = $aspectDeviation
        IsReliable = $isReliable
    }
}
