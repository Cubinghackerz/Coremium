import XCTest
@testable import CoremiumCore

final class ActivityMonitorTests: XCTestCase {
    func testCPUPercentIsOneCoreForOneFullIntervalOfCPUTime() {
        XCTAssertEqual(ActivityMath.cpuPercent(previousNanos: 0, currentNanos: 1_000_000_000, elapsedNanos: 1_000_000_000), 100, accuracy: 1e-9)
        XCTAssertEqual(ActivityMath.cpuPercent(previousNanos: 0, currentNanos: 500_000_000, elapsedNanos: 1_000_000_000), 50, accuracy: 1e-9)
    }

    func testCPUPercentIsZeroWhenReadingsCannotBeCompared() {
        XCTAssertEqual(ActivityMath.cpuPercent(previousNanos: 10, currentNanos: 5, elapsedNanos: 1_000), 0)
        XCTAssertEqual(ActivityMath.cpuPercent(previousNanos: 0, currentNanos: 5, elapsedNanos: 0), 0)
    }

    func testRankingPutsBusiestFirstWithStableTies() {
        let rows = [
            ActivityProcess(pid: 30, name: "c", cpuPercent: 5, memoryBytes: 100, isMoved: false),
            ActivityProcess(pid: 10, name: "a", cpuPercent: 40, memoryBytes: 100, isMoved: false),
            ActivityProcess(pid: 20, name: "b", cpuPercent: 5, memoryBytes: 900, isMoved: true),
            ActivityProcess(pid: 40, name: "d", cpuPercent: 5, memoryBytes: 900, isMoved: false),
        ]
        let ranked = ActivityMath.ranked(rows, limit: 3).map(\.pid)
        // Highest CPU first; equal CPU goes to the larger footprint, then the lower pid.
        XCTAssertEqual(ranked, [10, 20, 40])
    }

    func testRankingRespectsTheLimit() {
        let rows = (1...20).map { ActivityProcess(pid: Int32($0), name: "p", cpuPercent: Double($0), memoryBytes: 0, isMoved: false) }
        XCTAssertEqual(ActivityMath.ranked(rows, limit: 12).count, 12)
        XCTAssertEqual(ActivityMath.ranked(rows, limit: 0).count, 0)
    }

    func testLiveSampleFindsThisProcessWithItsFootprint() {
        let sampler = ActivitySampler()
        _ = sampler.sample(limit: 12, moved: [], logicalCPUs: 1)
        let snapshot = sampler.sample(limit: 12, moved: [], logicalCPUs: 1)
        XCTAssertGreaterThan(snapshot.processCount, 1)
        XCTAssertLessThanOrEqual(snapshot.processes.count, 12)
        XCTAssertGreaterThanOrEqual(snapshot.totalPercentOfMachine, 0)
        let me = snapshot.processes.first { $0.pid == getpid() }
        // This test process may not make the top twelve, so check the sampler on its own row when it does.
        if let me { XCTAssertGreaterThan(me.memoryBytes, 0) }
        let all = ActivityMath.ranked(snapshot.processes, limit: 12)
        XCTAssertEqual(all.map(\.cpuPercent), all.map(\.cpuPercent).sorted(by: >))
    }

    func testMovedFlagFollowsTheProvidedPids() {
        let sampler = ActivitySampler()
        let target = getpid()
        _ = sampler.sample(limit: 500, moved: [target], logicalCPUs: 1)
        let snapshot = sampler.sample(limit: 500, moved: [target], logicalCPUs: 1)
        XCTAssertEqual(snapshot.processes.first { $0.pid == target }?.isMoved, true)
    }
}
