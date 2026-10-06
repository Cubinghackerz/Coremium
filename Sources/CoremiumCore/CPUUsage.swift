import Darwin
import Foundation

/// Measures per-process CPU usage (percent of one core) between successive calls.
public final class ProcessCPUSampler {
    private var last: [Int32: (cpuNanos: UInt64, at: UInt64)] = [:]
    private let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    public init() {}

    /// Memory the process is responsible for (what Activity Monitor calls "Memory"), or nil if not readable.
    public static func footprint(of pid: Int32) -> UInt64? {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
        }
        return result == 0 ? info.ri_phys_footprint : nil
    }

    /// Total CPU time (user + system) of `pid` in nanoseconds, or nil if not readable.
    public func cpuNanos(of pid: Int32) -> UInt64? {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        guard result == 0 else { return nil }
        // ri_*_time is in mach absolute time units on Apple Silicon; convert to ns.
        let ticks = info.ri_user_time &+ info.ri_system_time
        return ticks * UInt64(timebase.numer) / UInt64(max(timebase.denom, 1))
    }

    /// CPU percent (of one core) used by each pid since the previous call for that pid.
    /// A pid seen for the first time reports 0 (no baseline yet). Unreadable pids are left out.
    public func percentages(of pids: [Int32]) -> [Int32: Double] {
        let now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        var result: [Int32: Double] = [:]
        for pid in pids {
            guard let cpu = cpuNanos(of: pid) else { continue }
            var value = 0.0
            if let previous = last[pid], now > previous.at, cpu >= previous.cpuNanos {
                value = Double(cpu - previous.cpuNanos) / Double(now - previous.at) * 100
            }
            result[pid] = value
            last[pid] = (cpu, now)
        }
        return result
    }

    /// Total CPU percent of one core used by all the given pids.
    public func percent(of pids: [Int32]) -> Double {
        percentages(of: pids).values.reduce(0, +)
    }

    /// Drops baselines for pids not in `alive`.
    public func prune(keeping alive: Set<Int32>) {
        last = last.filter { alive.contains($0.key) }
    }
}
