import Darwin
import XCTest
@testable import CoremiumCore

final class SamplerResourceTests: XCTestCase {
    func references(to port: mach_port_t) -> mach_port_urefs_t {
        var count: mach_port_urefs_t = 0
        XCTAssertEqual(mach_port_get_refs(mach_task_self_, port, mach_port_right_t(MACH_PORT_RIGHT_SEND), &count), KERN_SUCCESS)
        return count
    }

    func testCoreLoadSamplingDoesNotAccumulateHostPortRights() {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let sampler = CPULoadSampler()
        let before = references(to: host)
        for _ in 0..<20 { _ = sampler.sample() }
        XCTAssertEqual(references(to: host), before)
    }

    func testMemorySamplingDoesNotAccumulateHostPortRights() {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let before = references(to: host)
        for _ in 0..<20 { _ = MemoryInfo.current() }
        XCTAssertEqual(references(to: host), before)
    }

    func testCoreLoadSamplerReleasesItsCachedHostPortOnDestruction() {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let before = references(to: host)
        for _ in 0..<20 {
            autoreleasepool { _ = CPULoadSampler().sample() }
        }
        XCTAssertEqual(references(to: host), before)
    }

    /// Regression: the first reading after an idle stretch used to average the whole stretch as if it were now.
    func testCoreLoadReprimesAfterAGapInsteadOfAveragingIdleTime() {
        let sampler = CPULoadSampler()
        _ = sampler.sample(now: 0)
        let afterGap = sampler.sample(now: 100, maxGap: 3)
        XCTAssertFalse(afterGap.isEmpty)
        XCTAssertTrue(afterGap.allSatisfy { $0 == 0 }, "after a gap the sampler must re-prime, not report the idle average")
        let next = sampler.sample(now: 101, maxGap: 3)
        XCTAssertEqual(next.count, afterGap.count)
        XCTAssertTrue(next.allSatisfy { (0...1).contains($0) })
    }

    func testCoreLoadKeepsTheBaselineWithinTheGap() {
        let sampler = CPULoadSampler()
        _ = sampler.sample(now: 0)
        let within = sampler.sample(now: 2, maxGap: 3)
        XCTAssertEqual(within.count, sampler.sample(now: 3, maxGap: 3).count)
        XCTAssertTrue(within.allSatisfy { (0...1).contains($0) })
        XCTAssertFalse(within.isEmpty)
    }
}
