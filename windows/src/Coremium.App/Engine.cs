using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Windows.Media;
using System.Windows.Threading;
using Coremium.Core;
using Microsoft.Win32;

namespace Coremium.App;

abstract class Observable : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;
    protected bool Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return false;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        return true;
    }
    protected void Raise(string name) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}

sealed class ChipVM(AppRule rule, string state) { public AppRule Rule { get; } = rule; public string Label => Rule.ToString(); public string State { get; } = state; }
sealed class ModeVM(Mode mode, bool selected, string title) { public Mode Mode { get; } = mode; public bool Selected { get; } = selected; public string Title { get; } = title; }

sealed class AppRowVM : Observable
{
    public string Id { get; init; } = "";
    public string Name { get; init; } = "";
    public ImageSource? Icon { get; init; }
    string subtitle = "", load = "", numbers = ""; bool moved; List<ChipVM> chips = new();
    public string Subtitle { get => subtitle; set => Set(ref subtitle, value); }
    public string Load { get => load; set => Set(ref load, value); }
    public string Numbers { get => numbers; set => Set(ref numbers, value); }
    public bool Moved { get => moved; set => Set(ref moved, value); }
    public List<ChipVM> Chips { get => chips; set { chips = value; Raise(nameof(Chips)); } }
}

/// <summary>Watches what you're doing, decides, applies, and exposes everything the window shows.</summary>
sealed class Engine : Observable
{
    public RuleSet Rules { get; } = Store.Load<RuleSet>("settings.json");
    readonly Usage usage = Store.Load<Usage>("usage.json");
    readonly DecisionLog log = new();
    readonly Scheduler scheduler = new();
    readonly DispatcherTimer timer = new();
    readonly Dictionary<int, (long Start, long Cpu, long At)> cpuLast = new();
    readonly Dictionary<string, (string Name, ImageSource? Icon, string? Path)> appInfo = new();
    readonly Native.WinEventProc foregroundHook;
    long lastSysIdle, lastSysTotal;
    DateTime lastTick = DateTime.Now, lastBoostAt = DateTime.MinValue, lastPersist = DateTime.Now;
    bool sessionActive, paused, advanced, windowVisible;

    public ObservableCollection<AppRowVM> Rows { get; } = new();
    public ObservableCollection<Decision> Decisions { get; } = new();
    public string ChipName { get; }
    public string CoresText { get; }
    string status = "", decisionHead = "", decisionDetail = "", today = "", now = "", memory = "", power = "", warning = "", loadText = "";
    double load; List<ModeVM> modes = new();
    public string Status { get => status; private set => Set(ref status, value); }
    public string DecisionHead { get => decisionHead; private set => Set(ref decisionHead, value); }
    public string DecisionDetail { get => decisionDetail; private set => Set(ref decisionDetail, value); }
    public string TodayText { get => today; private set => Set(ref today, value); }
    public string NowText { get => now; private set => Set(ref now, value); }
    public string MemoryText { get => memory; private set => Set(ref memory, value); }
    public string PowerText { get => power; private set => Set(ref power, value); }
    public string Warning { get => warning; private set => Set(ref warning, value); }
    public double Load { get => load; private set => Set(ref load, value); }
    public string LoadText { get => loadText; private set => Set(ref loadText, value); }
    public List<ModeVM> Modes { get => modes; private set { modes = value; Raise(nameof(Modes)); } }
    public bool SessionActive => sessionActive;

    public bool Paused { get => paused; set { if (Set(ref paused, value)) Tick(); } }
    public bool Advanced { get => advanced; set { if (Set(ref advanced, value)) Tick(); } }
    public bool WindowVisible { get => windowVisible; set { windowVisible = value; Reschedule(); if (value) Tick(); } }

