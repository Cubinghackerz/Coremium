import XCTest
@testable import CoremiumCore

final class SystemInfoTests: XCTestCase {
    func testChipInfoMatchesSysctl() {
        let chip = ChipInfo.current()
        XCTAssertFalse(chip.brand.isEmpty)
        XCTAssertEqual(chip.performanceCores + chip.efficiencyCores >= 1, true)
        XCTAssertGreaterThan(chip.memoryBytes, 0)
        if chip.isAppleSilicon {
            XCTAssertEqual(chip.performanceCores, sysctlInt("hw.perflevel0.physicalcpu"))
            XCTAssertEqual(chip.efficiencyCores, sysctlInt("hw.perflevel1.physicalcpu"))
            XCTAssertEqual(chip.efficiencyCPUs.count, chip.efficiencyCores, "registry cluster-type must match sysctl core counts")
            XCTAssertEqual(chip.performanceCPUs.count, chip.performanceCores)
            XCTAssertEqual(Set(chip.efficiencyCPUs).union(chip.performanceCPUs), Set(0..<chip.logicalCPUs))
            if let gpu = chip.gpuCores { XCTAssertGreaterThan(gpu, 0) }   // absent inside CI virtual machines
            XCTAssertFalse(chip.shortName.hasPrefix("Apple"))
        }
    }

    func testCPULoadSamplerReturnsOneValuePerCPU() {
        let sampler = CPULoadSampler()
        _ = sampler.sample()
        usleep(200_000)
        let loads = sampler.sample()
        XCTAssertEqual(loads.count, ProcessInfo.processInfo.processorCount)
        XCTAssertTrue(loads.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    func testProcessCPUSamplerMeasuresOwnBusyLoop() {
        let sampler = ProcessCPUSampler()
        XCTAssertNotNil(sampler.cpuNanos(of: getpid()))
        _ = sampler.percent(of: [getpid()])
        let end = Date().addingTimeInterval(0.3)
        var x = 0.0
        while Date() < end { x += sin(x) + 1 }
        XCTAssertGreaterThan(x, 0)
        XCTAssertGreaterThan(sampler.percent(of: [getpid()]), 30, "a busy loop should register as significant CPU")
    }
}

final class MemoryInfoTests: XCTestCase {
    func testMemoryNumbersAreSane() {
        let memory = MemoryInfo.current()
        XCTAssertEqual(memory.totalBytes, UInt64(sysctlInt64("hw.memsize") ?? -1))
        XCTAssertGreaterThan(memory.usedBytes, 100 * 1_048_576, "any running Mac uses more than 100 MB")
        XCTAssertLessThanOrEqual(memory.usedBytes, memory.totalBytes)
    }
}
