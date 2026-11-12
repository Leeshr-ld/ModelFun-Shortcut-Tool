[CmdletBinding()]
param(
    [string]$OutputRoot = '',
    [switch]$PassThru
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$appDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $appDirectory 'portable-dist'
}
$versionPath = Join-Path $appDirectory 'version.json'
if (-not (Test-Path -LiteralPath $versionPath)) {
    throw "缺少版本文件：$versionPath"
}

$versionInfo = Get-Content -LiteralPath $versionPath -Raw -Encoding UTF8 | ConvertFrom-Json
$version = [string]$versionInfo.version
$releaseName = "模方面板快捷键助手_$version"
$outputRootFull = [System.IO.Path]::GetFullPath($OutputRoot)
$releaseDirectory = Join-Path $outputRootFull $releaseName
$zipPath = Join-Path $outputRootFull "${releaseName}_便携版.zip"
$hashPath = "$zipPath.sha256.txt"

$copyMap = @(
    @{ Source = 'RoadLevelHotkeys.exe'; Destination = 'RoadLevelHotkeys.exe' },
    @{ Source = 'RoadLevelHotkeys.ps1'; Destination = 'RoadLevelHotkeys.ps1' },
    @{ Source = 'config.default.json'; Destination = 'config.json' },
    @{ Source = 'ShortcutRules.ps1'; Destination = 'ShortcutRules.ps1' },
    @{ Source = 'MouseAutomation.ps1'; Destination = 'MouseAutomation.ps1' },
    @{ Source = 'BackupWorkflow.ps1'; Destination = 'BackupWorkflow.ps1' },
    @{ Source = 'VersionInfo.ps1'; Destination = 'VersionInfo.ps1' },
    @{ Source = 'version.json'; Destination = 'version.json' },
    @{ Source = 'LayoutPolicy.ps1'; Destination = 'LayoutPolicy.ps1' },
    @{ Source = 'model_shortcuts.json'; Destination = 'model_shortcuts.json' },
    @{ Source = 'LICENSE'; Destination = 'LICENSE' },
    @{ Source = '版权与使用限制.txt'; Destination = '版权与使用限制.txt' },
    @{ Source = '使用说明.md'; Destination = '使用说明.md' }
)

foreach ($entry in $copyMap) {
    $sourcePath = Join-Path $appDirectory $entry.Source
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "缺少运行文件：$sourcePath"
    }
}

$rootPrefix = $outputRootFull.TrimEnd('\') + '\'
foreach ($target in @($releaseDirectory, $zipPath, $hashPath)) {
    $targetFull = [System.IO.Path]::GetFullPath($target)
    if (-not $targetFull.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "输出路径越界：$targetFull"
    }
}

if (-not (Test-Path -LiteralPath $outputRootFull)) {
    New-Item -ItemType Directory -Path $outputRootFull -Force | Out-Null
}
if (Test-Path -LiteralPath $releaseDirectory) {
    Remove-Item -LiteralPath $releaseDirectory -Recurse -Force
}
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
if (Test-Path -LiteralPath $hashPath) {
    Remove-Item -LiteralPath $hashPath -Force
}

New-Item -ItemType Directory -Path $releaseDirectory -Force | Out-Null
foreach ($entry in $copyMap) {
    Copy-Item -LiteralPath (Join-Path $appDirectory $entry.Source) -Destination (Join-Path $releaseDirectory $entry.Destination) -Force
}

Compress-Archive -LiteralPath $releaseDirectory -DestinationPath $zipPath -CompressionLevel Optimal -Force
$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
Set-Content -LiteralPath $hashPath -Value "$hash  $(Split-Path -Leaf $zipPath)" -Encoding UTF8

$result = [pscustomobject]@{
    Version = $version
    ReleaseDirectory = $releaseDirectory
    ZipPath = $zipPath
    HashPath = $hashPath
    Sha256 = $hash
    Files = @($copyMap | ForEach-Object Destination)
}

if ($PassThru) {
    return $result
}

Write-Output "已生成：$zipPath"
Write-Output "SHA256：$hash"
