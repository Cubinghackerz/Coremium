using Coremium.Core;
using Xunit;

public class CoreTests
{
    static AppGroup App(string id, Category c, double cpu = 0, params int[] pids) => new(id, id, c, pids.Length > 0 ? pids : [id.GetHashCode() & 0xffff], cpu);

    readonly List<AppGroup> apps =
    [
        App("robloxplayerbeta", Category.Game, 80, 100, 101),
        App("chrome", Category.Browser, 30, 200, 201, 202),
        App("discord", Category.Communication, 5, 300),
        App("spotify", Category.Media, 2, 400),
        App("explorer", Category.System, 1, 500),
    ];

    [Fact]
    public void AutomaticFollowsTheAppInFront()
    {
        Assert.Equal(Mode.Gaming, Evaluator.ActiveProfile(apps, "robloxplayerbeta", new RuleSet()).Mode);
        Assert.Equal(Mode.Coding, Profile.Resolve(Mode.Automatic, Category.Developer, new HashSet<Category>()).Mode);
        Assert.Equal(Mode.Balanced, Profile.Resolve(Mode.Automatic, Category.Browser, new HashSet<Category>()).Mode);
    }

    [Fact]
    public void GameInFrontMovesBrowsersAndChatButNotProtected()
    {
        var e = Evaluator.Evaluate(apps, "robloxplayerbeta", new RuleSet(), sessionActive: false);
        Assert.True(e.BoostTriggered);
        Assert.Contains(200, e.Demote);
        Assert.Contains(202, e.Demote);
        Assert.Contains(300, e.Demote);
        Assert.DoesNotContain(100, e.Demote);
        Assert.DoesNotContain(400, e.Demote);   // Spotify protected by default
        Assert.DoesNotContain(500, e.Demote);   // Explorer essential
    }

    [Fact]
    public void ExplicitChoiceBeatsDefaultProtectionButNotEssentials()
    {
        var rules = new RuleSet { Mode = Mode.Balanced };
        rules.Rules["spotify"] = AppRule.Eco;
        rules.Rules["explorer"] = AppRule.Eco;
        var e = Evaluator.Evaluate(apps, "chrome", rules, false);
        Assert.Contains(400, e.Demote);
        Assert.DoesNotContain(500, e.Demote);
    }

    [Fact]
    public void FrontAppIsNeverMovedAndYieldOnlyMovesDuringSession()
    {
        var rules = new RuleSet { Mode = Mode.Balanced, BoostWhenBusy = false };
        rules.Rules["chrome"] = AppRule.Yield;
        rules.Rules["discord"] = AppRule.Eco;
        var idle = Evaluator.Evaluate(apps, "spotify", rules, false);
        Assert.DoesNotContain(200, idle.Demote);
        Assert.Contains(300, idle.Demote);
        var inFront = Evaluator.Evaluate(apps, "discord", rules, true);
        Assert.DoesNotContain(300, inFront.Demote);
        Assert.Contains(200, inFront.Demote);
    }

    [Fact]
    public void DecisionSentencesReadNaturally()
    {
        Assert.Equal("Chrome and Discord moved to Yield and Spotify to Eco.",
            DecisionLog.MovedSentence([("Discord", AppRule.Yield), ("Chrome", AppRule.Yield), ("Spotify", AppRule.Eco)]));
        var log = new DecisionLog();
        Assert.NotNull(log.Update(false, Mode.Automatic, Profile.Balanced, false, null, null, []));
        Assert.Null(log.Update(false, Mode.Automatic, Profile.Balanced, false, null, null, []));
        Assert.Equal("Paused", log.Update(true, Mode.Automatic, Profile.Balanced, false, null, null, [])!.Headline);
    }

    [Fact]
    public void ClassifierKnowsCommonApps()
    {
        Assert.Equal(Category.Game, Classifier.Classify("RobloxPlayerBeta", null));
        Assert.Equal(Category.Game, Classifier.Classify("whatever", @"C:\Program Files (x86)\Steam\steamapps\common\G\g.exe"));
        Assert.Equal(Category.Developer, Classifier.Classify("Code", null));
        Assert.Equal(Category.Other, Classifier.Classify("unknownthing", null));
    }

    [Fact]
    public void UsageAndStoreRoundTrip()
    {
        Environment.SetEnvironmentVariable("COREMIUM_DATA_DIR", Path.Combine(Path.GetTempPath(), "coremium-test-" + Guid.NewGuid()));
        var u = new Usage();
        u.Record(DateTime.Now, 5, true, true, 12);
        u.Record(DateTime.Now, 5, true, false, 3);
        Store.Save("usage.json", u);
        var back = Store.Load<Usage>("usage.json");
        Assert.Equal(10, back.Today.BoostedSeconds);
        Assert.Equal(12, back.Today.PeakMoved);
        Assert.Equal(1, back.Today.Sessions);
        var rules = new RuleSet { Mode = Mode.Coding };
        rules.Rules["chrome"] = AppRule.Yield;
        Store.Save("settings.json", rules);
        var r = Store.Load<RuleSet>("settings.json");
        Assert.Equal(Mode.Coding, r.Mode);
        Assert.Equal(AppRule.Yield, r.Rules["chrome"]);
    }
}
