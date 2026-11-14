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

    $archive = [System.IO.Compression.ZipFile]::OpenRead($result.ZipPath)
    try {
        $names = @($archive.Entries | ForEach-Object FullName)
        $configEntry = $archive.Entries | Where-Object { $_.FullName -like '*/config.json' } | Select-Object -First 1
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
    }
    finally {
        $archive.Dispose()
    }

    $required = @(
        'RoadLevelHotkeys.exe',
        'RoadLevelHotkeys.ps1',
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

    if (-not ($names | Where-Object { $_ -like '*模方面板快捷键助手_V1.2.0/*' })) {
        throw '发行包缺少V1.2.0顶层目录'
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
