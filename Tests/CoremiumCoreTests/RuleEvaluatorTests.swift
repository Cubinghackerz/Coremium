import XCTest
@testable import CoremiumCore

final class RuleEvaluatorTests: XCTestCase {
    let me: UInt32 = 501
    let ownPid: Int32 = 900

    // Roblox 100 (boost) ─ 101 helper
    // Chrome 200 (auto)  ─ 201, 202 ─ 203 (grandchild), 204 owned by root
    // Claude 300 (auto)  ─ 301
    // Finder 400 (efficiency but protected)
    // Notes 500 (efficiency)
    // TextEdit 600 (normal)
    func makeSnapshot() -> ProcessSnapshot {
        func p(_ pid: Int32, _ ppid: Int32, uid: UInt32 = 501) -> ProcEntry {
            ProcEntry(pid: pid, ppid: ppid, uid: uid, startTime: UInt64(pid) * 10, name: "p\(pid)")
        }
        return ProcessSnapshot([
            p(1, 0, uid: 0), p(ownPid, 1),
            p(100, 1), p(101, 100),
            p(200, 1), p(201, 200), p(202, 200), p(203, 202), p(204, 200, uid: 0),
            p(300, 1), p(301, 300),
            p(400, 1), p(500, 1), p(600, 1),
        ])
    }

    let apps = [
        AppProcess(pid: 100, bundleID: "com.roblox.RobloxPlayer"),
        AppProcess(pid: 200, bundleID: "com.google.Chrome"),
        AppProcess(pid: 300, bundleID: "com.anthropic.claudefordesktop"),
        AppProcess(pid: 400, bundleID: "com.apple.finder"),
        AppProcess(pid: 500, bundleID: "com.apple.Notes"),
        AppProcess(pid: 600, bundleID: "com.apple.TextEdit"),
    ]

    func rules() -> RuleSet {
        var r = RuleSet(mode: .balanced, rules: [
            "com.roblox.RobloxPlayer": .boost,
            "com.google.Chrome": .auto,
            "com.anthropic.claudefordesktop": .auto,
            "com.apple.finder": .efficiency,
            "com.apple.Notes": .efficiency,
        ], protectedBundleIDs: RuleSet.defaultProtected)
        r.demoteHeavyApps = false
        return r
    }

    func input(front: Int32?, session: Bool, cpu: [Int32: Double] = [:], rules: RuleSet? = nil) -> EvaluationInput {
        EvaluationInput(snapshot: makeSnapshot(), apps: apps, frontmostPid: front, rules: rules ?? self.rules(),
                        sessionActive: session, cpuByAppPid: cpu, ownUid: me, ownPid: ownPid)
    }

    func testNoSessionOnlyEfficiencyAppsDemoted() {
        let result = RuleEvaluator.pidsToDemote(input(front: 600, session: false))
        XCTAssertEqual(result, [500])
    }

    func testSessionDemotesAutoTreesButNotRootOwnedOrBoost() {
        let result = RuleEvaluator.pidsToDemote(input(front: 100, session: true))
        XCTAssertEqual(result, [200, 201, 202, 203, 300, 301, 500])
        XCTAssertFalse(result.contains(204), "root-owned child must never be touched")
        XCTAssertFalse(result.contains(100))
        XCTAssertFalse(result.contains(101))
    }

    func testFrontmostAppIsAlwaysSpared() {
        let result = RuleEvaluator.pidsToDemote(input(front: 200, session: true))
        XCTAssertFalse(result.contains(200))
        XCTAssertFalse(result.contains(203))
        XCTAssertTrue(result.contains(300))
    }

    func testFrontmostEfficiencyAppIsSpared() {
        let result = RuleEvaluator.pidsToDemote(input(front: 500, session: false))
        XCTAssertTrue(result.isEmpty)
    }

    func testProtectedAppNeverDemotedEvenWithEfficiencyRule() {
        let result = RuleEvaluator.pidsToDemote(input(front: 600, session: true))
        XCTAssertFalse(result.contains(400))
    }

