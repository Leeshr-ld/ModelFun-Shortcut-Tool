function Get-ConfigBackupFileName([datetime]$Timestamp) {
    return 'config.{0}.json' -f $Timestamp.ToString('yyyyMMdd-HHmmss-fff')
}

if (-not (Get-Command New-UiException -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'Localization.ps1')
}

function Write-ConfigTextAtomic {
    param(
        [string]$ConfigPath,
        [string]$Json
    )

    $parent = Split-Path -Parent $ConfigPath
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $temporaryPath = "$ConfigPath.tmp.$PID." + [Guid]::NewGuid().ToString('N')
    try {
        [System.IO.File]::WriteAllText($temporaryPath, $Json, [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporaryPath -Destination $ConfigPath -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Read-ConfigJsonFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw (New-UiException `
            -Key 'error.configFileNotFound' `
            -FallbackMessage "配置文件不存在：$Path" `
            -Tokens @{ path = $Path })
    }
    try {
        return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw (New-UiException `
            -Key 'error.invalidConfigJson' `
            -FallbackMessage '配置文件的JSON格式无效。')
    }
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

function Get-LatestConfigBackup {
    param(
        [string]$BackupDirectory,
        [scriptblock]$Validator = $null
    )

    if (-not (Test-Path -LiteralPath $BackupDirectory)) {
        return $null
    }
    $backups = Get-ChildItem -LiteralPath $BackupDirectory -Filter 'config.*.json' -File |
        Sort-Object Name -Descending
    foreach ($backup in $backups) {
        if ($null -eq $Validator) {
            return $backup.FullName
        }
        try {
            $candidate = Read-ConfigJsonFile $backup.FullName
            $null = & $Validator $candidate
            return $backup.FullName
        }
        catch {
            continue
        }
    }
    return $null
}

function Restore-LatestConfigFile {
    param(
        [string]$ConfigPath,
        [string]$BackupDirectory,
        [scriptblock]$Validator = $null
    )

    $latest = Get-LatestConfigBackup -BackupDirectory $BackupDirectory -Validator $Validator
    if ($null -eq $latest) {
        throw (New-UiException `
            -Key 'error.noValidConfigBackup' `
            -FallbackMessage '没有可恢复的有效配置备份。')
    }
    $restoredConfig = Read-ConfigJsonFile $latest
    if (Test-Path -LiteralPath $ConfigPath -PathType Leaf) {
        $currentIsValid = $true
        if ($null -ne $Validator) {
            try {
                $currentCandidate = Read-ConfigJsonFile $ConfigPath
                $null = & $Validator $currentCandidate
            }
            catch {
                $currentIsValid = $false
            }
        }
        if ($currentIsValid) {
            Backup-ConfigFile `
                -ConfigPath $ConfigPath `
                -BackupDirectory $BackupDirectory | Out-Null
        }
    }
    Write-ConfigTextAtomic `
        -ConfigPath $ConfigPath `
        -Json ($restoredConfig | ConvertTo-Json -Depth 12)
    return $latest
}

function Read-ConfigFileWithRecovery {
    param(
        [string]$ConfigPath,
        [string]$BackupDirectory,
        [scriptblock]$Validator = $null
    )

    try {
        $candidate = Read-ConfigJsonFile $ConfigPath
        $sourceVersion = if ($candidate.PSObject.Properties['version']) { [int]$candidate.version } else { 0 }
        $validated = if ($null -ne $Validator) { & $Validator $candidate } else { $candidate }
        if ($null -eq $validated) {
            throw '配置未通过校验。'
        }
        return [pscustomobject]@{
            Config = $validated
            SourceVersion = $sourceVersion
            Restored = $false
            RestoredFrom = $null
        }
    }
    catch {
        $restoredFrom = Restore-LatestConfigFile `
            -ConfigPath $ConfigPath `
            -BackupDirectory $BackupDirectory `
            -Validator $Validator
        $candidate = Read-ConfigJsonFile $ConfigPath
        $sourceVersion = if ($candidate.PSObject.Properties['version']) { [int]$candidate.version } else { 0 }
        $validated = if ($null -ne $Validator) { & $Validator $candidate } else { $candidate }
        return [pscustomobject]@{
            Config = $validated
            SourceVersion = $sourceVersion
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
        [datetime]$Timestamp = (Get-Date),
        [scriptblock]$Validator = $null
    )

    if ($null -eq $Config) {
        throw (New-UiException `
            -Key 'error.configEmpty' `
            -FallbackMessage '配置不能为空。')
    }
    if ($null -ne $Validator) {
        $Config = & $Validator $Config
        if ($null -eq $Config) {
            throw (New-UiException `
                -Key 'error.configValidation' `
                -FallbackMessage '配置未通过校验。')
        }
    }
    $backupPath = Backup-ConfigFile `
        -ConfigPath $ConfigPath `
        -BackupDirectory $BackupDirectory `
        -Timestamp $Timestamp

    Write-ConfigTextAtomic `
        -ConfigPath $ConfigPath `
        -Json ($Config | ConvertTo-Json -Depth 12)
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
            throw (New-UiException `
                -Key 'error.configValidation' `
                -FallbackMessage '导入配置未通过校验。')
        }
    }

    $null = Save-ConfigFile `
        -ConfigPath $ConfigPath `
        -Config $candidate `
        -BackupDirectory $BackupDirectory `
        -Validator $Validator
    return $candidate
}
