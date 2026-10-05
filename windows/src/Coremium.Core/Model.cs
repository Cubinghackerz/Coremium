using System.Text.Json.Serialization;

namespace Coremium.Core;

/// <summary>What Coremium does with one app.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<AppRule>))]
public enum AppRule { Boost, Normal, Yield, Eco }

[JsonConverter(typeof(JsonStringEnumConverter<Mode>))]
public enum Mode { Automatic, Balanced, Gaming, Creator, Coding, LocalAI }

public enum Category { Game, Creative, Developer, LocalAI, Browser, Communication, AI, Media, Productivity, System, Other }

public static class Labels
{
    public static string Of(Mode m) => m switch { Mode.LocalAI => "Local AI", _ => m.ToString() };
    public static string Of(AppRule r) => r.ToString();
    public static string Of(Category c) => c switch
    {
        Category.Game => "Games", Category.Creative => "Creative tools", Category.Developer => "Developer tools",
        Category.LocalAI => "Local AI & compute", Category.Browser => "Browsers", Category.Communication => "Communication",
        Category.AI => "AI assistants", Category.Media => "Media", Category.Productivity => "Productivity",
        Category.System => "System & utilities", _ => "Other",
    };
    /// <summary>What the rule means for this app, shown under its name.</summary>
    public static string Meaning(AppRule r) => r switch
    {
        AppRule.Boost => "Protected", AppRule.Yield => "Steps aside during boosts",
        AppRule.Eco => "Always on efficiency cores", _ => "",
    };
}

/// <summary>Which kinds of app a mode protects and which it moves aside.</summary>
public sealed record Profile(Mode Mode, IReadOnlySet<Category> Boost, IReadOnlySet<Category> Yield)
{
    public static readonly Profile Balanced = new(Mode.Balanced, new HashSet<Category>(), new HashSet<Category>());
    public static readonly Profile Gaming = new(Mode.Gaming, new HashSet<Category> { Category.Game },
        new HashSet<Category> { Category.Creative, Category.Developer, Category.Browser, Category.Communication, Category.AI });
    public static readonly Profile Creator = new(Mode.Creator, new HashSet<Category> { Category.Creative },
        new HashSet<Category> { Category.Game, Category.Browser, Category.Communication, Category.AI });
    public static readonly Profile Coding = new(Mode.Coding, new HashSet<Category> { Category.Developer },
        new HashSet<Category> { Category.Game, Category.Creative });
    public static readonly Profile LocalAI = new(Mode.LocalAI, new HashSet<Category> { Category.LocalAI },
        new HashSet<Category> { Category.Game, Category.Creative, Category.Browser, Category.Communication });

    /// <summary>The profile in force. Automatic follows the app in front, or a busy game/creative/AI/dev app.</summary>
    public static Profile Resolve(Mode mode, Category? front, IReadOnlySet<Category> busy) => mode switch
    {
        Mode.Balanced => Balanced, Mode.Gaming => Gaming, Mode.Creator => Creator, Mode.Coding => Coding, Mode.LocalAI => LocalAI,
        _ => (front is { } f ? Trigger(f) : null)
             ?? new[] { Category.Game, Category.LocalAI, Category.Creative, Category.Developer }.Where(busy.Contains).Select(Trigger).FirstOrDefault(p => p != null)
             ?? Balanced,
    };

    static Profile? Trigger(Category c) => c switch
    {
        Category.Game => Gaming, Category.Creative => Creator, Category.Developer => Coding, Category.LocalAI => LocalAI, _ => null,
    };
}

public sealed class RuleSet
{
    public Mode Mode { get; set; } = Mode.Automatic;
    /// <summary>Your explicit choices, keyed by app id (lower-case executable name, e.g. "chrome").</summary>
    public Dictionary<string, AppRule> Rules { get; set; } = new();
    public HashSet<string> Protected { get; set; } = new(DefaultProtected);
    public bool BoostWhenBusy { get; set; } = true;
    public double BoostBusyPercent { get; set; } = 20;
    public double GraceSeconds { get; set; } = 90;

    /// <summary>Protected by default; an explicit choice overrides these (so Spotify can be set to Eco).</summary>
    public static readonly string[] DefaultProtected = ["spotify", "music.ui", "explorer"];

    /// <summary>Never moved, whatever the user picks.</summary>
    public static readonly HashSet<string> SystemEssential = new(StringComparer.OrdinalIgnoreCase)
    {
        "coremium", "explorer", "dwm", "csrss", "winlogon", "sihost", "shellexperiencehost", "startmenuexperiencehost",
        "searchhost", "textinputhost", "applicationframehost", "systemsettings", "taskmgr", "lockapp", "ctfmon", "fontdrvhost",
    };

    public AppRule Effective(string id, Category category, Profile profile)
    {
        if (SystemEssential.Contains(id)) return AppRule.Normal;
        if (Rules.TryGetValue(id, out var chosen)) return chosen;
        if (Protected.Contains(id)) return AppRule.Normal;
        if (profile.Boost.Contains(category)) return AppRule.Boost;
        if (profile.Yield.Contains(category)) return AppRule.Yield;
        return AppRule.Normal;
    }
}

/// <summary>A running app: every process with the same executable name, grouped.</summary>
public sealed record AppGroup(string Id, string Name, Category Category, IReadOnlyList<int> Pids, double Cpu);
