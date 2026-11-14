$ErrorActionPreference = 'Stop'

$localizationPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Localization.ps1'
. $localizationPath

$languages = @(Get-UiLanguageOptions)
if ($languages.Count -ne 2) {
    throw "Expected two language options, got $($languages.Count)"
}
if (($languages.Code -join ',') -ne 'zh-CN,en-US') {
    throw "Unexpected language codes: $($languages.Code -join ',')"
}

if ((Resolve-UiLanguage '') -ne 'zh-CN') {
    throw 'Empty language must fall back to zh-CN'
}
if ((Resolve-UiLanguage 'xx-YY') -ne 'zh-CN') {
    throw 'Unknown language must fall back to zh-CN'
}
if ((Resolve-UiLanguage 'en-US') -ne 'en-US') {
    throw 'Supported language was not preserved'
}

$chinese = Get-UiTextMap 'zh-CN'
$english = Get-UiTextMap 'en-US'
$missingInEnglish = @(Compare-Object @($chinese.Keys) @($english.Keys))
if ($missingInEnglish.Count -ne 0) {
    throw "Language resource keys do not match: $($missingInEnglish | Out-String)"
}

$requiredKeys = @(
    'app.name',
    'main.title',
    'main.summary',
    'language.label',
    'button.detect',
    'button.editShortcut',
    'button.resetDefaults',
    'button.loadConfig',
    'button.openConfig',
    'button.configManager',
    'button.userGuide',
    'button.enableHotkeys',
    'button.about',
    'button.exit',
    'button.exportConfig',
    'button.importConfig',
    'button.restoreBackup',
    'column.action',
    'column.keyboard',
    'column.mouse',
    'column.status',
    'editor.title',
    'editor.heading',
    'editor.keyboardLabel',
    'editor.clearKeyboard',
    'editor.mouseLabel',
    'editor.noConflict',
    'button.save',
    'button.cancel',
    'button.ok',
    'mouse.none',
    'mouse.side1',
    'mouse.side2',
    'about.title',
    'about.heading',
    'about.currentVersion',
    'about.author',
    'about.versionHistory',
    'status.paused',
    'status.waitingModelFun',
    'status.standby',
    'status.backupOnly',
    'status.detected',
    'status.detectionFailed'
)
foreach ($language in @('zh-CN', 'en-US')) {
    $map = Get-UiTextMap $language
    foreach ($key in $requiredKeys) {
        if (-not $map.ContainsKey($key) -or [string]::IsNullOrWhiteSpace([string]$map[$key])) {
            throw "Missing localization key $key for $language"
        }
    }
}

if ((Get-UiText -Key 'main.title' -Language 'en-US') -ne 'ModelFun Shortcut Tool') {
    throw 'English main title is incorrect'
}
if ((Get-LocalizedPanelTitle -PanelTitle '道路置平' -Language 'en-US') -ne 'Road Leveling') {
    throw 'English panel title is incorrect'
}
if ((Get-LocalizedActionLabel -Label '备份当前工程瓦片' -Language 'en-US') -ne 'Backup Project Tiles') {
    throw 'English action label is incorrect'
}

Write-Output 'PASS localization resources, language fallback and display mappings'
