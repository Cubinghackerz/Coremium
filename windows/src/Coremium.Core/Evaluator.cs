namespace Coremium.Core;

public sealed record Evaluation(Profile Profile, bool BoostTriggered, string? BoostApp, HashSet<int> Demote);

/// <summary>Pure decision logic: given the running apps, which processes go to the efficiency cores.</summary>
public static class Evaluator
{
    public static Profile ActiveProfile(IReadOnlyList<AppGroup> apps, string? frontId, RuleSet rules)
    {
        var front = apps.FirstOrDefault(a => a.Id == frontId)?.Category;
        var busy = rules.BoostWhenBusy
            ? apps.Where(a => a.Cpu > rules.BoostBusyPercent).Select(a => a.Category).ToHashSet()
            : new HashSet<Category>();
        return Profile.Resolve(rules.Mode, front, busy);
    }

    public static Evaluation Evaluate(IReadOnlyList<AppGroup> apps, string? frontId, RuleSet rules, bool sessionActive)
    {
        var profile = ActiveProfile(apps, frontId, rules);
        string? boostApp = null;
        var triggered = false;
        foreach (var a in apps)
        {
            if (rules.Effective(a.Id, a.Category, profile) != AppRule.Boost) continue;
            if (a.Id == frontId) { triggered = true; boostApp = a.Name; break; }
            if (rules.BoostWhenBusy && a.Cpu > rules.BoostBusyPercent) { triggered = true; boostApp ??= a.Name; }
        }
        var session = sessionActive || triggered;
        var demote = new HashSet<int>();
        foreach (var a in apps)
        {
            if (a.Id == frontId || RuleSet.SystemEssential.Contains(a.Id)) continue;
            var rule = rules.Effective(a.Id, a.Category, profile);
            var move = rule switch { AppRule.Eco => true, AppRule.Yield => session, _ => false };
            if (move) demote.UnionWith(a.Pids);
        }
        return new Evaluation(profile, triggered, boostApp, demote);
    }
}
