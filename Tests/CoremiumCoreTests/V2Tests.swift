import XCTest
@testable import CoremiumCore

final class V2Tests: XCTestCase {
    func testGameRulesWinWhileThatGameIsBoosted() {
        var rules = RuleSet()
        rules.rules["com.google.Chrome"] = .normal
        rules.gameRules["com.roblox.RobloxPlayer"] = ["com.google.Chrome": .efficiency, "com.hnc.Discord": .auto]
        XCTAssertEqual(rules.merged(forBoost: "com.roblox.RobloxPlayer").rules["com.google.Chrome"], .efficiency)
        XCTAssertEqual(rules.merged(forBoost: "com.other.game").rules["com.google.Chrome"], .normal)
        XCTAssertEqual(rules.merged(forBoost: nil), rules)
    }

    func testOldSettingsAndHistoryStillLoad() throws {
        let settings = try JSONDecoder().decode(RuleSet.self, from: Data(#"{"mode":"gaming"}"#.utf8))
        XCTAssertTrue(settings.saveBatteryWhenUnplugged)
        XCTAssertTrue(settings.gameRules.isEmpty)
        let ledger = try JSONDecoder().decode(UsageLedger.self, from: Data(#"{"days":{}}"#.utf8))
        XCTAssertTrue(ledger.reports.isEmpty)
    }

    func testReportSummaryIsPlain() {
        let r = SessionReport(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 42 * 60), appName: "Roblox", mode: "gaming",
                              peakMovedProcesses: 23, movedCoreSeconds: 100, backgroundGPUSeconds: 0, worstPressure: "normal", swapGrowthBytes: 0)
        XCTAssertTrue(r.summary.hasPrefix("Roblox · "))
        XCTAssertTrue(r.summary.contains("23 background processes"))
        XCTAssertTrue(r.summary.hasSuffix("memory stayed normal"))
        var ledger = UsageLedger()
        for _ in 0..<40 { ledger.add(r) }
        XCTAssertEqual(ledger.reports.count, 30)
    }

    func testParsesLaunchAgentsAndDisabledList() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("coremium-agents-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: home) }
        let dir = LaunchAgents.folder(home: home)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let plist: [String: Any] = ["Label": "com.example.helper", "ProgramArguments": ["/Applications/Example.app/Contents/MacOS/helper", "-x"], "RunAtLoad": true]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: dir.appendingPathComponent("com.example.helper.plist"))
        try PropertyListSerialization.data(fromPropertyList: ["Label": "com.cubinghackerz.coremium"], format: .xml, options: 0)
            .write(to: dir.appendingPathComponent("coremium.plist"))
        let agents = LaunchAgents.list(home: home)
        XCTAssertEqual(agents.map(\.label), ["com.example.helper"])
        XCTAssertEqual(agents.first?.displayName, "Example")
        XCTAssertTrue(agents.first?.runAtLoad ?? false)
        let out = "disabled services = {\n\t\"com.example.helper\" => disabled\n\t\"com.other\" => enabled\n}"
        XCTAssertEqual(LaunchAgents.disabledLabels(fromPrintDisabled: out), ["com.example.helper"])
    }
}
