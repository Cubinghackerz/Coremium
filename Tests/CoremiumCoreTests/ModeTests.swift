import XCTest
@testable import CoremiumCore

final class ModeTests: XCTestCase {
    // MARK: classification

    func testKnownAppsAreClassified() {
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.roblox.RobloxPlayer", lsCategory: nil), .game)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.google.Chrome", lsCategory: nil), .browser)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.apple.FinalCut", lsCategory: nil), .creative)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.apple.dt.Xcode", lsCategory: nil), .developer)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.anthropic.claudefordesktop", lsCategory: nil), .ai)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.hnc.Discord", lsCategory: nil), .communication)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.modrinth.theseus", lsCategory: nil), .game)
    }

    func testPrefixOrderingAndAdobeSpecialCases() {
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.adobe.Photoshop", lsCategory: nil), .creative)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.adobe.PremierePro.25", lsCategory: nil), .creative)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.adobe.acc.AdobeCreativeCloud", lsCategory: nil), .system)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.adobe.Acrobat.Pro", lsCategory: nil), .productivity)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.jetbrains.intellij", lsCategory: nil), .developer)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.autodesk.fusion360", lsCategory: nil), .creative)
    }

    func testFallsBackToDeclaredAppStoreCategory() {
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.example.x", lsCategory: "public.app-category.games"), .game)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.example.x", lsCategory: "public.app-category.action-games"), .game)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.example.x", lsCategory: "public.app-category.video"), .creative)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.example.x", lsCategory: "public.app-category.developer-tools"), .developer)
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.example.x", lsCategory: nil), .other)
        XCTAssertEqual(AppClassifier.classify(bundleID: nil, lsCategory: "public.app-category.social-networking"), .communication)
    }

    func testExactTableBeatsDeclaredCategory() {
        XCTAssertEqual(AppClassifier.classify(bundleID: "com.google.Chrome", lsCategory: "public.app-category.games"), .browser)
    }

    // MARK: profile resolution

    func testFixedModes() {
        for (mode, profile) in [(PerformanceMode.gaming, ModeProfile.gaming), (.professional, .professional),
                                (.coding, .coding), (.balanced, .balanced)] {
            XCTAssertEqual(ModeProfile.resolve(mode: mode, frontCategory: .browser, busyCategories: []), profile)
        }
    }

    func testAutomaticFollowsTheFrontApp() {
        XCTAssertEqual(ModeProfile.resolve(mode: .automatic, frontCategory: .game, busyCategories: []), .gaming)
        XCTAssertEqual(ModeProfile.resolve(mode: .automatic, frontCategory: .creative, busyCategories: []), .professional)
        XCTAssertEqual(ModeProfile.resolve(mode: .automatic, frontCategory: .developer, busyCategories: []), .coding)
        XCTAssertEqual(ModeProfile.resolve(mode: .automatic, frontCategory: .browser, busyCategories: []), .balanced)
    }

    func testAutomaticFallsBackToABusyGameWhenAnotherAppIsInFront() {
        XCTAssertEqual(ModeProfile.resolve(mode: .automatic, frontCategory: .ai, busyCategories: [.game]), .gaming)
        XCTAssertEqual(ModeProfile.resolve(mode: .automatic, frontCategory: .ai, busyCategories: [.creative, .developer]), .professional)
        XCTAssertEqual(ModeProfile.resolve(mode: .automatic, frontCategory: nil, busyCategories: []), .balanced)
    }

    // MARK: end-to-end evaluation by category

    // Roblox 100 (game) ─ 101;  Chrome 200 (browser) ─ 201;  Cursor 300 (developer);
    // Premiere 400 (creative) ─ 401;  Claude 500 (ai);  Notes 600 (other)
    func world(front: Int32, cpu: [Int32: Double] = [:], mode: PerformanceMode, overrides: [String: AppRule] = [:],
               session: Bool = true) -> (Set<Int32>, ModeProfile) {
        func p(_ pid: Int32, _ ppid: Int32) -> ProcEntry { ProcEntry(pid: pid, ppid: ppid, uid: 501, startTime: UInt64(pid), name: "p") }
        let snapshot = ProcessSnapshot([p(1, 0), p(100, 1), p(101, 100), p(200, 1), p(201, 200), p(300, 1), p(400, 1), p(401, 400), p(500, 1), p(600, 1)])
        let apps = [
            AppProcess(pid: 100, bundleID: "com.roblox.RobloxPlayer"), AppProcess(pid: 200, bundleID: "com.google.Chrome"),
            AppProcess(pid: 300, bundleID: "com.todesktop.230313mzl4w4u92"), AppProcess(pid: 400, bundleID: "com.adobe.PremierePro.25"),
            AppProcess(pid: 500, bundleID: "com.anthropic.claudefordesktop"), AppProcess(pid: 600, bundleID: "com.apple.Notes"),
        ]
        var categories: [String: AppCategory] = [:]
        for a in apps { categories[a.bundleID!] = AppClassifier.classify(bundleID: a.bundleID, lsCategory: nil) }
        var rules = RuleSet(mode: mode, rules: overrides)
        // These fixtures exercise the classic category profiles; adaptive timing is covered separately.
        rules.adaptiveAutomatic = false
        let input = EvaluationInput(snapshot: snapshot, apps: apps, frontmostPid: front, rules: rules, sessionActive: session,
                                    cpuByAppPid: cpu, categories: categories, ownUid: 501, ownPid: 999)
        let profile = RuleEvaluator.activeProfile(apps: apps, frontmostPid: front, rules: rules, cpuByAppPid: cpu, categories: categories)
        return (RuleEvaluator.pidsToDemote(input), profile)
    }

    func testGamingModeDemotesEverythingExceptTheGame() {
        let (demoted, profile) = world(front: 100, mode: .gaming)
        XCTAssertEqual(profile, .gaming)
        XCTAssertEqual(demoted, [200, 201, 300, 400, 401, 500])
        XCTAssertFalse(demoted.contains(600), "uncategorised apps stay untouched")
    }

    func testProfessionalModeProtectsProAppAndDemotesGamesBrowsersAndAI() {
        let (demoted, _) = world(front: 400, mode: .professional)
        XCTAssertEqual(demoted, [100, 101, 200, 201, 500])
        XCTAssertFalse(demoted.contains(300), "dev tools are left alone in professional mode")
    }

    func testCodingModeDemotesGamesAndCreativeOnly() {
        let (demoted, _) = world(front: 300, mode: .coding)
        XCTAssertEqual(demoted, [100, 101, 400, 401])
    }

    func testBalancedModeDoesNothingWithoutOverrides() {
        XCTAssertTrue(world(front: 100, mode: .balanced).0.isEmpty)
    }

    func testAutomaticSwitchesWithTheFrontApp() {
        XCTAssertEqual(world(front: 100, mode: .automatic).1, .gaming)
        XCTAssertEqual(world(front: 400, mode: .automatic).1, .professional)
        XCTAssertEqual(world(front: 300, mode: .automatic).1, .coding)
        let (demoted, profile) = world(front: 600, mode: .automatic)
        XCTAssertEqual(profile, .balanced)
        XCTAssertTrue(demoted.isEmpty)
    }

    func testAutomaticKeepsProtectingABusyGameWhileYouUseAnotherApp() {
        let (demoted, profile) = world(front: 500, cpu: [100: 95], mode: .automatic)
        XCTAssertEqual(profile, .gaming)
        XCTAssertTrue(demoted.contains(200))
        XCTAssertFalse(demoted.contains(500), "the app you're using is always spared")
        XCTAssertFalse(demoted.contains(100))
    }

    func testPerAppOverridesBeatTheMode() {
        let (demoted, _) = world(front: 100, mode: .gaming, overrides: ["com.google.Chrome": .normal, "com.apple.Notes": .efficiency])
        XCTAssertFalse(demoted.contains(200), "Chrome opted out")
        XCTAssertTrue(demoted.contains(600), "Notes forced to efficiency")
    }

    func testNoSessionNoModeDemotions() {
        XCTAssertTrue(world(front: 300, mode: .gaming, session: false).0.isEmpty)
    }

    func testBoostTriggerUsesActiveProfile() {
        let apps = [AppProcess(pid: 100, bundleID: "com.roblox.RobloxPlayer"), AppProcess(pid: 200, bundleID: "com.google.Chrome")]
        let cats = ["com.roblox.RobloxPlayer": AppCategory.game, "com.google.Chrome": .browser]
        let auto = RuleSet(mode: .automatic)
        XCTAssertTrue(RuleEvaluator.boostTriggered(apps: apps, frontmostPid: 100, rules: auto, cpuByAppPid: [:], categories: cats))
        XCTAssertFalse(RuleEvaluator.boostTriggered(apps: apps, frontmostPid: 200, rules: auto, cpuByAppPid: [:], categories: cats))
        XCTAssertTrue(RuleEvaluator.boostTriggered(apps: apps, frontmostPid: 200, rules: auto, cpuByAppPid: [100: 80], categories: cats))
        let balanced = RuleSet(mode: .balanced)
        XCTAssertFalse(RuleEvaluator.boostTriggered(apps: apps, frontmostPid: 100, rules: balanced, cpuByAppPid: [:], categories: cats))
    }

    // MARK: settings compatibility and scanner

    func testOldSettingsFilesStillDecode() throws {
        let json = #"{"rules":{"com.roblox.RobloxPlayer":"boost"},"graceSeconds":45}"#
        let decoded = try JSONDecoder().decode(RuleSet.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.mode, .automatic)
        XCTAssertEqual(decoded.graceSeconds, 45)
        XCTAssertEqual(decoded.rule(for: "com.roblox.RobloxPlayer"), .boost)
        XCTAssertTrue(decoded.protectedBundleIDs.contains("com.cubinghackerz.coremium"))
    }

    func testScannerReadsAFakeAppBundleAndNeverLaunchesIt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coremium-scan-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        func makeApp(_ dir: String, name: String, id: String, category: String?) throws {
            let contents = root.appendingPathComponent(dir).appendingPathComponent("\(name).app/Contents")
            try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
            var plist: [String: Any] = ["CFBundleIdentifier": id, "CFBundleName": name]
            if let category { plist["LSApplicationCategoryType"] = category }
            try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                .write(to: contents.appendingPathComponent("Info.plist"))
        }
        try makeApp(".", name: "Fake Game", id: "com.example.fakegame", category: "public.app-category.games")
        try makeApp("Adobe Photoshop 2025", name: "Photoshop", id: "com.adobe.Photoshop", category: nil)
        let apps = InstalledAppScanner.scan(roots: [root])
        XCTAssertEqual(apps.map(\.bundleID).sorted(), ["com.adobe.Photoshop", "com.example.fakegame"])
        XCTAssertEqual(apps.first { $0.bundleID == "com.example.fakegame" }?.category, .game)
        XCTAssertEqual(apps.first { $0.bundleID == "com.adobe.Photoshop" }?.category, .creative)
    }

    func testScannerHandlesMissingFolders() {
        XCTAssertTrue(InstalledAppScanner.scan(roots: [URL(fileURLWithPath: "/definitely/not/here")]).isEmpty)
    }
}
