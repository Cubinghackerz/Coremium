import Darwin
import Foundation

/// A snapshot of memory use, for the Advanced view.
public struct MemoryInfo: Equatable, Sendable {
    public enum Pressure: String, Sendable { case normal, warning, critical }

    public let totalBytes: UInt64
    /// App memory + wired + compressed, like Activity Monitor's "Memory Used".
    public let usedBytes: UInt64
    public let swapUsedBytes: UInt64
    public let pressure: Pressure

    public init(totalBytes: UInt64, usedBytes: UInt64, swapUsedBytes: UInt64, pressure: Pressure) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.swapUsedBytes = swapUsedBytes
        self.pressure = pressure
    }

    public static func current() -> MemoryInfo {
        let total = UInt64(sysctlInt64("hw.memsize") ?? 0)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        var used: UInt64 = 0
        if result == KERN_SUCCESS {
            var pageSize: vm_size_t = 0
            host_page_size(mach_host_self(), &pageSize)
            let pages = UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
            used = min(pages * UInt64(pageSize), total)
        }

        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        let swapUsed = sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 ? UInt64(swap.xsu_used) : 0

        let level = sysctlInt("kern.memorystatus_vm_pressure_level") ?? 1
        let pressure: Pressure = level >= 4 ? .critical : (level >= 2 ? .warning : .normal)
        return MemoryInfo(totalBytes: total, usedBytes: used, swapUsedBytes: swapUsed, pressure: pressure)
    }
}
