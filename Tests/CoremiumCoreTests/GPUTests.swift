import XCTest
@testable import CoremiumCore

final class GPUTests: XCTestCase {
    func testParsesCreatorPid() {
        XCTAssertEqual(GPUStats.pid(fromCreator: "pid 671, com.apple.dock.e"), 671)
        XCTAssertEqual(GPUStats.pid(fromCreator: "pid 410, WindowServer"), 410)
        XCTAssertNil(GPUStats.pid(fromCreator: "WindowServer"))
    }

    func testSumsAccumulatedGPUTimeAcrossQueues() {
        let usage: [[String: Any]] = [["API": "Metal", "accumulatedGPUTime": NSNumber(value: 1_000)],
                                      ["API": "Metal", "accumulatedGPUTime": NSNumber(value: 2_500)], ["API": "Metal"]]
        XCTAssertEqual(GPUStats.gpuNanos(fromAppUsage: usage), 3_500)
        XCTAssertEqual(GPUStats.gpuNanos(fromAppUsage: nil), 0)
    }

    func testSamplerReportsShareOfWallTime() {
        let sampler = GPUSampler()
        XCTAssertTrue(sampler.percentages(from: GPUReading(gpuNanosByPid: [1: 0, 2: 0]), now: 1_000_000_000).isEmpty, "no baseline yet")
        let p = sampler.percentages(from: GPUReading(gpuNanosByPid: [1: 250_000_000, 2: 0, 3: 5]), now: 2_000_000_000)
        XCTAssertEqual(p[1] ?? -1, 25, accuracy: 1e-9)
        XCTAssertEqual(p[2], 0)
        XCTAssertEqual(p[3], 0, "new pid has no baseline")
    }

    func testOldUsageHistoryStillLoads() throws {
        let json = #"{"day":"2026-10-05","sessions":2,"boostedSeconds":780,"movedCoreSeconds":10,"peakMovedProcesses":72,"hotSeconds":0,"secondsByMode":{}}"#
        let day = try JSONDecoder().decode(DayStats.self, from: Data(json.utf8))
        XCTAssertEqual(day.peakMovedProcesses, 72)
        XCTAssertEqual(day.backgroundGPUSeconds, 0)
    }

    func testLiveReadDoesNotCrash() {
        _ = GPUStats.read()
    }
}
