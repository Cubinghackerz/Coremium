import Foundation

/// What Coremium does with an app.
public enum AppRule: String, Codable, CaseIterable, Sendable {
    /// Never demoted. While it is the app you're using (or busy in the background), a boost session runs.
    case boost
    /// Left alone (unless the optional heavy-app catcher is on during a boost session).
    case normal
    /// "Yield": steps aside. Pushed to the efficiency cores during a boost session, unless it is the app you're using.
    /// (The raw value stays `auto` so settings from older versions keep working.)
    case auto
    /// Pushed to the efficiency cores at all times, unless it is the app you're using.
    case efficiency

    public var label: String {
        switch self {
        case .boost: return "Boost"
        case .normal: return "Normal"
        case .auto: return "Yield"
        case .efficiency: return "Efficiency"
        }
    }
}

/// All user-configurable behaviour. Persisted as JSON by the app. Missing keys fall back to defaults,
/// so settings files from older versions keep working.
public struct RuleSet: Codable, Equatable, Sendable {
    public var mode: PerformanceMode
    /// Per-app overrides: bundle identifier → rule. These always win over the mode's category rules.
    public var rules: [String: AppRule]
    /// Bundle identifiers that are never demoted, whatever else says.
    public var protectedBundleIDs: Set<String>
    /// During a boost session, also demote any other (non-protected, normal) app above `heavyThresholdPercent`.
    public var demoteHeavyApps: Bool
    public var heavyThresholdPercent: Double
    /// Start a session when a boost app is busy in the background (above `boostBusyPercent`), not only when it's frontmost.
    public var boostWhenBusy: Bool
    public var boostBusyPercent: Double
    /// Seconds a session keeps running after the boost app leaves the front.
    public var graceSeconds: Double
    public var fullscreenFixEnabled: Bool
    public var keepDisplayAwakeDuringBoost: Bool

    public init(mode: PerformanceMode = .automatic, rules: [String: AppRule] = [:],
                protectedBundleIDs: Set<String> = RuleSet.defaultProtected, demoteHeavyApps: Bool = false,
                heavyThresholdPercent: Double = 25, boostWhenBusy: Bool = true, boostBusyPercent: Double = 20,
                graceSeconds: Double = 90, fullscreenFixEnabled: Bool = false, keepDisplayAwakeDuringBoost: Bool = true) {
        self.mode = mode
        self.rules = rules
        self.protectedBundleIDs = protectedBundleIDs
        self.demoteHeavyApps = demoteHeavyApps
        self.heavyThresholdPercent = heavyThresholdPercent
        self.boostWhenBusy = boostWhenBusy
        self.boostBusyPercent = boostBusyPercent
        self.graceSeconds = graceSeconds
        self.fullscreenFixEnabled = fullscreenFixEnabled
        self.keepDisplayAwakeDuringBoost = keepDisplayAwakeDuringBoost
    }

    private enum CodingKeys: String, CodingKey {
        case mode, rules, protectedBundleIDs, demoteHeavyApps, heavyThresholdPercent, boostWhenBusy,
             boostBusyPercent, graceSeconds, fullscreenFixEnabled, keepDisplayAwakeDuringBoost
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = RuleSet()
        mode = try c.decodeIfPresent(PerformanceMode.self, forKey: .mode) ?? d.mode
        rules = try c.decodeIfPresent([String: AppRule].self, forKey: .rules) ?? d.rules
        protectedBundleIDs = try c.decodeIfPresent(Set<String>.self, forKey: .protectedBundleIDs) ?? d.protectedBundleIDs
        demoteHeavyApps = try c.decodeIfPresent(Bool.self, forKey: .demoteHeavyApps) ?? d.demoteHeavyApps
        heavyThresholdPercent = try c.decodeIfPresent(Double.self, forKey: .heavyThresholdPercent) ?? d.heavyThresholdPercent
        boostWhenBusy = try c.decodeIfPresent(Bool.self, forKey: .boostWhenBusy) ?? d.boostWhenBusy
        boostBusyPercent = try c.decodeIfPresent(Double.self, forKey: .boostBusyPercent) ?? d.boostBusyPercent
        graceSeconds = try c.decodeIfPresent(Double.self, forKey: .graceSeconds) ?? d.graceSeconds
        fullscreenFixEnabled = try c.decodeIfPresent(Bool.self, forKey: .fullscreenFixEnabled) ?? d.fullscreenFixEnabled
        keepDisplayAwakeDuringBoost = try c.decodeIfPresent(Bool.self, forKey: .keepDisplayAwakeDuringBoost)
            ?? d.keepDisplayAwakeDuringBoost
    }

    /// The explicit per-app override, or `.normal` if there is none.
    public func rule(for bundleID: String?) -> AppRule {
        guard let bundleID else { return .normal }
        return rules[bundleID] ?? .normal
    }

    /// What actually applies: your override if there is one, otherwise what the active profile says for the app's category.
    public func effectiveRule(bundleID: String?, category: AppCategory, profile: ModeProfile) -> AppRule {
        if let bundleID, let explicit = rules[bundleID] { return explicit }
        if profile.boost.contains(category) { return .boost }
        if profile.demote.contains(category) { return .auto }
        return .normal
    }

    public static let defaultProtected: Set<String> = [
        "com.cubinghackerz.coremium",
        "com.apple.finder", "com.apple.dock", "com.apple.systemuiserver", "com.apple.controlcenter",
        "com.apple.loginwindow", "com.apple.Music", "com.spotify.client", "com.apple.WindowManager",
    ]

