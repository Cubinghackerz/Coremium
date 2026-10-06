import XCTest
@testable import CoremiumCore

final class EngineSamplingPlanTests: XCTestCase {
    func plan(paused: Bool = false, visible: Bool = false, active: Bool = false, lowPower: Bool = false,
              now: Double = 100, diagnostics: Double? = nil, footprints: Double? = nil) -> EngineSamplingPlan {
        EngineSamplingPlan(paused: paused, panelVisible: visible, sessionActive: active, lowPowerMode: lowPower,
            uptime: now, lastDiagnosticsAt: diagnostics, lastFootprintsAt: footprints)
    }

    func testPausedClosedHasNoTimerOrDiagnosticsEvenBeforeSessionEnds() {
        let p = plan(paused: true, active: true)
        XCTAssertNil(p.timerInterval)
        XCTAssertFalse(p.samplesCPU)
        XCTAssertFalse(p.samplesDiagnostics)
        XCTAssertFalse(p.samplesFootprints)
    }

    func testIdleAvoidsUnneededCoreGPUAndMemorySampling() {
        let p = plan()
        XCTAssertEqual(p.timerInterval, 10)
        XCTAssertFalse(p.samplesCPU)
        XCTAssertFalse(p.samplesDiagnostics)
        XCTAssertFalse(p.samplesFootprints)
    }

    func testActiveSessionReusesCPUButThrottlesDiagnosticsAndNeverScansFootprints() {
        let p = plan(active: true, diagnostics: 96)
        XCTAssertEqual(p.timerInterval, 4)
        XCTAssertTrue(p.samplesCPU)
        XCTAssertFalse(p.samplesDiagnostics)
        XCTAssertFalse(p.samplesFootprints)
        XCTAssertTrue(plan(active: true, diagnostics: 88).samplesDiagnostics)
    }

    func testVisibleDiagnosticsAreAvailableImmediatelyThenRateLimited() {
        XCTAssertEqual(plan(visible: true).timerInterval, 2)
        XCTAssertTrue(plan(visible: true).samplesDiagnostics)
        XCTAssertTrue(plan(visible: true).samplesFootprints)
        XCTAssertFalse(plan(visible: true, diagnostics: 98, footprints: 98).samplesDiagnostics)
        XCTAssertFalse(plan(visible: true, diagnostics: 98, footprints: 98).samplesFootprints)
        XCTAssertTrue(plan(visible: true, diagnostics: 96, footprints: 94).samplesDiagnostics)
        XCTAssertTrue(plan(visible: true, diagnostics: 96, footprints: 94).samplesFootprints)
        XCTAssertTrue(plan(paused: true, visible: true).samplesCPU)
    }

    func testLowPowerModeReducesPollingInEveryState() {
        XCTAssertEqual(plan(lowPower: true).timerInterval, 20)
        XCTAssertEqual(plan(active: true, lowPower: true).timerInterval, 6)
        XCTAssertEqual(plan(visible: true, lowPower: true).timerInterval, 3)
        XCTAssertFalse(plan(active: true, lowPower: true, diagnostics: 88).samplesDiagnostics)
        XCTAssertTrue(plan(active: true, lowPower: true, diagnostics: 80).samplesDiagnostics)
    }

    func testClockResetRefreshesButInvalidClockDoesNotPoll() {
        XCTAssertTrue(plan(active: true, now: 1, diagnostics: 100).samplesDiagnostics)
        XCTAssertFalse(plan(visible: true, now: .nan).samplesDiagnostics)
        XCTAssertFalse(plan(visible: true, now: .infinity).samplesFootprints)
    }

    func testClosedSessionHasAtMostFiveDiagnosticScansAndNoFootprintScansPerMinute() {
        var diagnosticsAt: Double?
        var scans = 0
        for second in stride(from: 0.0, to: 60, by: 4) {
            let p = plan(active: true, now: second, diagnostics: diagnosticsAt)
            XCTAssertFalse(p.samplesFootprints)
            if p.samplesDiagnostics { scans += 1; diagnosticsAt = second }
        }
        XCTAssertEqual(scans, 5)
    }
}
