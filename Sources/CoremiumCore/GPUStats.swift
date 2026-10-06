import Foundation
import IOKit

/// GPU usage read from the IORegistry, without root: device-wide utilization and per-process GPU time.
/// Each Metal/OpenGL client of the GPU is an `AGXDeviceUserClient` whose `AppUsage` lists accumulated GPU time (ns).
public struct GPUReading: Equatable, Sendable {
    public var devicePercent: Int?
    public var rendererPercent: Int?
    public var tilerPercent: Int?
    /// Accumulated GPU time per pid, in nanoseconds (summed over all of that process's GPU clients).
    public var gpuNanosByPid: [Int32: UInt64]

    public init(devicePercent: Int? = nil, rendererPercent: Int? = nil, tilerPercent: Int? = nil, gpuNanosByPid: [Int32: UInt64] = [:]) {
        self.devicePercent = devicePercent
        self.rendererPercent = rendererPercent
        self.tilerPercent = tilerPercent
        self.gpuNanosByPid = gpuNanosByPid
    }
}

public enum GPUStats {
    /// "pid 671, com.apple.dock.e" → 671.
    public static func pid(fromCreator creator: String) -> Int32? {
        guard creator.hasPrefix("pid ") else { return nil }
        let digits = creator.dropFirst(4).prefix { $0.isNumber }
        return Int32(digits)
    }

    /// Sum of `accumulatedGPUTime` over an `AppUsage` array.
    public static func gpuNanos(fromAppUsage usage: Any?) -> UInt64 {
        guard let entries = usage as? [[String: Any]] else { return 0 }
        return entries.reduce(0) { $0 &+ ((($1["accumulatedGPUTime"]) as? NSNumber)?.uint64Value ?? 0) }
    }

    public static func read() -> GPUReading {
        var reading = GPUReading()
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else { return reading }
        defer { IOObjectRelease(iterator) }
        while case let accelerator = IOIteratorNext(iterator), accelerator != 0 {
            defer { IOObjectRelease(accelerator) }
            if reading.devicePercent == nil,
               let stats = IORegistryEntryCreateCFProperty(accelerator, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any] {
                reading.devicePercent = (stats["Device Utilization %"] as? NSNumber)?.intValue
                reading.rendererPercent = (stats["Renderer Utilization %"] as? NSNumber)?.intValue
                reading.tilerPercent = (stats["Tiler Utilization %"] as? NSNumber)?.intValue
            }
            var children: io_iterator_t = 0
            guard IORegistryEntryGetChildIterator(accelerator, kIOServicePlane, &children) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(children) }
            while case let client = IOIteratorNext(children), client != 0 {
                defer { IOObjectRelease(client) }
                guard let creator = IORegistryEntryCreateCFProperty(client, "IOUserClientCreator" as CFString, kCFAllocatorDefault, 0)?
                        .takeRetainedValue() as? String,
                      let pid = pid(fromCreator: creator) else { continue }
                let usage = IORegistryEntryCreateCFProperty(client, "AppUsage" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
                reading.gpuNanosByPid[pid, default: 0] &+= gpuNanos(fromAppUsage: usage)
            }
        }
        return reading
    }
}

/// Per-process GPU share between successive samples: percent of wall time the GPU spent on that process's work.
public final class GPUSampler {
    private var last: [Int32: UInt64] = [:]
    private var lastAt: UInt64?

    public init() {}

    /// `now` is a monotonic clock in nanoseconds. First call (or a new pid) reports 0: no baseline yet.
    public func percentages(from reading: GPUReading, now: UInt64 = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) -> [Int32: Double] {
        defer { last = reading.gpuNanosByPid; lastAt = now }
        guard let lastAt, now > lastAt else { return [:] }
        let elapsed = Double(now - lastAt)
        var result: [Int32: Double] = [:]
        for (pid, nanos) in reading.gpuNanosByPid {
            guard let previous = last[pid], nanos >= previous else { result[pid] = 0; continue }
            result[pid] = min(100, Double(nanos - previous) / elapsed * 100)
        }
        return result
    }

    public func reset() { last = [:]; lastAt = nil }
}
