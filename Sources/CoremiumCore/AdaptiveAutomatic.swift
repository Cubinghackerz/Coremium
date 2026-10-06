import Foundation

public struct AdaptiveAutomaticDecision: Equatable, Sendable {
    public enum Phase: String, Sendable { case observing, yielding, recovering }
    public let appPids: Set<Int32>
    public let phase: Phase
    public let reason: String

    public static let observing = AdaptiveAutomaticDecision(appPids: [], phase: .observing,
        reason: "Watching CPU load; no adaptive priority changes right now.")
}

/// A local, deterministic policy. High CPU load is a signal, not proof of a speed improvement.
/// Explicit rules bypass this policy; busy renders, builds and local models are preserved.
public struct AdaptiveAutomaticPolicy: Sendable {
    private struct Candidate: Sendable {
        let startTime: UInt64
        let since: TimeInterval
    }
    private var candidates: [Int32: Candidate] = [:]
    private var selected: [Int32: UInt64] = [:]
    private var pressureSince: TimeInterval?
    private var quietSince: TimeInterval?
    private var engagedAt: TimeInterval?
    private var previousSample: TimeInterval?
    private var cooldownUntil: TimeInterval = 0

    public init() {}

    /// `performanceLoad` is the measured average busy fraction of P cores, or all cores on Intel.
    /// `uptime` is monotonic seconds; missing measurements release only this policy's changes.
    public mutating func evaluate(_ input: EvaluationInput, performanceLoad: Double?,
                                 uptime: TimeInterval) -> AdaptiveAutomaticDecision {
        guard input.rules.mode == .automatic, input.rules.adaptiveAutomatic, input.sessionActive,
              input.frontmostPid != nil, let load = performanceLoad, load.isFinite, (0...1).contains(load),
              uptime.isFinite else {
            self = Self()
            return .observing
        }
        if let previousSample, uptime <= previousSample || uptime - previousSample > 15 {
            self = Self()
        }
        previousSample = uptime

        let profile = RuleEvaluator.activeProfile(apps: input.apps, frontmostPid: input.frontmostPid,
            rules: input.rules, cpuByAppPid: input.cpuByAppPid, categories: input.categories)
        let frontBundle = input.apps.first { $0.pid == input.frontmostPid }?.bundleID
        var eligible: [Int32: UInt64] = [:]
        for app in input.apps {
            guard app.pid != input.frontmostPid, app.pid != input.ownPid,
                  let bundle = app.bundleID, bundle != frontBundle, input.rules.rules[bundle] == nil,
                  !input.rules.protectedBundleIDs.contains(bundle), !RuleSet.systemEssential.contains(bundle),
                  let process = input.snapshot.entries[app.pid], process.uid == input.ownUid else { continue }
            let category = input.categories[bundle] ?? .other
            let cpu = input.cpuByAppPid[app.pid] ?? 0
            guard cpu.isFinite, cpu >= 0,
                  input.rules.effectiveRule(bundleID: bundle, category: category, profile: profile) != .boost else { continue }
            // A background build/render/model may be the user's main task even when another app is in front.
            if [.creative, .developer, .localAI].contains(category), cpu > input.rules.boostBusyPercent { continue }
            eligible[app.pid] = process.startTime
            if cpu >= 25 {
                if candidates[app.pid]?.startTime != process.startTime {
                    candidates[app.pid] = Candidate(startTime: process.startTime, since: uptime)
                }
            } else { candidates[app.pid] = nil }
        }
        candidates = candidates.filter { eligible[$0.key] == $0.value.startTime }
        selected = selected.filter { eligible[$0.key] == $0.value }

        if load >= 0.80 { pressureSince = pressureSince ?? uptime }
        else { pressureSince = nil }

        if engagedAt == nil, uptime >= cooldownUntil,
           let pressureSince, uptime - pressureSince >= 6 {
            engagedAt = uptime
        }
        if engagedAt != nil {
            for (pid, candidate) in candidates where uptime - candidate.since >= 6 {
                selected[pid] = candidate.startTime
            }
            if load <= 0.55 { quietSince = quietSince ?? uptime }
            else { quietSince = nil }
            if let quietSince, let engagedAt, uptime - quietSince >= 12, uptime - engagedAt >= 15 {
                selected.removeAll()
                candidates.removeAll()
                self.engagedAt = nil
                self.quietSince = nil
                pressureSince = nil
                cooldownUntil = uptime + 10
                return AdaptiveAutomaticDecision(appPids: [], phase: .observing,
                    reason: "CPU pressure eased; adaptive priority changes restored.")
            }
        }
        guard !selected.isEmpty else { return .observing }
        return AdaptiveAutomaticDecision(appPids: Set(selected.keys), phase: quietSince == nil ? .yielding : .recovering,
            reason: quietSince == nil ? "Sustained high CPU load; busy background apps are yielding."
                : "CPU load eased; waiting briefly before restoring normal priority.")
    }
}
