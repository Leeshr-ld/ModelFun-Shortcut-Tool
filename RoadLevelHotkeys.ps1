#requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$SelfTest,
    [switch]$Diagnostic,
    [switch]$UiSmokeTest,
    [string]$UiSmokeLanguage = '',
    [string]$UiSmokeScreenshotPath = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$dpiSupportPath = Join-Path $PSScriptRoot 'DpiSupport.ps1'
if (-not (Test-Path -LiteralPath $dpiSupportPath -PathType Leaf)) {
    throw "缺少DPI支持文件：$dpiSupportPath"
}
. $dpiSupportPath
$localizationPath = Join-Path $PSScriptRoot 'Localization.ps1'
if (-not (Test-Path -LiteralPath $localizationPath -PathType Leaf)) {
    throw "缺少语言资源文件：$localizationPath"
}
. $localizationPath
$script:UiSmokeLanguageOverride = if ([string]::IsNullOrWhiteSpace($UiSmokeLanguage)) {
    ''
}
else {
    Resolve-UiLanguage $UiSmokeLanguage
}
$script:UiLanguage = if ($script:UiSmokeLanguageOverride) {
    $script:UiSmokeLanguageOverride
}
else {
    'zh-CN'
}
try {
    $script:DpiInitialization = Initialize-PerMonitorDpiAwareness
}
catch {
    $script:DpiInitialization = [pscustomobject]@{
        SetSucceeded = $false
        ErrorCode = 0
        Awareness = 1
        IsReady = $false
        ErrorMessage = $_.Exception.Message
    }
}
$script:DpiReady = [bool]$script:DpiInitialization.IsReady

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not ([System.Management.Automation.PSTypeName]'RoadLevel.WinApi').Type) {
    $compileReferences = @('System.Windows.Forms.dll', 'System.Drawing.dll')
    $winFormsPrimitives = Join-Path $PSHOME 'System.Windows.Forms.Primitives.dll'
    if (Test-Path -LiteralPath $winFormsPrimitives) {
        $compileReferences += $winFormsPrimitives
    }
    $componentPrimitives = Join-Path $PSHOME 'System.ComponentModel.Primitives.dll'
    if (Test-Path -LiteralPath $componentPrimitives) {
        $compileReferences += $componentPrimitives
    }

    Add-Type -ReferencedAssemblies $compileReferences -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace RoadLevel
{
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public struct POINT
    {
        public int X;
        public int Y;
    }

    public static class WinApi
    {
        private const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
        private const uint MOUSEEVENTF_LEFTUP = 0x0004;

        private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);

        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        [DllImport("user32.dll")]
        private static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

        [DllImport("user32.dll")]
        private static extern bool ClientToScreen(IntPtr hWnd, ref POINT point);

        [DllImport("user32.dll")]
        private static extern bool GetCursorPos(out POINT point);

        [DllImport("user32.dll")]
        private static extern bool SetCursorPos(int x, int y);

        [DllImport("user32.dll")]
        private static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);

        [DllImport("user32.dll")]
        private static extern short GetAsyncKeyState(int virtualKey);

        [DllImport("user32.dll")]
        private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint modifiers, uint virtualKey);

        [DllImport("user32.dll")]
        private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

        [DllImport("user32.dll")]
        private static extern IntPtr GetDC(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern int ReleaseDC(IntPtr hWnd, IntPtr hdc);

        [DllImport("gdi32.dll")]
        private static extern uint GetPixel(IntPtr hdc, int x, int y);

        [DllImport("user32.dll")]
        private static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern bool IsIconic(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr hWnd, int command);

        [DllImport("kernel32.dll")]
        private static extern void Sleep(uint milliseconds);

        public static string GetWindowTitle(IntPtr hWnd)
        {
            StringBuilder text = new StringBuilder(1024);
            GetWindowText(hWnd, text, text.Capacity);
            return text.ToString();
        }

        public static IntPtr FindWindowContaining(string fragment)
        {
            IntPtr found = IntPtr.Zero;
            if (String.IsNullOrWhiteSpace(fragment))
                return found;

            EnumWindows(delegate(IntPtr hWnd, IntPtr lParam)
            {
                if (!IsWindowVisible(hWnd))
                    return true;

                string title = GetWindowTitle(hWnd);
                if (title.IndexOf(fragment, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    found = hWnd;
                    return false;
                }
                return true;
            }, IntPtr.Zero);

            return found;
        }

        public static IntPtr FindPanelWindow(IntPtr targetWindow, string[] titles)
        {
            if (targetWindow == IntPtr.Zero)
                return IntPtr.Zero;

            uint targetProcessId;
            GetWindowThreadProcessId(targetWindow, out targetProcessId);
            return FindPanelWindowInProcess(targetProcessId, titles);
        }

        public static IntPtr FindPanelWindowInProcess(uint targetProcessId, string[] titles)
        {
            IntPtr firstMatch = IntPtr.Zero;
            IntPtr foregroundMatch = IntPtr.Zero;
            if (targetProcessId == 0 || titles == null || titles.Length == 0)
                return IntPtr.Zero;

            IntPtr foreground = GetForegroundWindow();

            EnumWindows(delegate(IntPtr hWnd, IntPtr lParam)
            {
                if (!IsWindowVisible(hWnd))
                    return true;

                uint processId;
                GetWindowThreadProcessId(hWnd, out processId);
                if (processId != targetProcessId)
                    return true;

                string title = GetWindowTitle(hWnd);
                for (int i = 0; i < titles.Length; i++)
                {
                    if (String.Equals(title, titles[i], StringComparison.Ordinal))
                    {
                        if (firstMatch == IntPtr.Zero)
                            firstMatch = hWnd;
                        if (hWnd == foreground)
                        {
                            foregroundMatch = hWnd;
                            return false;
                        }
                        break;
                    }
                }
                return true;
            }, IntPtr.Zero);

            return foregroundMatch != IntPtr.Zero ? foregroundMatch : firstMatch;
        }

        public static bool IsTargetActive(IntPtr targetWindow, string titleFragment)
        {
            if (targetWindow == IntPtr.Zero)
                return false;

            IntPtr foreground = GetForegroundWindow();
            if (foreground == targetWindow)
                return true;

            uint targetProcessId;
            uint foregroundProcessId;
            GetWindowThreadProcessId(targetWindow, out targetProcessId);
            GetWindowThreadProcessId(foreground, out foregroundProcessId);

            if (targetProcessId != 0 && targetProcessId == foregroundProcessId)
                return true;

            string title = GetWindowTitle(foreground);
            return title.IndexOf(titleFragment, StringComparison.OrdinalIgnoreCase) >= 0;
        }

        public static POINT GetCursorPosition()
        {
            POINT point;
            GetCursorPos(out point);
            return point;
        }

        public static POINT GetClientOrigin(IntPtr hWnd)
        {
            POINT point = new POINT();
            point.X = 0;
            point.Y = 0;
            ClientToScreen(hWnd, ref point);
            return point;
        }

        public static RECT GetWindowBounds(IntPtr hWnd)
        {
            RECT rect;
            GetWindowRect(hWnd, out rect);
            return rect;
        }

        public static bool IsPointInsideWindow(IntPtr hWnd, POINT point)
        {
            RECT rect = GetWindowBounds(hWnd);
            return point.X >= rect.Left && point.X <= rect.Right &&
                   point.Y >= rect.Top && point.Y <= rect.Bottom;
        }

        public static bool IsKeyDown(int virtualKey)
        {
            return (GetAsyncKeyState(virtualKey) & 0x8000) != 0;
        }

        public static void LeftClick(int x, int y)
        {
            SetCursorPos(x, y);
            mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
            Sleep(18);
            mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
        }

        public static bool RegisterGlobalHotkey(IntPtr hWnd, int id, uint modifiers, uint virtualKey)
        {
            return RegisterHotKey(hWnd, id, modifiers | 0x4000, virtualKey);
        }

        public static void UnregisterGlobalHotkey(IntPtr hWnd, int id)
        {
            UnregisterHotKey(hWnd, id);
        }

        public static void ActivateWindow(IntPtr hWnd)
        {
            if (hWnd != IntPtr.Zero)
            {
                if (IsIconic(hWnd))
                    ShowWindow(hWnd, 9);
                SetForegroundWindow(hWnd);
            }
        }

        private static uint GetScreenPixel(int x, int y)
        {
            IntPtr hdc = GetDC(IntPtr.Zero);
            try
            {
                return GetPixel(hdc, x, y);
            }
            finally
            {
                ReleaseDC(IntPtr.Zero, hdc);
            }
        }

        private static bool IsLight(uint color)
        {
            int red = (int)(color & 0xFF);
            int green = (int)((color >> 8) & 0xFF);
            int blue = (int)((color >> 16) & 0xFF);
            return red >= 195 && green >= 195 && blue >= 195;
        }

        private static bool IsDark(uint color)
        {
            int red = (int)(color & 0xFF);
            int green = (int)((color >> 8) & 0xFF);
            int blue = (int)((color >> 16) & 0xFF);
            return red <= 135 && green <= 135 && blue <= 135;
        }

        public static bool IsExpectedPanelVisible(int panelX, int panelY, double scaleX, double scaleY)
        {
            int headerA = (int)Math.Round(12 * scaleX);
            int headerB = (int)Math.Round(205 * scaleX);
            int headerY = (int)Math.Round(10 * scaleY);
            int bodyA = (int)Math.Round(6 * scaleX);
            int bodyB = (int)Math.Round(238 * scaleX);
            int bodyY = (int)Math.Round(62 * scaleY);

            uint header1 = GetScreenPixel(panelX + headerA, panelY + headerY);
            uint header2 = GetScreenPixel(panelX + headerB, panelY + headerY);
            uint body1 = GetScreenPixel(panelX + bodyA, panelY + bodyY);
            uint body2 = GetScreenPixel(panelX + bodyB, panelY + bodyY);

            return IsLight(header1) && IsLight(header2) && IsDark(body1) && IsDark(body2);
        }
    }

    public sealed class HotkeyNativeWindow : NativeWindow, IDisposable
    {
        public event Action<int> HotkeyPressed;
        private bool disposed;

        public HotkeyNativeWindow()
        {
            CreateHandle(new CreateParams());
        }

        public IntPtr HotkeyHandle
        {
            get { return Handle; }
        }

        protected override void WndProc(ref Message message)
        {
            if (message.Msg == 0x0312 && HotkeyPressed != null)
                HotkeyPressed(message.WParam.ToInt32());
            base.WndProc(ref message);
        }

        public void Dispose()
        {
            if (!disposed)
            {
                if (Handle != IntPtr.Zero)
                    DestroyHandle();
                disposed = true;
                GC.SuppressFinalize(this);
            }
        }
    }

    public sealed class HotkeyForm : Form
    {
        public event Action<int> HotkeyPressed;

        protected override void WndProc(ref Message message)
        {
            if (message.Msg == 0x0312 && HotkeyPressed != null)
                HotkeyPressed(message.WParam.ToInt32());
            base.WndProc(ref message);
        }
    }
}
'@
}

