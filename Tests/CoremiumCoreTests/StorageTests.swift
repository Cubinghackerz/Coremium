import XCTest
@testable import CoremiumCore

final class StorageTests: XCTestCase {
    var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("coremium-home-\(UUID().uuidString)").standardizedFileURL
        for sub in ["Library/Caches", "Library/Logs", "Downloads", ".Trash", "Documents"] {
            try FileManager.default.createDirectory(at: home.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: home) }

    func write(_ path: String, bytes: Int, ageDays: Int = 0) throws -> URL {
        let url = home.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
        if ageDays > 0 { try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-Double(ageDays) * 86_400)], ofItemAtPath: url.path) }
        return url
    }

    func testOnlyDirectChildrenOfAllowedRootsAreCleanable() throws {
        let cache = try write("Library/Caches/com.example.app/data.bin", bytes: 10)
        XCTAssertTrue(StorageRoots.isCleanable(cache.deletingLastPathComponent(), home: home))
        XCTAssertFalse(StorageRoots.isCleanable(cache, home: home), "grandchildren are not offered")
        XCTAssertFalse(StorageRoots.isCleanable(home.appendingPathComponent("Documents"), home: home))
        XCTAssertFalse(StorageRoots.isCleanable(home.appendingPathComponent("Library/Caches"), home: home), "the root itself")
        XCTAssertFalse(StorageRoots.isCleanable(URL(fileURLWithPath: "/System/Library/Caches"), home: home))
        XCTAssertFalse(StorageRoots.isCleanable(home.appendingPathComponent("Library/Caches/CloudKit"), home: home), "keep list")
    }

    func testSymlinksAreNeverCleaned() throws {
        let target = try write("Documents/precious.txt", bytes: 5)
        let link = home.appendingPathComponent("Library/Caches/link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        XCTAssertFalse(StorageRoots.isCleanable(link, home: home))
    }

    func testScanFindsSizesAndAgesAndSkipsRecentDownloads() throws {
        _ = try write("Library/Caches/com.big.app/blob", bytes: 3_000_000)
        _ = try write("Library/Caches/com.tiny.app/blob", bytes: 100)
        _ = try write("Downloads/old.iso", bytes: 2_000_000, ageDays: 120)
        _ = try write("Downloads/new.iso", bytes: 2_000_000, ageDays: 1)
        _ = try write(".Trash/junk", bytes: 1_500_000)
        let items = StorageScanner.scan(home: home)
        XCTAssertEqual(items.map(\.name), ["com.big.app", "old.iso", "junk"])
        XCTAssertEqual(items.first?.kind, .appCaches)
        XCTAssertGreaterThanOrEqual(items.first?.bytes ?? 0, 3_000_000)
        XCTAssertFalse(items.contains { $0.name == "new.iso" })
    }

    func testMoveToTrashIsReversibleAndRefusesTrashAndStrangers() throws {
        _ = try write("Library/Caches/com.big.app/blob", bytes: 2_000_000)
        _ = try write(".Trash/junk", bytes: 2_000_000)
        let doc = try write("Documents/keep.txt", bytes: 2_000_000)
        var items = StorageScanner.scan(home: home)
        items.append(StorageItem(url: doc, name: "keep.txt", kind: .appCaches, bytes: 2_000_000))
        let result = StorageCleaner.moveToTrash(items, home: home)
        XCTAssertEqual(result.movedCount, 1)
        XCTAssertEqual(Set(result.failed), ["junk", "keep.txt"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: doc.path), "documents are untouched")
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent("Library/Caches/com.big.app").path))
    }
}
