import XCTest
@testable import CoremiumCore

final class AdaptiveAutomaticTests: XCTestCase {
    func input(category: AppCategory = .browser, cpu: Double = 100) -> EvaluationInput {
        EvaluationInput(snapshot: ProcessSnapshot([
            ProcEntry(pid: 100, ppid: 1, uid: 501, startTime: 10, name: "game"),
            ProcEntry(pid: 200, ppid: 1, uid: 501, startTime: 20, name: "background"),
            ProcEntry(pid: 201, ppid: 200, uid: 501, startTime: 21, name: "helper"),
            ProcEntry(pid: 202, ppid: 200, uid: 0, startTime: 22, name: "root helper"),
        ]), apps: [AppProcess(pid: 100, bundleID: "game"), AppProcess(pid: 200, bundleID: "background")],
            frontmostPid: 100, rules: .defaults, sessionActive: true, cpuByAppPid: [100: 150, 200: cpu],
            categories: ["game": .game, "background": category], ownUid: 501, ownPid: 900)
    }

    func engage(_ policy: inout AdaptiveAutomaticPolicy, input: EvaluationInput) -> AdaptiveAutomaticDecision {
        _ = policy.evaluate(input, performanceLoad: 0.9, uptime: 0)
        _ = policy.evaluate(input, performanceLoad: 0.9, uptime: 3)
        return policy.evaluate(input, performanceLoad: 0.9, uptime: 6)
    }

    func testRequiresSustainedPressureAndBusyBackgroundWork() {
        var policy = AdaptiveAutomaticPolicy()
        XCTAssertTrue(policy.evaluate(input(), performanceLoad: 0.9, uptime: 0).appPids.isEmpty)
        XCTAssertTrue(policy.evaluate(input(), performanceLoad: 0.4, uptime: 3).appPids.isEmpty)
        XCTAssertTrue(policy.evaluate(input(), performanceLoad: 0.9, uptime: 6).appPids.isEmpty)
        XCTAssertEqual(policy.evaluate(input(), performanceLoad: 0.9, uptime: 12).appPids, [200])
        var quietApp = AdaptiveAutomaticPolicy()
        XCTAssertTrue(engage(&quietApp, input: input(cpu: 5)).appPids.isEmpty)
    }

    func testRestoresAfterReliefWithoutFlappingAndRetainsThrottledApps() {
        var policy = AdaptiveAutomaticPolicy()
        XCTAssertEqual(engage(&policy, input: input()).appPids, [200])
        XCTAssertEqual(policy.evaluate(input(cpu: 5), performanceLoad: 0.5, uptime: 10).phase, .recovering)
        XCTAssertEqual(policy.evaluate(input(cpu: 5), performanceLoad: 0.5, uptime: 20).appPids, [200])
        XCTAssertTrue(policy.evaluate(input(cpu: 5), performanceLoad: 0.5, uptime: 22).appPids.isEmpty)
        XCTAssertTrue(policy.evaluate(input(), performanceLoad: 0.9, uptime: 25).appPids.isEmpty)
    }

    func testPreservesBusyBuildsRendersAndModels() {
        for category in [AppCategory.developer, .creative, .localAI] {
            var policy = AdaptiveAutomaticPolicy()
            XCTAssertTrue(engage(&policy, input: input(category: category)).appPids.isEmpty)
        }
    }

    func testExplicitChoicesAlwaysWin() {
        for rule in AppRule.allCases {
            var policy = AdaptiveAutomaticPolicy()
            var value = input()
            value.rules.rules["background"] = rule
            XCTAssertTrue(engage(&policy, input: value).appPids.isEmpty)
            value.adaptiveDemotionAppPids = [200]
            XCTAssertEqual(RuleEvaluator.pidsToDemote(value), [.auto, .efficiency].contains(rule) ? [200, 201] : [])
        }
    }

    func testEvaluatorShieldsForegroundChildrenAndOtherUsers() {
        var value = input()
        value.adaptiveDemotionAppPids = [100, 200]
        XCTAssertEqual(RuleEvaluator.pidsToDemote(value), [200, 201])
        value.frontmostPid = 200
        XCTAssertTrue(RuleEvaluator.pidsToDemote(value).isEmpty)
    }