    public Engine()
    {
        scheduler.RestoreAll();   // anything left over from a crash goes back first
        ChipName = (Registry.GetValue(@"HKEY_LOCAL_MACHINE\HARDWARE\DESCRIPTION\System\CentralProcessor\0", "ProcessorNameString", null) as string)?.Trim() ?? "Processor";
        var (p, e) = Native.CoreCounts();
        CoresText = e > 0 ? $"{p} performance + {e} efficiency cores" : $"{p} cores (no efficiency cores: moved apps get lower priority)";
        timer.Tick += (_, _) => Tick();
        // Switching apps wakes the engine right away (debounced: one switch can fire several events).
        var debounce = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(150) };
        debounce.Tick += (_, _) => { debounce.Stop(); Tick(); };
        foregroundHook = (_, _, _, _, _, _, _) => { debounce.Stop(); debounce.Start(); };
        Native.SetWinEventHook(Native.EVENT_SYSTEM_FOREGROUND, Native.EVENT_SYSTEM_FOREGROUND, IntPtr.Zero, foregroundHook, 0, 0, Native.WINEVENT_OUTOFCONTEXT);
        Reschedule();
        Tick();
    }

    void Reschedule()
    {
        timer.Interval = TimeSpan.FromSeconds(windowVisible ? 1.5 : sessionActive ? 4 : 8);
        timer.Start();
    }

    public void SetMode(Mode m) { Rules.Mode = m; SaveSettings(); Tick(); }

    public void Toggle(string id, AppRule rule)
    {
        if (Rules.Rules.TryGetValue(id, out var current) && current == rule) Rules.Rules.Remove(id); else Rules.Rules[id] = rule;
        SaveSettings();
        Tick();
    }

    public void RestoreAll() { scheduler.RestoreAll(); Tick(); }
    public void Shutdown() { timer.Stop(); scheduler.RestoreAll(); Persist(); }
    void SaveSettings() { try { Store.Save("settings.json", Rules); } catch { } }
    void Persist() { try { Store.Save("usage.json", usage); } catch { } lastPersist = DateTime.Now; }

    public void Tick()
    {
        var nowT = DateTime.Now;
        var seconds = Math.Min((nowT - lastTick).TotalSeconds, 60);
        lastTick = nowT;
        var ownPid = Environment.ProcessId;
        var session = Process.GetCurrentProcess().SessionId;
        var stamp = Stopwatch.GetTimestamp();

        // Group processes by executable name; an "app" is a name with at least one visible window.
        var byName = new Dictionary<string, List<Process>>();
        var withWindow = new HashSet<string>();
        var windowPids = Native.PidsWithVisibleWindows();
        foreach (var proc in Process.GetProcesses())
        {
            try
            {
                if (proc.SessionId != session || proc.Id == ownPid) { proc.Dispose(); continue; }
                var name = proc.ProcessName.ToLowerInvariant();
                if (!byName.TryGetValue(name, out var list)) byName[name] = list = new();
                list.Add(proc);
                if (windowPids.Contains(proc.Id)) withWindow.Add(name);
            }
            catch { proc.Dispose(); }
        }
        Native.GetWindowThreadProcessId(Native.GetForegroundWindow(), out var frontPid);
        string? frontId = null;

        var apps = new List<AppGroup>();
        var alive = new HashSet<int>();
        var ownCpu = 0.0;
        foreach (var (name, procs) in byName)
        {
            if (!withWindow.Contains(name) || RuleSet.SystemEssential.Contains(name) && name != "explorer") { foreach (var p in procs) p.Dispose(); continue; }
            double cpu = 0;
            var pids = new List<int>();
            foreach (var p in procs)
            {
                pids.Add(p.Id); alive.Add(p.Id);
                if (p.Id == frontPid) frontId = name;
                cpu += CpuPercent(p.Id, stamp);
                p.Dispose();
            }
            if (!appInfo.TryGetValue(name, out var info)) appInfo[name] = info = Describe(name, pids[0]);
            apps.Add(new AppGroup(name, info.Name, Classifier.Classify(name, info.Path), pids, cpu));
        }
        ownCpu = CpuPercent(ownPid, stamp);
        foreach (var pid in cpuLast.Keys.Where(k => !alive.Contains(k) && k != ownPid).ToList()) cpuLast.Remove(pid);

        Evaluation eval;
        var wasActive = sessionActive;
        if (paused)
        {
            scheduler.RestoreAll();
            sessionActive = false;
            eval = new Evaluation(Profile.Balanced, false, null, new HashSet<int>());
        }
        else
        {
            eval = Evaluator.Evaluate(apps, frontId, Rules, sessionActive);
            if (eval.BoostTriggered) { lastBoostAt = nowT; sessionActive = true; }
            else if (sessionActive && (nowT - lastBoostAt).TotalSeconds > Rules.GraceSeconds) sessionActive = false;
            if (!eval.BoostTriggered && sessionActive) eval = Evaluator.Evaluate(apps, frontId, Rules, true);
            scheduler.Apply(eval.Demote);
        }
        usage.Record(nowT, seconds, sessionActive, sessionActive && !wasActive, scheduler.Count);
        if ((nowT - lastPersist).TotalSeconds > 60) Persist();
        if (wasActive != sessionActive) Reschedule();

        // What the window shows
        var moved = apps.Where(a => a.Pids.Any(scheduler.Contains))
            .Select(a => (a.Name, Rules.Effective(a.Id, a.Category, eval.Profile))).ToList();
        var frontBoost = apps.FirstOrDefault(a => a.Id == frontId && Rules.Effective(a.Id, a.Category, eval.Profile) == AppRule.Boost)?.Name;
        if (log.Update(paused, Rules.Mode, eval.Profile, sessionActive, frontBoost, eval.BoostApp, moved) is { } d)
        {
            DecisionHead = d.Headline + "."; DecisionDetail = d.Detail;
            Decisions.Insert(0, d); while (Decisions.Count > 8) Decisions.RemoveAt(Decisions.Count - 1);
        }
        Status = paused ? "Paused: Windows default scheduling restored."
            : sessionActive ? $"Protecting {eval.BoostApp ?? frontBoost ?? "your app"} · {scheduler.Count} background processes on efficiency cores"
            : Rules.Mode == Mode.Automatic ? "Automatically adapting to what you're doing" : $"{Labels.Of(Rules.Mode)} mode. Waiting for a boost app.";
        var activeMode = eval.Profile.Mode;
        Modes = Enum.GetValues<Mode>().Select(m => new ModeVM(m, m == Rules.Mode,
            m == Mode.Automatic && Rules.Mode == Mode.Automatic && !paused && activeMode != Mode.Balanced ? $"Automatic · {Labels.Of(activeMode)}" : Labels.Of(m))).ToList();

        var t = usage.Today;
        TodayText = t.BoostedSeconds < 1 ? "Today: nothing needed protecting yet"
            : $"Today: a boost ran for {Duration(t.BoostedSeconds)} · peak {t.PeakMoved} background processes moved to efficiency cores";
        NowText = (scheduler.Count == 0 ? "No Boost running, nothing moved" : $"{scheduler.Count} processes on efficiency cores now")
                  + $" · Coremium overhead {ownCpu:0.0}% of one core";
        SystemStats();
        UpdateRows(apps, frontId, eval.Profile);
    }

    double CpuPercent(int pid, long stamp)
    {
        if (Native.Times(pid) is not { } t) return 0;
        double value = 0;
        if (cpuLast.TryGetValue(pid, out var prev) && prev.Start == t.Start && stamp > prev.At)
        {
            var elapsed100ns = (stamp - prev.At) * 10_000_000.0 / Stopwatch.Frequency;
            value = Math.Max(0, (t.Cpu - prev.Cpu) / elapsed100ns * 100);
        }
        cpuLast[pid] = (t.Start, t.Cpu, stamp);
        return value;
    }

    static (string, ImageSource?, string?) Describe(string id, int pid)
    {
        var path = Native.ImagePath(pid);
        string name = id;
        ImageSource? icon = null;
        if (path != null)
        {
            try { var desc = FileVersionInfo.GetVersionInfo(path).FileDescription; if (!string.IsNullOrWhiteSpace(desc) && desc.Length < 40) name = desc.Trim(); } catch { }
            try
            {
                using var ico = System.Drawing.Icon.ExtractAssociatedIcon(path);
                if (ico != null)
                {
                    var src = System.Windows.Interop.Imaging.CreateBitmapSourceFromHIcon(ico.Handle, System.Windows.Int32Rect.Empty,
                        System.Windows.Media.Imaging.BitmapSizeOptions.FromWidthAndHeight(32, 32));
                    src.Freeze(); icon = src;
                }
            }
            catch { }
        }
        if (name == id && id.Length > 0) name = char.ToUpperInvariant(id[0]) + id[1..];
        return (name, icon, path);
    }

    void SystemStats()
    {
        if (Native.GetSystemTimes(out var idle, out var kernel, out var user))
        {
            long total = kernel + user, dTotal = total - lastSysTotal, dIdle = idle - lastSysIdle;
            if (lastSysTotal > 0 && dTotal > 0) { Load = Math.Clamp(1 - dIdle / (double)dTotal, 0, 1); LoadText = $"{Load * 100:0}% total load"; }
            lastSysIdle = idle; lastSysTotal = total;
        }
        var m = new Native.MemoryStatus { Length = (uint)System.Runtime.InteropServices.Marshal.SizeOf<Native.MemoryStatus>() };
        if (Native.GlobalMemoryStatusEx(ref m))
            MemoryText = $"{(m.TotalPhys - m.AvailPhys) / 1073741824.0:0.0} / {m.TotalPhys / 1073741824.0:0} GB memory";
        if (Native.GetSystemPowerStatus(out var ps))
        {
            var onBattery = ps.AcLine == 0;
            PowerText = onBattery ? $"On battery{(ps.Percent <= 100 ? $" · {ps.Percent}%" : "")}" : "Plugged in";
            Warning = onBattery ? "On battery: plug in for full speed" : "";
        }
    }

    void UpdateRows(List<AppGroup> apps, string? frontId, Profile profile)
    {
        var ordered = apps.OrderBy(a => Rules.Effective(a.Id, a.Category, profile) == AppRule.Boost ? 0 : 1)
                          .ThenBy(a => a.Name, StringComparer.OrdinalIgnoreCase).ToList();
        var ids = ordered.Select(a => a.Id).ToList();
        for (int i = Rows.Count - 1; i >= 0; i--) if (!ids.Contains(Rows[i].Id)) Rows.RemoveAt(i);
        for (int i = 0; i < ordered.Count; i++)
        {
            var a = ordered[i];
            var row = Rows.FirstOrDefault(r => r.Id == a.Id);
            if (row == null) { row = new AppRowVM { Id = a.Id, Name = a.Name, Icon = appInfo[a.Id].Icon }; Rows.Insert(Math.Min(i, Rows.Count), row); }
            else if (Rows.IndexOf(row) != i) Rows.Move(Rows.IndexOf(row), Math.Min(i, Rows.Count - 1));
            var effective = Rules.Effective(a.Id, a.Category, profile);
            Rules.Rules.TryGetValue(a.Id, out var chosen);
            var hasChoice = Rules.Rules.ContainsKey(a.Id);
            var meaning = Labels.Meaning(effective);
            row.Subtitle = a.Id == frontId ? "In front" : meaning.Length > 0 ? meaning : Labels.Of(a.Category);
            row.Moved = a.Pids.Any(scheduler.Contains);
            row.Load = row.Moved ? "Background" : a.Cpu < 10 ? "" : a.Cpu < 40 ? "Light" : a.Cpu < 120 ? "Moderate" : "Heavy";
            row.Numbers = advanced ? $"{a.Cpu:0}% · {a.Pids.Count} proc{(a.Pids.Count == 1 ? "" : "s")} · {(hasChoice ? "your choice" : Rules.Protected.Contains(a.Id) ? "protected" : effective != AppRule.Normal ? Labels.Of(profile.Mode) + " mode" : "default")}" : "";
            var states = Enum.GetValues<AppRule>().Select(r => hasChoice && chosen == r ? "chosen" : !hasChoice && effective == r ? "implied" : "none");
            var newChips = Enum.GetValues<AppRule>().Zip(states, (r, s) => new ChipVM(r, s)).ToList();
            if (!row.Chips.Select(c => c.State).SequenceEqual(newChips.Select(c => c.State))) row.Chips = newChips;
        }
    }

    public static string Duration(double s) => s < 60 ? $"{s:0} s" : s < 3600 ? $"{s / 60:0} min" : $"{(int)(s / 3600)} h {(int)(s % 3600 / 60)} min";
}
