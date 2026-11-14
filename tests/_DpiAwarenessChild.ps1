$ErrorActionPreference = 'Stop'

$appDirectory = Split-Path -Parent $PSScriptRoot
$supportPath = Join-Path $appDirectory 'DpiSupport.ps1'
if (-not (Test-Path -LiteralPath $supportPath)) {
    throw "缺少DPI支持模块：$supportPath"
}

. $supportPath
$initialization = Initialize-PerMonitorDpiAwareness

Add-Type -AssemblyName System.Windows.Forms
$form = New-Object System.Windows.Forms.Form
$form.Show()
[System.Windows.Forms.Application]::DoEvents()
$awareness = Get-WindowDpiAwareness $form.Handle
$dpi = Get-WindowDpi $form.Handle
Write-Output ("SET={0} AWARENESS={1} DPI={2}" -f $initialization.SetSucceeded, $awareness, $dpi)
$form.Close()
$form.Dispose()

if ($awareness -ne 2) {
    exit 1
}
