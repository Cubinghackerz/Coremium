import Foundation

/// A small, deterministic resource budget shared by the engine and tests. No timers or system calls here.
/// Event-driven application notifications still trigger immediate rule evaluation between timer ticks.
public struct EngineSamplingPlan: Equatable, Sendable {
    /// Nil means no periodic polling. Low Power Mode slows sampling without adding another timer.
    public let timerInterval: TimeInterval?
    public let samplesCPU: Bool
    public let samplesDiagnostics: Bool
    public let samplesFootprints: Bool

    public init(paused: Bool, panelVisible: Bool, sessionActive: Bool, lowPowerMode: Bool,
                uptime: TimeInterval, lastDiagnosticsAt: TimeInterval? = nil,
                lastFootprintsAt: TimeInterval? = nil) {
        timerInterval = Self.interval(paused: paused, panelVisible: panelVisible,
            sessionActive: sessionActive, lowPowerMode: lowPowerMode)
        samplesCPU = panelVisible || (!paused && sessionActive)
        let diagnosticInterval: TimeInterval = panelVisible ? (lowPowerMode ? 8 : 4) : (lowPowerMode ? 20 : 12)
        samplesDiagnostics = samplesCPU && Self.due(uptime, since: lastDiagnosticsAt, interval: diagnosticInterval)
        // Per-process footprint scans are UI-only. Session reports need global memory pressure, not every app's RAM.
        samplesFootprints = panelVisible && Self.due(uptime, since: lastFootprintsAt, interval: lowPowerMode ? 12 : 6)
    }

    public static func interval(paused: Bool, panelVisible: Bool, sessionActive: Bool,
                                lowPowerMode: Bool) -> TimeInterval? {
        if paused && !panelVisible { return nil }
        if panelVisible { return lowPowerMode ? 3 : 2 }
        if sessionActive { return lowPowerMode ? 6 : 4 }
        return lowPowerMode ? 20 : 10
    }

    private static func due(_ now: TimeInterval, since previous: TimeInterval?, interval: TimeInterval) -> Bool {
        guard now.isFinite else { return false }
        guard let previous, previous.isFinite, now >= previous else { return true }
        return now - previous >= interval
    }
}
