import AppKit
import Combine
import CoremiumCore
import IOKit.pwr_mgt

#if PREVIEW
/// Preview/profile builds must never change another process's priority, even when exercising the live sampling loop.
private struct ReadOnlyPriorityBackend: PriorityBackend {
    func setBackground(_ pid: Int32, _ on: Bool) -> Bool { false }
}
#endif

/// One line in the app list.
struct AppRow: Identifiable, Equatable {
    let id: String
    let name: String
    let bundleID: String?
    let path: String?
    let category: AppCategory
    /// Your explicit choice for this app, if any.
    let override: AppRule?
    /// What is in force right now (running apps only).
    let effective: AppRule?
    let demoted: Bool
    let cpu: Double
    // Details for Advanced mode
    var pid: Int32 = 0
    var processes = 0
    var demotedProcesses = 0
    /// Why this rule applies: "your choice", "mode: Gaming", "protected" or "default".
    var source = ""
    /// Share of GPU time (percent), measured only while the panel is open or a boost runs.
    var gpu = 0.0
}

/// An app using a lot of memory, for the memory guard.
struct MemoryHog: Identifiable, Equatable {
    var id: Int32 { pid }
    let pid: Int32
    let name: String
    let bundleID: String?
    let bytes: UInt64
}

/// Running totals for the session report card.
private struct SessionTally {
    let start: Date
    var appName = ""
    var mode = ""
    var peakMoved = 0
    var movedCoreSeconds = 0.0
    var gpuSeconds = 0.0
    var worstPressure = "normal"
    let swapAtStart: UInt64
}

/// One thing Coremium decided, in plain words ("Coding mode activated: Terminal became active. Chrome moved to Yield.").
struct Decision: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let headline: String
    let detail: String
}

/// How the last scan of installed apps went.
struct IndexInfo: Equatable {
    var appCount = 0
    var seconds = 0.0
    var reused = 0
    var read = 0
    var date: Date?
}

/// Watches what you're doing and moves apps between the performance and efficiency cores accordingly.
/// Nothing is ever quit; the app you're using is always left at full speed.
@MainActor
final class AppEngine: ObservableObject {
    private let isPreview: Bool
    let chip = ChipInfo.current()

    @Published var rules: RuleSet
    @Published var paused = false {
        didSet { if paused != oldValue { reschedule(); tick() } }
    }
    @Published private(set) var rows: [AppRow] = []
    @Published private(set) var installedRows: [AppRow] = []
    @Published private(set) var sessionActive = false
    /// A boost app is in front. The notch ignores the mouse then so it can never get in the way of a game.
    @Published private(set) var boostAppFocused = false
    @Published private(set) var activeProfile = ModeProfile.balanced
    @Published private(set) var boostAppName: String?
    @Published private(set) var demotedCount = 0
    @Published private(set) var cpuLoads: [Double] = []
    @Published private(set) var powerSource: PowerSource = .unknown
    @Published private(set) var lowPower = false
    @Published private(set) var thermal: ProcessInfo.ThermalState = .nominal
    @Published private(set) var launchAtLogin = false
    @Published private(set) var detectedSummary = ""
    @Published private(set) var installedApps: [InstalledApp] = []
    @Published private(set) var indexInfo = IndexInfo()
    @Published private(set) var isIndexing = false
    @Published private(set) var usage = UsageLedger()
    @Published private(set) var suggestions: [Suggestion] = []
    @Published private(set) var memory = MemoryInfo.current()
    /// Main-thread time of the last tick, and how long its measurement took off the main thread.
    @Published private(set) var tickMs = 0.0
    @Published private(set) var measureMs = 0.0
    /// Longest main-thread tick since launch (the profiler's budget check).
    private(set) var maxTickMs = 0.0
    /// Device-wide GPU utilization (%), and the renderer/tiler split for Advanced. Nil until first measured.
    /// The boosted app whose own rules are in force right now, and whether chips edit those rules or everyone's.
    @Published private(set) var boostBundleID: String?
    @Published var ruleScopeIsGame = false
    @Published private(set) var memoryHogs: [MemoryHog] = []
    @Published private(set) var latestReport: SessionReport?
    @Published private(set) var swapGrowth: UInt64 = 0
    private var tally: SessionTally?
    @Published private(set) var gpuDevicePercent: Int?
    @Published private(set) var gpuDetail = ""
    private var gpuByApp: [Int32: Double] = [:]
    /// Coremium's own CPU use (percent of one core): the cost of the optimiser itself.
    @Published private(set) var ownCPU = 0.0
    /// Newest first. Explains every change of profile or of which apps were moved aside.
    @Published private(set) var decisions: [Decision] = []
    @Published private(set) var adaptiveDecision = AdaptiveAutomaticDecision.observing
    private var adaptivePolicy = AdaptiveAutomaticPolicy()
    private var lastDecisionKey = ""
    @Published private(set) var sessionStartedAt: Date?

