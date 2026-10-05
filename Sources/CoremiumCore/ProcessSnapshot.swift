import Darwin
import Foundation

/// One process as seen by `sysctl(KERN_PROC_ALL)`.
public struct ProcEntry: Equatable, Hashable, Sendable {
    public let pid: Int32
    public let ppid: Int32
    public let uid: UInt32
    /// Process start time in microseconds since 1970. Used to detect pid reuse.
    public let startTime: UInt64
    public let name: String

    public init(pid: Int32, ppid: Int32, uid: UInt32, startTime: UInt64, name: String) {
        self.pid = pid
        self.ppid = ppid
        self.uid = uid
        self.startTime = startTime
        self.name = name
    }
}

/// A point-in-time process table with a parent → children index.
public struct ProcessSnapshot: Sendable {
    public let entries: [Int32: ProcEntry]
    public let children: [Int32: [Int32]]

    public init(_ list: [ProcEntry]) {
        var byPid: [Int32: ProcEntry] = [:]
        var kids: [Int32: [Int32]] = [:]
        for e in list {
            byPid[e.pid] = e
            if e.ppid != e.pid { kids[e.ppid, default: []].append(e.pid) }
        }
        entries = byPid
        children = kids
    }

    /// `pid` plus all of its descendants that exist in this snapshot (breadth-first, cycle-safe).
    public func tree(of pid: Int32) -> [Int32] {
        guard entries[pid] != nil else { return [] }
        var result: [Int32] = []
        var seen: Set<Int32> = [pid]
        var queue: [Int32] = [pid]
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            result.append(current)
            for child in children[current] ?? [] where !seen.contains(child) {
                seen.insert(child)
                queue.append(child)
            }
        }
        return result
    }

    /// Captures the live process table. Returns an empty snapshot if the kernel call fails.
    public static func capture() -> ProcessSnapshot {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return ProcessSnapshot([]) }
        let stride = MemoryLayout<kinfo_proc>.stride
        // Leave headroom for processes spawned between the two calls.
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: size / stride + 32)
        size = procs.count * stride
        guard sysctl(&mib, UInt32(mib.count), &procs, &size, nil, 0) == 0 else { return ProcessSnapshot([]) }
        let count = size / stride

        var list: [ProcEntry] = []
        list.reserveCapacity(count)
        for i in 0..<count {
            var p = procs[i]
            let start = p.kp_proc.p_starttime
            let name = withUnsafeBytes(of: &p.kp_proc.p_comm) { raw -> String in
                let bytes = raw.prefix { $0 != 0 }
                return String(decoding: bytes, as: UTF8.self)
            }
            list.append(ProcEntry(
                pid: p.kp_proc.p_pid,
                ppid: p.kp_eproc.e_ppid,
                uid: p.kp_eproc.e_ucred.cr_uid,
                startTime: UInt64(max(start.tv_sec, 0)) * 1_000_000 + UInt64(max(start.tv_usec, 0)),
                name: name
            ))
        }
        return ProcessSnapshot(list)
    }
}

/// Full executable path of a process, or nil if it can't be read.
public func executablePath(of pid: Int32) -> String? {
    var buffer = [CChar](repeating: 0, count: 4096)
    let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
    guard length > 0 else { return nil }
    return String(cString: buffer)
}
