import Foundation
import XCTest
@testable import CoremiumCore

final class SessionReportTests: XCTestCase {
    private func report(names: [String]? = nil, own: Double? = nil) -> SessionReport {
        SessionReport(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 600), appName: "Game", mode: "Gaming",
                      peakMovedProcesses: 4, movedCoreSeconds: 30, backgroundGPUSeconds: 2, worstPressure: "normal",
                      swapGrowthBytes: 0, movedAppNames: names, coremiumCoreSeconds: own)
    }

    func testRoundTripKeepsTheNewFields() throws {
        let original = report(names: ["Chrome", "Discord"], own: 1.5)
        let decoded = try JSONDecoder().decode(SessionReport.self, from: try JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.movedAppNames, ["Chrome", "Discord"])
        XCTAssertEqual(decoded.coremiumCoreSeconds ?? -1, 1.5, accuracy: 1e-9)
    }

    func testReportsSavedByOlderVersionsStillLoad() throws {
        // A report as version 2.0.x wrote it: no moved-app names and no Coremium CPU.
        let old = report()
        var object = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(old)) as! [String: Any]
        object.removeValue(forKey: "movedAppNames")
        object.removeValue(forKey: "coremiumCoreSeconds")
        let data = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(SessionReport.self, from: data)
        XCTAssertNil(decoded.movedAppNames)
        XCTAssertNil(decoded.coremiumCoreSeconds)
        XCTAssertEqual(decoded.appName, "Game")
        XCTAssertEqual(decoded.summary, old.summary, "the notch line is unchanged for old reports")
    }
}