    func testAnotherInstanceOfForegroundAppIsNeverSelected() {
        var value = input()
        value.apps = [AppProcess(pid: 100, bundleID: "background"), AppProcess(pid: 200, bundleID: "background")]
        var policy = AdaptiveAutomaticPolicy()
        XCTAssertTrue(engage(&policy, input: value).appPids.isEmpty)
    }

    func testAdaptiveSelectionRetainsNormallyUntouchedAppsUntilRecovery() {
        var policy = AdaptiveAutomaticPolicy()
        var value = input(category: .other)
        value.rules.heavyThresholdPercent = 999
        value.adaptiveDemotionAppPids = engage(&policy, input: value).appPids
        XCTAssertEqual(RuleEvaluator.pidsToDemote(value), [200, 201])
        value.cpuByAppPid[200] = 5
        value.adaptiveDemotionAppPids = policy.evaluate(value, performanceLoad: 0.5, uptime: 10).appPids
        XCTAssertEqual(RuleEvaluator.pidsToDemote(value), [200, 201])
    }

    func testPerGameOverridesAndProtectedAppsWin() {
        var value = input()
        value.rules.gameRules["game"] = ["background": .normal]
        value.rules = value.rules.merged(forBoost: "game")
        var policy = AdaptiveAutomaticPolicy()
        XCTAssertTrue(engage(&policy, input: value).appPids.isEmpty)
        value = input()
        value.rules.protectedBundleIDs.insert("background")
        XCTAssertTrue(engage(&policy, input: value).appPids.isEmpty)
    }

    func testUnavailableSensorsPauseMissingFocusAndModeChangesReleasePolicy() {
        var policy = AdaptiveAutomaticPolicy()
        _ = engage(&policy, input: input())
        XCTAssertTrue(policy.evaluate(input(), performanceLoad: nil, uptime: 10).appPids.isEmpty)
        _ = engage(&policy, input: input())
        var value = input()
        value.sessionActive = false
        XCTAssertTrue(policy.evaluate(value, performanceLoad: 0.9, uptime: 10).appPids.isEmpty)
        value.sessionActive = true
        value.frontmostPid = nil
        XCTAssertTrue(policy.evaluate(value, performanceLoad: 0.9, uptime: 11).appPids.isEmpty)
        value = input()
        value.rules.mode = .gaming
        XCTAssertTrue(policy.evaluate(value, performanceLoad: 0.9, uptime: 12).appPids.isEmpty)
        value.rules.mode = .automatic
        value.rules.adaptiveAutomatic = false
        XCTAssertTrue(policy.evaluate(value, performanceLoad: 0.9, uptime: 13).appPids.isEmpty)
    }

    func testPidReuseSamplingGapsAndInvalidNumbersCannotKeepOldSelections() {
        var policy = AdaptiveAutomaticPolicy()
        _ = engage(&policy, input: input())
        var reused = input()
        reused.snapshot = ProcessSnapshot([ProcEntry(pid: 200, ppid: 1, uid: 501, startTime: 999, name: "new process")])
        XCTAssertTrue(policy.evaluate(reused, performanceLoad: 0.9, uptime: 10).appPids.isEmpty)
        XCTAssertTrue(policy.evaluate(input(), performanceLoad: 0.9, uptime: 40).appPids.isEmpty)
        XCTAssertTrue(policy.evaluate(input(), performanceLoad: .nan, uptime: 44).appPids.isEmpty)
    }

    func testNoSensorDataLeavesAutomaticCategoryChangesIdleButManualYieldWorks() {
        var value = input()
        XCTAssertTrue(RuleEvaluator.pidsToDemote(value).isEmpty)
        value.rules.rules["background"] = .auto
        XCTAssertEqual(RuleEvaluator.pidsToDemote(value), [200, 201])
    }

    func testOldSettingsDecodeAndAdaptivePreferenceRoundTrips() throws {
        let legacy = try JSONDecoder().decode(RuleSet.self, from: Data("{\"mode\":\"automatic\"}".utf8))
        XCTAssertTrue(legacy.adaptiveAutomatic)
        var rules = legacy
        rules.adaptiveAutomatic = false
        XCTAssertEqual(try JSONDecoder().decode(RuleSet.self, from: JSONEncoder().encode(rules)), rules)
    }
}
