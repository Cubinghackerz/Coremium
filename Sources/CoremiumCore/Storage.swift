import Foundation

/// What a group of reclaimable files is, in words people use.
public enum StorageKind: String, CaseIterable, Sendable {
    case appCaches, logs, developerBuilds, oldDownloads, trash

    public var title: String {
        switch self {
        case .appCaches: return "App caches"
        case .logs: return "Logs"
        case .developerBuilds: return "Xcode build files"
        case .oldDownloads: return "Old downloads"
        case .trash: return "Trash"
        }
    }

    public var explanation: String {
        switch self {
        case .appCaches: return "Temporary files apps rebuild when they need them. Safe to clear; apps may start a little slower once."
        case .logs: return "Diagnostic logs apps wrote. Safe to clear."
        case .developerBuilds: return "Xcode's intermediate build products. Xcode recreates them on the next build."
        case .oldDownloads: return "Files in Downloads you haven't touched for 90 days. Check them before clearing."
        case .trash: return "Already in the Trash. Coremium never empties it: use Finder's Empty Trash when you're sure."
        }
    }

    /// Items here can be moved to the Trash by Coremium.
    public var cleanable: Bool { self != .trash }
}

public struct StorageItem: Identifiable, Hashable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let name: String
    public let kind: StorageKind
    public let bytes: Int64
}

public struct DiskUsage: Equatable, Sendable {
    public let total: Int64
    public let available: Int64
    public var used: Int64 { max(0, total - available) }

    public static func current() -> DiskUsage? {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity, let free = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return DiskUsage(total: Int64(total), available: free)
    }
}

/// Where Coremium is allowed to look and to clean. Everything else is off limits.
public enum StorageRoots {
    public static func root(for kind: StorageKind, home: URL = URL(fileURLWithPath: NSHomeDirectory())) -> URL {
        switch kind {
        case .appCaches: return home.appendingPathComponent("Library/Caches")
        case .logs: return home.appendingPathComponent("Library/Logs")
        case .developerBuilds: return home.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        case .oldDownloads: return home.appendingPathComponent("Downloads")
        case .trash: return home.appendingPathComponent(".Trash")
        }
    }

    /// Caches that must stay: system services and Coremium's own files.
    static let keepCaches: Set<String> = ["com.apple.HomeKit", "CloudKit", "com.apple.bird", "com.apple.nsurlsessiond", "FamilyCircle"]

    /// True only for a direct child of a cleanable root, inside the home folder, not a symlink, and not on the keep list.
    public static func isCleanable(_ url: URL, home: URL = URL(fileURLWithPath: NSHomeDirectory())) -> Bool {
        let path = url.standardizedFileURL.path
        guard !path.contains("/../"), path.hasPrefix(home.standardizedFileURL.path + "/") else { return false }
        guard let kind = StorageKind.allCases.first(where: { $0.cleanable && url.deletingLastPathComponent().standardizedFileURL.path == root(for: $0, home: home).standardizedFileURL.path }) else { return false }
        if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true { return false }
        if kind == .appCaches, keepCaches.contains(url.lastPathComponent) || url.lastPathComponent.hasPrefix("com.cubinghackerz.coremium") { return false }
        return true
    }
}

public enum StorageScanner {
    /// Allocated size of a file or folder, without following symlinks.
    public static func size(of url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
        if let v = try? url.resourceValues(forKeys: Set(keys)), v.isRegularFile == true { return Int64(v.totalFileAllocatedSize ?? 0) }
        guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in walker {
            guard let v = try? file.resourceValues(forKeys: Set(keys)), v.isSymbolicLink != true, v.isRegularFile == true else { continue }
            total += Int64(v.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    /// Reads every kind's folder (one level deep), sizes the entries in parallel, largest first. Read-only.
    public static func scan(home: URL = URL(fileURLWithPath: NSHomeDirectory()), minimumBytes: Int64 = 1_000_000,
                            oldDownloadsDays: Int = 90, now: Date = Date()) -> [StorageItem] {
        var candidates: [(URL, StorageKind)] = []
        for kind in StorageKind.allCases {
            let root = StorageRoots.root(for: kind, home: home)
            guard let children = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey, .isSymbolicLinkKey], options: []) else { continue }
            for child in children where child.lastPathComponent != ".DS_Store" {
                if kind != .trash, !StorageRoots.isCleanable(child, home: home) { continue }
                if kind == .oldDownloads {
                    let modified = (try? child.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? now
                    guard now.timeIntervalSince(modified) > Double(oldDownloadsDays) * 86_400 else { continue }
                }
                candidates.append((child, kind))
            }
        }
        var sizes = [Int64](repeating: 0, count: candidates.count)
        sizes.withUnsafeMutableBufferPointer { buffer in
            let base = buffer.baseAddress!
            DispatchQueue.concurrentPerform(iterations: candidates.count) { base[$0] = size(of: candidates[$0].0) }
        }
        return zip(candidates, sizes).compactMap { pair, bytes in
            bytes >= minimumBytes ? StorageItem(url: pair.0, name: pair.0.lastPathComponent, kind: pair.1, bytes: bytes) : nil
        }.sorted { $0.bytes > $1.bytes }
    }
}

public struct CleanResult: Equatable, Sendable {
    public var movedBytes: Int64 = 0
    public var movedCount = 0
    public var failed: [String] = []
}

public enum StorageCleaner {
    /// Moves items to the Trash (never deletes permanently), skipping anything that is not on the allowed list.
    @discardableResult
    public static func moveToTrash(_ items: [StorageItem], home: URL = URL(fileURLWithPath: NSHomeDirectory())) -> CleanResult {
        var result = CleanResult()
        for item in items {
            guard item.kind.cleanable, StorageRoots.isCleanable(item.url, home: home) else { result.failed.append(item.name); continue }
            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                result.movedBytes += item.bytes
                result.movedCount += 1
            } catch { result.failed.append(item.name) }
        }
        return result
    }
}

public func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
