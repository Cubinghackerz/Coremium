import XCTest
@testable import CoremiumCore

final class ProductTests: XCTestCase {
    // MARK: Local AI mode

    func testLocalAIAppsAreRecognisedByIDAndByName() {
        XCTAssertEqual(AppClassifier.classify(bundleID: "ai.elementlabs.lmstudio", lsCategory: nil), .localAI)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.unknown.thing", lsCategory: nil, name: "ComfyUI Desktop"), .localAI)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.unknown.thing", lsCategory: nil, name: "Ollama"), .localAI)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.parallels.desktop.console", lsCategory: nil), .localAI)
        // "Diffusion Studio" is a video editor, not Stable Diffusion.
        XCTAssertNotEqual(AppClassifier.classify(bundleID: "com.example.ds", lsCategory: nil, name: "Diffusion Studio"), .localAI)
    }

    func testLocalAIModeProtectsAIComputeAndMovesGamesBrowsersAside() {
        XCTAssertEqual(ModeProfile.resolve(mode: .localAI, frontCategory: .browser, busyCategories: []), .localAI)
        XCTAssertTrue(ModeProfile.localAI.boost.contains(.localAI))
        XCTAssertTrue(ModeProfile.localAI.demote.isSuperset(of: [.game, .browser, .communication, .creative]))
        XCTAssertEqual(ModeProfile.resolve(mode: .automatic, frontCategory: .localAI, busyCategories: []), .localAI)
        XCTAssertEqual(ModeProfile.resolve(mode: .automatic, frontCategory: .ai, busyCategories: [.localAI]), .localAI)
    }

    func testClearNames() {
        XCTAssertEqual(AppRule.auto.label, "Yield")
        XCTAssertEqual(PerformanceMode.professional.label, "Creator")
        XCTAssertEqual(PerformanceMode.allCases.count, 6)
    }

    func testSteamGamesAreDetectedByPath() {
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.example.g", lsCategory: nil,
                                              path: "/Users/x/Library/Application Support/Steam/steamapps/common/G/G.app"), .game)
    }

    // MARK: Usage history

    func testLedgerAccumulatesPerDay() {
        var ledger = UsageLedger()
        let now = Date()
        ledger.record(at: now, seconds: 5, sessionActive: true, mode: .gaming, movedCoreSeconds: 10, movedProcesses: 12, hot: false, sessionStarted: true)
        ledger.record(at: now, seconds: 5, sessionActive: true, mode: .gaming, movedCoreSeconds: 6, movedProcesses: 20, hot: true, sessionStarted: false)
        ledger.record(at: now, seconds: 5, sessionActive: false, mode: .gaming, movedCoreSeconds: 0, movedProcesses: 0, hot: false, sessionStarted: false)
        let today = ledger.days[UsageLedger.dayKey(now)]
        XCTAssertEqual(today?.sessions, 1)
        XCTAssertEqual(today?.boostedSeconds, 10)
        XCTAssertEqual(today?.movedCoreSeconds, 16)
        XCTAssertEqual(today?.peakMovedProcesses, 20)
        XCTAssertEqual(today?.hotSeconds, 5)
        XCTAssertEqual(today?.secondsByMode["gaming"], 10)
    }

    func testLedgerIgnoresAbsurdIntervals() {
        var ledger = UsageLedger()
        ledger.record(at: Date(), seconds: 3600, sessionActive: true, mode: .gaming, movedCoreSeconds: 5, movedProcesses: 1, hot: false, sessionStarted: false)
        XCTAssertTrue(ledger.days.isEmpty, "a long gap (sleep) must not count as boosted time")
    }

    func testLastDaysIsZeroFilledAndOrdered() {
        var ledger = UsageLedger()
        let now = Date()
        ledger.record(at: now, seconds: 5, sessionActive: true, mode: .coding, movedCoreSeconds: 3, movedProcesses: 4, hot: false, sessionStarted: true)
        let week = ledger.lastDays(7, endingAt: now)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.last?.day, UsageLedger.dayKey(now))
        XCTAssertEqual(week.first?.boostedSeconds, 0)
        XCTAssertEqual(ledger.total(days: 7, endingAt: now).sessions, 1)
    }

    func testLedgerRoundTripsThroughDisk() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("coremium-usage-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        var ledger = UsageLedger()
        ledger.record(at: Date(), seconds: 5, sessionActive: true, mode: .gaming, movedCoreSeconds: 2, movedProcesses: 3, hot: false, sessionStarted: true)
        ledger.save(to: url)
        XCTAssertEqual(UsageLedger.load(from: url), ledger)
    }

    func testEnergyEstimateIsSimpleAndTransparent() {
        XCTAssertEqual(EnergyEstimate.watthours(forMovedCoreSeconds: 3600), EnergyEstimate.assumedWattsSavedPerCore, accuracy: 1e-9)
        XCTAssertEqual(formatDuration(45), "45s")
        XCTAssertEqual(formatDuration(600), "10 min")
        XCTAssertEqual(formatDuration(3900), "1 h 5 min")
    }

    // MARK: Learning

    func testLearnerSuggestsYieldForBackgroundHogsOnlyWithEnoughEvidence() {
        var learner = WorkloadLearner()
        for _ in 0..<(WorkloadLearner.minimumBackgroundSamples - 1) {
            learner.ingest(bundleID: "com.example.hog", name: "Hog", isFront: false, sessionActive: true, cores: 1.2)
        }
        XCTAssertTrue(learner.suggestions { _, _ in false }.isEmpty, "not enough evidence yet")
        learner.ingest(bundleID: "com.example.hog", name: "Hog", isFront: false, sessionActive: true, cores: 1.2)
        let found = learner.suggestions { _, _ in false }
        XCTAssertEqual(found.map(\.kind), [.yield])
        XCTAssertEqual(found.first?.bundleID, "com.example.hog")
        XCTAssertTrue(learner.suggestions { id, kind in id == "com.example.hog" && kind == .yield }.isEmpty, "already handled")
    }

    func testLearnerIgnoresBackgroundUseOutsideSessionsAndQuietApps() {
        var learner = WorkloadLearner()
        for _ in 0..<100 {
            learner.ingest(bundleID: "a", name: "A", isFront: false, sessionActive: false, cores: 3)   // no session: not counted
            learner.ingest(bundleID: "b", name: "B", isFront: false, sessionActive: true, cores: 0.05) // quiet
        }
        XCTAssertTrue(learner.suggestions { _, _ in false }.isEmpty)
    }

    func testLearnerSuggestsBoostForHardWorkingFocusedApps() {
        var learner = WorkloadLearner()
        for _ in 0..<WorkloadLearner.minimumFrontSamples {
            learner.ingest(bundleID: "com.example.render", name: "Render", isFront: true, sessionActive: false, cores: 2.5)
        }
        let found = learner.suggestions { _, _ in false }
        XCTAssertEqual(found.map(\.kind), [.boost])
    }

    func testDismissedSuggestionsStayDismissed() {
        var learner = WorkloadLearner()
        for _ in 0..<WorkloadLearner.minimumBackgroundSamples {
            learner.ingest(bundleID: "x", name: "X", isFront: false, sessionActive: true, cores: 1)
        }
        let suggestion = try! XCTUnwrap(learner.suggestions { _, _ in false }.first)
        learner.dismiss(suggestion)
        XCTAssertTrue(learner.suggestions { _, _ in false }.isEmpty)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("coremium-learn-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        learner.save(to: url)
        XCTAssertEqual(WorkloadLearner.load(from: url), learner)
    }

    // MARK: Simulation

    func testSimulationIsDeterministic() {
        var a = FrameTimeModel(coremiumOn: false, contention: 0.7, seed: 42)
        var b = FrameTimeModel(coremiumOn: false, contention: 0.7, seed: 42)
        XCTAssertEqual((0..<500).map { _ in a.nextFrameMs() }, (0..<500).map { _ in b.nextFrameMs() })
    }

    func testSimulationShowsStallsOnlyWithoutCoremium() {
        var off = FrameTimeModel(coremiumOn: false, contention: 0.8, seed: 7)
        var on = FrameTimeModel(coremiumOn: true, contention: 0.8, seed: 7)
        let offFrames = (0..<20_000).map { _ in off.nextFrameMs() }
        let onFrames = (0..<20_000).map { _ in on.nextFrameMs() }
        XCTAssertGreaterThan(offFrames.max()!, 40)
        XCTAssertLessThan(onFrames.max()!, 16)
        XCTAssertGreaterThan(onFrames.min()!, 7)
    }

    func testPlacementPutsOnlyTheBoostedAppOnPerformanceCoresWhenOn() {
        let apps = SimScenario.gaming.apps
        let on = SimPlacement.compute(apps: apps, coremiumOn: true, performanceCores: 5, efficiencyCores: 6)
        XCTAssertEqual(Set(on.performance.flatMap { $0 }), [0], "only the game on the fast cores")
        XCTAssertFalse(on.isOverloaded)
        let off = SimPlacement.compute(apps: apps, coremiumOn: false, performanceCores: 5, efficiencyCores: 6)
        XCTAssertGreaterThan(Set(off.performance.flatMap { $0 }).count, 1, "everything competes for the fast cores")
        XCTAssertTrue(off.isOverloaded)
        XCTAssertGreaterThan(off.performanceDemand, on.performanceDemand)
    }

    // MARK: Scanner cache

    func testScannerReusesCachedEntriesAndDropsRemovedApps() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coremium-cache-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        func makeApp(_ name: String) throws {
            let contents = root.appendingPathComponent("\(name).app/Contents")
            try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
            try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "com.example.\(name)", "CFBundleName": name],
                                               format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        }
        try makeApp("One")
        try makeApp("Two")
        let first = InstalledAppScanner.scanDetailed(roots: [ScanRoot(root)], cache: AppIndexCache())
        XCTAssertEqual(first.report.apps.count, 2)
        XCTAssertEqual(first.report.read, 2)
        XCTAssertEqual(first.report.reused, 0)

        let second = InstalledAppScanner.scanDetailed(roots: [ScanRoot(root)], cache: first.cache)
        XCTAssertEqual(second.report.reused, 2, "unchanged apps come from the cache")
        XCTAssertEqual(second.report.read, 0)

        try FileManager.default.removeItem(at: root.appendingPathComponent("Two.app"))
        let third = InstalledAppScanner.scanDetailed(roots: [ScanRoot(root)], cache: second.cache)
        XCTAssertEqual(third.report.apps.map(\.bundleID), ["com.example.One"])
        XCTAssertEqual(third.cache.entries.count, 1, "removed apps leave the cache")
    }

    func testIndexCacheRoundTripsAndFullScanIsFast() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("coremium-index-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let result = InstalledAppScanner.scanDetailed(roots: InstalledAppScanner.defaultRoots, cache: AppIndexCache())
        result.cache.save(to: url)
        let loaded = AppIndexCache.load(from: url)
        XCTAssertEqual(loaded.entries.count, result.cache.entries.count)
        XCTAssertLessThan(result.report.seconds, 3.0, "indexing every installed app must stay quick")
    }
}
