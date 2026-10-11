import XCTest
@testable import CoremiumCore

final class TelemetryBuilderTests: XCTestCase {
    func testAnAppsShareIsTheSumOverItsWholeProcessTree() {
        let shares = TelemetryBuilder.appGPU(perPid: [1: 10, 2: 5, 3: 7], trees: ["com.game": [1, 2], "com.chat": [3]])
        XCTAssertEqual(shares["com.game"] ?? -1, 15, accuracy: 1e-9)
        XCTAssertEqual(shares["com.chat"] ?? -1, 7, accuracy: 1e-9)
    }

    func testOnlyTheTopAppsAreNamedAndTheRestFoldIntoOther() {
        let perPid: [Int32: Double] = [1: 50, 2: 30, 3: 20, 4: 10, 5: 5, 6: 4]
        let trees: [String: [Int32]] = ["a": [1], "b": [2], "c": [3], "d": [4], "e": [5], "f": [6]]
        let shares = TelemetryBuilder.appGPU(perPid: perPid, trees: trees, top: 3)
        XCTAssertEqual(shares["a"], 50)
        XCTAssertEqual(shares["b"], 30)
        XCTAssertEqual(shares["c"], 20)
        XCTAssertNil(shares["d"])
        XCTAssertEqual(shares[TelemetryBuilder.otherKey] ?? -1, 19, accuracy: 1e-9, "10 + 5 + 4")
    }

    func testAppsWithNoGPUUseAreLeftOut() {
        let shares = TelemetryBuilder.appGPU(perPid: [1: 0], trees: ["idle": [Int32(1)], "unknown": [99]])
        XCTAssertTrue(shares.isEmpty)
    }

    func testTiesAreOrderedByName() {
        let shares = TelemetryBuilder.appGPU(perPid: [1: 10, 2: 10], trees: ["zed": [1], "alpha": [2]] as [String: [Int32]], top: 1)
        XCTAssertEqual(shares, ["alpha": 10, TelemetryBuilder.otherKey: 10], "on a tie the name sorts first, so the result is stable")
    }
}
