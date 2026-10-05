import Darwin
import Foundation
import IOKit
import IOKit.ps

/// Static description of the Mac's processor, read once at launch.
public struct ChipInfo: Sendable {
    public let brand: String            // "Apple M3 Pro"
    public let isAppleSilicon: Bool
    public let performanceCores: Int
    public let efficiencyCores: Int
    public let performanceL2Bytes: Int
    public let efficiencyL2Bytes: Int
    public let logicalCPUs: Int
    public let gpuCores: Int?
    public let memoryBytes: UInt64

    /// "M3 Pro" for Apple chips, the brand string otherwise.
    public var shortName: String {
        isAppleSilicon && brand.hasPrefix("Apple ") ? String(brand.dropFirst(6)) : brand
    }

    /// Logical CPU indices (as used by `host_processor_info`) that are efficiency / performance cores.
    /// Read from the IORegistry (`cluster-type` on each `cpuN` node). On an M3 Pro this is cpu0–5 = E, cpu6–10 = P.
    public let efficiencyCPUs: [Int]
    public let performanceCPUs: [Int]

    public init(brand: String, isAppleSilicon: Bool, performanceCores: Int, efficiencyCores: Int,
                performanceL2Bytes: Int, efficiencyL2Bytes: Int, logicalCPUs: Int, gpuCores: Int?, memoryBytes: UInt64,
                efficiencyCPUs: [Int]? = nil) {
        self.brand = brand
        self.isAppleSilicon = isAppleSilicon
        self.performanceCores = performanceCores
        self.efficiencyCores = efficiencyCores
        self.performanceL2Bytes = performanceL2Bytes
        self.efficiencyL2Bytes = efficiencyL2Bytes
        self.logicalCPUs = logicalCPUs
        self.gpuCores = gpuCores
        self.memoryBytes = memoryBytes
        // Without registry data, assume efficiency cores are numbered first (true on every Apple Silicon Mac checked).
        let efficiency = efficiencyCPUs ?? Array(0..<(isAppleSilicon ? min(efficiencyCores, logicalCPUs) : 0))
        self.efficiencyCPUs = efficiency
        self.performanceCPUs = (0..<logicalCPUs).filter { !efficiency.contains($0) }
    }

    public static func current() -> ChipInfo {
        let brand = sysctlString("machdep.cpu.brand_string") ?? "Unknown CPU"
        let levels = sysctlInt("hw.nperflevels") ?? 1
        let appleSilicon = brand.hasPrefix("Apple")
        let logical = sysctlInt("hw.logicalcpu") ?? ProcessInfo.processInfo.activeProcessorCount
        let pCores: Int
        let eCores: Int
        if levels >= 2 {
            pCores = sysctlInt("hw.perflevel0.physicalcpu") ?? logical
            eCores = sysctlInt("hw.perflevel1.physicalcpu") ?? 0
        } else {
            pCores = sysctlInt("hw.physicalcpu") ?? logical
            eCores = 0
        }
        return ChipInfo(
            brand: brand,
            isAppleSilicon: appleSilicon,
            performanceCores: pCores,
            efficiencyCores: eCores,
            performanceL2Bytes: sysctlInt("hw.perflevel0.l2cachesize") ?? sysctlInt("hw.l2cachesize") ?? 0,
            efficiencyL2Bytes: levels >= 2 ? (sysctlInt("hw.perflevel1.l2cachesize") ?? 0) : 0,
            logicalCPUs: logical,
            gpuCores: appleSilicon ? gpuCoreCount() : nil,
            memoryBytes: UInt64(sysctlInt64("hw.memsize") ?? 0),
            efficiencyCPUs: appleSilicon ? registryEfficiencyCPUs(logical: logical) : nil
        )
    }

    /// Reads `cluster-type` ("E" or "P") from `IOService:/AppleARMPE/cpus/cpuN`. Returns nil if the registry has no data.
    static func registryEfficiencyCPUs(logical: Int) -> [Int]? {
        var efficiency: [Int] = []
        var seen = 0
        for index in 0..<logical {
            let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/AppleARMPE/cpus/cpu\(index)")
            guard entry != 0 else { continue }
            defer { IOObjectRelease(entry) }
            guard let raw = IORegistryEntryCreateCFProperty(entry, "cluster-type" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Data, let first = raw.first else { continue }
            seen += 1
            if first == UInt8(ascii: "E") { efficiency.append(index) }
        }
        return seen == logical ? efficiency : nil
    }

    private static func gpuCoreCount() -> Int? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AGXAccelerator"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let value = IORegistryEntryCreateCFProperty(service, "gpu-core-count" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() else { return nil }
        return (value as? NSNumber)?.intValue
    }
}

/// Live power state.
public enum PowerSource: Sendable { case ac, battery, unknown }

public func currentPowerSource() -> PowerSource {
    guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String? else { return .unknown }
    if type == kIOPMACPowerKey { return .ac }
    if type == kIOPMBatteryPowerKey { return .battery }
    return .unknown
}

// MARK: - sysctl helpers

public func sysctlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
    return String(cString: buffer)
}

public func sysctlInt(_ name: String) -> Int? {
    var value: Int32 = 0
    var size = MemoryLayout<Int32>.size
    guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
    return Int(value)
}

public func sysctlInt64(_ name: String) -> Int64? {
    var value: Int64 = 0
    var size = MemoryLayout<Int64>.size
    guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
    return value
}
