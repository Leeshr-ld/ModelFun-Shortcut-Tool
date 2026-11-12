function Get-BackupDialogPoints($Bounds) {
    $referenceWidth = 555.0
    $referenceHeight = 503.0
    $scaleX = ([double]$Bounds.Right - [double]$Bounds.Left) / $referenceWidth
    $scaleY = ([double]$Bounds.Bottom - [double]$Bounds.Top) / $referenceHeight

    return [pscustomobject]@{
        SelectAllX = [int][Math]::Round($Bounds.Left + 309 * $scaleX)
        SelectAllY = [int][Math]::Round($Bounds.Top + 407 * $scaleY)
        BackupNowX = [int][Math]::Round($Bounds.Left + 49 * $scaleX)
        BackupNowY = [int][Math]::Round($Bounds.Top + 140 * $scaleY)
    }
}

function Invoke-BackupWorkflowSteps {
    param(
        [scriptblock]$ClickBackupButton,
        [scriptblock]$WaitForDialog,
        [scriptblock]$ClickSelectAll,
        [scriptblock]$ClickBackupNow
    )

    & $ClickBackupButton
    $dialogBounds = & $WaitForDialog
    if ($null -eq $dialogBounds) {
        throw '没有等到“备份和恢复”窗口。'
    }

    & $ClickSelectAll $dialogBounds
    & $ClickBackupNow $dialogBounds
}