$script:AppDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ConfigPath = Join-Path $script:AppDirectory 'config.json'
$script:ConfigBackupDirectory = Join-Path $script:AppDirectory 'config-backups'
$script:ModelShortcutsPath = Join-Path $script:AppDirectory 'model_shortcuts.json'
$script:DiagnosticEnabled = ([bool]$Diagnostic -or [bool]$UiSmokeTest)
$script:UiSmokeTest = [bool]$UiSmokeTest
$script:UiSmokeTestCompleted = $false
$script:UiSmokeTestError = ''
$script:DiagnosticLogPath = Join-Path $script:AppDirectory '诊断日志.txt'
. (Join-Path $script:AppDirectory 'ShortcutRules.ps1')
. (Join-Path $script:AppDirectory 'MouseAutomation.ps1')
. (Join-Path $script:AppDirectory 'BackupWorkflow.ps1')
. (Join-Path $script:AppDirectory 'VersionInfo.ps1')
. (Join-Path $script:AppDirectory 'LayoutPolicy.ps1')
. (Join-Path $script:AppDirectory 'ConfigStorage.ps1')
. (Join-Path $script:AppDirectory 'SingleInstance.ps1')
$script:VersionPath = Join-Path $script:AppDirectory 'version.json'
$script:VersionInfo = Get-AppVersionInfo -Path $script:VersionPath
$script:AppVersion = [string]$script:VersionInfo.version
$script:ActionOrder = @(
    'backup',
    'slot1', 'slot2', 'slot3', 'slot4', 'slot5', 'slot6', 'slot7', 'slot8',
    'toggle1', 'toggle2', 'undo', 'redo', 'confirm', 'cancel'
)
$script:PanelTitles = @('道路置平', '表面置平', '指定置平', '补洞')
$script:PanelProfiles = @{
    '道路置平' = @{
        referenceWidth = 230
        referenceHeight = 181
        buttons = [ordered]@{
            slot1 = [pscustomobject]@{ label = '操作图标'; x = 54; y = 130 }
            undo = [pscustomobject]@{ label = '撤销'; x = 122; y = 130 }
            redo = [pscustomobject]@{ label = '重做'; x = 188; y = 130 }
            confirm = [pscustomobject]@{ label = '确认'; x = 69; y = 163 }
            cancel = [pscustomobject]@{ label = '取消'; x = 176; y = 163 }
        }
    }
    '表面置平' = @{
        referenceWidth = 267
        referenceHeight = 202
        buttons = [ordered]@{
            slot1 = [pscustomobject]@{ label = '操作图标'; x = 52; y = 110 }
            slot2 = [pscustomobject]@{ label = '应用/勾选'; x = 105; y = 110 }
            undo = [pscustomobject]@{ label = '撤销'; x = 158; y = 110 }
            redo = [pscustomobject]@{ label = '重做'; x = 211; y = 110 }
            confirm = [pscustomobject]@{ label = '确认'; x = 67; y = 162 }
            cancel = [pscustomobject]@{ label = '取消'; x = 176; y = 162 }
        }
    }
    '指定置平' = @{
        referenceWidth = 368
        referenceHeight = 265
        buttons = [ordered]@{
            slot1 = [pscustomobject]@{ label = '操作图标'; x = 54; y = 119 }
            slot2 = [pscustomobject]@{ label = '曲线/路径'; x = 107; y = 119 }
            slot3 = [pscustomobject]@{ label = '应用/勾选'; x = 160; y = 119 }
            slot4 = [pscustomobject]@{ label = '更多选项'; x = 213; y = 119 }
            undo = [pscustomobject]@{ label = '撤销'; x = 266; y = 119 }
            redo = [pscustomobject]@{ label = '重做'; x = 319; y = 119 }
            toggle1 = [pscustomobject]@{ label = '隐藏平面'; x = 82; y = 130 }
            toggle2 = [pscustomobject]@{ label = '优化切割线'; x = 82; y = 162 }
            confirm = [pscustomobject]@{ label = '确定'; x = 97; y = 235 }
            cancel = [pscustomobject]@{ label = '取消'; x = 270; y = 235 }
        }
    }
    '补洞' = @{
        referenceWidth = 274
        referenceHeight = 404
        buttons = [ordered]@{
            slot1 = [pscustomobject]@{ label = '填充方式1'; x = 72; y = 103 }
            slot2 = [pscustomobject]@{ label = '填充方式2'; x = 141; y = 103 }
            slot3 = [pscustomobject]@{ label = '填充方式3'; x = 210; y = 103 }
            slot4 = [pscustomobject]@{ label = '填充方式4'; x = 141; y = 139 }
            slot5 = [pscustomobject]@{ label = '编辑三角形1'; x = 92; y = 222 }
            slot6 = [pscustomobject]@{ label = '编辑三角形2'; x = 186; y = 222 }
            undo = [pscustomobject]@{ label = '撤销'; x = 95; y = 303 }
            redo = [pscustomobject]@{ label = '重做'; x = 180; y = 303 }
            confirm = [pscustomobject]@{ label = '确认'; x = 83; y = 360 }
            cancel = [pscustomobject]@{ label = '取消'; x = 188; y = 360 }
        }
    }
}
$script:Calibration = $null
$script:Enabled = $true
$script:VerifyPanel = $true
$script:HotkeysRegistered = $false
$script:RegisteredPanelTitle = ''
$script:MainForm = $null
$script:EditingShortcuts = $false
$script:GridActionNames = @()
$script:ModelShortcutConflicts = @()
$script:HotkeyIds = @{}
$script:MouseWasDown = @{}
$script:KeyboardWasDown = @{}
$script:DiagnosticF12WasDown = $false
$script:CalibrationOverlay = $null
$script:CalibrationStep = 0
$script:CalibrationFirstPoint = $null
$script:CalibrationWindow = [IntPtr]::Zero
$script:CalibrationF7WasDown = $false
$script:LastPanelTitle = ''
$script:LastMessage = ''
$script:ConfigRecoveryNotice = ''
$script:SingleInstanceGuard = $null
$script:SuppressLanguageChange = $false

function T([string]$Key, [hashtable]$Tokens = @{}) {
    return Get-UiText -Key $Key -Language $script:UiLanguage -Tokens $Tokens
}

$script:ConfigValidator = {
    param($Config)
    ConvertTo-ValidatedShortcutConfig -Config $Config
}

function Write-Config {
    $null = Save-ConfigFile `
        -ConfigPath $script:ConfigPath `
        -Config $script:Config `
        -BackupDirectory $script:ConfigBackupDirectory `
        -Validator $script:ConfigValidator
}

function Write-DiagnosticLog([string]$message) {
    if (-not $script:DiagnosticEnabled) {
        return
    }
    $line = '{0} {1}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff'), $message
    Add-Content -LiteralPath $script:DiagnosticLogPath -Value $line -Encoding UTF8
}

function Get-DefaultConfig {
    return New-DefaultShortcutConfig -TargetTitle '模方ModelFun'
}

