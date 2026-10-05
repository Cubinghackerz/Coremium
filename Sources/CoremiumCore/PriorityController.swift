import Darwin
import Foundation

/// Applies the background (efficiency-core) band to a process. Abstracted for tests.
public protocol PriorityBackend {
    /// Returns true on success.
    func setBackground(_ pid: Int32, _ on: Bool) -> Bool
}

/// The real thing: `setpriority(PRIO_DARWIN_PROCESS, pid, PRIO_DARWIN_BG)`, which is what `taskpolicy -b -p` does.
/// macOS schedules background-band processes on the efficiency cores with throttled disk and network I/O.
/// Works only for processes owned by the current user.
public struct DarwinPriorityBackend: PriorityBackend {
    public init() {}

    public func setBackground(_ pid: Int32, _ on: Bool) -> Bool {
        setpriority(PRIO_DARWIN_PROCESS, id_t(pid), on ? PRIO_DARWIN_BG : 0) == 0
    }
}

/// A demoted process. The start time guards against restoring a different process that reused the pid.
public struct LedgerEntry: Codable, Hashable, Sendable {
    public let pid: Int32
    public let startTime: UInt64

    public init(pid: Int32, startTime: UInt64) {
        self.pid = pid
        self.startTime = startTime
    }
}

/// Persists which processes Coremium demoted, so a crash never leaves apps stuck on the efficiency cores.
public final class DemotionLedger {
    public let url: URL?
    public private(set) var entries: [Int32: LedgerEntry] = [:]

    /// `url == nil` keeps the ledger in memory only (tests).
    public init(url: URL?) {
        self.url = url
        guard let url, let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([LedgerEntry].self, from: data) else { return }
        for entry in list { entries[entry.pid] = entry }
    }

    public func insert(_ entry: LedgerEntry) { entries[entry.pid] = entry }
    public func remove(_ pid: Int32) { entries[pid] = nil }
    public func removeAll() { entries.removeAll() }

    public func save() {
        guard let url else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Array(entries.values))
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("Coremium: could not save ledger: \(error)")
        }
    }
}

/// Moves processes in and out of the background band and keeps the ledger in sync.
public final class PriorityController {
    private let backend: PriorityBackend
    public let ledger: DemotionLedger
    private let ownPid: Int32
    private let ownUid: UInt32

    public init(backend: PriorityBackend = DarwinPriorityBackend(), ledger: DemotionLedger,
                ownPid: Int32 = getpid(), ownUid: UInt32 = getuid()) {
        self.backend = backend
        self.ledger = ledger
        self.ownPid = ownPid
        self.ownUid = ownUid
    }

    /// Pids currently demoted by Coremium.
    public var demotedPids: Set<Int32> { Set(ledger.entries.keys) }

    private func canTouch(_ entry: ProcEntry) -> Bool {
        entry.pid > 1 && entry.pid != ownPid && entry.uid == ownUid
    }

    /// Makes the demoted set equal to `target` (restoring anything no longer targeted).
    public func apply(target: Set<Int32>, snapshot: ProcessSnapshot) {
        var changed = false
        // Restore first, so a process moving out of the target set is never left behind.
        for (pid, entry) in ledger.entries where !target.contains(pid) {
            restore(entry, snapshot: snapshot)
            changed = true
        }
        for pid in target where ledger.entries[pid] == nil {
            guard let proc = snapshot.entries[pid], canTouch(proc) else { continue }
            if backend.setBackground(pid, true) {
                ledger.insert(LedgerEntry(pid: pid, startTime: proc.startTime))
                changed = true
            }
        }
        if changed { ledger.save() }
    }

    /// Restores everything Coremium demoted (still-running processes only; exited ones are just forgotten).
    public func restoreAll(snapshot: ProcessSnapshot = .capture()) {
        guard !ledger.entries.isEmpty else { return }
        for entry in ledger.entries.values { restore(entry, snapshot: snapshot) }
        ledger.removeAll()
        ledger.save()
    }

    private func restore(_ entry: LedgerEntry, snapshot: ProcessSnapshot) {
        if let live = snapshot.entries[entry.pid], live.startTime == entry.startTime, canTouch(live) {
            _ = backend.setBackground(entry.pid, false)
        }
        ledger.remove(entry.pid)
    }
}
