function Get-ConfigBackupFileName([datetime]$Timestamp) {
    return 'config.{0}.json' -f $Timestamp.ToString('yyyyMMdd-HHmmss-fff')
}

function Read-ConfigJsonFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "配置文件不存在：$Path"
    }
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Backup-ConfigFile {
    param(
        [string]$ConfigPath,
        [string]$BackupDirectory,
        [datetime]$Timestamp = (Get-Date),
        [int]$RetainCount = 20
    )

    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        return $null
    }
    if (-not (Test-Path -LiteralPath $BackupDirectory)) {
        New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    }

    $backupPath = Join-Path $BackupDirectory (Get-ConfigBackupFileName $Timestamp)
    Copy-Item -LiteralPath $ConfigPath -Destination $backupPath -Force

    $backups = @(
        Get-ChildItem -LiteralPath $BackupDirectory -Filter 'config.*.json' -File |
            Sort-Object Name -Descending
    )
    if ($RetainCount -gt 0 -and $backups.Count -gt $RetainCount) {
        foreach ($expired in $backups[$RetainCount..($backups.Count - 1)]) {
            Remove-Item -LiteralPath $expired.FullName -Force
        }
    }
    return $backupPath
}

function Get-LatestConfigBackup([string]$BackupDirectory) {
    if (-not (Test-Path -LiteralPath $BackupDirectory)) {
        return $null
    }
    $backup = Get-ChildItem -LiteralPath $BackupDirectory -Filter 'config.*.json' -File |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($null -eq $backup) {
        return $null
    }
    return $backup.FullName
}

function Restore-LatestConfigFile {
    param(
        [string]$ConfigPath,
        [string]$BackupDirectory
    )

    $latest = Get-LatestConfigBackup -BackupDirectory $BackupDirectory
    if ($null -eq $latest) {
        throw '没有可恢复的配置备份。'
    }
    $null = Read-ConfigJsonFile $latest
    if (Test-Path -LiteralPath $ConfigPath -PathType Leaf) {
        Backup-ConfigFile `
            -ConfigPath $ConfigPath `
            -BackupDirectory $BackupDirectory | Out-Null
    }
    Copy-Item -LiteralPath $latest -Destination $ConfigPath -Force
    return $latest
}

function Read-ConfigFileWithRecovery {
    param(
        [string]$ConfigPath,
        [string]$BackupDirectory
    )

    try {
        return [pscustomobject]@{
            Config = Read-ConfigJsonFile $ConfigPath
            Restored = $false
            RestoredFrom = $null
        }
    }
    catch {
        $restoredFrom = Restore-LatestConfigFile `
            -ConfigPath $ConfigPath `
            -BackupDirectory $BackupDirectory
        return [pscustomobject]@{
            Config = Read-ConfigJsonFile $ConfigPath
            Restored = $true
            RestoredFrom = $restoredFrom
        }
    }
}

function Export-ConfigFile {
    param(
        [string]$ConfigPath,
        [string]$DestinationPath
    )

    $null = Read-ConfigJsonFile $ConfigPath
    $parent = Split-Path -Parent $DestinationPath
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $ConfigPath -Destination $DestinationPath -Force
    return $DestinationPath
}

function Save-ConfigFile {
    param(
        [string]$ConfigPath,
        $Config,
        [string]$BackupDirectory,
        [datetime]$Timestamp = (Get-Date)
    )

    if ($null -eq $Config) {
        throw '配置不能为空。'
    }
    $backupPath = Backup-ConfigFile `
        -ConfigPath $ConfigPath `
        -BackupDirectory $BackupDirectory `
        -Timestamp $Timestamp

    $parent = Split-Path -Parent $ConfigPath
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $temporaryPath = "$ConfigPath.tmp"
    try {
        $json = $Config | ConvertTo-Json -Depth 12
        [System.IO.File]::WriteAllText($temporaryPath, $json, [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporaryPath -Destination $ConfigPath -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
    return $backupPath
}

function Import-ConfigFile {
    param(
        [string]$SourcePath,
        [string]$ConfigPath,
        [string]$BackupDirectory,
        [scriptblock]$Validator = $null
    )

    $candidate = Read-ConfigJsonFile $SourcePath
    if ($null -ne $Validator) {
        $candidate = & $Validator $candidate
        if ($null -eq $candidate) {
            throw '导入配置未通过校验。'
        }
    }

    $null = Save-ConfigFile `
        -ConfigPath $ConfigPath `
        -Config $candidate `
        -BackupDirectory $BackupDirectory
    return $candidate
}