function Load-Config {
    if (-not (Test-Path -LiteralPath $script:ConfigPath)) {
        $script:Config = & $script:ConfigValidator (Get-DefaultConfig)
        $loadedVersion = 5
        Write-Config
    }
    else {
        $loadedConfig = Read-ConfigFileWithRecovery `
            -ConfigPath $script:ConfigPath `
            -BackupDirectory $script:ConfigBackupDirectory `
            -Validator $script:ConfigValidator
        $script:Config = $loadedConfig.Config
        $loadedVersion = [int]$loadedConfig.SourceVersion
        if ($loadedConfig.Restored) {
            $script:ConfigRecoveryNotice = "RECOVERED_FROM=$($loadedConfig.RestoredFrom)"
        }
    }

    $script:Config = & $script:ConfigValidator $script:Config
    if ($loadedVersion -lt 5) {
        Write-Config
    }

    $script:UiLanguage = if ($script:UiSmokeLanguageOverride) {
        $script:UiSmokeLanguageOverride
    }
    else {
        Resolve-UiLanguage ([string]$script:Config.language)
    }

    if (Test-Path -LiteralPath $script:ModelShortcutsPath) {
        $script:ModelShortcutConflicts = @(
            Get-Content -LiteralPath $script:ModelShortcutsPath -Raw -Encoding UTF8 |
                ConvertFrom-Json
        )
    }
    else {
        $script:ModelShortcutConflicts = @()
    }
}

function Test-KeyDown([int]$virtualKey) {
    return [RoadLevel.WinApi]::IsKeyDown($virtualKey)
}

function Get-BindingKeyCode($binding) {
    if ([string]::IsNullOrWhiteSpace([string]$binding.key)) {
        return $null
    }

    $keyName = ConvertTo-ShortcutKeyName ([string]$binding.key)

    try {
        $parsed = [System.Enum]::Parse(
            [System.Windows.Forms.Keys],
            $keyName,
            $true
        )
        return [int]$parsed
    }
    catch {
        return $null
    }
}

function Format-Binding($binding) {
    $parts = New-Object System.Collections.Generic.List[string]
    if ($binding.ctrl -eq $true) { $parts.Add('Ctrl') }
    if ($binding.alt -eq $true) { $parts.Add('Alt') }
    if ($binding.shift -eq $true) { $parts.Add('Shift') }
    if (-not [string]::IsNullOrWhiteSpace([string]$binding.key)) {
        $parts.Add([string]$binding.key)
    }
    if ($parts.Count -eq 0) {
        return T 'format.unbound'
    }
    return ($parts -join '+')
}

function Format-MouseBinding($binding) {
    switch ([string]$binding.mouseButton) {
        'XButton1' { return (T 'mouse.side1') }
        'XButton2' { return (T 'mouse.side2') }
        default { return (T 'mouse.none') }
    }
}

function Get-LocalizedConflictMessage($Conflict) {
    if ($null -eq $Conflict) {
        return ''
    }
    switch ([string]$Conflict.Kind) {
        'Model' {
            return (T 'conflict.model' @{
                shortcut = ([string]$Conflict.Shortcut)
                action = (Get-LocalizedActionCodeLabel -ActionName ([string]$Conflict.ActionName) -Language $script:UiLanguage)
            })
        }
        default {
            return (T 'conflict.internal' @{
                action = (Get-LocalizedActionCodeLabel -ActionName ([string]$Conflict.ActionName) -Language $script:UiLanguage)
            })
        }
    }
}

function Unregister-AllHotkeys {
    if ($null -eq $script:MainForm -or -not $script:MainForm.IsHandleCreated) {
        $script:HotkeyIds.Clear()
        $script:HotkeysRegistered = $false
        $script:RegisteredPanelTitle = ''
        return
    }

    foreach ($id in $script:HotkeyIds.Keys) {
        [RoadLevel.WinApi]::UnregisterGlobalHotkey($script:MainForm.Handle, [int]$id)
    }
    $script:HotkeyIds.Clear()
    $script:HotkeysRegistered = $false
    $script:RegisteredPanelTitle = ''
}

function Register-AllHotkeys {
    if ($script:HotkeysRegistered) {
        return $true
    }
    if ($null -eq $script:MainForm -or -not $script:MainForm.IsHandleCreated) {
        return $false
    }

    $panel = Get-ActivePanel
    $availableActions = New-Object System.Collections.Generic.List[string]
    $availableActions.Add('backup')
    if ($null -ne $panel) {
        foreach ($name in $panel.Profile.buttons.Keys) {
            $availableActions.Add([string]$name)
        }
    }

    $index = 0
    $panelTitle = if ($null -ne $panel) { [string]$panel.Title } else { '' }
    foreach ($name in $availableActions) {
        $binding = Get-ActionBinding -Config $script:Config -PanelTitle $panelTitle -ActionName $name
        if ($null -eq $binding) {
            $index++
            continue
        }
        $keyCode = Get-BindingKeyCode $binding
        if ($null -eq $keyCode) {
            $index++
            continue
        }

        $modifiers = 0
        if ($binding.ctrl -eq $true) { $modifiers = $modifiers -bor 0x0002 }
        if ($binding.alt -eq $true) { $modifiers = $modifiers -bor 0x0001 }
        if ($binding.shift -eq $true) { $modifiers = $modifiers -bor 0x0004 }

        $id = 0x5300 + $index
        $ok = [RoadLevel.WinApi]::RegisterGlobalHotkey(
            $script:MainForm.Handle,
            $id,
            [uint32]$modifiers,
            [uint32]$keyCode
        )
        if (-not $ok) {
            Unregister-AllHotkeys
            Set-Status (T 'status.hotkeyRegistrationFailed' @{ binding = (Format-Binding $binding) }) '#C0392B'
            return $false
        }
        $script:HotkeyIds[$id] = $name
        $index++
    }

    $script:HotkeysRegistered = $true
    $script:RegisteredPanelTitle = if ($null -ne $panel) { [string]$panel.Title } else { '通用' }
    Write-DiagnosticLog ("REGISTERED_PANEL={0}; IDS={1}" -f $script:RegisteredPanelTitle, ($script:HotkeyIds.Keys -join ','))
    return $true
}

function Set-Status([string]$text, [string]$color = '#1F5F99') {
    if (-not $script:DpiReady) {
        $text = T 'status.dpiLimited' @{ message = $text }
    }
    $script:LastMessage = $text
    $statusLabel.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($color)
    $statusLabel.Text = $text
}

function Get-TargetWindow {
    return [RoadLevel.WinApi]::FindWindowContaining([string]$script:Config.targetTitle)
}

function Get-ActivePanel {
    $target = Get-TargetWindow
    if ($target -eq [IntPtr]::Zero) {
        return $null
    }

    $panelHandle = [RoadLevel.WinApi]::FindPanelWindow($target, [string[]]$script:PanelTitles)
    if ($panelHandle -eq [IntPtr]::Zero) {
        return $null
    }

    $panelTitle = [RoadLevel.WinApi]::GetWindowTitle($panelHandle)
    if (-not $script:PanelProfiles.ContainsKey($panelTitle)) {
        return $null
    }

    return [pscustomobject]@{
        Handle = $panelHandle
        Title = $panelTitle
        Bounds = [RoadLevel.WinApi]::GetWindowBounds($panelHandle)
        Profile = $script:PanelProfiles[$panelTitle]
    }
}

function Get-PanelPoint([string]$name) {
    $panel = Get-ActivePanel
    if ($null -eq $panel) {
        return $null
    }

    if (-not $panel.Profile.buttons.Contains($name)) {
        return $null
    }

    $button = $panel.Profile.buttons[$name]
    $scaleInfo = Get-PanelScaleInfo `
        -PanelWidth ($panel.Bounds.Right - $panel.Bounds.Left) `
        -PanelHeight ($panel.Bounds.Bottom - $panel.Bounds.Top) `
        -ReferenceWidth $panel.Profile.referenceWidth `
        -ReferenceHeight $panel.Profile.referenceHeight
    if (-not $scaleInfo.IsReliable) {
        Write-DiagnosticLog ("PANEL_SCALE_UNRELIABLE={0}; X={1:F3}; Y={2:F3}; Deviation={3:F3}" -f $panel.Title, $scaleInfo.ScaleX, $scaleInfo.ScaleY, $scaleInfo.AspectDeviation)
        return $null
    }

    return @{
        X = [int][Math]::Round($panel.Bounds.Left + $button.x * $scaleInfo.ScaleX)
        Y = [int][Math]::Round($panel.Bounds.Top + $button.y * $scaleInfo.ScaleY)
        Title = $panel.Title
        Label = [string]$button.label
    }
}

function Get-DipWorkingArea($OwnerControl) {
    $screen = [System.Windows.Forms.Screen]::FromControl($OwnerControl)
    $scale = [double]$OwnerControl.DeviceDpi / 96.0
    $size = ConvertTo-DipSize -PixelWidth $screen.WorkingArea.Width -PixelHeight $screen.WorkingArea.Height -Scale $scale
    return [pscustomobject]@{
        Width = [int]$size.Width
        Height = [int]$size.Height
        Scale = $scale
    }
}

function Resize-DialogWithinWorkingArea($Dialog, $OwnerControl) {
    $workingArea = Get-DipWorkingArea $OwnerControl
    $size = Get-ClampedDialogSize `
        -WorkingWidthDip $workingArea.Width `
        -WorkingHeightDip $workingArea.Height `
        -DesiredWidth $Dialog.ClientSize.Width `
        -DesiredHeight $Dialog.ClientSize.Height
    $Dialog.MinimumSize = New-Object System.Drawing.Size(
        [Math]::Min($Dialog.MinimumSize.Width, $size.Width),
        [Math]::Min($Dialog.MinimumSize.Height, $size.Height)
    )
    $Dialog.ClientSize = New-Object System.Drawing.Size($size.Width, $size.Height)
}

function Fit-MainFormToWorkingArea {
    $workingArea = Get-DipWorkingArea $form
    $size = Get-PreferredClientSize -WorkingWidthDip $workingArea.Width -WorkingHeightDip $workingArea.Height
    $form.MinimumSize = New-Object System.Drawing.Size(
        [Math]::Min(780, [Math]::Max(560, $size.Width)),
        [Math]::Min(540, [Math]::Max(420, $size.Height))
    )
    $form.ClientSize = New-Object System.Drawing.Size($size.Width, $size.Height)
}

function Wait-ForWindowTitle([string]$TitleFragment, [int]$TimeoutMilliseconds = 5000) {
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        $handle = [RoadLevel.WinApi]::FindWindowContaining($TitleFragment)
        if ($handle -ne [IntPtr]::Zero) {
            return $handle
        }
        Start-Sleep -Milliseconds 40
    } while ([DateTime]::UtcNow -lt $deadline)
    return [IntPtr]::Zero
}

function Invoke-BackupWorkflow {
    $target = Get-TargetWindow
    if ($target -eq [IntPtr]::Zero) {
        Set-Status (T 'status.backupNoModelWindow') '#C0392B'
        return
    }
    if (-not [RoadLevel.WinApi]::IsTargetActive($target, [string]$script:Config.targetTitle)) {
        Set-Status (T 'status.backupNotForeground') '#C0392B'
        return
    }

    $dialogHandle = [RoadLevel.WinApi]::FindWindowContaining('备份和恢复')
    if ($dialogHandle -eq [IntPtr]::Zero) {
        $client = [RoadLevel.WinApi]::GetClientOrigin($target)
        $backupButtonX = $client.X + 290
        $backupButtonY = $client.Y + 94
        Write-DiagnosticLog ("BACKUP_STEP=open-dialog; POINT={0},{1}" -f $backupButtonX, $backupButtonY)
        if ($script:DiagnosticEnabled) {
            Set-Status (T 'status.backupDiagnostic') '#B9770E'
            return
        }
        Invoke-QuickClickAndRestore -X $backupButtonX -Y $backupButtonY | Out-Null
        $dialogHandle = Wait-ForWindowTitle -TitleFragment '备份和恢复' -TimeoutMilliseconds 5000
    }

    if ($dialogHandle -eq [IntPtr]::Zero) {
        Set-Status (T 'status.backupDialogTimeout') '#C0392B'
        return
    }

    $dialogBounds = [RoadLevel.WinApi]::GetWindowBounds($dialogHandle)
    $points = Get-BackupDialogPoints -Bounds $dialogBounds
    Write-DiagnosticLog ("BACKUP_STEP=select-all; POINT={0},{1}" -f $points.SelectAllX, $points.SelectAllY)
    Invoke-QuickClickAndRestore -X $points.SelectAllX -Y $points.SelectAllY | Out-Null
    Start-Sleep -Milliseconds 50
    Write-DiagnosticLog ("BACKUP_STEP=backup-now; POINT={0},{1}" -f $points.BackupNowX, $points.BackupNowY)
    Invoke-QuickClickAndRestore -X $points.BackupNowX -Y $points.BackupNowY | Out-Null
    Set-Status (T 'status.backupComplete') '#1E8449'
}

function Invoke-PanelButton([string]$name) {
    $target = Get-TargetWindow
    if ($target -eq [IntPtr]::Zero) {
        Set-Status (T 'status.clickNoModelWindow') '#C0392B'
        return
    }
    if (-not [RoadLevel.WinApi]::IsTargetActive($target, [string]$script:Config.targetTitle)) {
        Set-Status (T 'status.clickNotForeground') '#C0392B'
        return
    }

    if ($name -eq 'backup') {
        Invoke-BackupWorkflow
        return
    }

    $panel = Get-ActivePanel
    if ($null -eq $panel) {
        Set-Status (T 'status.panelNotRecognized') '#C0392B'
        return
    }
    if (-not $panel.Profile.buttons.Contains($name)) {
        $bindingName = Get-LocalizedActionCodeLabel -ActionName $name -Language $script:UiLanguage
        Set-Status (T 'status.actionUnavailable' @{
            panel = (Get-LocalizedPanelTitle -PanelTitle $panel.Title -Language $script:UiLanguage)
            action = $bindingName
        }) '#B9770E'
        return
    }

    $point = Get-PanelPoint $name
    if ($null -eq $point) {
        Set-Status (T 'status.panelPointFailed') '#C0392B'
        return
    }

    Write-DiagnosticLog ("ACTION={0}; PANEL={1}; LABEL={2}; POINT={3},{4}" -f $name, $point.Title, $point.Label, $point.X, $point.Y)
    if ($script:DiagnosticEnabled) {
        Set-Status (T 'status.diagnosticClick' @{
            label = (Get-LocalizedActionLabel -Label $point.Label -Language $script:UiLanguage)
            x = $point.X
            y = $point.Y
        }) '#B9770E'
        return
    }

    Invoke-QuickClickAndRestore -X $point.X -Y $point.Y | Out-Null
    Set-Status (T 'status.clicked' @{
        panel = (Get-LocalizedPanelTitle -PanelTitle $point.Title -Language $script:UiLanguage)
        label = (Get-LocalizedActionLabel -Label $point.Label -Language $script:UiLanguage)
    }) '#1E8449'
}

function Update-HotkeyRegistration {
    if ($script:EditingShortcuts) {
        if ($script:HotkeysRegistered) {
            Unregister-AllHotkeys
        }
        return
    }
    $target = Get-TargetWindow
    $active = $target -ne [IntPtr]::Zero -and [RoadLevel.WinApi]::IsTargetActive($target, [string]$script:Config.targetTitle)
    $panel = if ($active) { Get-ActivePanel } else { $null }

    $registrationKey = if ($null -ne $panel) { [string]$panel.Title } else { '通用' }
    if ($script:HotkeysRegistered -and $script:RegisteredPanelTitle -ne $registrationKey) {
        Unregister-AllHotkeys
    }

    if ($script:Enabled -and $active) {
        if (-not $script:HotkeysRegistered) {
            [void](Register-AllHotkeys)
        }
    }
    elseif ($script:HotkeysRegistered) {
        Unregister-AllHotkeys
    }
}

function Poll-MouseBindings {
    if ($script:EditingShortcuts) {
        return
    }
    $target = Get-TargetWindow
    $active = $target -ne [IntPtr]::Zero -and [RoadLevel.WinApi]::IsTargetActive($target, [string]$script:Config.targetTitle)
    $panel = if ($active) { Get-ActivePanel } else { $null }
    $panelTitle = if ($null -ne $panel) { [string]$panel.Title } else { '' }

    foreach ($name in $script:ActionOrder) {
        $binding = Get-ActionBinding -Config $script:Config -PanelTitle $panelTitle -ActionName $name
        $virtualKey = 0
        if ($null -eq $binding) {
            $script:MouseWasDown[$name] = $false
            continue
        }
        switch ([string]$binding.mouseButton) {
            'XButton1' { $virtualKey = 0x05 }
            'XButton2' { $virtualKey = 0x06 }
            default { $virtualKey = 0 }
        }

        $down = $false
        if ($virtualKey -ne 0) {
            $down = [RoadLevel.WinApi]::IsKeyDown($virtualKey)
        }

        $wasDown = $false
        if ($script:MouseWasDown.ContainsKey($name)) {
            $wasDown = [bool]$script:MouseWasDown[$name]
        }
        if ($script:Enabled -and $active -and $down -and -not $wasDown) {
            Invoke-PanelButton $name
        }
        $script:MouseWasDown[$name] = $down
    }
}

function Poll-KeyboardBindings {
    $target = Get-TargetWindow
    $active = $target -ne [IntPtr]::Zero -and [RoadLevel.WinApi]::IsTargetActive($target, [string]$script:Config.targetTitle)
    $panel = if ($active) { Get-ActivePanel } else { $null }
    $panelTitle = if ($null -ne $panel) { [string]$panel.Title } else { '' }
    $ctrlDown = [RoadLevel.WinApi]::IsKeyDown(0x11)
    $altDown = [RoadLevel.WinApi]::IsKeyDown(0x12)
    $shiftDown = [RoadLevel.WinApi]::IsKeyDown(0x10)

    if ($script:DiagnosticEnabled) {
        $diagnosticF12Down = $ctrlDown -and $altDown -and $shiftDown -and [RoadLevel.WinApi]::IsKeyDown(0x7B)
        if ($diagnosticF12Down -and -not $script:DiagnosticF12WasDown) {
            Write-DiagnosticLog 'POLL_TEST_F12'
        }
        $script:DiagnosticF12WasDown = $diagnosticF12Down
    }

    foreach ($name in $script:ActionOrder) {
        $binding = Get-ActionBinding -Config $script:Config -PanelTitle $panelTitle -ActionName $name
        if ($null -eq $binding) {
            $script:KeyboardWasDown[$name] = $false
            continue
        }
        $keyCode = Get-BindingKeyCode $binding
        $down = $false
        if ($null -ne $keyCode) {
            $down = [RoadLevel.WinApi]::IsKeyDown([int]$keyCode)
            if ($binding.ctrl -eq $true -and -not $ctrlDown) { $down = $false }
            if ($binding.alt -eq $true -and -not $altDown) { $down = $false }
            if ($binding.shift -eq $true -and -not $shiftDown) { $down = $false }
        }

        $wasDown = $false
        if ($script:KeyboardWasDown.ContainsKey($name)) {
            $wasDown = [bool]$script:KeyboardWasDown[$name]
        }
        if ($script:Enabled -and $active -and $down -and -not $wasDown) {
            Write-DiagnosticLog ("KEYBOARD_EDGE={0}" -f $name)
            Invoke-PanelButton $name
        }
        $script:KeyboardWasDown[$name] = $down
    }
}

function Refresh-BindingGrid($panel) {
    $bindingGrid.Rows.Clear()
    $script:GridActionNames = @()

    $warningMessages = New-Object System.Collections.Generic.List[string]
    $displayItems = [ordered]@{
        backup = [pscustomobject]@{ label = '备份当前工程瓦片' }
    }
    if ($null -ne $panel) {
        foreach ($entry in $panel.Profile.buttons.GetEnumerator()) {
            $displayItems[$entry.Key] = $entry.Value
        }
    }
    $panelTitle = if ($null -ne $panel) { [string]$panel.Title } else { '' }
    $conflictScope = Get-ConflictScopeBindings -Config $script:Config -PanelTitle $panelTitle

    foreach ($entry in $displayItems.GetEnumerator()) {
        $name = [string]$entry.Key
        $button = $entry.Value
        $binding = Get-ActionBinding -Config $script:Config -PanelTitle $panelTitle -ActionName $name
        $conflicts = @()
        if ($name -eq 'backup') {
            $globalConflict = Find-GlobalBackupConflict -Candidate $binding -Config $script:Config -ModelConflicts $script:ModelShortcutConflicts
            if ($null -ne $globalConflict) {
                $conflicts = @($globalConflict)
            }
        }
        else {
            $conflicts = @(Get-BindingConflictList -ActionName $name -Binding $binding -Bindings $conflictScope -ModelConflicts $script:ModelShortcutConflicts)
        }
        $status = T 'row.normal'
        $statusColor = [System.Drawing.Color]::FromArgb(30, 105, 60)
        if ($conflicts.Count -gt 0) {
            foreach ($conflict in $conflicts) {
                $localizedConflictMessage = Get-LocalizedConflictMessage $conflict
                if (-not $warningMessages.Contains($localizedConflictMessage)) {
                    $warningMessages.Add($localizedConflictMessage)
                }
            }
            if (@($conflicts | Where-Object Kind -eq 'Model').Count -gt 0) {
                $status = T 'row.modelConflict'
                $statusColor = [System.Drawing.Color]::FromArgb(180, 95, 0)
            }
            else {
                $status = T 'row.duplicate'
                $statusColor = [System.Drawing.Color]::FromArgb(180, 40, 40)
            }
        }

        $rowIndex = $bindingGrid.Rows.Add(
            (Get-LocalizedActionLabel -Label ([string]$button.label) -Language $script:UiLanguage),
            (Format-Binding $binding),
            (Format-MouseBinding $binding),
            $status
        )
        $script:GridActionNames += $name
        $row = $bindingGrid.Rows[$rowIndex]
        $row.Cells[3].Style.ForeColor = $statusColor
        $row.Cells[3].Style.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9, [System.Drawing.FontStyle]::Bold)
        if ($conflicts.Count -gt 0) {
            $conflictText = ($conflicts | ForEach-Object { Get-LocalizedConflictMessage $_ }) -join "`r`n"
            $row.Cells[3].ToolTipText = $conflictText
            $row.Cells[1].ToolTipText = $conflictText
        }
    }

    if ($warningMessages.Count -gt 0) {
        $shortcutNoticeLabel.Text = T 'notice.conflicts' @{
            count = $warningMessages.Count
            first = $warningMessages[0]
        }
        $shortcutNoticeLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 95, 0)
    }
    elseif ($null -eq $panel) {
        $shortcutNoticeLabel.Text = T 'notice.noPanel'
        $shortcutNoticeLabel.ForeColor = [System.Drawing.Color]::FromArgb(30, 105, 60)
    }
    else {
        $shortcutNoticeLabel.Text = T 'notice.noConflict'
        $shortcutNoticeLabel.ForeColor = [System.Drawing.Color]::FromArgb(30, 105, 60)
    }

    $backupDisplay = Get-ShortcutDisplay (Get-ActionBinding -Config $script:Config -PanelTitle '' -ActionName 'backup')
    $hintLabel.Text = T 'status.hint' @{ backup = $backupDisplay }
}

function Close-CalibrationOverlay {
    if ($null -ne $script:CalibrationOverlay) {
        $script:CalibrationOverlay.Close()
        $script:CalibrationOverlay.Dispose()
        $script:CalibrationOverlay = $null
    }
    $script:CalibrationStep = 0
    $script:CalibrationFirstPoint = $null
    $script:CalibrationWindow = [IntPtr]::Zero
    $script:CalibrationF7WasDown = $false
}

function Start-Calibration {
    $target = Get-TargetWindow
    if ($target -eq [IntPtr]::Zero) {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'dialog.modelWindowMissingBody'),
            (T 'dialog.modelWindowMissingTitle'),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    Close-CalibrationOverlay
    Unregister-AllHotkeys
    $script:CalibrationWindow = $target
    $script:CalibrationStep = 1

    $overlay = New-Object System.Windows.Forms.Form
    $overlay.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
    $overlay.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $overlay.TopMost = $true
    $overlay.ShowInTaskbar = $false
    $overlay.BackColor = [System.Drawing.Color]::FromArgb(38, 48, 61)
    $overlay.ForeColor = [System.Drawing.Color]::White
    $overlay.ClientSize = New-Object System.Drawing.Size(650, 112)
    $overlay.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    Resize-DialogWithinWorkingArea -Dialog $overlay -OwnerControl $form

    $workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $overlay.Left = $workingArea.Left + [int](($workingArea.Width - $overlay.Width) / 2)
    $overlay.Top = $workingArea.Top + 28

    $overlayLabel = New-Object System.Windows.Forms.Label
    $overlayLabel.AutoSize = $false
    $overlayLabel.Left = 20
    $overlayLabel.Top = 16
    $overlayLabel.Width = 610
    $overlayLabel.Height = 50
    $overlayLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 11, [System.Drawing.FontStyle]::Bold)
    $overlayLabel.ForeColor = [System.Drawing.Color]::White
    $overlayLabel.Text = T 'calibration.step1'
    $overlay.Controls.Add($overlayLabel)

    $overlayHint = New-Object System.Windows.Forms.Label
    $overlayHint.AutoSize = $false
    $overlayHint.Left = 20
    $overlayHint.Top = 70
    $overlayHint.Width = 430
    $overlayHint.Height = 25
    $overlayHint.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
    $overlayHint.ForeColor = [System.Drawing.Color]::FromArgb(205, 215, 225)
    $overlayHint.Text = T 'calibration.hint'
    $overlay.Controls.Add($overlayHint)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = T 'button.cancelCalibration'
    $cancelButton.Left = 540
    $cancelButton.Top = 66
    $cancelButton.Width = 90
    $cancelButton.Height = 30
    $cancelButton.Add_Click({ Close-CalibrationOverlay })
    $overlay.Controls.Add($cancelButton)

    $script:CalibrationOverlay = $overlay
    $script:CalibrationOverlayLabel = $overlayLabel
    $overlay.Show()
    $overlay.Activate()
    Set-Status (T 'status.calibrationWaiting') '#B9770E'
}

function Complete-Calibration($firstPoint, $secondPoint) {
    $deltaX = [double]$secondPoint.X - [double]$firstPoint.X
    $deltaY = [double]$secondPoint.Y - [double]$firstPoint.Y

    if ($deltaX -le 0 -or $deltaY -le 0) {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'message.calibrationOrder'),
            (T 'message.calibrationFailedTitle'),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        Start-Calibration
        return
    }

    $scaleX = $deltaX / 122.0
    $scaleY = $deltaY / 54.0
    $ratio = $scaleX / $scaleY
    if ($scaleX -lt 0.45 -or $scaleX -gt 3.2 -or $scaleY -lt 0.45 -or $scaleY -gt 3.2 -or $ratio -lt 0.65 -or $ratio -gt 1.55) {
        $errorMessage = T 'message.calibrationRatio' @{
            x = ('{0:N2}' -f $scaleX)
            y = ('{0:N2}' -f $scaleY)
        }
        [System.Windows.Forms.MessageBox]::Show(
            $errorMessage,
            (T 'message.calibrationFailedTitle'),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        Start-Calibration
        return
    }

    $client = [RoadLevel.WinApi]::GetClientOrigin($script:CalibrationWindow)
    $offsetX = [double]$firstPoint.X - $client.X - 54.0 * $scaleX
    $offsetY = [double]$firstPoint.Y - $client.Y - 120.0 * $scaleY

    $calibration = [pscustomobject]@{
        completed = $true
        offsetX = [Math]::Round($offsetX, 4)
        offsetY = [Math]::Round($offsetY, 4)
        scaleX = [Math]::Round($scaleX, 6)
        scaleY = [Math]::Round($scaleY, 6)
        calibratedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
    $script:Config.calibration = $calibration
    Write-Config

    $script:Calibration = @{
        offsetX = [double]$calibration.offsetX
        offsetY = [double]$calibration.offsetY
        scaleX = [double]$calibration.scaleX
        scaleY = [double]$calibration.scaleY
    }

    $target = $script:CalibrationWindow
    Close-CalibrationOverlay
    [RoadLevel.WinApi]::ActivateWindow($target)
    Set-Status (T 'status.calibrationComplete') '#1E8449'
    Update-HotkeyRegistration
}

function Handle-CalibrationTick {
    if ($null -eq $script:CalibrationOverlay -or $script:CalibrationStep -eq 0) {
        return
    }

    $escapeDown = Test-KeyDown 0x1B
    $f7Down = Test-KeyDown 0x76

    if ($escapeDown) {
        Close-CalibrationOverlay
        Set-Status (T 'status.calibrationCancelled') '#C0392B'
        $script:CalibrationF7WasDown = $f7Down
        return
    }

    if ($f7Down -and -not $script:CalibrationF7WasDown) {
        $point = [RoadLevel.WinApi]::GetCursorPosition()

        if (-not [RoadLevel.WinApi]::IsPointInsideWindow($script:CalibrationWindow, $point)) {
            Set-Status (T 'status.calibrationOutside') '#C0392B'
            $script:CalibrationF7WasDown = $f7Down
            return
        }

        if ($script:CalibrationStep -eq 1) {
            $script:CalibrationFirstPoint = $point
            $script:CalibrationStep = 2
            $script:CalibrationOverlayLabel.Text = T 'calibration.step2'
            Set-Status (T 'status.calibrationFirstPoint') '#B9770E'
        }
        elseif ($script:CalibrationStep -eq 2) {
            $firstPoint = $script:CalibrationFirstPoint
            Complete-Calibration $firstPoint $point
        }
    }

    $script:CalibrationF7WasDown = $f7Down
}

function Get-FriendlyShortcutKeyName($KeyCode) {
    $name = [string]$KeyCode
    if ($name -match '^D([0-9])$') {
        return $Matches[1]
    }
    if ($name -eq 'Back') {
        return 'Backspace'
    }
    return $name
}

function Test-ShortcutUsable($Binding) {
    if ([string]::IsNullOrWhiteSpace([string]$Binding.key)) {
        return $true
    }
    if ($null -eq $script:MainForm -or -not $script:MainForm.IsHandleCreated) {
        return $false
    }

    $keyCode = Get-BindingKeyCode $Binding
    if ($null -eq $keyCode) {
        return $false
    }

    $modifiers = 0
    if ($Binding.ctrl -eq $true) { $modifiers = $modifiers -bor 0x0002 }
    if ($Binding.alt -eq $true) { $modifiers = $modifiers -bor 0x0001 }
    if ($Binding.shift -eq $true) { $modifiers = $modifiers -bor 0x0004 }

    $testId = 0x7E00
    $registered = [RoadLevel.WinApi]::RegisterGlobalHotkey(
        $script:MainForm.Handle,
        $testId,
        [uint32]$modifiers,
        [uint32]$keyCode
    )
    if ($registered) {
        [RoadLevel.WinApi]::UnregisterGlobalHotkey($script:MainForm.Handle, $testId)
    }
    return $registered
}

function Show-ShortcutEditor([string]$ActionName) {
    $panel = Get-ActivePanel
    $isBackupAction = $ActionName -eq 'backup'
    if (-not $isBackupAction -and ($null -eq $panel -or -not $panel.Profile.buttons.Contains($ActionName))) {
        Set-Status (T 'status.panelNotRecognized') '#B9770E'
        return
    }

    $buttonInfo = if ($isBackupAction) {
        [pscustomobject]@{ label = '备份当前工程瓦片' }
    }
    else {
        $panel.Profile.buttons[$ActionName]
    }
    $panelTitle = if ($isBackupAction) { '' } else { [string]$panel.Title }
    $currentBinding = Get-ActionBinding -Config $script:Config -PanelTitle $panelTitle -ActionName $ActionName
    $draft = $currentBinding.PSObject.Copy()
    $script:EditingShortcuts = $true
    Unregister-AllHotkeys

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = T 'editor.title'
    $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ClientSize = New-Object System.Drawing.Size(560, 315)
    $dialog.KeyPreview = $true
    $dialog.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
    $dialog.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    Resize-DialogWithinWorkingArea -Dialog $dialog -OwnerControl $form

    $title = New-Object System.Windows.Forms.Label
    $title.Text = T 'editor.heading' @{
        label = (Get-LocalizedActionLabel -Label ([string]$buttonInfo.label) -Language $script:UiLanguage)
    }
    $title.Left = 22
    $title.Top = 18
    $title.Width = 510
    $title.Height = 30
    $title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 14, [System.Drawing.FontStyle]::Bold)
    $dialog.Controls.Add($title)

    $captureLabel = New-Object System.Windows.Forms.Label
    $captureLabel.Text = T 'editor.keyboardLabel'
    $captureLabel.Left = 24
    $captureLabel.Top = 62
    $captureLabel.Width = 490
    $captureLabel.Height = 22
    $dialog.Controls.Add($captureLabel)

    $captureBox = New-Object System.Windows.Forms.TextBox
    $captureBox.Left = 24
    $captureBox.Top = 88
    $captureBox.Width = 330
    $captureBox.Height = 32
    $captureBox.ReadOnly = $true
    $captureBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
    $captureBox.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 11, [System.Drawing.FontStyle]::Bold)
    $dialog.Controls.Add($captureBox)

    $clearKeyboardButton = New-Object System.Windows.Forms.Button
    $clearKeyboardButton.Text = T 'editor.clearKeyboard'
    $clearKeyboardButton.Left = 366
    $clearKeyboardButton.Top = 86
    $clearKeyboardButton.Width = 110
    $clearKeyboardButton.Height = 34
    $dialog.Controls.Add($clearKeyboardButton)

    $mouseLabel = New-Object System.Windows.Forms.Label
    $mouseLabel.Text = T 'editor.mouseLabel'
    $mouseLabel.Left = 24
    $mouseLabel.Top = 137
    $mouseLabel.Width = 120
    $mouseLabel.Height = 22
    $dialog.Controls.Add($mouseLabel)

    $mouseCombo = New-Object System.Windows.Forms.ComboBox
    $mouseCombo.Left = 140
    $mouseCombo.Top = 134
    $mouseCombo.Width = 160
    $mouseCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    [void]$mouseCombo.Items.Add((T 'mouse.none'))
    [void]$mouseCombo.Items.Add((T 'mouse.side1'))
    [void]$mouseCombo.Items.Add((T 'mouse.side2'))
    switch ([string]$draft.mouseButton) {
        'XButton1' { $mouseCombo.SelectedIndex = 1 }
        'XButton2' { $mouseCombo.SelectedIndex = 2 }
        default { $mouseCombo.SelectedIndex = 0 }
    }
    $dialog.Controls.Add($mouseCombo)

    $conflictLabel = New-Object System.Windows.Forms.Label
    $conflictLabel.Left = 24
    $conflictLabel.Top = 176
    $conflictLabel.Width = 512
    $conflictLabel.Height = 70
    $conflictLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9, [System.Drawing.FontStyle]::Bold)
    $dialog.Controls.Add($conflictLabel)

    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Text = T 'button.save'
    $saveButton.Left = 330
    $saveButton.Top = 262
    $saveButton.Width = 95
    $saveButton.Height = 35
    $dialog.Controls.Add($saveButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = T 'button.cancel'
    $cancelButton.Left = 437
    $cancelButton.Top = 262
    $cancelButton.Width = 95
    $cancelButton.Height = 35
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $dialog.Controls.Add($cancelButton)
    $dialog.CancelButton = $cancelButton

    $refreshEditorConflict = {
        $captureBox.Text = if ([string]::IsNullOrWhiteSpace([string]$draft.key)) { T 'format.unbound' } else { Get-ShortcutDisplay $draft }
        switch ($mouseCombo.SelectedIndex) {
            1 { $draft.mouseButton = 'XButton1' }
            2 { $draft.mouseButton = 'XButton2' }
            default { $draft.mouseButton = '' }
        }

        $conflicts = @()
        if ($isBackupAction) {
            $globalConflict = Find-GlobalBackupConflict -Candidate $draft -Config $script:Config -ModelConflicts $script:ModelShortcutConflicts
            if ($null -ne $globalConflict) {
                $conflicts = @($globalConflict)
            }
        }
        else {
            $scope = Get-ConflictScopeBindings -Config $script:Config -PanelTitle $panelTitle
            $conflicts = @(Get-BindingConflictList -ActionName $ActionName -Binding $draft -Bindings $scope -ModelConflicts $script:ModelShortcutConflicts)
        }
        if ($conflicts.Count -eq 0) {
            $conflictLabel.Text = T 'editor.noConflict'
            $conflictLabel.ForeColor = [System.Drawing.Color]::FromArgb(30, 105, 60)
        }
        else {
            $conflictLabel.Text = ($conflicts | ForEach-Object { Get-LocalizedConflictMessage $_ }) -join "`r`n"
            if (@($conflicts | Where-Object Kind -eq 'Model').Count -gt 0) {
                $conflictLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 95, 0)
            }
            else {
                $conflictLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 40, 40)
            }
        }
    }

    $captureBox.Add_KeyDown({
        param($sender, $eventArgs)
        $eventArgs.SuppressKeyPress = $true
        $eventArgs.Handled = $true

        $modifierKeys = @(
            [System.Windows.Forms.Keys]::ControlKey,
            [System.Windows.Forms.Keys]::LControlKey,
            [System.Windows.Forms.Keys]::RControlKey,
            [System.Windows.Forms.Keys]::Menu,
            [System.Windows.Forms.Keys]::LMenu,
            [System.Windows.Forms.Keys]::RMenu,
            [System.Windows.Forms.Keys]::ShiftKey,
            [System.Windows.Forms.Keys]::LShiftKey,
            [System.Windows.Forms.Keys]::RShiftKey
        )
        if ($modifierKeys -contains $eventArgs.KeyCode) {
            return
        }
        if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            return
        }

        $draft.key = Get-FriendlyShortcutKeyName $eventArgs.KeyCode
        $modifiers = [System.Windows.Forms.Control]::ModifierKeys
        $draft.ctrl = (($modifiers -band [System.Windows.Forms.Keys]::Control) -ne 0)
        $draft.alt = (($modifiers -band [System.Windows.Forms.Keys]::Alt) -ne 0)
        $draft.shift = (($modifiers -band [System.Windows.Forms.Keys]::Shift) -ne 0)
        & $refreshEditorConflict
    })

    $mouseCombo.Add_SelectedIndexChanged({ & $refreshEditorConflict })
    $clearKeyboardButton.Add_Click({
        $draft.key = ''
        $draft.ctrl = $false
        $draft.alt = $false
        $draft.shift = $false
        & $refreshEditorConflict
    })

    $saveButton.Add_Click({
        if ([string]::IsNullOrWhiteSpace([string]$draft.key) -and [string]::IsNullOrWhiteSpace([string]$draft.mouseButton)) {
            [System.Windows.Forms.MessageBox]::Show(
                (T 'message.bindingRequired'),
                (T 'message.cannotSave'),
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        $conflicts = @()
        if ($isBackupAction) {
            $globalConflict = Find-GlobalBackupConflict -Candidate $draft -Config $script:Config -ModelConflicts $script:ModelShortcutConflicts
            if ($null -ne $globalConflict) {
                $conflicts = @($globalConflict)
            }
        }
        else {
            $scope = Get-ConflictScopeBindings -Config $script:Config -PanelTitle $panelTitle
            $conflicts = @(Get-BindingConflictList -ActionName $ActionName -Binding $draft -Bindings $scope -ModelConflicts $script:ModelShortcutConflicts)
        }
        $internalConflict = $conflicts | Where-Object Kind -eq 'Internal' | Select-Object -First 1
        if ($null -ne $internalConflict) {
            [System.Windows.Forms.MessageBox]::Show(
                (Get-LocalizedConflictMessage $internalConflict),
                (T 'message.shortcutDuplicate'),
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
            return
        }

        $modelConflict = $conflicts | Where-Object Kind -eq 'Model' | Select-Object -First 1
        if ($null -ne $modelConflict) {
            $answer = [System.Windows.Forms.MessageBox]::Show(
                (T 'message.modelConflictBody' @{ message = (Get-LocalizedConflictMessage $modelConflict) }),
                (T 'message.modelConflictTitle'),
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
                return
            }
        }

        if (-not (Test-ShortcutUsable $draft)) {
            [System.Windows.Forms.MessageBox]::Show(
                (T 'message.shortcutUnavailable'),
                (T 'message.unavailableTitle'),
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
            return
        }

        Set-ActionBinding -Config $script:Config -PanelTitle $panelTitle -ActionName $ActionName -Binding $draft | Out-Null
        Write-Config
        $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $dialog.Close()
    })

    & $refreshEditorConflict
    try {
        $captureBox.Focus()
        [void]$dialog.ShowDialog($form)
    }
    finally {
        $script:EditingShortcuts = $false
        $dialog.Dispose()
    }

    Refresh-Detection
}

function Reset-ShortcutSettings {
    $answer = [System.Windows.Forms.MessageBox]::Show(
        (T 'message.resetConfirm'),
        (T 'message.resetTitle'),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }

    $script:Config = Reset-ShortcutBindings -Config $script:Config
    Write-Config
    Unregister-AllHotkeys
    Load-ConfigurationIntoUi
    Set-Status (T 'status.defaultsRestored') '#1E8449'
}

function Export-ShortcutConfiguration {
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    try {
        $dialog.Title = T 'config.exportTitle'
        $dialog.Filter = T 'config.filter'
        $dialog.DefaultExt = 'json'
        $dialog.AddExtension = $true
        $dialog.FileName = 'ModelFun-Shortcuts-{0}.json' -f (Get-Date).ToString('yyyyMMdd-HHmmss')
        if ($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) {
            return
        }
        $null = Export-ConfigFile -ConfigPath $script:ConfigPath -DestinationPath $dialog.FileName
        Set-Status (T 'config.exportSuccess') '#1E8449'
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'config.exportFailed' @{ message = (Format-UiException -Exception $_.Exception -Language $script:UiLanguage) }),
            (T 'button.exportConfig'),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    finally {
        $dialog.Dispose()
    }
}

function Import-ShortcutConfiguration {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    try {
        $dialog.Title = T 'config.importTitle'
        $dialog.Filter = T 'config.filter'
        $dialog.CheckFileExists = $true
        $dialog.Multiselect = $false
        if ($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) {
            return
        }
        Import-ConfigFile `
            -SourcePath $dialog.FileName `
            -ConfigPath $script:ConfigPath `
            -BackupDirectory $script:ConfigBackupDirectory `
            -Validator {
                param($candidate)
                ConvertTo-ValidatedShortcutConfig -Config $candidate
            } | Out-Null
        Unregister-AllHotkeys
        Load-ConfigurationIntoUi
        Set-Status (T 'config.importSuccess') '#1E8449'
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'config.importFailed' @{ message = (Format-UiException -Exception $_.Exception -Language $script:UiLanguage) }),
            (T 'button.importConfig'),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    finally {
        $dialog.Dispose()
    }
}

function Restore-ShortcutConfiguration {
    $latestBackup = Get-LatestConfigBackup -BackupDirectory $script:ConfigBackupDirectory
    if ($null -eq $latestBackup) {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'config.noBackup'),
            (T 'config.restoreTitle'),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }

    $answer = [System.Windows.Forms.MessageBox]::Show(
        (T 'config.restoreConfirm'),
        (T 'config.restoreTitle'),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }

    try {
        $null = Restore-LatestConfigFile `
            -ConfigPath $script:ConfigPath `
            -BackupDirectory $script:ConfigBackupDirectory `
            -Validator $script:ConfigValidator
        Unregister-AllHotkeys
        Load-ConfigurationIntoUi
        Set-Status (T 'config.restoreSuccess') '#1E8449'
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'config.restoreFailed' @{ message = (Format-UiException -Exception $_.Exception -Language $script:UiLanguage) }),
            (T 'config.restoreTitle'),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

function Show-UserGuide {
    $guidePath = Join-Path $script:AppDirectory '用户指南.html'
    if (-not (Test-Path -LiteralPath $guidePath -PathType Leaf)) {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'guide.notFoundBody'),
            (T 'guide.notFoundTitle'),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    try {
        $guideUri = ([System.Uri]$guidePath).AbsoluteUri
        Start-Process -FilePath "$guideUri?lang=$($script:UiLanguage)"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'guide.openFailed' @{ message = (Format-UiException -Exception $_.Exception -Language $script:UiLanguage) }),
            (T 'guide.notFoundTitle'),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

function Show-AboutDialog {
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "$(T 'about.title') $($script:AppVersion)"
    $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $dialog.MinimumSize = New-Object System.Drawing.Size(620, 460)
    $dialog.ClientSize = New-Object System.Drawing.Size(700, 540)
    $dialog.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $dialog.ShowInTaskbar = $false
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
    $dialog.BackColor = [System.Drawing.Color]::FromArgb(246, 248, 251)
    Resize-DialogWithinWorkingArea -Dialog $dialog -OwnerControl $form

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $layout.ColumnCount = 1
    $layout.RowCount = 3
    $layout.Padding = New-Object System.Windows.Forms.Padding(14)
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 44)))
    $dialog.Controls.Add($layout)

    $heading = New-Object System.Windows.Forms.Label
    $heading.Text = T 'about.heading' @{ version = $script:AppVersion }
    $heading.Dock = [System.Windows.Forms.DockStyle]::Fill
    $heading.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 14, [System.Drawing.FontStyle]::Bold)
    $heading.ForeColor = [System.Drawing.Color]::FromArgb(35, 55, 75)
    $heading.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $layout.Controls.Add($heading, 0, 0)

    $textBox = New-Object System.Windows.Forms.RichTextBox
    $textBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $textBox.ReadOnly = $true
    $textBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $textBox.BackColor = [System.Drawing.Color]::White
    $textBox.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
    $textBox.Text = Get-AboutText -Info $script:VersionInfo -Language $script:UiLanguage
    $textBox.SelectionStart = 0
    $textBox.SelectionLength = 0
    $layout.Controls.Add($textBox, 0, 1)

    $buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttonPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $buttonPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
    $buttonPanel.WrapContents = $false
    $buttonPanel.Padding = New-Object System.Windows.Forms.Padding(0, 7, 0, 0)
    $layout.Controls.Add($buttonPanel, 0, 2)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = T 'button.ok'
    $okButton.Width = 100
    $okButton.Height = 32
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $buttonPanel.Controls.Add($okButton)
    $dialog.AcceptButton = $okButton

    [void]$dialog.ShowDialog($form)
    $dialog.Dispose()
}

