import Darwin
import Foundation

/// One process in the Activity tab.
public struct ActivityProcess: Identifiable, Equatable, Sendable {
    public let pid: Int32
    public let name: String
    /// Percent of one core over the last sample interval (above 100 means several cores).
    public let cpuPercent: Double
    /// Memory the process is responsible for (its physical footprint), as Activity Monitor counts it.
    public let memoryBytes: UInt64
    /// Coremium has moved this process to the efficiency cores.
    public let isMoved: Bool

    public var id: Int32 { pid }

    public init(pid: Int32, name: String, cpuPercent: Double, memoryBytes: UInt64, isMoved: Bool) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
        self.isMoved = isMoved
    }
}

/// One sample: the machine total and the busiest processes.
public struct ActivitySnapshot: Equatable, Sendable {
    public var processCount: Int
    /// Percent of the whole machine (every logical core) over the last sample interval.
    public var totalPercentOfMachine: Double
    /// The busiest processes, highest CPU first.
    public var processes: [ActivityProcess]

    public static let empty = ActivitySnapshot(processCount: 0, totalPercentOfMachine: 0, processes: [])

    public init(processCount: Int, totalPercentOfMachine: Double, processes: [ActivityProcess]) {
        self.processCount = processCount
        self.totalPercentOfMachine = totalPercentOfMachine
        self.processes = processes
    }
}

public enum ActivityMath {
    /// CPU percent of one core for the CPU time used between two readings. Zero when the readings cannot be compared.
    public static func cpuPercent(previousNanos: UInt64, currentNanos: UInt64, elapsedNanos: UInt64) -> Double {
        guard elapsedNanos > 0, currentNanos >= previousNanos else { return 0 }
        return Double(currentNanos - previousNanos) / Double(elapsedNanos) * 100
    }

    /// Busiest first. Ties go to the larger footprint, then the lower pid, so the order never flickers.
    public static func ranked(_ rows: [ActivityProcess], limit: Int) -> [ActivityProcess] {
        let sorted = rows.sorted { a, b in
            if a.cpuPercent != b.cpuPercent { return a.cpuPercent > b.cpuPercent }
            if a.memoryBytes != b.memoryBytes { return a.memoryBytes > b.memoryBytes }
            return a.pid < b.pid
        }
        return Array(sorted.prefix(max(limit, 0)))
    }
}

/// Reads every process once per sample, with proc_listallpids and proc_pid_rusage. It spawns nothing: no ps, no top, no
/// full process table. Names are read once per process and kept until the process ends.
///
/// A process is keyed by its pid and its start time, so a pid that is reused by a new process starts with no baseline
/// instead of inheriting the old one's CPU time.
public final class ActivitySampler {
    private struct Key: Hashable {
        let pid: Int32
        let started: UInt64
    }

    private var previous: [Key: (nanos: UInt64, at: UInt64)] = [:]
    private var names: [Key: String] = [:]
    private let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    public init() {}

    /// Samples every process. Processes this user cannot read are left out, as Activity Monitor leaves them out.
    public func sample(limit: Int, moved: Set<Int32>, logicalCPUs: Int) -> ActivitySnapshot {
        let now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        let capacity = Int(proc_listallpids(nil, 0))
        guard capacity > 0 else { return .empty }
        var pids = [pid_t](repeating: 0, count: capacity + 32)
        let filled = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride)))

        var rows: [ActivityProcess] = []
        var current: [Key: (nanos: UInt64, at: UInt64)] = [:]
        for pid in pids.prefix(max(filled, 0)) where pid > 0 {
            var info = rusage_info_v4()
            let result = withUnsafeMutablePointer(to: &info) { pointer in
                pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
            }
            guard result == 0 else { continue }
            let key = Key(pid: pid, started: info.ri_proc_start_abstime)
            // ri_*_time is in mach absolute time units; convert to nanoseconds.
            let ticks = info.ri_user_time &+ info.ri_system_time
            let nanos = ticks &* UInt64(timebase.numer) / UInt64(max(timebase.denom, 1))
            var cpu = 0.0
            if let last = previous[key], now > last.at {
                cpu = ActivityMath.cpuPercent(previousNanos: last.nanos, currentNanos: nanos, elapsedNanos: now - last.at)
            }
            current[key] = (nanos, now)
            rows.append(ActivityProcess(pid: pid, name: name(for: key, pid: pid), cpuPercent: cpu,
                                        memoryBytes: info.ri_phys_footprint, isMoved: moved.contains(pid)))
        }
        // Forget processes that ended, so the caches stay the size of the live process table.
        previous = current
        names = names.filter { current[$0.key] != nil }

        let total = rows.reduce(0) { $0 + $1.cpuPercent } / Double(max(logicalCPUs, 1))
        return ActivitySnapshot(processCount: rows.count, totalPercentOfMachine: total,
                                processes: ActivityMath.ranked(rows, limit: limit))
    }

    private func name(for key: Key, pid: pid_t) -> String {
        if let cached = names[key] { return cached }
        var buffer = [CChar](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        let value = length > 0 ? String(cString: buffer) : "Process \(pid)"
        names[key] = value
        return value
    }
}
