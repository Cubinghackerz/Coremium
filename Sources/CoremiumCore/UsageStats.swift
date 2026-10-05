import Foundation

/// What Coremium did on one calendar day. Only things it can actually measure.
public struct DayStats: Codable, Equatable, Sendable {
    public var day: String                      // yyyy-MM-dd, local time
    public var sessions = 0
    /// Seconds a boost session was running.
    public var boostedSeconds = 0.0
    /// CPU work (in core-seconds) that ran on the efficiency cores because Coremium moved it there.
    public var movedCoreSeconds = 0.0
    /// Most processes moved at once.
    public var peakMovedProcesses = 0
    /// Seconds of boost time the Mac reported being "serious" or "critical" hot (macOS thermal state).
    public var hotSeconds = 0.0
    /// Seconds per mode (raw value of the profile in force).
    public var secondsByMode: [String: Double] = [:]

    public init(day: String) { self.day = day }
}

/// Daily totals, saved as JSON.
public struct UsageLedger: Codable, Equatable, Sendable {
    public var days: [String: DayStats] = [:]

    public init() {}

    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Adds one engine tick covering `seconds` of wall-clock time.
    public mutating func record(at date: Date, seconds: Double, sessionActive: Bool, mode: PerformanceMode,
                                movedCoreSeconds: Double, movedProcesses: Int, hot: Bool, sessionStarted: Bool,
                                calendar: Calendar = .current) {
        guard seconds > 0, seconds <= 60 else { return }
        let key = Self.dayKey(date, calendar: calendar)
        var day = days[key] ?? DayStats(day: key)
        if sessionStarted { day.sessions += 1 }
        if sessionActive {
            day.boostedSeconds += seconds
            day.secondsByMode[mode.rawValue, default: 0] += seconds
            if hot { day.hotSeconds += seconds }
        }
        day.movedCoreSeconds += max(0, movedCoreSeconds)
        day.peakMovedProcesses = max(day.peakMovedProcesses, movedProcesses)
        days[key] = day
    }

    /// The most recent `count` calendar days ending today, oldest first, with zero-filled gaps.
    public func lastDays(_ count: Int, endingAt date: Date = Date(), calendar: Calendar = .current) -> [DayStats] {
        (0..<count).reversed().compactMap { offset in
            guard let d = calendar.date(byAdding: .day, value: -offset, to: date) else { return nil }
            let key = Self.dayKey(d, calendar: calendar)
            return days[key] ?? DayStats(day: key)
        }
    }

    public func total(days count: Int, endingAt date: Date = Date(), calendar: Calendar = .current) -> DayStats {
        var sum = DayStats(day: "total")
        for d in lastDays(count, endingAt: date, calendar: calendar) {
            sum.sessions += d.sessions
            sum.boostedSeconds += d.boostedSeconds
            sum.movedCoreSeconds += d.movedCoreSeconds
            sum.peakMovedProcesses = max(sum.peakMovedProcesses, d.peakMovedProcesses)
            sum.hotSeconds += d.hotSeconds
            for (mode, seconds) in d.secondsByMode { sum.secondsByMode[mode, default: 0] += seconds }
        }
        return sum
    }

    public static func load(from url: URL) -> UsageLedger {
        guard let data = try? Data(contentsOf: url) else { return UsageLedger() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(UsageLedger.self, from: data)) ?? UsageLedger()
    }

    public func save(to url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(self) { try? data.write(to: url, options: .atomic) }
    }
}

/// A deliberately rough, clearly-labelled estimate. Coremium cannot measure power draw without admin rights.
public enum EnergyEstimate {
    /// Assumed watts saved for each core's worth of work that runs on an efficiency core instead of a performance core.
    /// Apple Silicon performance cores draw roughly 2–4 W under load and efficiency cores roughly 0.3–0.6 W.
    public static let assumedWattsSavedPerCore = 1.5

    public static func watthours(forMovedCoreSeconds coreSeconds: Double) -> Double {
        coreSeconds * assumedWattsSavedPerCore / 3600
    }
}

public func formatDuration(_ seconds: Double) -> String {
    let total = Int(seconds.rounded())
    if total < 60 { return "\(total)s" }
    if total < 3600 { return "\(total / 60) min" }
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    return minutes == 0 ? "\(hours) h" : "\(hours) h \(minutes) min"
}
