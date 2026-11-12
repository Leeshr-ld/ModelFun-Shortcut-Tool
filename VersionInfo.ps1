function Get-AppVersionInfo([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-AboutText($Info) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('模方面板快捷键助手')
    $lines.Add("当前版本：$($Info.version)")
    $lines.Add("作者：$($Info.author)")
    $lines.Add([string]$Info.copyright)
    $lines.Add('')
    $lines.Add([string]$Info.licenseNotice)
    $lines.Add('')
    $lines.Add('==================================================')
    $lines.Add('版本历史')
    $lines.Add('')

    foreach ($release in $Info.history) {
        $lines.Add("$($release.version)　$($release.date)")
        $index = 1
        foreach ($change in $release.changes) {
            $lines.Add("$index. $change")
            $index++
        }
        $lines.Add('')
    }

    return ($lines -join "`r`n")
}
