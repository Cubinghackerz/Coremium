import Foundation

/// A suggestion learned from how you actually use your Mac.
public struct Suggestion: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable { case yield, boost }

    public var id: String { "\(kind.rawValue):\(bundleID)" }
    public let kind: Kind
    public let bundleID: String
    public let name: String
    /// Plain-language evidence, e.g. "Used about 1.4 cores while a boost session was running in the background."
    public let reason: String

    public init(kind: Kind, bundleID: String, name: String, reason: String) {
        self.kind = kind
        self.bundleID = bundleID
        self.name = name
        self.reason = reason
    }
}

/// Learns two things, entirely on this Mac:
///  1. which apps keep using a lot of CPU in the background while you're boosting something (suggest "Yield"), and
///  2. which apps you actually spend heavy, focused time in (suggest "Boost").
public struct WorkloadLearner: Codable, Equatable, Sendable {
    public struct AppStats: Codable, Equatable, Sendable {
        public var name: String
        public var frontSamples = 0
        public var frontCores = 0.0
        public var backSamples = 0      // only counted while a boost session is running
        public var backCores = 0.0
    }

    public var apps: [String: AppStats] = [:]
    public var dismissed: Set<String> = []

    /// Minimum evidence before suggesting anything. Samples arrive every few seconds.
    public static let minimumBackgroundSamples = 40
    public static let minimumFrontSamples = 120
    public static let backgroundCoresThreshold = 0.35
    public static let frontCoresThreshold = 0.6

    public init() {}

    /// `cores` is CPU use in cores (1.0 = one core fully busy).
    public mutating func ingest(bundleID: String, name: String, isFront: Bool, sessionActive: Bool, cores: Double) {
        var entry = apps[bundleID] ?? AppStats(name: name)
        entry.name = name
        if isFront {
            entry.frontSamples += 1
            entry.frontCores += cores
        } else if sessionActive {
            entry.backSamples += 1
            entry.backCores += cores
        }
        apps[bundleID] = entry
    }

    public mutating func dismiss(_ suggestion: Suggestion) { dismissed.insert(suggestion.id) }

    /// Suggestions for apps that currently have no explicit choice and whose behaviour the mode doesn't already cover.
    /// `isHandled(bundleID, kind)` tells the learner when the app is already boosted/yielding, so it stays quiet.
    public func suggestions(isHandled: (String, Suggestion.Kind) -> Bool) -> [Suggestion] {
        var result: [Suggestion] = []
        for (bundleID, stats) in apps {
            if stats.backSamples >= Self.minimumBackgroundSamples {
                let average = stats.backCores / Double(stats.backSamples)
                let suggestion = Suggestion(
                    kind: .yield, bundleID: bundleID, name: stats.name,
                    reason: String(format: "Kept about %.1f cores busy in the background while you were boosting something.", average))
                if average >= Self.backgroundCoresThreshold, !isHandled(bundleID, .yield), !dismissed.contains(suggestion.id) {
                    result.append(suggestion)
                }
            }
            if stats.frontSamples >= Self.minimumFrontSamples {
                let average = stats.frontCores / Double(stats.frontSamples)
                let suggestion = Suggestion(
                    kind: .boost, bundleID: bundleID, name: stats.name,
                    reason: String(format: "You spend a lot of focused time here and it works hard (about %.1f cores).", average))
                if average >= Self.frontCoresThreshold, !isHandled(bundleID, .boost), !dismissed.contains(suggestion.id) {
                    result.append(suggestion)
                }
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public static func load(from url: URL) -> WorkloadLearner {
        guard let data = try? Data(contentsOf: url),
              let learner = try? JSONDecoder().decode(WorkloadLearner.self, from: data) else { return WorkloadLearner() }
        return learner
    }

    public func save(to url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) { try? data.write(to: url, options: .atomic) }
    }
}
