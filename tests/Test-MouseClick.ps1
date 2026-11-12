$ErrorActionPreference = 'Stop'

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'MouseAutomation.ps1'
if (-not (Test-Path -LiteralPath $modulePath)) {
    throw "缺少待测文件：$modulePath"
}
. $modulePath

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class TestDpiContext
{
    [DllImport("user32.dll")]
    public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
}
'@
[TestDpiContext]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null

$form = New-Object System.Windows.Forms.Form
$form.Text = 'MouseClickTest'
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.TopMost = $true
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
$workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Left = $workingArea.Right - 260
$form.Top = $workingArea.Bottom - 180
$form.ClientSize = New-Object System.Drawing.Size(220, 120)

$button = New-Object System.Windows.Forms.Button
$button.Text = 'Test'
$button.Left = 40
$button.Top = 35
$button.Width = 140
$button.Height = 48
$form.Controls.Add($button)

$script:WasClicked = $false
$button.Add_Click({ $script:WasClicked = $true })

$original = Get-CursorPosition
$passed = $false
try {
    $form.Show()
    $form.BringToFront()
    $form.Activate()
    Start-Sleep -Milliseconds 150
    [System.Windows.Forms.Application]::DoEvents()

    $buttonCenter = $form.PointToScreen(
        (New-Object System.Drawing.Point(
            ($button.Left + [int]($button.Width / 2)),
            ($button.Top + [int]($button.Height / 2))
        ))
    )

    Invoke-QuickClickAndRestore -X $buttonCenter.X -Y $buttonCenter.Y | Out-Null
    Start-Sleep -Milliseconds 120
    [System.Windows.Forms.Application]::DoEvents()

    $restored = Get-CursorPosition
    if (-not $script:WasClicked) {
        throw '目标按钮没有收到模拟点击'
    }
    if ($restored.X -ne $original.X -or $restored.Y -ne $original.Y) {
        throw "鼠标未恢复：原位置=($($original.X),$($original.Y))，当前位置=($($restored.X),$($restored.Y))"
    }

    $passed = $true
    Write-Output 'PASS 模拟点击后鼠标恢复原位置'
}
finally {
    Set-CursorPosition -X $original.X -Y $original.Y | Out-Null
    $form.Close()
    $form.Dispose()
}

if (-not $passed) {
    exit 1
}
