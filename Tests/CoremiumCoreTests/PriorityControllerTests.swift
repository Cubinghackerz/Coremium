import XCTest
@testable import CoremiumCore

final class MockBackend: PriorityBackend {
    var background: Set<Int32> = []
    var calls: [(Int32, Bool)] = []

    func setBackground(_ pid: Int32, _ on: Bool) -> Bool {
        calls.append((pid, on))
        if on { background.insert(pid) } else { background.remove(pid) }
        return true
    }
}

final class PriorityControllerTests: XCTestCase {
    func snapshot(_ pids: [(Int32, UInt64)], uid: UInt32 = 501) -> ProcessSnapshot {
        ProcessSnapshot(pids.map { ProcEntry(pid: $0.0, ppid: 1, uid: uid, startTime: $0.1, name: "x") })
    }

    func testApplyDemotesAndRestoresDiff() {
        let backend = MockBackend()
        let controller = PriorityController(backend: backend, ledger: DemotionLedger(url: nil), ownPid: 9, ownUid: 501)
        let snap = snapshot([(10, 1), (11, 2), (12, 3)])

        controller.apply(target: [10, 11], snapshot: snap)
        XCTAssertEqual(backend.background, [10, 11])
        XCTAssertEqual(controller.demotedPids, [10, 11])

        controller.apply(target: [11, 12], snapshot: snap)
        XCTAssertEqual(backend.background, [11, 12])

        controller.restoreAll(snapshot: snap)
        XCTAssertTrue(backend.background.isEmpty)
        XCTAssertTrue(controller.demotedPids.isEmpty)
    }

    func testNeverTouchesForeignUidOwnPidOrLaunchd() {
        let backend = MockBackend()
        let controller = PriorityController(backend: backend, ledger: DemotionLedger(url: nil), ownPid: 9, ownUid: 501)
        var list = [ProcEntry(pid: 1, ppid: 0, uid: 501, startTime: 1, name: "launchd"),
                    ProcEntry(pid: 9, ppid: 1, uid: 501, startTime: 1, name: "me"),
                    ProcEntry(pid: 20, ppid: 1, uid: 0, startTime: 1, name: "root")]
        list.append(ProcEntry(pid: 21, ppid: 1, uid: 501, startTime: 1, name: "ok"))
        controller.apply(target: [1, 9, 20, 21], snapshot: ProcessSnapshot(list))
        XCTAssertEqual(backend.background, [21])
    }

    func testPidReuseIsNotRestored() {
        let backend = MockBackend()
        let controller = PriorityController(backend: backend, ledger: DemotionLedger(url: nil), ownPid: 9, ownUid: 501)
        controller.apply(target: [30], snapshot: snapshot([(30, 100)]))
        backend.calls.removeAll()
        // Process 30 exited and a different process got pid 30 (different start time).
        controller.restoreAll(snapshot: snapshot([(30, 999)]))
        XCTAssertTrue(backend.calls.isEmpty, "must not touch an unrelated process that reused the pid")
        XCTAssertTrue(controller.demotedPids.isEmpty)
    }

    func testLedgerPersistsAndRestoresAfterCrash() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("coremium-ledger-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let snap = snapshot([(40, 7), (41, 8)])

        let first = MockBackend()
        PriorityController(backend: first, ledger: DemotionLedger(url: url), ownPid: 9, ownUid: 501)
            .apply(target: [40, 41], snapshot: snap)
        XCTAssertEqual(first.background, [40, 41])

        // "Relaunch": a new controller reads the ledger and restores what is still running.
        let second = MockBackend()
        let relaunched = PriorityController(backend: second, ledger: DemotionLedger(url: url), ownPid: 9, ownUid: 501)
        XCTAssertEqual(relaunched.demotedPids, [40, 41])
        relaunched.restoreAll(snapshot: snapshot([(40, 7)]))   // 41 has exited
        XCTAssertEqual(second.calls.map(\.0), [40])
        XCTAssertEqual(second.calls.map(\.1), [false])
        XCTAssertTrue(DemotionLedger(url: url).entries.isEmpty)
    }

    /// Uses the real kernel call on a throwaway `sleep` child: priority must drop to the background band and come back.
    func testDarwinBackendMovesRealProcessToBackgroundBand() throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["30"]
        try child.run()
        defer { child.terminate() }
        let pid = child.processIdentifier

        // The test runner itself may have been launched in the background band (children inherit it),
        // so establish a normal baseline first.
        XCTAssertTrue(DarwinPriorityBackend().setBackground(pid, false))
        let normal = try scheduledPriority(pid)
        XCTAssertTrue(DarwinPriorityBackend().setBackground(pid, true))
        let background = try scheduledPriority(pid)
        XCTAssertTrue(DarwinPriorityBackend().setBackground(pid, false))
        let restored = try scheduledPriority(pid)

        XCTAssertEqual(background, 4, "background band priority on macOS is 4")
        XCTAssertGreaterThan(normal, background)
        XCTAssertEqual(restored, normal)
    }

    func testCaptureSeesOwnProcess() {
        let snap = ProcessSnapshot.capture()
        let me = snap.entries[getpid()]
        XCTAssertNotNil(me)
        XCTAssertEqual(me?.uid, getuid())
        XCTAssertGreaterThan(me?.startTime ?? 0, 0)
        XCTAssertTrue(snap.tree(of: 1).contains(getpid()), "everything descends from launchd")
    }

    func testTreeHandlesMissingPidAndCycles() {
        let snap = ProcessSnapshot([
            ProcEntry(pid: 5, ppid: 6, uid: 501, startTime: 1, name: "a"),
            ProcEntry(pid: 6, ppid: 5, uid: 501, startTime: 1, name: "b"),
        ])
        XCTAssertEqual(Set(snap.tree(of: 5)), [5, 6])
        XCTAssertEqual(snap.tree(of: 77), [])
    }

    private func scheduledPriority(_ pid: Int32) throws -> Int {
        let ps = Process()
        let pipe = Pipe()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-o", "pri=", "-p", String(pid)]
        ps.standardOutput = pipe
        try ps.run()
        ps.waitUntilExit()
        let text = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return try XCTUnwrap(Int(text.trimmingCharacters(in: .whitespacesAndNewlines)))
    }
}