    /// Never moved, whatever the user picks: Coremium itself and the system UI.
    public static let systemEssential: Set<String> = [
        "com.cubinghackerz.coremium", "com.apple.finder", "com.apple.dock", "com.apple.systemuiserver",
        "com.apple.controlcenter", "com.apple.loginwindow", "com.apple.WindowManager",
    ]

    /// Out of the box: Automatic mode, no overrides, everything decided by app category.
    public static let defaults = RuleSet()
}

/// A running GUI app as the engine sees it.
public struct AppProcess: Equatable, Sendable {
    public let pid: Int32
    public let bundleID: String?

    public init(pid: Int32, bundleID: String?) {
        self.pid = pid
        self.bundleID = bundleID
    }
}

/// Everything the evaluator needs to decide, as plain data (no system calls) so it can be unit-tested.
public struct EvaluationInput: Sendable {
    public var snapshot: ProcessSnapshot
    public var apps: [AppProcess]
    public var frontmostPid: Int32?
    public var rules: RuleSet
    public var sessionActive: Bool
    /// CPU percent per app main pid (whole process tree). Used for busy-boost detection and the heavy-app catcher.
    public var cpuByAppPid: [Int32: Double]
    /// Bundle identifier → category. Unknown bundles count as `.other`.
    public var categories: [String: AppCategory]
    public var ownUid: UInt32
    public var ownPid: Int32

    public init(snapshot: ProcessSnapshot, apps: [AppProcess], frontmostPid: Int32?, rules: RuleSet,
                sessionActive: Bool, cpuByAppPid: [Int32: Double] = [:], categories: [String: AppCategory] = [:],
                ownUid: UInt32, ownPid: Int32) {
        self.snapshot = snapshot
        self.apps = apps
        self.frontmostPid = frontmostPid
        self.rules = rules
        self.sessionActive = sessionActive
        self.cpuByAppPid = cpuByAppPid
        self.categories = categories
        self.ownUid = ownUid
        self.ownPid = ownPid
    }
}

public enum RuleEvaluator {
    /// The profile in force right now, given the mode, the app in front and which apps are busy.
    public static func activeProfile(apps: [AppProcess], frontmostPid: Int32?, rules: RuleSet,
                                     cpuByAppPid: [Int32: Double], categories: [String: AppCategory]) -> ModeProfile {
        func category(_ app: AppProcess) -> AppCategory { app.bundleID.flatMap { categories[$0] } ?? .other }
        let front = apps.first { $0.pid == frontmostPid }.map(category)
        let busy = Set(apps.filter { (cpuByAppPid[$0.pid] ?? 0) > rules.boostBusyPercent }.map(category))
        return ModeProfile.resolve(mode: rules.mode, frontCategory: front, busyCategories: rules.boostWhenBusy ? busy : [])
    }

    /// Whether a boost session should be running right now (ignoring the grace period, which is time-based).
    public static func boostTriggered(apps: [AppProcess], frontmostPid: Int32?, rules: RuleSet,
                                      cpuByAppPid: [Int32: Double], categories: [String: AppCategory] = [:]) -> Bool {
        let profile = activeProfile(apps: apps, frontmostPid: frontmostPid, rules: rules,
                                    cpuByAppPid: cpuByAppPid, categories: categories)
        for app in apps {
            let category = app.bundleID.flatMap { categories[$0] } ?? .other
            guard rules.effectiveRule(bundleID: app.bundleID, category: category, profile: profile) == .boost else { continue }
            if app.pid == frontmostPid { return true }
            if rules.boostWhenBusy, (cpuByAppPid[app.pid] ?? 0) > rules.boostBusyPercent { return true }
        }
        return false
    }

    /// The set of pids that should be on the efficiency cores right now.
    public static func pidsToDemote(_ input: EvaluationInput) -> Set<Int32> {
        let rules = input.rules
        let snapshot = input.snapshot
        let profile = activeProfile(apps: input.apps, frontmostPid: input.frontmostPid, rules: rules,
                                    cpuByAppPid: input.cpuByAppPid, categories: input.categories)

        func effective(_ app: AppProcess) -> AppRule {
            let category = app.bundleID.flatMap { input.categories[$0] } ?? .other
            return rules.effectiveRule(bundleID: app.bundleID, category: category, profile: profile)
        }

        // The app you're using, and every boost app, are never touched, including their child processes.
        var shielded: Set<Int32> = [input.ownPid]
        var frontBundle: String?
        for app in input.apps {
            let isFront = app.pid == input.frontmostPid
            if isFront { frontBundle = app.bundleID }
            if isFront || effective(app) == .boost {
                shielded.formUnion(snapshot.tree(of: app.pid))
            }
        }

        var result: Set<Int32> = []
        for app in input.apps {
            if app.pid == input.frontmostPid { continue }
            if let bundle = app.bundleID {
                // An explicit choice beats the default protection (so Spotify can be set to Eco); the system UI never moves.
                if RuleSet.systemEssential.contains(bundle) { continue }
                if rules.protectedBundleIDs.contains(bundle), rules.rules[bundle] == nil { continue }
                if bundle == frontBundle { continue }   // another instance of the app you're using
            }
            let demote: Bool
            switch effective(app) {
            case .boost: demote = false
            case .efficiency: demote = true
            case .auto: demote = input.sessionActive
            case .normal:
                demote = input.sessionActive && rules.demoteHeavyApps && app.bundleID != nil
                    && (input.cpuByAppPid[app.pid] ?? 0) > rules.heavyThresholdPercent
            }
            guard demote else { continue }
            for pid in snapshot.tree(of: app.pid) where !shielded.contains(pid) && pid > 1 {
                guard let entry = snapshot.entries[pid], entry.uid == input.ownUid else { continue }
                result.insert(pid)
            }
        }
        return result
    }
}