function Load-ConfigurationIntoUi {
    Load-Config
    $script:SuppressLanguageChange = $true
    try {
        foreach ($option in $languageCombo.Items) {
            if ([string]$option.Code -eq $script:UiLanguage) {
                $languageCombo.SelectedItem = $option
                break
            }
        }
    }
    finally {
        $script:SuppressLanguageChange = $false
    }
    Apply-UiLanguage
    Refresh-Detection
}

function Refresh-Detection([switch]$ShowDialog) {
    $panel = Get-ActivePanel
    $script:LastPanelTitle = if ($null -ne $panel) { [string]$panel.Title } else { '' }
    Refresh-BindingGrid $panel

    if ($null -ne $panel) {
        Set-Status (T 'status.detectedInfo' @{
            panel = (Get-LocalizedPanelTitle -PanelTitle $panel.Title -Language $script:UiLanguage)
            count = $panel.Profile.buttons.Count
        }) '#1E8449'
        return
    }

    $target = Get-TargetWindow
    if ($target -eq [IntPtr]::Zero) {
        Set-Status (T 'status.waitingModelFun') '#B9770E'
        if ($ShowDialog) {
            [System.Windows.Forms.MessageBox]::Show(
                (T 'dialog.modelWindowMissingBody'),
                (T 'dialog.modelWindowMissingTitle'),
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
        }
    }
    else {
        Set-Status (T 'status.waitingPanel') '#B9770E'
        if ($ShowDialog) {
            [System.Windows.Forms.MessageBox]::Show(
                (T 'dialog.panelMissingBody'),
                (T 'dialog.panelMissingTitle'),
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        }
    }
}

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

if ($SelfTest) {
        Load-Config
        $resolvedBindings = [ordered]@{
            common = [ordered]@{}
            panels = [ordered]@{}
        }
        foreach ($name in $script:ActionOrder) {
            $binding = Get-ActionBinding -Config $script:Config -PanelTitle '' -ActionName $name
            if ($null -eq $binding) {
                continue
            }
            $keyCode = Get-BindingKeyCode $binding
            if ($null -eq $keyCode) {
                throw "通用快捷键解析失败：$name"
            }
            $resolvedBindings.common[$name] = $keyCode
        }
        foreach ($panelTitle in Get-PanelTitles) {
            $resolvedBindings.panels[$panelTitle] = [ordered]@{}
            foreach ($name in Get-PanelActionNames $panelTitle) {
                $binding = Get-ActionBinding -Config $script:Config -PanelTitle $panelTitle -ActionName $name
                $keyCode = Get-BindingKeyCode $binding
                if ($null -eq $keyCode) {
                    throw "快捷键解析失败：$panelTitle/$name"
                }
                $resolvedBindings.panels[$panelTitle][$name] = $keyCode
            }
        }

        $profileChecks = [ordered]@{}
        foreach ($panelTitle in $script:PanelTitles) {
            $profile = $script:PanelProfiles[$panelTitle]
            foreach ($entry in $profile.buttons.GetEnumerator()) {
                $button = $entry.Value
                if ($button.x -le 0 -or $button.x -ge $profile.referenceWidth -or
                    $button.y -le 0 -or $button.y -ge $profile.referenceHeight) {
                    throw ("按钮坐标越界：{0}/{1}" -f $panelTitle, $entry.Key)
                }
            }
            $profileChecks[$panelTitle] = $profile.buttons.Count
        }

        $panel = Get-ActivePanel
        $detectedPanel = $null
        if ($null -ne $panel) {
            $detectedPanel = [ordered]@{
                title = $panel.Title
                left = $panel.Bounds.Left
                top = $panel.Bounds.Top
                width = $panel.Bounds.Right - $panel.Bounds.Left
                height = $panel.Bounds.Bottom - $panel.Bounds.Top
                buttons = @($panel.Profile.buttons.Keys)
            }
        }

        $mockPanel = $null
        $mockDetection = $false
        try {
            $mockPanel = New-Object System.Windows.Forms.Form
            $mockPanel.Text = '补洞'
            $mockPanel.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
            $mockPanel.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
            $mockPanel.Location = New-Object System.Drawing.Point(-20000, -20000)
            $mockPanel.ClientSize = New-Object System.Drawing.Size(1, 1)
            $mockPanel.ShowInTaskbar = $false
            $mockPanel.Show()
            $mockPanel.Refresh()
            $mockHandle = [RoadLevel.WinApi]::FindPanelWindowInProcess([uint32]$PID, [string[]]@('补洞'))
            $mockDetection = $mockHandle -eq $mockPanel.Handle
        }
        finally {
            if ($null -ne $mockPanel) {
                $mockPanel.Close()
                $mockPanel.Dispose()
            }
        }
        if (-not $mockDetection) {
            throw '面板窗口枚举自检失败。'
        }

        $result = [ordered]@{
            ok = $true
            powershell = $PSVersionTable.PSVersion.ToString()
            config = $script:ConfigPath
            appVersion = $script:AppVersion
            versionHistory = @($script:VersionInfo.history | ForEach-Object version)
            backupKey = (Get-ActionBinding -Config $script:Config -PanelTitle '' -ActionName 'backup').key
            bindings = $resolvedBindings
            keyboardMode = 'window-hotkey'
            modelShortcutConflicts = @($script:ModelShortcutConflicts).Count
            profileChecks = $profileChecks
            detectedPanel = $detectedPanel
            mockPanelDetection = $mockDetection
        }
        Write-Output ($result | ConvertTo-Json -Depth 5)
        exit 0
}

try {
    if (-not $SelfTest -and -not $script:UiSmokeTest) {
        $script:SingleInstanceGuard = New-SingleInstanceGuard -Name 'RoadLevelHotkeys-shijye'
        if (-not $script:SingleInstanceGuard.Created) {
            $existingWindow = [IntPtr]::Zero
            for ($attempt = 0; $attempt -lt 20 -and $existingWindow -eq [IntPtr]::Zero; $attempt++) {
                foreach ($titleFragment in @('模方面板快捷键助手', 'ModelFun Shortcut Tool')) {
                    $existingWindow = [RoadLevel.WinApi]::FindWindowContaining($titleFragment)
                    if ($existingWindow -ne [IntPtr]::Zero) {
                        break
                    }
                }
                if ($existingWindow -eq [IntPtr]::Zero) {
                    Start-Sleep -Milliseconds 100
                }
            }
            if ($existingWindow -ne [IntPtr]::Zero) {
                [RoadLevel.WinApi]::ActivateWindow($existingWindow)
            }
            Close-SingleInstanceGuard -Guard $script:SingleInstanceGuard
            $script:SingleInstanceGuard = $null
            exit 0
        }
    }

    Load-Config
}
catch {
    Close-SingleInstanceGuard -Guard $script:SingleInstanceGuard
    $script:SingleInstanceGuard = $null
    $startupError = Format-UiException -Exception $_.Exception -Language $script:UiLanguage
    if ($script:UiSmokeTest) {
        Write-Error "Startup failed: $startupError"
        exit 1
    }
    [System.Windows.Forms.MessageBox]::Show(
        ("启动失败 / Startup failed`r`n`r`n{0}" -f $startupError),
        '模方面板快捷键助手 / ModelFun Shortcut Tool',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity)
if (-not $currentPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator) -and -not $script:UiSmokeTest) {
    [System.Windows.Forms.MessageBox]::Show(
        (T 'message.adminRequired'),
        (T 'message.adminRequiredTitle'),
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    exit 1
}

$form = New-Object RoadLevel.HotkeyForm
$script:MainForm = $form
$form.add_HotkeyPressed({
    param([int]$id)

    if ($script:HotkeyIds.ContainsKey($id)) {
        $actionName = [string]$script:HotkeyIds[$id]
        Write-DiagnosticLog ("HOTKEY={0}; ACTION={1}" -f $id, $actionName)
        Invoke-PanelButton $actionName
    }
})
if ($script:DiagnosticEnabled) {
    $script:HotkeyIds[0x7F01] = 'slot1'
}
$form.Text = "$(T 'app.name') $($script:AppVersion)"
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.ClientSize = New-Object System.Drawing.Size(860, 580)
$form.MinimumSize = New-Object System.Drawing.Size(780, 540)
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
$form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$form.BackColor = [System.Drawing.Color]::FromArgb(246, 248, 251)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "$(T 'main.title')　$($script:AppVersion)"
$titleLabel.Left = 20
$titleLabel.Top = 16
$titleLabel.Width = 470
$titleLabel.Height = 38
$titleLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(35, 55, 75)
$form.Controls.Add($titleLabel)

$languageCombo = New-Object System.Windows.Forms.ComboBox
$languageCombo.Left = 708
$languageCombo.Top = 18
$languageCombo.Width = 132
$languageCombo.Height = 34
$languageCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$languageCombo.DisplayMember = 'DisplayName'
$languageCombo.ValueMember = 'Code'
$languageCombo.AccessibleName = T 'language.label'
$languageCombo.TabStop = $true
foreach ($languageOption in @(Get-UiLanguageOptions)) {
    [void]$languageCombo.Items.Add($languageOption)
    if ($languageOption.Code -eq $script:UiLanguage) {
        $languageCombo.SelectedItem = $languageOption
    }
}
$languageToolTip = New-Object System.Windows.Forms.ToolTip
$languageToolTip.SetToolTip($languageCombo, (T 'language.tooltip'))
$form.Controls.Add($languageCombo)

$summaryLabel = New-Object System.Windows.Forms.Label
$summaryLabel.Text = T 'main.summary'
$summaryLabel.Left = 21
$summaryLabel.Top = 64
$summaryLabel.Width = 720
$summaryLabel.Height = 44
$summaryLabel.AutoEllipsis = $false
$summaryLabel.ForeColor = [System.Drawing.Color]::FromArgb(85, 100, 115)
$form.Controls.Add($summaryLabel)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Left = 20
$statusLabel.Top = 114
$statusLabel.Width = 740
$statusLabel.Height = 28
$statusLabel.AutoEllipsis = $true
$statusLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($statusLabel)

$bindingGrid = New-Object System.Windows.Forms.DataGridView
$bindingGrid.Left = 20
$bindingGrid.Top = 150
$bindingGrid.Width = 740
$bindingGrid.Height = 220
$bindingGrid.AllowUserToAddRows = $false
$bindingGrid.AllowUserToDeleteRows = $false
$bindingGrid.AllowUserToResizeRows = $false
$bindingGrid.RowHeadersVisible = $false
$bindingGrid.ReadOnly = $true
$bindingGrid.MultiSelect = $false
$bindingGrid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
$bindingGrid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$bindingGrid.BackgroundColor = [System.Drawing.Color]::White
$bindingGrid.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$bindingGrid.GridColor = [System.Drawing.Color]::FromArgb(220, 226, 232)
$bindingGrid.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(225, 235, 244)
$bindingGrid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9, [System.Drawing.FontStyle]::Bold)
$bindingGrid.EnableHeadersVisualStyles = $false
$bindingGrid.ColumnHeadersHeight = 34
$bindingGrid.RowTemplate.Height = 32
[void]$bindingGrid.Columns.Add('action', (T 'column.action'))
[void]$bindingGrid.Columns.Add('keyboard', (T 'column.keyboard'))
[void]$bindingGrid.Columns.Add('mouse', (T 'column.mouse'))
[void]$bindingGrid.Columns.Add('status', (T 'column.status'))
$bindingGrid.Columns[0].FillWeight = 28
$bindingGrid.Columns[1].FillWeight = 32
$bindingGrid.Columns[2].FillWeight = 18
$bindingGrid.Columns[3].FillWeight = 22
$bindingGrid.Add_CellDoubleClick({
    param($sender, $eventArgs)
    if ($eventArgs.RowIndex -ge 0 -and $eventArgs.RowIndex -lt $script:GridActionNames.Count) {
        Show-ShortcutEditor $script:GridActionNames[$eventArgs.RowIndex]
    }
})
$form.Controls.Add($bindingGrid)

$shortcutNoticeLabel = New-Object System.Windows.Forms.Label
$shortcutNoticeLabel.Left = 20
$shortcutNoticeLabel.Top = 340
$shortcutNoticeLabel.Width = 740
$shortcutNoticeLabel.Height = 24
$shortcutNoticeLabel.AutoEllipsis = $true
$shortcutNoticeLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8.5)
$form.Controls.Add($shortcutNoticeLabel)

$buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$buttonPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$buttonPanel.WrapContents = $true
$buttonPanel.AutoScroll = $false
$buttonPanel.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($buttonPanel)

$calibrateButton = New-Object System.Windows.Forms.Button
$calibrateButton.Text = T 'button.detect'
$calibrateButton.Left = 20
$calibrateButton.Top = 358
$calibrateButton.Width = 105
$calibrateButton.Height = 36
$calibrateButton.BackColor = [System.Drawing.Color]::FromArgb(42, 116, 178)
$calibrateButton.ForeColor = [System.Drawing.Color]::White
$calibrateButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$calibrateButton.Add_Click({ Refresh-Detection -ShowDialog })
$buttonPanel.Controls.Add($calibrateButton)

$editShortcutButton = New-Object System.Windows.Forms.Button
$editShortcutButton.Text = T 'button.editShortcut'
$editShortcutButton.Left = 118
$editShortcutButton.Top = 358
$editShortcutButton.Width = 120
$editShortcutButton.Height = 36
$editShortcutButton.Add_Click({
    if ($bindingGrid.CurrentRow -eq $null -or $bindingGrid.CurrentRow.Index -lt 0 -or $bindingGrid.CurrentRow.Index -ge $script:GridActionNames.Count) {
        Set-Status (T 'status.selectRow') '#B9770E'
        return
    }
    Show-ShortcutEditor $script:GridActionNames[$bindingGrid.CurrentRow.Index]
})
$buttonPanel.Controls.Add($editShortcutButton)

$resetShortcutButton = New-Object System.Windows.Forms.Button
$resetShortcutButton.Text = T 'button.resetDefaults'
$resetShortcutButton.Left = 236
$resetShortcutButton.Top = 358
$resetShortcutButton.Width = 110
$resetShortcutButton.Height = 36
$resetShortcutButton.Add_Click({ Reset-ShortcutSettings })
$buttonPanel.Controls.Add($resetShortcutButton)

$reloadButton = New-Object System.Windows.Forms.Button
$reloadButton.Text = T 'button.loadConfig'
$reloadButton.Left = 334
$reloadButton.Top = 358
$reloadButton.Width = 110
$reloadButton.Height = 36
$reloadButton.Add_Click({
    try {
        Unregister-AllHotkeys
        Load-ConfigurationIntoUi
    }
    catch {
        Set-Status (T 'status.configReadFailed' @{ message = (Format-UiException -Exception $_.Exception -Language $script:UiLanguage) }) '#C0392B'
    }
})
$buttonPanel.Controls.Add($reloadButton)

$openConfigButton = New-Object System.Windows.Forms.Button
$openConfigButton.Text = T 'button.openConfig'
$openConfigButton.Left = 432
$openConfigButton.Top = 358
$openConfigButton.Width = 105
$openConfigButton.Height = 36
$openConfigButton.Add_Click({
    Start-Process -FilePath 'notepad.exe' -ArgumentList ('"{0}"' -f $script:ConfigPath)
})
$buttonPanel.Controls.Add($openConfigButton)

$configManagerButton = New-Object System.Windows.Forms.Button
$configManagerButton.Text = T 'button.configManager'
$configManagerButton.Width = 105
$configManagerButton.Height = 36
$configMenu = New-Object System.Windows.Forms.ContextMenuStrip
$exportConfigMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$importConfigMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$restoreConfigMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exportConfigMenuItem.Text = T 'button.exportConfig'
$importConfigMenuItem.Text = T 'button.importConfig'
$restoreConfigMenuItem.Text = T 'button.restoreBackup'
$exportConfigMenuItem.Add_Click({ Export-ShortcutConfiguration })
$importConfigMenuItem.Add_Click({ Import-ShortcutConfiguration })
$restoreConfigMenuItem.Add_Click({ Restore-ShortcutConfiguration })
[void]$configMenu.Items.Add($exportConfigMenuItem)
[void]$configMenu.Items.Add($importConfigMenuItem)
[void]$configMenu.Items.Add($restoreConfigMenuItem)
$configManagerButton.ContextMenuStrip = $configMenu
$configManagerButton.Add_Click({
    $configMenu.Show(
        $configManagerButton,
        (New-Object System.Drawing.Point(0, $configManagerButton.Height)),
        [System.Windows.Forms.ToolStripDropDownDirection]::BelowRight
    )
})
$buttonPanel.Controls.Add($configManagerButton)

$guideButton = New-Object System.Windows.Forms.Button
$guideButton.Text = T 'button.userGuide'
$guideButton.Width = 105
$guideButton.Height = 36
$guideButton.Add_Click({ Show-UserGuide })
$buttonPanel.Controls.Add($guideButton)

$enabledCheckBox = New-Object System.Windows.Forms.CheckBox
$enabledCheckBox.Text = T 'button.enableHotkeys'
$enabledCheckBox.Left = 530
$enabledCheckBox.Top = 365
$enabledCheckBox.Width = 140
$enabledCheckBox.AutoSize = $true
$enabledCheckBox.MinimumSize = New-Object System.Drawing.Size(130, 30)
$enabledCheckBox.Checked = $true
$enabledCheckBox.Add_CheckedChanged({
    $script:Enabled = $enabledCheckBox.Checked
    if (-not $script:Enabled) {
        Unregister-AllHotkeys
        Set-Status (T 'status.paused') '#B9770E'
    }
})
$buttonPanel.Controls.Add($enabledCheckBox)

$aboutButton = New-Object System.Windows.Forms.Button
$aboutButton.Text = T 'button.about'
$aboutButton.Width = 72
$aboutButton.Height = 36
$aboutButton.Add_Click({ Show-AboutDialog })
$buttonPanel.Controls.Add($aboutButton)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = T 'button.exit'
$exitButton.Left = 688
$exitButton.Top = 358
$exitButton.Width = 72
$exitButton.Height = 36
$exitButton.Add_Click({ $form.Close() })
$buttonPanel.Controls.Add($exitButton)

$hintLabel = New-Object System.Windows.Forms.Label
$hintLabel.Text = T 'status.hint' @{ backup = (Format-Binding $script:Config.commonBindings.backup) }
$hintLabel.Left = 20
$hintLabel.Top = 405
$hintLabel.Width = 740
$hintLabel.Height = 24
$hintLabel.AutoEllipsis = $true
$hintLabel.ForeColor = [System.Drawing.Color]::FromArgb(95, 110, 125)
$form.Controls.Add($hintLabel)

function Apply-UiLanguage {
    $form.Text = "$(T 'app.name') $($script:AppVersion)"
    $titleLabel.Text = "$(T 'main.title')　$($script:AppVersion)"
    $summaryLabel.Text = T 'main.summary'
    $languageCombo.AccessibleName = T 'language.label'
    $languageToolTip.SetToolTip($languageCombo, (T 'language.tooltip'))
    $bindingGrid.Columns[0].HeaderText = T 'column.action'
    $bindingGrid.Columns[1].HeaderText = T 'column.keyboard'
    $bindingGrid.Columns[2].HeaderText = T 'column.mouse'
    $bindingGrid.Columns[3].HeaderText = T 'column.status'
    $calibrateButton.Text = T 'button.detect'
    $editShortcutButton.Text = T 'button.editShortcut'
    $resetShortcutButton.Text = T 'button.resetDefaults'
    $reloadButton.Text = T 'button.loadConfig'
    $openConfigButton.Text = T 'button.openConfig'
    $configManagerButton.Text = T 'button.configManager'
    $guideButton.Text = T 'button.userGuide'
    $enabledCheckBox.Text = T 'button.enableHotkeys'
    $aboutButton.Text = T 'button.about'
    $exitButton.Text = T 'button.exit'
    $exportConfigMenuItem.Text = T 'button.exportConfig'
    $importConfigMenuItem.Text = T 'button.importConfig'
    $restoreConfigMenuItem.Text = T 'button.restoreBackup'
}

$languageCombo.Add_SelectedIndexChanged({
    if ($script:SuppressLanguageChange -or $null -eq $languageCombo.SelectedItem) {
        return
    }
    $selectedLanguage = [string]$languageCombo.SelectedItem.Code
    if ($selectedLanguage -eq $script:UiLanguage) {
        return
    }
    try {
        $script:Config = Set-ConfigLanguage -Config $script:Config -Language $selectedLanguage
        $script:UiLanguage = $selectedLanguage
        Write-Config
        Apply-UiLanguage
        Refresh-Detection
        Set-Status (T 'status.languageChanged') '#1E8449'
    }
    catch {
        Set-Status (T 'status.configReadFailed' @{ message = (Format-UiException -Exception $_.Exception -Language $script:UiLanguage) }) '#C0392B'
    }
})

function Update-MainWindowLayout {
    $metrics = Get-MainLayoutMetrics -ClientWidth $form.ClientSize.Width -ClientHeight $form.ClientSize.Height

    $titleLabel.Top = $metrics.TitleTop
    $titleLabel.Height = $metrics.TitleHeight
    $titleLabel.Width = $metrics.TitleWidth

    $languageCombo.Left = $metrics.LanguageSelectorLeft
    $languageCombo.Top = $metrics.LanguageSelectorTop
    $languageCombo.Width = $metrics.LanguageSelectorWidth
    $languageCombo.Height = $metrics.LanguageSelectorHeight

    $summaryLabel.Top = $metrics.SummaryTop
    $summaryLabel.Height = $metrics.SummaryHeight
    $summaryLabel.Width = $metrics.ContentWidth

    $statusLabel.Top = $metrics.StatusTop
    $statusLabel.Height = $metrics.StatusHeight
    $statusLabel.Width = $metrics.ContentWidth

    $bindingGrid.Top = $metrics.GridTop
    $bindingGrid.Width = $metrics.ContentWidth
    $bindingGrid.Height = $metrics.GridHeight

    $shortcutNoticeLabel.Left = 20
    $shortcutNoticeLabel.Top = $metrics.NoticeTop
    $shortcutNoticeLabel.Width = $metrics.ContentWidth
    $shortcutNoticeLabel.Height = $metrics.NoticeHeight

    $buttonPanel.Left = 20
    $buttonPanel.Top = $metrics.ButtonTop
    $buttonPanel.Width = $metrics.ContentWidth
    $buttonPanel.Height = $metrics.ButtonPanelHeight

    $hintLabel.Left = 20
    $hintLabel.Top = $metrics.HintTop
    $hintLabel.Width = $metrics.ContentWidth
    $hintLabel.Height = $metrics.HintHeight
}

$form.Add_Resize({ Update-MainWindowLayout })
$form.Add_DpiChanged({
    try {
        Fit-MainFormToWorkingArea
        Update-MainWindowLayout
    }
    catch {
        Set-Status (T 'status.dpiLayoutFailed' @{ message = (Format-UiException -Exception $_.Exception -Language $script:UiLanguage) }) '#C0392B'
    }
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 40
$timer.Add_Tick({
    try {
        if ($null -ne $script:CalibrationOverlay) {
            Handle-CalibrationTick
        }
        else {
            Update-HotkeyRegistration
            Poll-MouseBindings
            if ($script:DiagnosticEnabled) {
                Poll-KeyboardBindings
            }

            $target = Get-TargetWindow
            $panel = if ($target -ne [IntPtr]::Zero) { Get-ActivePanel } else { $null }
            $panelTitle = if ($null -ne $panel) { [string]$panel.Title } else { '' }
            if ($panelTitle -ne $script:LastPanelTitle) {
                $script:LastPanelTitle = $panelTitle
                Refresh-BindingGrid $panel
            }

            if (-not $script:Enabled) {
                Set-Status (T 'status.paused') '#B9770E'
            }
            elseif ($target -eq [IntPtr]::Zero) {
                Set-Status (T 'status.waitingModelFun') '#B9770E'
            }
            elseif (-not [RoadLevel.WinApi]::IsTargetActive($target, [string]$script:Config.targetTitle)) {
                Set-Status (T 'status.standby') '#1F5F99'
            }
            elseif ($null -eq $panel) {
                if ($script:HotkeysRegistered) {
                    Set-Status (T 'status.backupOnly') '#1E8449'
                }
                else {
                    Set-Status (T 'status.backupRegistrationFailed') '#C0392B'
                }
            }
            elseif ($script:HotkeysRegistered) {
                Set-Status (T 'status.detected' @{
                    panel = (Get-LocalizedPanelTitle -PanelTitle $panel.Title -Language $script:UiLanguage)
                }) '#1E8449'
            }
            else {
                Set-Status (T 'status.detectionFailed' @{
                    panel = (Get-LocalizedPanelTitle -PanelTitle $panel.Title -Language $script:UiLanguage)
                }) '#C0392B'
            }
        }
    }
    catch {
        Set-Status (T 'status.runtimeError' @{ message = (Format-UiException -Exception $_.Exception -Language $script:UiLanguage) }) '#C0392B'
    }
})

$form.Add_Shown({
    try {
        Fit-MainFormToWorkingArea
        Update-MainWindowLayout
        Load-ConfigurationIntoUi
        if ($script:UiSmokeTest) {
            if (-not $titleLabel.Text.Contains((T 'main.title')) -or
                $bindingGrid.Columns[0].HeaderText -ne (T 'column.action') -or
                $exitButton.Text -ne (T 'button.exit') -or
                $guideButton.Text -ne (T 'button.userGuide')) {
                throw "UI did not apply language $($script:UiLanguage)."
            }
            if (-not [string]::IsNullOrWhiteSpace($UiSmokeScreenshotPath)) {
                [System.Windows.Forms.Application]::DoEvents()
                $bitmap = New-Object System.Drawing.Bitmap($form.Width, $form.Height)
                try {
                    $form.DrawToBitmap(
                        $bitmap,
                        (New-Object System.Drawing.Rectangle(0, 0, $form.Width, $form.Height))
                    )
                    $bitmap.Save($UiSmokeScreenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
                }
                finally {
                    $bitmap.Dispose()
                }
            }
            $script:UiSmokeTestCompleted = $true
            [void]$form.BeginInvoke([System.Windows.Forms.MethodInvoker]{ $form.Close() })
            return
        }
        $timer.Start()
        if ($script:DiagnosticEnabled) {
            $testId = 0x7F01
            $testKey = 0x7B
            $testModifiers = 0x0002 -bor 0x0001 -bor 0x0004
            $registered = [RoadLevel.WinApi]::RegisterGlobalHotkey(
                $form.Handle,
                $testId,
                [uint32]$testModifiers,
                [uint32]$testKey
            )
            Write-DiagnosticLog ("DIAGNOSTIC_HOTKEY_TEST={0}; HANDLE={1}" -f $registered, $form.Handle.ToInt64())
        }
    }
    catch {
        Write-DiagnosticLog (
            "INITIALIZATION_FAILED={0}; STACK={1}" -f
            $_.Exception.Message,
            (($_.ScriptStackTrace -replace '\r?\n', ' | '))
        )
        if ($script:UiSmokeTest) {
            $script:UiSmokeTestError = $_.Exception.Message
            [void]$form.BeginInvoke([System.Windows.Forms.MethodInvoker]{ $form.Close() })
            return
        }
        [System.Windows.Forms.MessageBox]::Show(
            (Format-UiException -Exception $_.Exception -Language $script:UiLanguage),
            (T 'message.initializationFailed'),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

$form.Add_FormClosing({
    $timer.Stop()
    Close-CalibrationOverlay
    Unregister-AllHotkeys
    Close-SingleInstanceGuard -Guard $script:SingleInstanceGuard
    $script:SingleInstanceGuard = $null
    $script:MainForm = $null
})

[void]$form.ShowDialog()

if ($script:UiSmokeTest) {
    $form.Dispose()
    if ($script:UiSmokeTestCompleted -and [string]::IsNullOrWhiteSpace($script:UiSmokeTestError)) {
        Write-Output ("PASS Windows PowerShell UI initialization ({0}) completes without errors" -f $script:UiLanguage)
        exit 0
    }
    $message = if ([string]::IsNullOrWhiteSpace($script:UiSmokeTestError)) {
        Get-UiText -Key 'message.initializationIncomplete' -Language $script:UiLanguage
    }
    else {
        $script:UiSmokeTestError
    }
    Write-Error "FAIL Windows PowerShell UI initialization: $message"
    exit 1
}
