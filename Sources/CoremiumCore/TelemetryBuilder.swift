import Foundation

/// Pure helpers that turn raw readings into the series the charts show.
public enum TelemetryBuilder {
    /// The key the charts use for every app that is not among the top ones.
    public static let otherKey = "other"

    /// GPU share (0...100) per app, by bundle id: the `top` busiest apps by name, and everything else summed into
    /// `otherKey`. An app's share is the sum over its whole process tree. Apps with no GPU use are left out.
    ///
    /// - Parameters:
    ///   - perPid: GPU percent per process id, from `GPUSampler`.
    ///   - trees: process ids per app key (bundle id, or "pid:N" for an app without one).
    public static func appGPU(perPid: [Int32: Double], trees: [String: [Int32]], top: Int = 5) -> [String: Double] {
        var ranked: [(key: String, percent: Double)] = []
        for (key, pids) in trees {
            var total = 0.0
            for pid in pids { total += perPid[pid] ?? 0 }
            if total > 0 { ranked.append((key: key, percent: total)) }
        }
        ranked.sort { lhs, rhs in
            if lhs.percent != rhs.percent { return lhs.percent > rhs.percent }
            return lhs.key < rhs.key
        }
        var result: [String: Double] = [:]
        for (index, entry) in ranked.enumerated() {
            if index < top {
                result[entry.key] = entry.percent
            } else {
                result[otherKey, default: 0] += entry.percent
            }
        }
        return result
    }
}
