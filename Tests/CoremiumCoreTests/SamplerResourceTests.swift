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
}
