import XCTest
@testable import CoremiumCore

final class MetricHistoryTests: XCTestCase {
    private func sample(_ t: TimeInterval, cores: [Double] = [0.5], gpu: Double? = nil, apps: [String: Double] = [:],
                        memory: UInt64? = nil, swap: UInt64? = nil, pressure: MemoryInfo.Pressure? = nil) -> TelemetrySample {
        TelemetrySample(time: t, coreLoads: cores, gpuPercent: gpu, appGPUPercent: apps,
                        memoryUsedBytes: memory, swapBytes: swap, pressure: pressure)
    }

    private func times(_ entries: [TelemetryEntry]) -> [TimeInterval] {
        entries.compactMap { if case let .sample(s) = $0 { return s.time } else { return nil } }
    }

    func testFineSeriesKeepsOnlyTheNewestEntriesOldestFirst() {
        let history = MetricHistory(fineCapacity: 3)
        for t in 0..<5 { history.append(sample(TimeInterval(t))) }
        XCTAssertEqual(times(history.fineEntries), [2, 3, 4])
    }

    func testFineSeriesIsEmptyBeforeAnySample() {
        XCTAssertTrue(MetricHistory().fineEntries.isEmpty)
        XCTAssertTrue(MetricHistory().coarseEntries.isEmpty)
    }

    func testCoarseBucketAveragesItsSamples() {
        let history = MetricHistory(coarseInterval: 10)
        // One sample a second, as the telemetry service delivers them. Wider spacing is a gap, not one bucket.
        history.append(sample(0, cores: [0.2, 1.0]))
        history.append(sample(1, cores: [0.4, 0.0]))
        history.append(sample(2, cores: [0.6, 0.5]))
        guard case let .sample(bucket)? = history.coarseEntries.last else { return XCTFail("expected the open bucket") }
        XCTAssertEqual(bucket.time, 0)
        XCTAssertEqual(bucket.coreLoads[0], 0.4, accuracy: 1e-9)
        XCTAssertEqual(bucket.coreLoads[1], 0.5, accuracy: 1e-9)
    }

    func testCoarseBucketIsClosedWhenTheNextBucketStarts() {
        let history = MetricHistory(coarseInterval: 10)
        history.append(sample(8, cores: [1]))
        history.append(sample(9, cores: [1]))
        history.append(sample(10, cores: [0]))
        XCTAssertEqual(times(history.coarseEntries), [0, 10], "closed bucket 0, open bucket 10")
        guard case let .sample(first) = history.coarseEntries[0] else { return XCTFail() }
        XCTAssertEqual(first.coreLoads, [1])
    }

    func testSilenceLongerThanTwoCadencesBecomesAGapNotAnInterpolation() {
        let history = MetricHistory(cadence: 1)
        history.append(sample(0))
        history.append(sample(1))
        history.append(sample(10))
        XCTAssertEqual(history.fineEntries, [
            .sample(sample(0)), .sample(sample(1)), .gap(from: 1, to: 10), .sample(sample(10)),
        ])
    }

    func testAShortPauseIsNotAGap() {
        let history = MetricHistory(cadence: 1)
        history.append(sample(0))
        history.append(sample(2))
        XCTAssertEqual(times(history.fineEntries), [0, 2])
        XCTAssertFalse(history.fineEntries.contains { if case .gap = $0 { return true } else { return false } })
    }

    func testGpuAndMemoryAverageOnlyTheSamplesThatCarryThem() {
        let history = MetricHistory(coarseInterval: 10)
        history.append(sample(0, gpu: 40, memory: 1_000))
        history.append(sample(1))                       // GPU and memory not read this second
        history.append(sample(2, gpu: 60, memory: 3_000))
        guard case let .sample(bucket)? = history.coarseEntries.last else { return XCTFail() }
        XCTAssertEqual(bucket.gpuPercent ?? -1, 50, accuracy: 1e-9)
        XCTAssertEqual(bucket.memoryUsedBytes, 2_000)
        XCTAssertNil(bucket.swapBytes)
    }

    func testAnAppAbsentFromASampleCountsAsZeroForThatSample() {
        let history = MetricHistory(coarseInterval: 10)
        history.append(sample(0, apps: ["com.game": 80]))
        history.append(sample(1, apps: [:]))
        guard case let .sample(bucket)? = history.coarseEntries.last else { return XCTFail() }
        XCTAssertEqual(bucket.appGPUPercent["com.game"] ?? -1, 40, accuracy: 1e-9)
    }

    func testBucketKeepsTheWorstMemoryPressureNotTheAverage() {
        let history = MetricHistory(coarseInterval: 10)
        history.append(sample(0, pressure: .normal))
        history.append(sample(1, pressure: .critical))
        history.append(sample(2, pressure: .normal))
        guard case let .sample(bucket)? = history.coarseEntries.last else { return XCTFail() }
        XCTAssertEqual(bucket.pressure, .critical)
    }

    func testBucketIsMarkedAsSessionIfAnySampleWasInOne() {
        let history = MetricHistory(coarseInterval: 10)
        var quiet = sample(0)
        history.append(quiet)
        var boosted = sample(1)
        boosted.sessionActive = true
        history.append(boosted)
        guard case let .sample(bucket)? = history.coarseEntries.last else { return XCTFail() }
        XCTAssertTrue(bucket.sessionActive)
        quiet.time = 10
        history.append(quiet)
        guard case let .sample(first)? = history.coarseEntries.first else { return XCTFail() }
        XCTAssertTrue(first.sessionActive)
    }

    func testCoarseSeriesDropsOldBucketsPastCapacity() {
        let history = MetricHistory(coarseInterval: 10, coarseCapacity: 2)
        for t in 0..<40 { history.append(sample(TimeInterval(t))) }
        XCTAssertEqual(times(history.coarseEntries), [10, 20, 30], "the two newest closed buckets, then the open bucket 30")
    }
}