    /// The notch panel is open. Live stats use a faster cadence while someone is looking.
    var isPanelExpanded = false {
        didSet {
            guard oldValue != isPanelExpanded else { return }
            if isPanelExpanded { lastDiagnosticsAt = nil; lastFootprintsAt = nil }
            reschedule()
            panelAnimatingUntil = ProcessInfo.processInfo.systemUptime + NotchLayout.animationDuration + 0.05
            tick()
        }
    }
    /// Until then the panel is animating open or closed. A full tick (every process, CPU, GPU, rows) on the main
    /// thread inside that animation froze the panel mid-way, so ticks wait for it to finish.
    private var panelAnimatingUntil: TimeInterval = 0
    private var settledTickWork: DispatchWorkItem?

    /// Runs one tick when the panel animation ends. Returns false if no animation is running.
    private func deferTickWhileAnimating() -> Bool {
        let remaining = panelAnimatingUntil - ProcessInfo.processInfo.systemUptime
        guard remaining > 0 else { return false }
        if settledTickWork == nil {
            let work = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    self?.settledTickWork = nil
                    self?.tick()
                }
            }
            settledTickWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: work)
        }
        return true
    }

    /// The main window is open and visible.
    var isWindowVisible = false {
        didSet {
            guard oldValue != isWindowVisible else { return }
            if isWindowVisible { lastDiagnosticsAt = nil; lastFootprintsAt = nil }
            reschedule()
            tick()
        }
    }

    private var needsLiveStats: Bool { isPanelExpanded || isWindowVisible }

    private let controller: PriorityController
    private let measurer = EngineMeasurer()
    private var measuring = false
    private var tickPending = false
    private var installed: [InstalledApp] { installedApps }
    private var indexCache = AppIndexCache()
    private var watchers: [DispatchSourceFileSystemObject] = []
    private var rescanWork: DispatchWorkItem?
    private var categoryCache: [String: AppCategory] = [:]
    private var timer: Timer?
    private var lastBoostAt = Date.distantPast
    private var learner = WorkloadLearner()
    private var lastTickAt = Date()
    private var lastDiagnosticsAt: TimeInterval?
    private var lastFootprintsAt: TimeInterval?
    private var lastPersistAt = Date()
    private var lastSuggestionAt = Date.distantPast
    private var assertionID: IOPMAssertionID = 0
    private var assertionHeld = false
    private var cancellables = Set<AnyCancellable>()

    init(isPreview: Bool = false) {
        self.isPreview = isPreview
        rules = isPreview ? .defaults : SettingsStore.load()
        #if PREVIEW
        controller = PriorityController(backend: ReadOnlyPriorityBackend(), ledger: DemotionLedger(url: nil))
        #else
        controller = PriorityController(ledger: DemotionLedger(url: isPreview ? nil : SettingsStore.ledgerURL))
        #endif
        // Test/render instances must not restore the running app's ledger, persist settings, or observe other apps.
        if isPreview { return }
        // Undo anything a previous run left demoted (crash, force quit, power loss).
        controller.restoreAll()
        launchAtLogin = LoginItem.isEnabled
        usage = UsageLedger.load(from: SettingsStore.usageURL)
        learner = WorkloadLearner.load(from: SettingsStore.learningURL)
        refreshSystemState()

        $rules.dropFirst().debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { SettingsStore.save($0) }.store(in: &cancellables)
        // @Published emits before the value is stored, so re-evaluate on the next run-loop turn.
        $rules.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshInstalledRows()
                self?.tick()
            }
        }.store(in: &cancellables)

        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didWakeNotification] {
            workspace.publisher(for: name).sink { [weak self] _ in self?.tick() }.store(in: &cancellables)
        }
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in self?.refreshSystemState() }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in self?.refreshSystemState() }.store(in: &cancellables)

        // Show the last known list instantly, then refresh it in the background and keep it live.
        indexCache = AppIndexCache.load(from: SettingsStore.indexURL)
        installedApps = indexCache.apps
        for app in installedApps { categoryCache[app.bundleID] = app.category }
        refreshInstalledRows()
        reschedule()
        tick()
        rescan()
        startWatchingAppFolders()
    }

    #if PREVIEW
    /// Sample content for offscreen rendering only.
    func injectPreview(rows: [AppRow], installed: [InstalledApp], usage: UsageLedger, suggestions: [Suggestion],
                       session: Bool, boostName: String?, demoted: Int, loads: [Double]) {
        self.rows = rows
        self.installedApps = installed
        self.usage = usage
        self.suggestions = suggestions
        self.sessionActive = session
        self.boostAppName = boostName
        self.demotedCount = demoted
        self.cpuLoads = loads
        self.activeProfile = session ? .gaming : .balanced
        self.indexInfo = IndexInfo(appCount: installed.count, seconds: 0.05, reused: installed.count, read: 0, date: Date())
        refreshInstalledRows()
    }
    #endif

    // MARK: - User actions

    func setOverride(_ bundleID: String, _ rule: AppRule?) {
        if let rule { rules.rules[bundleID] = rule } else { rules.rules.removeValue(forKey: bundleID) }
    }

    /// Choosing the rule that is already set removes the override (back to "follow the mode").
    func toggleOverride(_ bundleID: String?, _ rule: AppRule) {
        guard let bundleID else { return }
        if ruleScopeIsGame, let game = boostBundleID {
            var map = rules.gameRules[game] ?? [:]
            map[bundleID] = map[bundleID] == rule ? nil : rule
            rules.gameRules[game] = map.isEmpty ? nil : map
            return
        }
        setOverride(bundleID, rules.rules[bundleID] == rule ? nil : rule)
    }

    /// The boost app in front, or a boost app busy in the background, by your general rules.
    private func boostBundle(apps: [AppProcess], front: Int32?, cpu: [Int32: Double], categories: [String: AppCategory]) -> String? {
        let profile = RuleEvaluator.activeProfile(apps: apps, frontmostPid: front, rules: rules, cpuByAppPid: cpu, categories: categories)
        func isBoost(_ app: AppProcess) -> Bool {
            rules.effectiveRule(bundleID: app.bundleID, category: app.bundleID.flatMap { categories[$0] } ?? .other, profile: profile) == .boost
        }
        if let app = apps.first(where: { $0.pid == front }), isBoost(app) { return app.bundleID }
        return apps.first { isBoost($0) && (cpu[$0.pid] ?? 0) > rules.boostBusyPercent }?.bundleID
    }

    /// Puts every app Coremium slowed back to full speed right now.
    func restoreAllNow() {
        controller.restoreAll()
        demotedCount = 0
        tick()
    }

    func resetSettings() {
        rules = .defaults
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        LoginItem.setEnabled(enabled)
        launchAtLogin = LoginItem.isEnabled
    }

    /// Restores every app to full speed. Called on quit and on SIGTERM/SIGINT.
    func shutdown() {
        timer?.invalidate()
        timer = nil
        controller.restoreAll()
        releaseAssertion()
        persistHistory()
    }

    private func persistHistory() {
        usage.save(to: SettingsStore.usageURL)
        learner.save(to: SettingsStore.learningURL)
        lastPersistAt = Date()
    }

    // MARK: - Evidence

    /// Seconds the current boost session has been running.
    var sessionSeconds: Double { sessionStartedAt.map { Date().timeIntervalSince($0) } ?? 0 }
    var ledgerCount: Int { controller.demotedPids.count }

    var today: DayStats { usage.days[UsageLedger.dayKey(Date())] ?? DayStats(day: UsageLedger.dayKey(Date())) }

    /// A real before/after measurement on this Mac. Starts busy "competitor" processes (copies of this app in a harmless
    /// busy-loop mode that stop by themselves), measures a game-like workload with the competitors at normal priority and
    /// then moved to the efficiency cores, alternating over several rounds, and records an honest verdict.
    // MARK: - Learning

    func refreshSuggestions() {
        lastSuggestionAt = Date()
        let rules = self.rules
        let categories = categoryCache
        let found = learner.suggestions { bundleID, kind in
            if rules.rules[bundleID] != nil { return true }
            let category = categories[bundleID] ?? .other
            switch kind {
            case .yield: return [.creative, .developer, .browser, .communication, .ai, .game, .localAI].contains(category)
            case .boost: return [.game, .creative, .developer, .localAI].contains(category)
            }
        }
        if found != suggestions { suggestions = found }
    }

    func accept(_ suggestion: Suggestion) {
        setOverride(suggestion.bundleID, suggestion.kind == .boost ? .boost : .auto)
        refreshSuggestions()
    }

    func dismiss(_ suggestion: Suggestion) {
        learner.dismiss(suggestion)
        learner.save(to: SettingsStore.learningURL)
        refreshSuggestions()
    }

    // MARK: - Loop

    private func reschedule() {
        guard !isPreview else { return }
        timer?.invalidate()
        // App launches, quits and switches wake the engine on their own (see the workspace observers), so the timer
        // only needs to catch background CPU changes: slow when idle, and coalesced by the system.
        guard let interval = EngineSamplingPlan.interval(paused: paused, panelVisible: needsLiveStats,
            sessionActive: sessionActive, lowPowerMode: lowPower) else {
            timer = nil
            return
        }
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        newTimer.tolerance = interval * 0.25
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func refreshSystemState() {
        let source = currentPowerSource()
        let power = ProcessInfo.processInfo.isLowPowerModeEnabled
        let state = ProcessInfo.processInfo.thermalState
        if source != powerSource { powerSource = source }
        if state != thermal { thermal = state }
        if power != lowPower { lowPower = power; reschedule() }
    }

    private func category(for app: NSRunningApplication) -> AppCategory {
        guard let id = app.bundleIdentifier else { return .other }
        if let cached = categoryCache[id] { return cached }
        var declared: String?
        if let url = app.bundleURL, let bundle = Bundle(url: url) {
            declared = bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String
        }
        let result = AppClassifier.classify(bundleID: id, lsCategory: declared, path: app.bundleURL?.path)
        categoryCache[id] = result
        return result
    }

    /// One evaluation: decide what needs measuring here, measure off the main thread, then decide and publish here.
    func tick() {
        guard !isPreview, !deferTickWhileAnimating() else { return }
        // One measurement at a time; anything that asks meanwhile gets one fresh tick right after it.
        if measuring { tickPending = true; return }
        let now = Date()
        let seconds = min(now.timeIntervalSince(lastTickAt), 60)
        lastTickAt = now
        // Pause restores once, then sleeps when the panel is closed. Workspace events stay cheap too.
        if paused && !needsLiveStats {
            if !controller.demotedPids.isEmpty { controller.restoreAll() }
            endSessionIfNeeded()
            adaptivePolicy = AdaptiveAutomaticPolicy()
            if adaptiveDecision != .observing { adaptiveDecision = .observing }
            if demotedCount != 0 { demotedCount = 0 }
            if boostAppName != nil { boostAppName = nil }
            if boostAppFocused { boostAppFocused = false }
            if activeProfile != .balanced { activeProfile = .balanced }
            reschedule()
            return
        }
        refreshSystemState()
        let uptime = ProcessInfo.processInfo.systemUptime
        let sampling = EngineSamplingPlan(paused: paused, panelVisible: needsLiveStats,
            sessionActive: sessionActive, lowPowerMode: lowPower, uptime: uptime,
            lastDiagnosticsAt: lastDiagnosticsAt, lastFootprintsAt: lastFootprintsAt)
        if sampling.samplesDiagnostics { lastDiagnosticsAt = uptime }
        if sampling.samplesFootprints { lastFootprintsAt = uptime }

        let ownPid = ProcessInfo.processInfo.processIdentifier
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != ownPid
        }
        let apps = running.map { AppProcess(pid: $0.processIdentifier, bundleID: $0.bundleIdentifier) }
        var categories: [String: AppCategory] = [:]
        for app in running { if let id = app.bundleIdentifier { categories[id] = category(for: app) } }
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier

        // Idle and panel closed: only apps that could start or hold a boost need measuring, not every browser tab.
        let lightweight = !needsLiveStats && !sessionActive && !paused
        let watched: Set<AppCategory> = [.game, .creative, .localAI, .developer]
        let expand = Set(apps.filter { app in
            !lightweight || app.pid == front || rules.rules[app.bundleID ?? ""] == .boost
                || (app.bundleID.flatMap { categories[$0] }.map(watched.contains) ?? false)
        }.map(\.pid))

        let context = TickContext(now: now, seconds: seconds, running: running, apps: apps, categories: categories,
                                  front: front, ownPid: ownPid)
        measuring = true
        measurer.measure(MeasureRequest(apps: apps, ownPid: ownPid, expand: expand, samplesCPU: sampling.samplesCPU,
                                        samplesDiagnostics: sampling.samplesDiagnostics,
                                        samplesFootprints: sampling.samplesFootprints)) { [weak self] m in
            self?.finishTick(m, context)
        }
    }

    /// A main-thread tick over 50 ms can be felt, so it is logged locally with its measurement time.
    private func finishTiming(startedAt start: UInt64, measureMs measured: Double) {
        let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
        maxTickMs = max(maxTickMs, ms)
        // Only the open panel shows these; don't re-render a closed one every tick.
        if needsLiveStats {
            tickMs = ms
            measureMs = measured
        }
        if ms > 50 || measured > 1000 {
            SettingsStore.logDiagnostic(String(format: "slow tick: main %.1f ms, measure %.1f ms, %d apps, panel %@, session %@",
                                               ms, measured, rows.count, needsLiveStats ? "open" : "closed",
                                               sessionActive ? "on" : "off"))
        }
    }

    /// Plain text for bug reports: versions, current state and the local slow-tick log. Copied only when asked.
    func diagnosticsReport() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let log = (try? String(contentsOf: SettingsStore.diagnosticsURL, encoding: .utf8)) ?? ""
        let recent = log.split(separator: "\n").suffix(40).joined(separator: "\n")
        return """
        Coremium \(version) on macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
        \(chip.brand): \(chip.performanceCores)P + \(chip.efficiencyCores)E, \(chip.memoryBytes / 1_073_741_824) GB
        mode \(rules.mode.rawValue) (\(activeProfile.mode.rawValue)), paused \(paused), session \(sessionActive), \
        \(rows.count) apps, \(demotedCount) processes moved
        tick \(String(format: "%.1f", tickMs)) ms (max \(String(format: "%.1f", maxTickMs)) ms), \
        measuring \(String(format: "%.0f", measureMs)) ms, Coremium CPU \(ownCPU)%
        Recent slow ticks:
        \(recent.isEmpty ? "none" : recent)
        """
    }

    private struct TickContext {
        let now: Date
        let seconds: TimeInterval
        let running: [NSRunningApplication]
        let apps: [AppProcess]
        let categories: [String: AppCategory]
        let front: Int32?
        let ownPid: Int32
    }

    private func finishTick(_ m: Measurement, _ context: TickContext) {
        // Publishing re-renders the panel, so results that land mid-animation wait for it to finish.
        let remaining = panelAnimatingUntil - ProcessInfo.processInfo.systemUptime
        if remaining > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [weak self] in
                MainActor.assumeIsolated { self?.finishTick(m, context) }
            }
            return
        }
        measuring = false
        defer {
            if tickPending { tickPending = false; tick() }
        }
        // Paused while measuring: the pending tick restores; never apply a measurement taken before the pause.
        guard !(paused && !needsLiveStats) else { tickPending = true; return }
        apply(m, context)
    }

    private func apply(_ m: Measurement, _ context: TickContext) {
        let applyStart = DispatchTime.now().uptimeNanoseconds
        let signpost = EngineMeasurer.signposter.beginInterval("apply")
        defer { EngineMeasurer.signposter.endInterval("apply", signpost) }
        let now = context.now, seconds = context.seconds, running = context.running, apps = context.apps
        let categories = context.categories, front = context.front, ownPid = context.ownPid
        if let loads = m.loads, loads != cpuLoads { cpuLoads = loads }
        if let reading = m.memory, reading != memory { memory = reading }
        let snapshot = m.snapshot, tree = m.tree, perPid = m.perPid

        let ownNow = ((perPid[ownPid] ?? 0) * 10).rounded() / 10
        if abs(ownNow - ownCPU) >= 0.5 { ownCPU = ownNow }
        var cpu: [Int32: Double] = [:]
        for app in apps { cpu[app.pid] = (tree[app.pid] ?? []).reduce(0) { $0 + (perPid[$1] ?? 0) } }

        // Advisory diagnostics share a slower budget; the adaptive policy needs CPU only.
        let appPids = Set(apps.map(\.pid))
        var gpu = gpuByApp.filter { appPids.contains($0.key) }
        if let (reading, perApp) = m.gpu {
            gpu.merge(perApp) { $1 }
            if gpuDevicePercent != reading.devicePercent { gpuDevicePercent = reading.devicePercent }
            let detail = "renderer \(reading.rendererPercent ?? 0)% · tiler \(reading.tilerPercent ?? 0)%"
            if gpuDetail != detail { gpuDetail = detail }
        } else if m.gpuReset {
            gpu = [:]
        }
        gpuByApp = gpu

        if paused {
            adaptivePolicy = AdaptiveAutomaticPolicy()
            if adaptiveDecision != .observing { adaptiveDecision = .observing }
            controller.restoreAll(snapshot: snapshot)
            endSessionIfNeeded()
            demotedCount = 0
            boostAppName = nil
            boostAppFocused = false
            activeProfile = .balanced
            publishRows(running: running, snapshot: snapshot, cpu: cpu, categories: categories, profile: .balanced, front: front, trees: tree)
            finishTiming(startedAt: applyStart, measureMs: m.milliseconds)
            return
        }

        // Per-game rules: while a boost app is in charge, its own rules win over your general ones.
        let game = boostBundle(apps: apps, front: front, cpu: cpu, categories: categories)
        if boostBundleID != game { boostBundleID = game; if game == nil { ruleScopeIsGame = false } }
        let effRules = rules.merged(forBoost: game)
        let profile = RuleEvaluator.activeProfile(apps: apps, frontmostPid: front, rules: effRules,
                                                  cpuByAppPid: cpu, categories: categories)
        let boostNow = RuleEvaluator.boostTriggered(apps: apps, frontmostPid: front, rules: effRules,
                                                    cpuByAppPid: cpu, categories: categories)
        let wasActive = sessionActive
        if boostNow {
            lastBoostAt = now
            if !sessionActive { startSession() }
        } else if sessionActive, now.timeIntervalSince(lastBoostAt) > rules.graceSeconds {
            endSessionIfNeeded()
        }

        var input = EvaluationInput(snapshot: snapshot, apps: apps, frontmostPid: front, rules: effRules,
                                    sessionActive: sessionActive, cpuByAppPid: cpu, categories: categories,
                                    ownUid: getuid(), ownPid: ownPid, onBattery: powerSource == .battery)
        if rules.mode == .automatic, rules.adaptiveAutomatic {
            let indices = chip.performanceCPUs.isEmpty ? Array(cpuLoads.indices) : chip.performanceCPUs
            let values = indices.compactMap { cpuLoads.indices.contains($0) ? cpuLoads[$0] : nil }
            let load = !values.isEmpty && values.count == indices.count ? values.reduce(0, +) / Double(values.count) : nil
            let decision = adaptivePolicy.evaluate(input, performanceLoad: load, uptime: ProcessInfo.processInfo.systemUptime)
            if decision != adaptiveDecision { adaptiveDecision = decision }
            input.adaptiveDemotionAppPids = decision.appPids
        } else {
            adaptivePolicy = AdaptiveAutomaticPolicy()
            if adaptiveDecision != .observing { adaptiveDecision = .observing }
        }
        controller.apply(target: RuleEvaluator.pidsToDemote(input), snapshot: snapshot)

        if activeProfile != profile { activeProfile = profile }
        let movedCount = controller.demotedPids.count
        if demotedCount != movedCount { demotedCount = movedCount }
        var boostName: String?
        var frontIsBoost = false
        for (index, app) in apps.enumerated() {
            let cat = app.bundleID.flatMap { categories[$0] } ?? .other
            guard effRules.effectiveRule(bundleID: app.bundleID, category: cat, profile: profile) == .boost else { continue }
            if app.pid == front { frontIsBoost = true; boostName = running[index].localizedName }
            else if boostName == nil, (cpu[app.pid] ?? 0) > rules.boostBusyPercent { boostName = running[index].localizedName }
        }
        if boostAppName != boostName { boostAppName = boostName }
        if boostAppFocused != frontIsBoost { boostAppFocused = frontIsBoost }

        // Evidence: real measurements only. Work that ran on the efficiency cores because Coremium moved it there.
        let movedPercent = controller.demotedPids.reduce(0.0) { $0 + (perPid[$1] ?? 0) }
        let backgroundGPU = apps.filter { $0.pid != front }.reduce(0) { $0 + (gpu[$1.pid] ?? 0) } / 100 * seconds
        if sessionActive, var t = tally {
            if t.appName.isEmpty, let boostName { t.appName = boostName }
            t.mode = profile.mode.label
            t.peakMoved = max(t.peakMoved, demotedCount)
            t.movedCoreSeconds += movedPercent / 100 * seconds
            t.gpuSeconds += backgroundGPU
            let order = ["normal", "warning", "critical"]
            let now = memory.pressure.rawValue
            if (order.firstIndex(of: now) ?? 0) > (order.firstIndex(of: t.worstPressure) ?? 0) { t.worstPressure = now }
            tally = t
            let growth = memory.swapUsedBytes > t.swapAtStart ? memory.swapUsedBytes - t.swapAtStart : 0
            if swapGrowth != growth { swapGrowth = growth }
        }
        // Detailed per-process memory is UI-only and slower than the rule loop.
        if let footprints = m.footprints {
            var hogs: [MemoryHog] = []
            for (index, app) in apps.enumerated() {
                let bytes = footprints[app.pid] ?? 0
                if bytes > 300_000_000 {
                    hogs.append(MemoryHog(pid: app.pid, name: running[index].localizedName ?? app.bundleID ?? "App", bundleID: app.bundleID, bytes: bytes))
                }
            }
            let top = Array(hogs.sorted { $0.bytes > $1.bytes }.prefix(6))
            if top.map(\.bytes).map { $0 / 50_000_000 } != memoryHogs.map(\.bytes).map({ $0 / 50_000_000 }) || top.map(\.pid) != memoryHogs.map(\.pid) {
                memoryHogs = top
            }
        }
        if sessionActive || demotedCount > 0 {
            usage.record(at: now, seconds: seconds, sessionActive: sessionActive, mode: profile.mode,
                         movedCoreSeconds: movedPercent / 100 * seconds, movedProcesses: demotedCount,
                         hot: thermal == .serious || thermal == .critical, sessionStarted: !wasActive && sessionActive,
                         backgroundGPUSeconds: backgroundGPU)
        }

        // Learning: what each app does when it is in front and when it is in the background during a session.
        for (index, app) in apps.enumerated() {
            guard sessionActive || app.pid == front else { continue }
            guard let id = app.bundleID else { continue }
            learner.ingest(bundleID: id, name: running[index].localizedName ?? id, isFront: app.pid == front,
                           sessionActive: sessionActive, cores: (cpu[app.pid] ?? 0) / 100)
        }
        if now.timeIntervalSince(lastSuggestionAt) > 30 { refreshSuggestions() }
        if now.timeIntervalSince(lastPersistAt) > 60 { persistHistory() }

        publishRows(running: running, snapshot: snapshot, cpu: cpu, categories: categories, profile: profile, front: front, trees: tree,
                    rules: effRules)
        finishTiming(startedAt: applyStart, measureMs: m.milliseconds)
        if wasActive != sessionActive { reschedule() }
    }

    private func publishRows(running: [NSRunningApplication], snapshot: ProcessSnapshot, cpu: [Int32: Double],
                             categories: [String: AppCategory], profile: ModeProfile, front: Int32?,
                             trees: [Int32: [Int32]], rules: RuleSet? = nil) {
        let rules = rules ?? self.rules
        let demoted = controller.demotedPids
        var list: [AppRow] = running.map { app in
            let id = app.bundleIdentifier
            let cat = id.flatMap { categories[$0] } ?? .other
            let modeRule = rules.effectiveRule(bundleID: id, category: cat, profile: profile)
            let adaptivelyMoved = adaptiveDecision.appPids.contains(app.processIdentifier)
            let effective = adaptivelyMoved && modeRule == .normal ? AppRule.auto : modeRule
            let pids = trees[app.processIdentifier] ?? []
            var source = "default"
            if let id, let game = boostBundleID, self.rules.gameRules[game]?[id] != nil { source = "for \(boostAppName ?? "this game")" }
            else if let id, rules.rules[id] != nil { source = "your choice" }
            else if let id, rules.protectedBundleIDs.contains(id) { source = "protected" }
            else if adaptivelyMoved { source = "adaptive CPU pressure" }
            else if effective != .normal { source = "\(profile.mode.label) mode" }
            return AppRow(id: id ?? "pid:\(app.processIdentifier)", name: app.localizedName ?? id ?? "Unknown",
                          bundleID: id, path: app.bundleURL?.path, category: cat,
                          override: id.flatMap { id in
                              if ruleScopeIsGame, let game = boostBundleID { return self.rules.gameRules[game]?[id] }
                              return self.rules.rules[id]
                          },
                          effective: effective,
                          demoted: demoted.contains(app.processIdentifier), cpu: (cpu[app.processIdentifier] ?? 0).rounded(),
                          pid: app.processIdentifier, processes: pids.count,
                          demotedProcesses: pids.filter { demoted.contains($0) }.count, source: source,
                          gpu: (gpuByApp[app.processIdentifier] ?? 0).rounded())
        }
        // Stable order (boost apps first, then A-Z) so rows never jump around under the cursor.
        func rank(_ rule: AppRule?) -> Int { rule == .boost ? 0 : 1 }
        list.sort { (rank($0.effective), $0.name.lowercased()) < (rank($1.effective), $1.name.lowercased()) }
        if list != rows { rows = list }
        logDecision(list, profile: profile, front: front)
    }

    /// Records why the set of moved-aside apps changed, so Automatic never feels like a black box.
    private func logDecision(_ list: [AppRow], profile: ModeProfile, front: Int32?) {
        let moved = list.filter { $0.demoted }.sorted { $0.name.lowercased() < $1.name.lowercased() }
        let key = paused ? "paused"
            : "\(profile.mode.rawValue)|\(sessionActive)|" + moved.map { "\($0.id):\($0.effective?.rawValue ?? "")" }.joined(separator: ",")
              + "|" + list.filter { $0.pid != front && $0.gpu >= 10 }.map(\.id).sorted().joined(separator: ",")
              + "|\(adaptiveDecision.phase.rawValue)|\(adaptiveDecision.reason)"
        guard key != lastDecisionKey else { return }
        lastDecisionKey = key

        let headline: String
        var sentences: [String] = []
        if paused {
            headline = "Paused"
            sentences = ["macOS default scheduling restored. Nothing is being moved."]
        } else if sessionActive || !moved.isEmpty {
            headline = rules.mode == .automatic ? "\(profile.mode.label) mode activated" : "\(profile.mode.label) mode"
            if let frontBoost = list.first(where: { $0.pid == front && $0.effective == .boost }) {
                sentences.append("\(frontBoost.name) became active.")
            } else if let busy = boostAppName {
                sentences.append("\(busy) is busy in the background.")
            }
            if !moved.isEmpty { sentences.append(Self.movedSentence(moved)) }
            if rules.mode == .automatic, rules.adaptiveAutomatic { sentences.append(adaptiveDecision.reason) }
            // GPU has no public priority control on macOS, so Coremium names who is using it instead of guessing.
            let gpuHeavy = list.filter { $0.pid != front && $0.gpu >= 10 }.sorted { $0.gpu > $1.gpu }.prefix(2)
            for app in gpuHeavy { sentences.append("\(app.name) is using \(Int(app.gpu))% of the GPU in the background.") }
        } else {
            headline = "Standing by"
            sentences = [rules.mode == .automatic
                ? "No Boost is running, so nothing is being moved. Automatic switches profile when a game, creative app, dev tool or local AI model is in front."
                : "No Boost is running, so nothing is being moved. Your app rules are ready."]
        }
        decisions.insert(Decision(date: Date(), headline: headline, detail: sentences.joined(separator: " ")), at: 0)
        if decisions.count > 30 { decisions.removeLast(decisions.count - 30) }
    }

    /// "Chrome and Discord moved to Yield and Spotify to Eco."
    private static func movedSentence(_ moved: [AppRow]) -> String {
        func names(_ rows: [AppRow]) -> String {
            let shown = rows.prefix(3).map(\.name)
            let text = shown.count > 1 ? shown.dropLast().joined(separator: ", ") + " and " + shown.last! : shown.joined()
            return rows.count > 3 ? "\(text) +\(rows.count - 3) more" : text
        }
        var parts: [String] = []
        for (rule, label) in [(AppRule.auto, "Yield"), (.efficiency, "Eco")] {
            let group = moved.filter { $0.effective == rule }
            if !group.isEmpty { parts.append(parts.isEmpty ? "\(names(group)) moved to \(label)" : "\(names(group)) to \(label)") }
        }
        let other = moved.filter { $0.effective != .auto && $0.effective != .efficiency }
        if !other.isEmpty { parts.append("\(names(other)) moved aside (heavy)") }
        return parts.joined(separator: " and ") + "."
    }

    // MARK: - Sessions

    private func startSession() {
        sessionActive = true
        sessionStartedAt = Date()
        memory = MemoryInfo.current()
        tally = SessionTally(start: Date(), swapAtStart: memory.swapUsedBytes)
        swapGrowth = 0
        guard rules.keepDisplayAwakeDuringBoost, !assertionHeld else { return }
        let result = IOPMAssertionCreateWithName("PreventUserIdleDisplaySleep" as CFString,
                                                 IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                 "Coremium boost session" as CFString, &assertionID)
        assertionHeld = result == kIOReturnSuccess
    }

    private func endSessionIfNeeded() {
        guard sessionActive else { return }
        sessionActive = false
        sessionStartedAt = nil
        if let t = tally, Date().timeIntervalSince(t.start) >= 60 {
            let report = SessionReport(start: t.start, end: Date(), appName: t.appName.isEmpty ? "Boost" : t.appName, mode: t.mode,
                                       peakMovedProcesses: t.peakMoved, movedCoreSeconds: t.movedCoreSeconds,
                                       backgroundGPUSeconds: t.gpuSeconds, worstPressure: t.worstPressure,
                                       swapGrowthBytes: swapGrowth)
            usage.add(report)
            latestReport = report
        }
        tally = nil
        swapGrowth = 0
        releaseAssertion()
    }

    private func releaseAssertion() {
        guard assertionHeld else { return }
        IOPMAssertionRelease(assertionID)
        assertionHeld = false
    }

    // MARK: - Installed apps

    /// Re-reads the app folders. Apps whose Info.plist hasn't changed come straight from the cache.
    func rescan() {
        guard !isIndexing else { return }
        isIndexing = true
        let cache = indexCache
        Task { @MainActor [weak self] in
            // Reading Info.plist files happens off the main thread, in parallel; only the result comes back here.
            let result = await Task.detached(priority: .utility) {
                InstalledAppScanner.scanDetailed(roots: InstalledAppScanner.defaultRoots, cache: cache)
            }.value
            guard let self else { return }
            isIndexing = false
            indexCache = result.cache
            result.cache.save(to: SettingsStore.indexURL)
            installedApps = result.report.apps
            for app in result.report.apps { categoryCache[app.bundleID] = app.category }
            indexInfo = IndexInfo(appCount: result.report.apps.count, seconds: result.report.seconds,
                                  reused: result.report.reused, read: result.report.read, date: Date())
            refreshInstalledRows()
        }
    }

    /// Watches the app folders so installs and removals show up within a couple of seconds, without a relaunch.
    private func startWatchingAppFolders() {
        for url in InstalledAppScanner.watchedFolders {
            let descriptor = open(url.path, O_EVTONLY)
            guard descriptor >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
                                                                   eventMask: [.write, .delete, .rename], queue: .main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.scheduleRescan() }
            }
            source.setCancelHandler { close(descriptor) }
            source.resume()
            watchers.append(source)
        }
    }

    private func scheduleRescan() {
        rescanWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.rescan() }
        }
        rescanWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    /// Installed apps as list rows. By default only the kinds of apps modes care about; `includeAll` adds the rest.
    func makeInstalledRows(includeAll: Bool) -> [AppRow] {
        let interesting: [AppCategory] = [.game, .creative, .developer, .ai, .browser, .communication, .media, .productivity]
        let rank = Dictionary(uniqueKeysWithValues: interesting.enumerated().map { ($1, $0) })
        func order(_ app: InstalledApp) -> Int { rank[app.category] ?? 99 }
        return installed
            .filter { !rules.protectedBundleIDs.contains($0.bundleID) && (includeAll || rank[$0.category] != nil) }
            .sorted { (order($0), $0.name.lowercased()) < (order($1), $1.name.lowercased()) }
            .map { app in
                AppRow(id: app.bundleID, name: app.name, bundleID: app.bundleID, path: app.path, category: app.category,
                       override: rules.rules[app.bundleID], effective: nil, demoted: false, cpu: 0)
            }
    }

    private func refreshInstalledRows() {
        let list = makeInstalledRows(includeAll: false)
        if list != installedRows { installedRows = list }

        func count(_ category: AppCategory) -> Int { installed.filter { $0.category == category }.count }
        var parts: [String] = []
        if count(.creative) > 0 { parts.append("\(count(.creative)) creative") }
        if count(.game) > 0 { parts.append("\(count(.game)) games") }
        if count(.developer) > 0 { parts.append("\(count(.developer)) dev") }
        if count(.localAI) > 0 { parts.append("\(count(.localAI)) AI") }
        let summary = parts.isEmpty ? "" : "Found " + parts.joined(separator: " · ")
        if summary != detectedSummary { detectedSummary = summary }
    }

    // MARK: - Display helpers

    var warnings: [String] {
        var list: [String] = []
        if powerSource == .battery { list.append("On battery: plug in for full speed") }
        if lowPower { list.append("Low Power Mode is on") }
        if thermal == .serious || thermal == .critical { list.append("Mac is hot: macOS is limiting performance") }
        if sessionActive, swapGrowth > 512_000_000 {
            list.append("Swap grew \(ByteCountFormatter.string(fromByteCount: Int64(swapGrowth), countStyle: .memory)) this boost: hide or quit a memory-heavy app (System tab)")
        }
        return list
    }

    var statusLine: String {
        if paused { return "Paused: macOS default scheduling restored." }
        if sessionActive {
            let who = boostAppName.map { "Protecting \($0)" } ?? "Protecting your app"
            return demotedCount > 0 ? "\(who) · \(demotedCount) background processes at lower priority"
                : "\(who). Watching CPU load; no background priority changes right now."
        }
        if demotedCount > 0 { return "\(demotedCount) background processes at lower priority" }
        return rules.mode == .automatic ? "Ready. No apps are being moved right now."
            : "\(rules.mode.label) mode. Waiting for a boost app."
    }

    /// The latest decision, for the line under the status: why things are the way they are.
    var latestDecision: Decision? { decisions.first }

    /// A one-word outcome for how much an app is using, to sit beside the technical "0.8 cores".
    static func loadWord(_ percent: Double, moved: Bool) -> String {
        if moved { return "Background" }
        switch percent {
        case ..<40: return "Light"
        case ..<120: return "Moderate"
        default: return "Heavy"
        }
    }
}
