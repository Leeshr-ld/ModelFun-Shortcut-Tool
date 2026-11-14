$ErrorActionPreference = 'Stop'

$singleInstancePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'SingleInstance.ps1'
. $singleInstancePath

$name = 'RoadLevelHotkeys.Test.' + [Guid]::NewGuid().ToString('N')
$first = $null
$second = $null
try {
    $first = New-SingleInstanceGuard -Name $name
    $second = New-SingleInstanceGuard -Name $name

    if (-not $first.Created) {
        throw 'First instance was not reported as created'
    }
    if ($second.Created) {
        throw 'Second instance was incorrectly reported as created'
    }

    Write-Output 'PASS named mutex detects duplicate application instances'
}
finally {
    if ($null -ne $second) {
        Close-SingleInstanceGuard -Guard $second
    }
    if ($null -ne $first) {
        Close-SingleInstanceGuard -Guard $first
    }
}

$appScriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'RoadLevelHotkeys.ps1'
$appScript = Get-Content -LiteralPath $appScriptPath -Raw -Encoding UTF8
$guardMatch = [regex]::Match($appScript, '\$script:SingleInstanceGuard\s*=\s*New-SingleInstanceGuard')
$loadMatches = [regex]::Matches($appScript, '(?m)^\s*Load-Config\s*$')
$loadMatch = $loadMatches[$loadMatches.Count - 1]
if (-not $guardMatch.Success -or $null -eq $loadMatch) {
    throw 'Cannot locate single-instance guard or startup config load'
}
if ($guardMatch.Index -gt $loadMatch.Index) {
    throw 'Single-instance guard must be acquired before Load-Config'
}

$childScript = Join-Path $PSScriptRoot '_SingleInstanceChild.ps1'
$readyPath = Join-Path ([System.IO.Path]::GetTempPath()) ('RoadLevelSingleReady_' + [guid]::NewGuid().ToString('N') + '.txt')
$mutexName = 'RoadLevelHotkeys.CrossProcessTest.' + [Guid]::NewGuid().ToString('N')
$hostExe = if ($PSVersionTable.PSEdition -eq 'Desktop') {
    Join-Path $PSHOME 'powershell.exe'
}
else {
    Join-Path $PSHOME 'pwsh.exe'
}
$firstProcess = $null
try {
    $firstProcess = Start-Process `
        -FilePath $hostExe `
        -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $childScript),'-Name',$mutexName,'-ReadyPath',('"{0}"' -f $readyPath),'-HoldMilliseconds','5000') `
        -WindowStyle Hidden `
        -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while (-not (Test-Path -LiteralPath $readyPath) -and [DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 50
    }
    if (-not (Test-Path -LiteralPath $readyPath)) {
        throw 'First cross-process instance did not become ready'
    }

    $secondProcess = Start-Process `
        -FilePath $hostExe `
        -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $childScript),'-Name',$mutexName,'-ReadyPath',('"{0}"' -f ($readyPath + '.second')),'-HoldMilliseconds','0') `
        -WindowStyle Hidden `
        -PassThru `
        -Wait
    if ($secondProcess.ExitCode -ne 2) {
        throw "Second cross-process instance returned $($secondProcess.ExitCode), expected 2"
    }
    Write-Output 'PASS cross-process mutex and startup order'
}
finally {
    if ($null -ne $firstProcess -and -not $firstProcess.HasExited) {
        Stop-Process -Id $firstProcess.Id -Force
    }
    if (Test-Path -LiteralPath $readyPath) {
        Remove-Item -LiteralPath $readyPath -Force
    }
    if (Test-Path -LiteralPath ($readyPath + '.second')) {
        Remove-Item -LiteralPath ($readyPath + '.second') -Force
    }
}
