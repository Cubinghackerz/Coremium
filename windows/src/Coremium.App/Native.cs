using System;
using System.Runtime.InteropServices;
using System.Text;

namespace Coremium.App;

static class Native
{
    public const uint PROCESS_SET_INFORMATION = 0x0200, PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
    public const uint IDLE_PRIORITY_CLASS = 0x40, NORMAL_PRIORITY_CLASS = 0x20;
    const int ProcessPowerThrottling = 4;
    const uint PROCESS_POWER_THROTTLING_EXECUTION_SPEED = 0x1;

    [StructLayout(LayoutKind.Sequential)]
    struct PowerThrottlingState { public uint Version, ControlMask, StateMask; }

    [DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] public static extern uint GetPriorityClass(IntPtr h);
    [DllImport("kernel32.dll")] public static extern bool SetPriorityClass(IntPtr h, uint cls);
    [DllImport("kernel32.dll")] static extern bool SetProcessInformation(IntPtr h, int cls, ref PowerThrottlingState info, int size);
    [DllImport("kernel32.dll")] public static extern bool GetProcessTimes(IntPtr h, out long creation, out long exit, out long kernel, out long user);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern bool QueryFullProcessImageName(IntPtr h, int flags, StringBuilder name, ref int size);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out int pid);
    [DllImport("kernel32.dll")] public static extern bool GetSystemTimes(out long idle, out long kernel, out long user);
    [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool GetLogicalProcessorInformationEx(int relation, IntPtr buffer, ref int length);

    [StructLayout(LayoutKind.Sequential)]
    public struct MemoryStatus { public uint Length, Load; public ulong TotalPhys, AvailPhys, TotalPage, AvailPage, TotalVirtual, AvailVirtual, AvailExt; }
    [DllImport("kernel32.dll")] public static extern bool GlobalMemoryStatusEx(ref MemoryStatus status);

    [StructLayout(LayoutKind.Sequential)]
    public struct PowerStatus { public byte AcLine, Battery, Percent, SystemStatus; public int LifeTime, FullLifeTime; }
    [DllImport("kernel32.dll")] public static extern bool GetSystemPowerStatus(out PowerStatus status);

    delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc proc, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr hwnd, uint cmd);
    [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr hwnd);

    /// <summary>Processes that own a visible, titled, top-level window: what people think of as "apps". One pass over the windows.</summary>
    public static System.Collections.Generic.HashSet<int> PidsWithVisibleWindows()
    {
        var set = new System.Collections.Generic.HashSet<int>();
        EnumWindows((h, _) =>
        {
            if (IsWindowVisible(h) && GetWindow(h, 4 /* GW_OWNER */) == IntPtr.Zero && GetWindowTextLength(h) > 0)
            {
                GetWindowThreadProcessId(h, out var pid);
                set.Add(pid);
            }
            return true;
        }, IntPtr.Zero);
        return set;
    }

    public delegate void WinEventProc(IntPtr hook, uint evt, IntPtr hwnd, int obj, int child, uint thread, uint time);
    [DllImport("user32.dll")] public static extern IntPtr SetWinEventHook(uint min, uint max, IntPtr module, WinEventProc proc, uint pid, uint thread, uint flags);
    public const uint EVENT_SYSTEM_FOREGROUND = 3, WINEVENT_OUTOFCONTEXT = 0;

    /// <summary>EcoQoS ("efficiency mode"): Windows runs the process on efficiency cores at lower clocks. Off hands control back to Windows.</summary>
    public static bool SetEcoQoS(IntPtr h, bool on)
    {
        var s = new PowerThrottlingState { Version = 1, ControlMask = on ? PROCESS_POWER_THROTTLING_EXECUTION_SPEED : 0, StateMask = on ? PROCESS_POWER_THROTTLING_EXECUTION_SPEED : 0 };
        return SetProcessInformation(h, ProcessPowerThrottling, ref s, Marshal.SizeOf<PowerThrottlingState>());
    }

    public static string? ImagePath(int pid)
    {
        var h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
        if (h == IntPtr.Zero) return null;
        try
        {
            var sb = new StringBuilder(1024); var size = sb.Capacity;
            return QueryFullProcessImageName(h, 0, sb, ref size) ? sb.ToString() : null;
        }
        finally { CloseHandle(h); }
    }

    /// <summary>Creation time (FILETIME ticks) and total CPU time (100 ns units) of a process, or null.</summary>
    public static (long Start, long Cpu)? Times(int pid)
    {
        var h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
        if (h == IntPtr.Zero) return null;
        try { return GetProcessTimes(h, out var c, out _, out var k, out var u) ? (c, k + u) : null; }
        finally { CloseHandle(h); }
    }

    /// <summary>Physical cores by efficiency class. Hybrid CPUs (Intel 12th gen and later, Snapdragon) report more than one class.</summary>
    public static (int Performance, int Efficiency) CoreCounts()
    {
        int len = 0;
        GetLogicalProcessorInformationEx(0, IntPtr.Zero, ref len);
        if (len == 0) return (Environment.ProcessorCount, 0);
        var buf = Marshal.AllocHGlobal(len);
        try
        {
            if (!GetLogicalProcessorInformationEx(0, buf, ref len)) return (Environment.ProcessorCount, 0);
            var classes = new System.Collections.Generic.List<byte>();
            for (int off = 0; off < len;)
            {
                int size = Marshal.ReadInt32(buf, off + 4);
                classes.Add(Marshal.ReadByte(buf, off + 9));   // PROCESSOR_RELATIONSHIP.EfficiencyClass
                if (size <= 0) break;
                off += size;
            }
            if (classes.Count == 0) return (Environment.ProcessorCount, 0);
            byte max = 0; foreach (var c in classes) if (c > max) max = c;
            int p = 0, e = 0; foreach (var c in classes) { if (c == max) p++; else e++; }
            return (p, e);
        }
        finally { Marshal.FreeHGlobal(buf); }
    }
}
