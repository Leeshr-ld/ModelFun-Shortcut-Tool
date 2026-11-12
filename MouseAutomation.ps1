if (-not ([System.Management.Automation.PSTypeName]'RoadLevel.MouseInput').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace RoadLevel
{
    public struct MousePoint
    {
        public int X;
        public int Y;
    }

    public static class MouseInput
    {
        private const uint INPUT_MOUSE = 0;
        private const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
        private const uint MOUSEEVENTF_LEFTUP = 0x0004;

        [StructLayout(LayoutKind.Sequential)]
        private struct INPUT
        {
            public uint type;
            public INPUTUNION union;
        }

        [StructLayout(LayoutKind.Explicit, Size = 32)]
        private struct INPUTUNION
        {
            [FieldOffset(0)]
            public MOUSEINPUT mouse;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct MOUSEINPUT
        {
            public int dx;
            public int dy;
            public uint mouseData;
            public uint flags;
            public uint time;
            public UIntPtr extraInfo;
        }

        [DllImport("user32.dll")]
        private static extern bool GetCursorPos(out MousePoint point);

        [DllImport("user32.dll")]
        private static extern bool SetCursorPos(int x, int y);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint SendInput(uint count, INPUT[] inputs, int size);

        [DllImport("kernel32.dll")]
        private static extern void Sleep(uint milliseconds);

        public static MousePoint CursorPosition()
        {
            MousePoint point;
            GetCursorPos(out point);
            return point;
        }

        public static bool MoveCursor(int x, int y)
        {
            return SetCursorPos(x, y);
        }

        public static MousePoint QuickClickAndRestore(int x, int y)
        {
            MousePoint original;
            GetCursorPos(out original);
            SetCursorPos(x, y);

            INPUT[] down = new INPUT[1];
            down[0].type = INPUT_MOUSE;
            down[0].union.mouse.flags = MOUSEEVENTF_LEFTDOWN;
            INPUT[] up = new INPUT[1];
            up[0].type = INPUT_MOUSE;
            up[0].union.mouse.flags = MOUSEEVENTF_LEFTUP;

            SendInput(1, down, Marshal.SizeOf(typeof(INPUT)));
            Sleep(8);
            SendInput(1, up, Marshal.SizeOf(typeof(INPUT)));
            Sleep(18);
            SetCursorPos(original.X, original.Y);
            return original;
        }
    }
}
'@
}

function Get-CursorPosition {
    return [RoadLevel.MouseInput]::CursorPosition()
}

function Set-CursorPosition {
    param([int]$X, [int]$Y)
    return [RoadLevel.MouseInput]::MoveCursor($X, $Y)
}

function Invoke-QuickClickAndRestore {
    param([int]$X, [int]$Y)
    return [RoadLevel.MouseInput]::QuickClickAndRestore($X, $Y)
}