    func testExplicitChoiceBeatsDefaultProtectionButNotSystemEssentials() {
        var r = rules()
        r.rules["com.spotify.client"] = .efficiency
        var i = input(front: 600, session: true, rules: r)
        i.apps = i.apps.map { $0.pid == 500 ? AppProcess(pid: 500, bundleID: "com.spotify.client") : $0 }
        XCTAssertTrue(RuleEvaluator.pidsToDemote(i).contains(500), "Spotify set to Eco is moved even though protected by default")
        XCTAssertFalse(RuleEvaluator.pidsToDemote(input(front: 600, session: true)).contains(400), "Finder stays untouchable")
        var plain = r
        plain.rules["com.spotify.client"] = nil
        var j = input(front: 600, session: true, rules: plain)
        j.apps = i.apps
        XCTAssertFalse(RuleEvaluator.pidsToDemote(j).contains(500), "default protection still applies without a choice")
    }

    func testOwnProcessNeverDemoted() {
        var r = rules()
        r.rules["com.cubinghackerz.coremium"] = .efficiency
        var i = input(front: 600, session: true, rules: r)
        i.apps.append(AppProcess(pid: ownPid, bundleID: "com.cubinghackerz.coremium"))
        XCTAssertFalse(RuleEvaluator.pidsToDemote(i).contains(ownPid))
    }

    func testHeavyAppCatcher() {
        var r = rules()
        r.demoteHeavyApps = true
        r.heavyThresholdPercent = 25
        let heavy = RuleEvaluator.pidsToDemote(input(front: 100, session: true, cpu: [600: 80], rules: r))
        XCTAssertTrue(heavy.contains(600))
        let light = RuleEvaluator.pidsToDemote(input(front: 100, session: true, cpu: [600: 5], rules: r))
        XCTAssertFalse(light.contains(600))
        let noSession = RuleEvaluator.pidsToDemote(input(front: 100, session: false, cpu: [600: 80], rules: r))
        XCTAssertFalse(noSession.contains(600))
    }

    func testBoostTrigger() {
        let r = rules()
        XCTAssertTrue(RuleEvaluator.boostTriggered(apps: apps, frontmostPid: 100, rules: r, cpuByAppPid: [:]))
        XCTAssertFalse(RuleEvaluator.boostTriggered(apps: apps, frontmostPid: 200, rules: r, cpuByAppPid: [:]))
        XCTAssertTrue(RuleEvaluator.boostTriggered(apps: apps, frontmostPid: 200, rules: r, cpuByAppPid: [100: 90]))
        var quiet = r
        quiet.boostWhenBusy = false
        XCTAssertFalse(RuleEvaluator.boostTriggered(apps: apps, frontmostPid: 200, rules: quiet, cpuByAppPid: [100: 90]))
    }

    func testDefaultsUseAutomaticModeWithNoOverrides() {
        XCTAssertEqual(RuleSet.defaults.mode, .automatic)
        XCTAssertTrue(RuleSet.defaults.rules.isEmpty)
        XCTAssertEqual(RuleSet.defaults.rule(for: "com.example.unknown"), .normal)
        XCTAssertTrue(RuleSet.defaults.protectedBundleIDs.contains("com.cubinghackerz.coremium"))
        // Roblox is protected purely because it is a game.
        let profile = ModeProfile.resolve(mode: .automatic, frontCategory: .game, busyCategories: [])
        XCTAssertEqual(RuleSet.defaults.effectiveRule(bundleID: "com.roblox.RobloxPlayer", category: .game, profile: profile), .boost)
        XCTAssertEqual(RuleSet.defaults.effectiveRule(bundleID: "com.google.Chrome", category: .browser, profile: profile), .auto)
    }

    func testRuleSetRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(RuleSet.defaults)
        XCTAssertEqual(try JSONDecoder().decode(RuleSet.self, from: data), RuleSet.defaults)
    }
}

extension RuleEvaluatorTests {
    func testOnBatteryHeavyBackgroundAppsStepAsideWithoutABoost() {
        var r = rules()
        r.mode = .balanced
        r.rules["com.apple.TextEdit"] = nil
        var i = input(front: 500, session: false, rules: r)
        i.cpuByAppPid = [600: 80]
        i.onBattery = true
        XCTAssertTrue(RuleEvaluator.pidsToDemote(i).contains(600), "heavy normal app moves aside on battery")
        i.onBattery = false
        XCTAssertFalse(RuleEvaluator.pidsToDemote(i).contains(600))
        i.onBattery = true
        i.rules.saveBatteryWhenUnplugged = false
        XCTAssertFalse(RuleEvaluator.pidsToDemote(i).contains(600))
    }
}
