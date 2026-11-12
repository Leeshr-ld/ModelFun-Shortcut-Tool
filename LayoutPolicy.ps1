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
