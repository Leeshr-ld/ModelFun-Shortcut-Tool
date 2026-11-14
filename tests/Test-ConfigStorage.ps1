$ErrorActionPreference = 'Stop'

$storagePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'ConfigStorage.ps1'
. $storagePath

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("RoadLevelConfigTest_" + [Guid]::NewGuid().ToString('N'))
$configPath = Join-Path $testRoot 'config.json'
$backupDirectory = Join-Path $testRoot 'config-backups'
$exportPath = Join-Path $testRoot 'exported-config.json'
$importPath = Join-Path $testRoot 'imported-config.json'

try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    Set-Content -LiteralPath $configPath -Value '{"version":5,"language":"zh-CN","value":"first"}' -Encoding UTF8

    $backupPath = Backup-ConfigFile `
        -ConfigPath $configPath `
        -BackupDirectory $backupDirectory `
        -Timestamp ([datetime]'2026-11-14T14:00:00')
    if (-not (Test-Path -LiteralPath $backupPath)) {
        throw 'Config backup was not created'
    }
    if ((Get-LatestConfigBackup -BackupDirectory $backupDirectory) -ne $backupPath) {
        throw 'Latest config backup was not found'
    }

    Set-Content -LiteralPath $configPath -Value '{"version":5,"language":"en-US","value":"changed"}' -Encoding UTF8
    $restoredPath = Restore-LatestConfigFile -ConfigPath $configPath -BackupDirectory $backupDirectory
    if ($restoredPath -ne $backupPath) {
        throw 'Restore did not use the latest backup'
    }
    $restored = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($restored.value -ne 'first') {
        throw 'Config was not restored from backup'
    }

    if (-not (Test-Path -LiteralPath (Export-ConfigFile -ConfigPath $configPath -DestinationPath $exportPath))) {
        throw 'Config export was not created'
    }

    Set-Content -LiteralPath $importPath -Value '{"version":5,"language":"en-US","value":"imported"}' -Encoding UTF8
    Import-ConfigFile `
        -SourcePath $importPath `
        -ConfigPath $configPath `
        -BackupDirectory $backupDirectory `
        -Validator { param($candidate) $candidate } | Out-Null
    $imported = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($imported.value -ne 'imported' -or $imported.language -ne 'en-US') {
        throw 'Config import did not replace the current configuration'
    }

    $beforeInvalidImport = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
    Set-Content -LiteralPath $importPath -Value '{broken json' -Encoding UTF8
    $failed = $false
    try {
        Import-ConfigFile -SourcePath $importPath -ConfigPath $configPath -BackupDirectory $backupDirectory
    }
    catch {
        $failed = $true
    }
    if (-not $failed) {
        throw 'Invalid imported JSON was accepted'
    }
    if ((Get-Content -LiteralPath $configPath -Raw -Encoding UTF8) -ne $beforeInvalidImport) {
        throw 'Invalid import changed the current configuration'
    }

    $saveConfig = [pscustomobject]@{ version = 5; language = 'zh-CN'; value = 'saved' }
    $saveBackup = Save-ConfigFile `
        -ConfigPath $configPath `
        -Config $saveConfig `
        -BackupDirectory $backupDirectory `
        -Timestamp ([datetime]'2026-11-14T14:05:00')
    if ($null -eq $saveBackup -or -not (Test-Path -LiteralPath $saveBackup)) {
        throw 'Save did not back up the previous configuration'
    }
    $saved = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($saved.value -ne 'saved') {
        throw 'Save did not write the new configuration'
    }

    $null = Backup-ConfigFile `
        -ConfigPath $configPath `
        -BackupDirectory $backupDirectory `
        -Timestamp ([datetime]'2099-01-01T00:00:00')
    Set-Content -LiteralPath $configPath -Value '{damaged config' -Encoding UTF8
    $recovered = Read-ConfigFileWithRecovery `
        -ConfigPath $configPath `
        -BackupDirectory $backupDirectory
    if (-not $recovered.Restored -or $recovered.Config.value -ne 'saved') {
        throw 'Damaged configuration was not recovered from backup'
    }
    $null = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

    $fallbackRoot = Join-Path $testRoot 'fallback'
    $fallbackBackups = Join-Path $fallbackRoot 'config-backups'
    $fallbackConfig = Join-Path $fallbackRoot 'config.json'
    New-Item -ItemType Directory -Path $fallbackBackups -Force | Out-Null
    $validator = {
        param($candidate)
        if ([int]$candidate.version -ne 5 -or $candidate.value -notin @('older-valid','current')) {
            throw 'schema-invalid'
        }
        return $candidate
    }
    Set-Content -LiteralPath (Join-Path $fallbackBackups 'config.20260101-000000-000.json') -Value '{"version":5,"value":"older-valid"}' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $fallbackBackups 'config.20260102-000000-000.json') -Value '{corrupt-latest' -Encoding UTF8
    Set-Content -LiteralPath $fallbackConfig -Value '{"version":5,"value":"current"}' -Encoding UTF8
    $fallbackPath = Restore-LatestConfigFile -ConfigPath $fallbackConfig -BackupDirectory $fallbackBackups -Validator $validator
    $fallbackRestored = Get-Content -LiteralPath $fallbackConfig -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($fallbackPath -notlike '*20260101*' -or $fallbackRestored.value -ne 'older-valid') {
        throw '恢复未跳过损坏的最新备份'
    }

    Set-Content -LiteralPath $fallbackConfig -Value '{"version":5,"value":"invalid-schema"}' -Encoding UTF8
    $fallbackRecovery = Read-ConfigFileWithRecovery `
        -ConfigPath $fallbackConfig `
        -BackupDirectory $fallbackBackups `
        -Validator $validator
    if (-not $fallbackRecovery.Restored -or $fallbackRecovery.Config.value -eq 'invalid-schema') {
        throw '结构错误配置未回退到有效备份'
    }

    Write-Output 'PASS config backup, safe save, restore, valid-backup fallback, recovery, export, import and invalid-input protection'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
