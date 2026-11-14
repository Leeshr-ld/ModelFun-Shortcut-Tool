$ErrorActionPreference = 'Stop'

$appDirectory = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $appDirectory 'runtime.sha256'
$buildScript = Join-Path $appDirectory '构建启动器.ps1'
$hashSourcePath = Join-Path $appDirectory 'RuntimeManifestHash.g.cs'
$attributesPath = Join-Path $appDirectory '.gitattributes'

foreach ($path in @($manifestPath, $buildScript, $hashSourcePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "缺少运行时完整性文件：$path"
    }
}

$attributes = Get-Content -LiteralPath $attributesPath -Raw -Encoding UTF8
foreach ($rule in @('*.ps1 text eol=lf','*.cs text eol=lf','*.html text eol=lf','*.exe binary')) {
    if (-not $attributes.Contains($rule)) {
        throw "缺少稳定换行规则：$rule"
    }
}

$manifestBytes = [System.IO.File]::ReadAllBytes($manifestPath)
for ($index = 0; $index -lt ($manifestBytes.Length - 1); $index++) {
    if ($manifestBytes[$index] -eq 13 -and $manifestBytes[$index + 1] -eq 10) {
        throw 'runtime.sha256必须使用纯LF换行'
    }
}

$manifestEntries = @{}
foreach ($line in Get-Content -LiteralPath $manifestPath -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }
    if ($line -notmatch '^([0-9A-Fa-f]{64})  (.+)$') {
        throw "清单格式错误：$line"
    }
    $manifestEntries[$Matches[2]] = $Matches[1].ToUpperInvariant()
}

foreach ($required in @(
    'RoadLevelHotkeys.ps1',
    'DpiSupport.ps1',
    'Localization.ps1',
    'ConfigStorage.ps1',
    'SingleInstance.ps1',
    'ShortcutRules.ps1',
    '用户指南.html'
)) {
    if (-not $manifestEntries.ContainsKey($required)) {
        throw "完整性清单缺少文件：$required"
    }
}

foreach ($entry in $manifestEntries.GetEnumerator()) {
    $path = Join-Path $appDirectory $entry.Key
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "完整性清单中的文件不存在：$($entry.Key)"
    }
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ($actual -ne $entry.Value) {
        throw "文件哈希不匹配：$($entry.Key)"
    }
}

$manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToUpperInvariant()
$source = Get-Content -LiteralPath $hashSourcePath -Raw -Encoding UTF8
if (-not $source.Contains($manifestHash)) {
    throw '启动器内置的清单哈希与runtime.sha256不一致'
}

$exePath = Join-Path $appDirectory 'RoadLevelHotkeys.exe'
if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
    throw '缺少RoadLevelHotkeys.exe'
}
$assembly = [System.Reflection.Assembly]::LoadFile($exePath)
$type = $assembly.GetType('RoadLevel.RuntimeIntegrity', $true)
$method = $type.GetMethod('Verify', [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
$result = $method.Invoke($null, [object[]]@([string]$appDirectory))
if ($null -ne $result) {
    throw "启动器完整性校验失败：$result"
}

$tamperRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('RoadLevelIntegrityTest_' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $tamperRoot -Force | Out-Null
    foreach ($entry in $manifestEntries.Keys) {
        $destination = Join-Path $tamperRoot $entry
        $parent = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Copy-Item -LiteralPath (Join-Path $appDirectory $entry) -Destination $destination -Force
    }
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $tamperRoot 'runtime.sha256') -Force
    Add-Content -LiteralPath (Join-Path $tamperRoot 'Localization.ps1') -Value '# tampered' -Encoding UTF8
    $tamperedResult = $method.Invoke($null, [object[]]@([string]$tamperRoot))
    if ($null -eq $tamperedResult -or -not ([string]$tamperedResult).Contains('Localization.ps1')) {
        throw '启动器未阻止被篡改的脚本'
    }
}
finally {
    if (Test-Path -LiteralPath $tamperRoot) {
        Remove-Item -LiteralPath $tamperRoot -Recurse -Force
    }
}

Write-Output 'PASS runtime integrity manifest, pinned hash and tamper detection'
