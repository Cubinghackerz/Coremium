using System.Text.Json;

namespace Coremium.Core;

/// <summary>Everything Coremium keeps lives in %LOCALAPPDATA%\Coremium (or COREMIUM_DATA_DIR).</summary>
public static class Store
{
    public static string Dir
    {
        get
        {
            var dir = Environment.GetEnvironmentVariable("COREMIUM_DATA_DIR")
                      ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Coremium");
            Directory.CreateDirectory(dir);
            return dir;
        }
    }

    static readonly JsonSerializerOptions Options = new() { WriteIndented = true };

    public static T Load<T>(string name) where T : new()
    {
        try { return JsonSerializer.Deserialize<T>(File.ReadAllText(Path.Combine(Dir, name)), Options) ?? new T(); }
        catch { return new T(); }
    }

    public static void Save<T>(string name, T value)
    {
        var path = Path.Combine(Dir, name);
        File.WriteAllText(path + ".tmp", JsonSerializer.Serialize(value, Options));
        File.Move(path + ".tmp", path, overwrite: true);
    }
}

/// <summary>One process Coremium moved, with what to put back. Start time guards against pid reuse.</summary>
public sealed record LedgerEntry(int Pid, long StartTicks, int PriorityBefore);

public sealed class Ledger
{
    public Dictionary<int, LedgerEntry> Entries { get; set; } = new();
}

public sealed class DayStats
{
    public int Sessions { get; set; }
    public double BoostedSeconds { get; set; }
    public int PeakMoved { get; set; }
}

public sealed class Usage
{
    public Dictionary<string, DayStats> Days { get; set; } = new();
    public DayStats Today => Days.TryGetValue(Key(DateTime.Now), out var d) ? d : new DayStats();
    public static string Key(DateTime t) => t.ToString("yyyy-MM-dd");

    public void Record(DateTime now, double seconds, bool session, bool sessionStarted, int moved)
    {
        var key = Key(now);
        if (!Days.TryGetValue(key, out var d)) Days[key] = d = new DayStats();
        if (sessionStarted) d.Sessions++;
        if (session) d.BoostedSeconds += seconds;
        d.PeakMoved = Math.Max(d.PeakMoved, moved);
        foreach (var old in Days.Keys.Where(k => string.CompareOrdinal(k, Key(now.AddDays(-60))) < 0).ToList()) Days.Remove(old);
    }
}
