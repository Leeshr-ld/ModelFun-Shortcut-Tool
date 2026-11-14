function Initialize-PerMonitorDpiAwareness {
    if (-not ([System.Management.Automation.PSTypeName]'RoadLevel.DpiSupport').Type) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace RoadLevel
{
    public static class DpiSupport
    {
        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool SetProcessDpiAwarenessContext(IntPtr value);

        [DllImport("user32.dll")]
        private static extern IntPtr GetThreadDpiAwarenessContext();

        [DllImport("user32.dll")]
        private static extern IntPtr GetWindowDpiAwarenessContext(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern int GetAwarenessFromDpiAwarenessContext(IntPtr context);

        [DllImport("user32.dll")]
        private static extern uint GetDpiForWindow(IntPtr hWnd);

        public static bool SetPerMonitorV2()
        {
            return SetProcessDpiAwarenessContext(new IntPtr(-4));
        }

        public static int CurrentAwareness()
        {
            return GetAwarenessFromDpiAwarenessContext(GetThreadDpiAwarenessContext());
        }

        public static int WindowAwareness(IntPtr hWnd)
        {
            return GetAwarenessFromDpiAwarenessContext(GetWindowDpiAwarenessContext(hWnd));
        }

        public static uint WindowDpi(IntPtr hWnd)
        {
            return GetDpiForWindow(hWnd);
        }
    }
}
'@
    }

    $succeeded = $false
    if ([RoadLevel.DpiSupport]::CurrentAwareness() -ne 2) {
        $succeeded = [RoadLevel.DpiSupport]::SetPerMonitorV2()
    }
    $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    $awareness = [RoadLevel.DpiSupport]::CurrentAwareness()
    return [pscustomobject]@{
        SetSucceeded = $succeeded
        ErrorCode = $errorCode
        Awareness = $awareness
        IsReady = ($awareness -eq 2)
    }
}

function Get-WindowDpiAwareness([IntPtr]$WindowHandle) {
    return [RoadLevel.DpiSupport]::WindowAwareness($WindowHandle)
}

function Get-WindowDpi([IntPtr]$WindowHandle) {
    return [RoadLevel.DpiSupport]::WindowDpi($WindowHandle)
}
