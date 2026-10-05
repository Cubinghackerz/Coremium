namespace Coremium.Core;

public sealed record Decision(DateTime At, string Headline, string Detail);

/// <summary>Turns state changes into plain sentences, so Automatic never feels like a black box.</summary>
public sealed class DecisionLog
{
    string lastKey = "";
    public List<Decision> Items { get; } = new();

    public Decision? Update(bool paused, Mode mode, Profile profile, bool session, string? frontBoostApp, string? busyBoostApp,
                            IReadOnlyList<(string Name, AppRule Rule)> moved)
    {
        var key = paused ? "paused" : $"{profile.Mode}|{session}|{string.Join(",", moved.Select(m => m.Name + m.Rule))}";
        if (key == lastKey) return null;
        lastKey = key;
        string head, detail;
        if (paused) { head = "Paused"; detail = "Windows default scheduling restored. Nothing is being moved."; }
        else if (session || moved.Count > 0)
        {
            head = mode == Mode.Automatic ? $"{Labels.Of(profile.Mode)} mode activated" : $"{Labels.Of(mode)} mode";
            var parts = new List<string>();
            if (frontBoostApp != null) parts.Add($"{frontBoostApp} became active.");
            else if (busyBoostApp != null) parts.Add($"{busyBoostApp} is busy in the background.");
            if (moved.Count > 0) parts.Add(MovedSentence(moved));
            detail = string.Join(" ", parts);
        }
        else
        {
            head = "Standing by";
            detail = mode == Mode.Automatic
                ? "No Boost is running, so nothing is being moved. Automatic switches profile when a game, creative app, dev tool or local AI model is in front."
                : "No Boost is running, so nothing is being moved. Your app rules are ready.";
        }
        var d = new Decision(DateTime.Now, head, detail);
        Items.Insert(0, d);
        if (Items.Count > 30) Items.RemoveRange(30, Items.Count - 30);
        return d;
    }

    /// <summary>"Chrome and Discord moved to Yield and Spotify to Eco."</summary>
    public static string MovedSentence(IReadOnlyList<(string Name, AppRule Rule)> moved)
    {
        static string Names(List<string> n) => n.Count switch
        {
            1 => n[0],
            <= 3 => string.Join(", ", n.Take(n.Count - 1)) + " and " + n[^1],
            _ => string.Join(", ", n.Take(2)) + $" and {n.Count - 2} more",
        };
        var parts = new List<string>();
        foreach (var rule in new[] { AppRule.Yield, AppRule.Eco })
        {
            var names = moved.Where(m => m.Rule == rule).Select(m => m.Name).OrderBy(n => n, StringComparer.OrdinalIgnoreCase).ToList();
            if (names.Count > 0) parts.Add(parts.Count == 0 ? $"{Names(names)} moved to {rule}" : $"{Names(names)} to {rule}");
        }
        return string.Join(" and ", parts) + ".";
    }
}
