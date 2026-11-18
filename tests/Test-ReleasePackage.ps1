$ErrorActionPreference = 'Stop'

$appDirectory = Split-Path -Parent $PSScriptRoot
$builderPath = Join-Path $appDirectory '打包便携版.ps1'
if (-not (Test-Path -LiteralPath $builderPath)) {
    throw "缺少待测打包脚本：$builderPath"
}
$defaultConfigPath = Join-Path $appDirectory 'config.default.json'
if (-not (Test-Path -LiteralPath $defaultConfigPath)) {
    throw "缺少默认配置：$defaultConfigPath"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("RoadLevelReleaseTest_" + [Guid]::NewGuid().ToString('N'))

try {
    $result = & $builderPath -OutputRoot $testRoot -PassThru
    if (-not (Test-Path -LiteralPath $result.ZipPath)) {
        throw "没有生成ZIP：$($result.ZipPath)"
    }
    $exePath = Join-Path $result.ReleaseDirectory 'RoadLevelHotkeys.exe'
    if (-not (Test-Path -LiteralPath $exePath)) {
        throw "发行包没有生成EXE：$exePath"
    }
    $versionInfo = Get-Content -LiteralPath (Join-Path $appDirectory 'version.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $expectedFileVersion = ([string]$versionInfo.version).TrimStart('V') + '.0'
    $exeVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exePath).FileVersion
    if ($exeVersion -ne $expectedFileVersion) {
        throw "EXE文件版本错误：$exeVersion，期望=$expectedFileVersion"
    }

    $archive = [System.IO.Compression.ZipFile]::OpenRead($result.ZipPath)
    try {
        $names = @($archive.Entries | ForEach-Object { $_.FullName -replace '\\', '/' })
        if ($names.Count -ne 19) {
            throw "发行包文件数量错误：$($names.Count)，期望19"
        }
        $configEntry = $archive.Entries | Where-Object { ($_.FullName -replace '\\', '/') -like '*/config.json' } | Select-Object -First 1
        if ($null -eq $configEntry) {
            throw '发行包缺少config.json'
        }
        $reader = New-Object System.IO.StreamReader($configEntry.Open())
        try {
            $config = $reader.ReadToEnd() | ConvertFrom-Json
        }
        finally {
            $reader.Dispose()
        }
        $manifestEntry = $archive.Entries | Where-Object { ($_.FullName -replace '\\', '/') -like '*/runtime.sha256' } | Select-Object -First 1
        if ($null -eq $manifestEntry) {
            throw '发行包缺少runtime.sha256'
        }
        $reader = New-Object System.IO.StreamReader($manifestEntry.Open(), [System.Text.Encoding]::UTF8)
        try {
            $manifestText = $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }
        $manifestPaths = @(
            $manifestText -split "`r?`n" |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                ForEach-Object {
                    if ($_ -notmatch '^[0-9A-Fa-f]{64}  (.+)$') {
                        throw "runtime.sha256格式错误：$_"
                    }
                    $Matches[1]
                }
        )
        $expectedProtected = @(
            $names |
                ForEach-Object { ($_ -split '[\\/]')[-1] } |
                Where-Object { $_ -notin @('RoadLevelHotkeys.exe', 'config.json', 'runtime.sha256') }
        )
        $missingProtected = @($expectedProtected | Where-Object { $_ -notin $manifestPaths })
        if ($missingProtected.Count -gt 0) {
            throw "完整性清单遗漏文件：$($missingProtected -join ', ')"
        }
    }
    finally {
        $archive.Dispose()
    }

    $required = @(
        'RoadLevelHotkeys.exe',
        'RoadLevelHotkeys.ps1',
        'DpiSupport.ps1',
        'Localization.ps1',
        'ConfigStorage.ps1',
        'SingleInstance.ps1',
        'runtime.sha256',
        '用户指南.html',
        'config.json',
        'ShortcutRules.ps1',
        'MouseAutomation.ps1',
        'BackupWorkflow.ps1',
        'VersionInfo.ps1',
        'version.json',
        'LayoutPolicy.ps1',
        'model_shortcuts.json',
        'LICENSE',
        '版权与使用限制.txt',
        '使用说明.md'
    )

    foreach ($fileName in $required) {
        if (-not ($names | Where-Object { $_ -like "*/$fileName" })) {
            throw "发行包缺少文件：$fileName"
        }
    }

    $forbidden = @(
        'Launcher.cs',
        'app.manifest',
        '打包便携版.ps1',
        '打包说明.md',
        'tests/'
    )
    foreach ($item in $forbidden) {
        if ($names | Where-Object { $_ -like "*$item*" }) {
            throw "发行包包含无关文件：$item"
        }
    }

    $expectedFolder = "模方面板快捷键助手_$([string]$versionInfo.version)"
    if (-not ($names | Where-Object { $_ -like "$expectedFolder/*" })) {
        throw "发行包缺少$expectedFolder顶层目录"
    }

    if ([string]$config.commonBindings.backup.key -ne 'B') {
        throw '发行包未使用默认备份快捷键B'
    }

    Write-Output 'PASS release package contains runtime files only'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
