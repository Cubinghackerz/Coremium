using System;
using System.Collections.Generic;
using System.Linq;
using Coremium.Core;

namespace Coremium.App;

/// <summary>Moves processes into Windows "efficiency mode" (EcoQoS + low priority) and back. Every change is recorded first,
/// so a crash or forced quit is undone on the next launch.</summary>
sealed class Scheduler
{
    readonly Ledger ledger = Store.Load<Ledger>("demoted.json");
    public int Count => ledger.Entries.Count;
    public bool Contains(int pid) => ledger.Entries.ContainsKey(pid);

    public void Apply(HashSet<int> target)
    {
        var changed = false;
        foreach (var e in ledger.Entries.Values.Where(e => !target.Contains(e.Pid)).ToList()) { Restore(e); changed = true; }
        foreach (var pid in target.Where(p => !ledger.Entries.ContainsKey(p)))
        {
            var t = Native.Times(pid);
            if (t == null) continue;
            var h = Native.OpenProcess(Native.PROCESS_SET_INFORMATION | Native.PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
            if (h == IntPtr.Zero) continue;
            try
            {
                var before = Native.GetPriorityClass(h);
                if (before == 0) continue;
                ledger.Entries[pid] = new LedgerEntry(pid, t.Value.Start, (int)before);
                Native.SetEcoQoS(h, true);
                Native.SetPriorityClass(h, Native.IDLE_PRIORITY_CLASS);
                changed = true;
            }
            finally { Native.CloseHandle(h); }
        }
        if (changed) Save();
    }

    public void RestoreAll()
    {
        if (ledger.Entries.Count == 0) return;
        foreach (var e in ledger.Entries.Values.ToList()) Restore(e);
        Save();
    }

    void Restore(LedgerEntry e)
    {
        ledger.Entries.Remove(e.Pid);
        // Only touch the same process: a reused pid has a different start time.
        if (Native.Times(e.Pid) is not { } t || t.Start != e.StartTicks) return;
        var h = Native.OpenProcess(Native.PROCESS_SET_INFORMATION | Native.PROCESS_QUERY_LIMITED_INFORMATION, false, e.Pid);
        if (h == IntPtr.Zero) return;
        try
        {
            Native.SetEcoQoS(h, false);
            Native.SetPriorityClass(h, e.PriorityBefore == Native.IDLE_PRIORITY_CLASS ? Native.NORMAL_PRIORITY_CLASS : (uint)e.PriorityBefore);
        }
        finally { Native.CloseHandle(h); }
    }

    void Save() { try { Store.Save("demoted.json", ledger); } catch { } }
}
