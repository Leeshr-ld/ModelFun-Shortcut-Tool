function Get-AppVersionInfo([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-AboutText($Info, [string]$Language = 'zh-CN') {
    $localizationPath = Join-Path $PSScriptRoot 'Localization.ps1'
    if (Test-Path -LiteralPath $localizationPath) {
        . $localizationPath
    }
    $languageCode = Resolve-UiLanguage $Language
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add((Get-UiText -Key 'app.name' -Language $languageCode))
    $lines.Add((Get-UiText -Key 'about.currentVersion' -Language $languageCode -Tokens @{ version = [string]$Info.version }))
    $lines.Add((Get-UiText -Key 'about.author' -Language $languageCode -Tokens @{ author = [string]$Info.author }))
    $lines.Add([string]$Info.copyright)
    $lines.Add('')
    $licenseNotice = if ($languageCode -eq 'en-US' -and $Info.PSObject.Properties['licenseNoticeEn']) {
        [string]$Info.licenseNoticeEn
    }
    else {
        [string]$Info.licenseNotice
    }
    $lines.Add($licenseNotice)
    $lines.Add('')
    $lines.Add('==================================================')
    $lines.Add((Get-UiText -Key 'about.versionHistory' -Language $languageCode))
    $lines.Add('')

    foreach ($release in $Info.history) {
        $lines.Add("$($release.version)　$($release.date)")
        $changes = if ($languageCode -eq 'en-US' -and $release.PSObject.Properties['changesEn']) {
            @($release.changesEn)
        }
        else {
            @($release.changes)
        }
        $index = 1
        foreach ($change in $changes) {
            $lines.Add("$index. $change")
            $index++
        }
        $lines.Add('')
    }

    return ($lines -join "`r`n")
}
