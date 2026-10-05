import Darwin
import Foundation

/// Per-CPU busy fraction (0...1) between successive `sample()` calls, via `host_processor_info`.
public final class CPULoadSampler {
    private var previous: [(busy: UInt64, total: UInt64)] = []

    public init() {}

    public func sample() -> [Double] {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount) == KERN_SUCCESS,
              let info else { return [] }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info),
                          vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }

        var current: [(busy: UInt64, total: UInt64)] = []
        current.reserveCapacity(Int(cpuCount))
        for cpu in 0..<Int(cpuCount) {
            let base = cpu * Int(CPU_STATE_MAX)
            let user = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]))
            let system = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]))
            let nice = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
            let idle = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]))
            current.append((user + system + nice, user + system + nice + idle))
        }

        defer { previous = current }
        guard previous.count == current.count else { return Array(repeating: 0, count: current.count) }
        return zip(previous, current).map { old, new in
            // Tick counters are 32-bit and can wrap; treat a wrap as no data.
            guard new.total > old.total, new.busy >= old.busy else { return 0 }
            return min(1, Double(new.busy - old.busy) / Double(new.total - old.total))
        }
    }
}
