using System;
using System.Runtime.InteropServices;
using Coremium.Core;

namespace Coremium.App;

/// Windows power mode ("Best performance" vs balanced) for the length of a boost. The previous mode is saved first,
/// so it is put back on session end, pause, quit, or the next launch after a crash.
sealed class PowerMode
{
    static readonly Guid BestPerformance = new("ded574b5-45a0-4f42-8737-46345c09c238");

    [DllImport("powrprof.dll")] static extern uint PowerGetEffectiveOverlayScheme(out Guid scheme);
    [DllImport("powrprof.dll")] static extern uint PowerSetActiveOverlayScheme(Guid scheme);

    sealed class State { public bool Active { get; set; } public Guid Previous { get; set; } }
    readonly State state = Store.Load<State>("power.json");

    public bool Active => state.Active;

    public void Begin()
    {
        if (state.Active) return;
        try
        {
            if (PowerGetEffectiveOverlayScheme(out var current) != 0 || current == BestPerformance) return;
            state.Previous = current;
            state.Active = true;
            Save();   // record first, then change, so a crash can always be undone
            if (PowerSetActiveOverlayScheme(BestPerformance) != 0) { state.Active = false; Save(); }
        }
        catch (EntryPointNotFoundException) { }
        catch (DllNotFoundException) { }
    }

    public void End()
    {
        if (!state.Active) return;
        try { PowerSetActiveOverlayScheme(state.Previous); } catch { }
        state.Active = false;
        Save();
    }

    void Save() { try { Store.Save("power.json", state); } catch { } }
}
