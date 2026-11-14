$ErrorActionPreference = 'Stop'

$guidePath = Join-Path (Split-Path -Parent $PSScriptRoot) '用户指南.html'
if (-not (Test-Path -LiteralPath $guidePath -PathType Leaf)) {
    throw "Missing user guide: $guidePath"
}

$content = Get-Content -LiteralPath $guidePath -Raw -Encoding UTF8
if ($content -notmatch '<!doctype html>') {
    throw 'Guide is missing an HTML5 doctype'
}
if ($content -notmatch 'name="viewport"') {
    throw 'Guide is missing responsive viewport metadata'
}
if ($content -notmatch 'V1\.3\.1') {
    throw 'Guide does not identify the current version'
}
if ($content -notmatch 'id="languageToggle"') {
    throw 'Guide is missing the language control'
}
if ($content -notmatch 'data-en=') {
    throw 'Guide is missing English localization data'
}

foreach ($requiredText in @(
    '快速开始',
    'Quick start',
    '快捷键',
    'Shortcuts',
    '备份',
    'Backup',
    '配置管理',
    'Config tools',
    'DPI',
    '故障排查',
    'Troubleshooting'
)) {
    if (-not $content.Contains($requiredText)) {
        throw "Guide is missing required content: $requiredText"
    }
}

if ($content -match '(?i)https?://') {
    throw 'Guide must remain fully offline and cannot contain external URLs'
}
if ($content -notmatch '@media\s+print') {
    throw 'Guide is missing print styles'
}
if ($content -notmatch 'prefers-reduced-motion') {
    throw 'Guide is missing reduced-motion support'
}
if ($content -notmatch 'localStorage') {
    throw 'Guide does not remember the selected language'
}
if ($content -notmatch 'function safeStorageGet' -or $content -notmatch 'function safeStorageSet') {
    throw 'Guide does not guard localStorage access'
}
if ($content -notmatch 'afterprint') {
    throw 'Guide does not restore accordion state after printing'
}
if ($content -notmatch '<svg') {
    throw 'Guide does not contain vector graphics'
}
if ((Get-Item -LiteralPath $guidePath).Length -lt 20000) {
    throw 'Guide content is unexpectedly small'
}

Write-Output 'PASS bilingual offline visual user guide'
