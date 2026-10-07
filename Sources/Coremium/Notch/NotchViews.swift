import AppKit
import CoremiumCore
import SwiftUI

/// Where the notch (or, on Macs without one, the menu-bar centre) is on the chosen screen.
struct NotchGeometry: Equatable {
    var hasNotch: Bool
    var notchWidth: CGFloat
    var notchHeight: CGFloat

    static let earWidth: CGFloat = 34
    var collapsedWidth: CGFloat { hasNotch ? notchWidth + 2 * Self.earWidth : 196 }

    @MainActor static func current() -> (NSScreen, NotchGeometry) {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.screens.first ?? NSScreen.main!
        return (screen, compute(for: screen))
    }

    @MainActor static func compute(for screen: NSScreen) -> NotchGeometry {
        let inset = screen.safeAreaInsets.top
        if inset > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            return NotchGeometry(hasNotch: true, notchWidth: screen.frame.width - left.width - right.width, notchHeight: inset)
        }
        return NotchGeometry(hasNotch: false, notchWidth: 0, notchHeight: max(NSStatusBar.system.thickness, 24))
    }
}

enum NotchLayout {
    static let animationDuration = 0.25
    static let toastExtra = CGSize(width: 300, height: 34)
    static let expandedSize = CGSize(width: 780, height: 488)
}

enum ListTab: String, CaseIterable {
    case running = "Running"
    case installed = "Installed"
}

enum NotchTab: String, CaseIterable, Identifiable {
    case apps, insights, storage, system, simulate, guide, settings

    var id: String { rawValue }
    var shortcutNumber: Int { Self.allCases.firstIndex(of: self)! + 1 }

    func next(offset: Int) -> NotchTab {
        let tabs = Self.allCases
        let index = tabs.firstIndex(of: self)!
        return tabs[((index + offset) % tabs.count + tabs.count) % tabs.count]
    }

    var title: String {
        switch self {
        case .apps: return "Apps"
        case .insights: return "Insights"
        case .storage: return "Storage"
        case .system: return "System"
        case .simulate: return "Simulate"
        case .guide: return "Guide"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .apps: return "square.grid.2x2.fill"
        case .insights: return "chart.bar.xaxis"
        case .storage: return "internaldrive.fill"
        case .system: return "memorychip.fill"
        case .simulate: return "waveform.path.ecg"
        case .guide: return "book.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

@MainActor
final class NotchUIState: ObservableObject {
    private let defaults: UserDefaults

    @Published var expanded = false
    @Published var geometry: NotchGeometry
    @Published var tab: NotchTab = .apps
    @Published var listTab: ListTab = .running
    @Published var showingOnboarding = false
    @Published var showingTour = false
    /// Show the numbers: per-core load, memory, process counts, timers.
    @Published var advanced: Bool {
        didSet { defaults.set(advanced, forKey: "advancedMode") }
    }
    /// Show the mode icon and status dot beside the notch. Off = the notch looks untouched ("hidden in plain sight").
    /// A decision Coremium just made, shown briefly as a pill under the notch.
    @Published var toast: Decision?
    /// Let decisions drop out of the notch for a moment while the panel is closed.
    @Published var decisionToasts: Bool {
        didSet { defaults.set(decisionToasts, forKey: "decisionToasts") }
    }
    @Published var showIndicators: Bool {
        didSet { defaults.set(showIndicators, forKey: "showIndicators") }
    }
    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: "onboardingCompleted") }
    }

    init(geometry: NotchGeometry, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.geometry = geometry
        advanced = defaults.bool(forKey: "advancedMode")
        showIndicators = defaults.object(forKey: "showIndicators") as? Bool ?? true
        decisionToasts = defaults.object(forKey: "decisionToasts") as? Bool ?? true
        onboardingCompleted = defaults.bool(forKey: "onboardingCompleted")
    }

    /// Closes the panel (wired to the controller).
    var onHide: (() -> Void)?
    /// Mouse interaction can give this nonactivating panel keyboard focus without stealing focus on hover.
    var onFocusTabs: (() -> Void)?

    func selectTab(_ tab: NotchTab) {
        if self.tab != tab { self.tab = tab }
        onFocusTabs?()
    }

    func finishOnboarding(tab: NotchTab = .apps) {
        onboardingCompleted = true
        showingOnboarding = false
        showingTour = false
        self.tab = tab
    }
}

/// A black shape with square top corners (it hangs from the screen edge) and rounded bottom corners.
struct NotchShape: Shape {
    var bottomRadius: CGFloat

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = min(bottomRadius, rect.height / 2, rect.width / 2)
        let k: CGFloat = 0.5523
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                      control1: CGPoint(x: rect.maxX, y: rect.maxY - r + k * r),
                      control2: CGPoint(x: rect.maxX - r + k * r, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                      control1: CGPoint(x: rect.minX + r - k * r, y: rect.maxY),
                      control2: CGPoint(x: rect.minX, y: rect.maxY - r + k * r))
        path.closeSubpath()
        return path
    }
}

extension PerformanceMode {
    var tint: Color { Theme.accent }
}

extension AppRule {
    var tint: Color {
        switch self {
        case .boost: return Theme.boost
        case .normal: return Color(white: 0.62)
        case .auto: return Theme.yield
        case .efficiency: return Theme.eco
        }
    }

    var shortLabel: String {
        switch self {
        case .boost: return "Boost"
        case .normal: return "Normal"
        case .auto: return "Yield"
        case .efficiency: return "Eco"
        }
    }
}

/// "0.6 cores" / "2.3 cores": CPU use in units people can picture (one core fully busy = 1.0).
func coresText(_ percent: Double) -> String {
    let cores = percent / 100
    return String(format: "%.1f core%@", cores, abs(cores - 1) < 0.05 ? "" : "s")
}

// MARK: - Root

struct NotchRootView: View {
    @ObservedObject var engine: AppEngine
    @ObservedObject var ui: NotchUIState

    var body: some View {
        let geometry = ui.geometry
        let toasting = !ui.expanded && ui.toast != nil
        let width = ui.expanded ? NotchLayout.expandedSize.width : geometry.collapsedWidth + (toasting ? NotchLayout.toastExtra.width : 0)
        let height = ui.expanded ? NotchLayout.expandedSize.height : geometry.notchHeight + (toasting ? NotchLayout.toastExtra.height : 0)
        ZStack(alignment: .top) {
            NotchShape(bottomRadius: ui.expanded ? 34 : (geometry.hasNotch ? 12 : 10)).fill(Color.black)
            if ui.expanded {
                Group {
                    if ui.showingOnboarding {
                        OnboardingView(engine: engine, ui: ui, onFinish: { ui.finishOnboarding() })
                    } else if ui.showingTour {
                        WelcomeTourView(engine: engine, ui: ui, onFinish: { ui.finishOnboarding() })
                    } else {
                        ExpandedView(engine: engine, ui: ui)
                    }
                }
                .frame(width: width, height: height - geometry.notchHeight - 2, alignment: .top)
                .clipped()
                .padding(.top, geometry.notchHeight + 2)
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    CollapsedView(engine: engine, geometry: geometry, visible: ui.showIndicators)
                        .frame(height: geometry.notchHeight)
                    if let toast = ui.toast {
                        (Text(toast.headline + ". ").fontWeight(.semibold).foregroundColor(.white)
                            + Text(toast.detail).foregroundColor(.white.opacity(0.6)))
                            .font(.system(size: 11.5, design: .rounded)).lineLimit(1).truncationMode(.tail)
                            .padding(.horizontal, 22).frame(height: NotchLayout.toastExtra.height - 6)
                            .transition(.opacity.combined(with: .offset(y: -6)))
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(width: width, height: height, alignment: .top)
        .clipShape(NotchShape(bottomRadius: ui.expanded ? 34 : (geometry.hasNotch ? 12 : 10)))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: NotchLayout.animationDuration), value: ui.expanded)
        .animation(.easeInOut(duration: NotchLayout.animationDuration), value: ui.toast)
        .preferredColorScheme(.dark)
    }
}

private struct CollapsedView: View {
    @ObservedObject var engine: AppEngine
    let geometry: NotchGeometry
    let visible: Bool

    var body: some View {
        if visible { indicators } else { Color.clear }
    }

    @ViewBuilder private var indicators: some View {
        if engine.sessionActive && !engine.paused && geometry.hasNotch { boostEars } else { idleEars }
    }

    /// During a boost the notch becomes a tiny live meter: performance-core load on the left, apps moved aside on the right.
    private var boostEars: some View {
        let loads = engine.cpuLoads
        let perf = engine.chip.performanceCPUs.prefix(6).map { $0 < loads.count ? loads[$0] : 0 }
        return HStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(perf.enumerated()), id: \.offset) { _, load in
                    Capsule().fill(Theme.yield.opacity(0.4 + 0.6 * load))
                        .frame(width: 2.5, height: max(3, 14 * CGFloat(load)))
                }
            }
            .frame(width: NotchGeometry.earWidth, height: 16, alignment: .bottom)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: perf)
            .help("Performance cores, live")
            Spacer().frame(width: geometry.notchWidth)
            Text("\(engine.demotedCount)")
                .font(.system(size: 10.5, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundColor(.white.opacity(0.9))
                .frame(width: NotchGeometry.earWidth)
                .help("Background processes moved to the efficiency cores")
        }
    }

    @ViewBuilder private var idleEars: some View {
        let mode = engine.rules.mode
        let dot: Color = engine.paused ? Color(white: 0.4) : (engine.sessionActive ? Theme.good : Color(white: 0.35))
        if geometry.hasNotch {
            HStack(spacing: 0) {
                Image(systemName: engine.paused ? "pause.fill" : mode.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(engine.paused ? Color(white: 0.5) : mode.tint)
                    .frame(width: NotchGeometry.earWidth)
                Spacer().frame(width: geometry.notchWidth)
                Circle().fill(dot).frame(width: 7, height: 7)
                    .shadow(color: engine.sessionActive ? Theme.good.opacity(0.8) : .clear, radius: 4)
                    .frame(width: NotchGeometry.earWidth)
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: engine.paused ? "pause.fill" : mode.symbol)
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(mode.tint)
                Text(engine.sessionActive ? (engine.boostAppName ?? "Boost") : "Coremium")
                    .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.85))
                    .lineLimit(1).truncationMode(.tail).frame(maxWidth: 110)
                Circle().fill(dot).frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Expanded

private struct ExpandedView: View {
    @ObservedObject var engine: AppEngine
    @ObservedObject var ui: NotchUIState

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ChipPanel(engine: engine, advanced: ui.advanced)
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    ModeBar(engine: engine)
                    // Mode names already fill this row (about 491 of 520 points). A shared row would drop those names.
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        PanelActions(ui: ui)
                    }
                }
                StatusLine(engine: engine, advanced: ui.advanced)
                UpdateBanner()
                TabBar(ui: ui)
                Group {
                    switch ui.tab {
                    case .apps: AppsTab(engine: engine, ui: ui)
                    case .insights: InsightsTab(engine: engine, advanced: ui.advanced)
                    case .simulate: SimulateTab(engine: engine, advanced: ui.advanced)
                    case .guide: GuideTab()
                    case .storage: StorageTab(ui: ui)
                    case .system: SystemTab(engine: engine, ui: ui)
                    case .settings: SettingsTab(engine: engine, ui: ui)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 20)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct ModeBar: View {
    @ObservedObject var engine: AppEngine

    var body: some View {
        // Every mode is named. Only if the column is too narrow do the unselected ones fall back to icons.
        ViewThatFits(in: .horizontal) {
            bar(labelAll: true)
            bar(labelAll: false)
        }
        .animation(.easeInOut(duration: 0.2), value: engine.rules.mode)
    }

    /// Automatic shows what it chose right now: "Automatic · Coding".
    private func pillTitle(_ mode: PerformanceMode, selected: Bool) -> String {
        guard selected, mode == .automatic else { return mode.label }
        let active = engine.activeProfile.mode
        return active == .automatic || active == .balanced || engine.paused ? mode.label : "\(mode.label) · \(active.label)"
    }

    private func bar(labelAll: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(PerformanceMode.allCases, id: \.self) { mode in
                let selected = engine.rules.mode == mode
                Button { engine.rules.mode = mode } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.symbol).font(.system(size: 10.5, weight: .semibold))
                        if selected || labelAll {
                            Text(pillTitle(mode, selected: selected)).font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .lineLimit(1).fixedSize()
                        }
                    }
                    .padding(.horizontal, labelAll ? 8 : (selected ? 11 : 9)).padding(.vertical, 6)
                    .foregroundColor(selected ? .black : .white.opacity(0.8))
                    .background(Capsule().fill(selected ? mode.tint : Color.white.opacity(0.09)))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("\(mode.label): \(mode.summary)")
                .accessibilityLabel(mode.label)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct StatusLine: View {
    @ObservedObject var engine: AppEngine
    let advanced: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(engine.sessionActive && !engine.paused ? Theme.good : Color(white: 0.4)).frame(width: 6, height: 6)
                Text(engine.statusLine)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            if !engine.paused, let decision = engine.latestDecision {
                // Why: the latest thing Coremium decided, in plain words.
                (Text(decision.headline + ". ").fontWeight(.semibold).foregroundColor(.white.opacity(0.85))
                    + Text(decision.detail).foregroundColor(Theme.textDim))
                    .font(.system(size: 10.5, design: .rounded))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 12)
                    .help("Why Coremium is doing this. The last few decisions are in Insights.")
            }
            if advanced {
                Text(advancedLine)
                    .font(.system(size: 9.5, design: .monospaced)).foregroundColor(Theme.textDim).lineLimit(1).minimumScaleFactor(0.7)
            }
            ForEach(engine.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.warn.opacity(0.9)).lineLimit(1)
            }
        }
    }

    private var advancedLine: String {
        var parts = ["profile \(engine.activeProfile.mode.rawValue)"]
        if engine.sessionActive { parts.append("session \(formatDuration(engine.sessionSeconds))") }
        parts.append("grace \(Int(engine.rules.graceSeconds)) s")
        parts.append("\(engine.ledgerCount) procs on E-cores")
        parts.append(String(format: "tick %.1f ms (+%.0f ms measuring)", engine.tickMs, engine.measureMs))
        return parts.joined(separator: " · ")
    }
}

private struct PanelActions: View {
    @ObservedObject var ui: NotchUIState

    var body: some View {
        HStack(spacing: 6) {
            Button { ui.advanced.toggle() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "number").font(.system(size: 9.5, weight: .bold))
                    Text("Advanced").font(.system(size: 10.5, weight: .semibold, design: .rounded)).lineLimit(1).fixedSize()
                }
                .padding(.horizontal, 9).frame(minHeight: 30)
                .foregroundColor(ui.advanced ? .black : .white.opacity(0.65))
                .background(Capsule().fill(ui.advanced ? Theme.accent : Color.white.opacity(0.08)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Show the numbers: per-core load, memory, process counts and timers.")
            .accessibilityLabel("Advanced mode")
            .accessibilityValue(ui.advanced ? "On" : "Off")
            Button { ui.onHide?() } label: {
                Image(systemName: "chevron.up").font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 9).frame(minHeight: 30)
                    .foregroundColor(.white.opacity(0.65))
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Hide Coremium (it keeps working; hover the notch or use the menu-bar icon to bring it back)")
            .accessibilityLabel("Hide Coremium")
        }
        .fixedSize()
    }
}

private struct TabBar: View {
    @ObservedObject var ui: NotchUIState
    @FocusState private var focusedTab: NotchTab?
    @State private var tabsHadFocus = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(NotchTab.allCases) { tab in
                let selected = ui.tab == tab
                let focused = focusedTab == tab
                Button { ui.selectTab(tab) } label: {
                    Text(tab.title)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .lineLimit(1).fixedSize()
                        .padding(.horizontal, 9).frame(minHeight: 30)
                        .foregroundColor(selected ? .black : .white.opacity(0.75))
                        .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Theme.accent : Color.clear))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(focusRing(selected: selected, focused: focused), lineWidth: 1.5))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .focusable()
                .modifier(OwnFocusRing())
                .focused($focusedTab, equals: tab)
                .onMoveCommand { direction in
                    guard direction == .left || direction == .right else { return }
                    let next = tab.next(offset: direction == .left ? -1 : 1)
                    ui.selectTab(next)
                    focusedTab = next
                }
                .help("\(tab.title) · ⌘\(tab.shortcutNumber). Control-Tab switches to the next tab.")
                .accessibilityLabel(tab.title)
                .accessibilityHint("Command \(tab.shortcutNumber). Control-Tab for the next tab.")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card))
        // Focus entering the bar lands on the selected tab, not the first one, and follows clicks and ⌘1–⌘7, so the
        // ring never marks a different tab from the one shown.
        .onChange(of: focusedTab) { focused in
            let entering = !tabsHadFocus
            tabsHadFocus = focused != nil
            if entering, let focused, focused != ui.tab { focusedTab = ui.tab }
        }
        .onChange(of: ui.tab) { tab in
            if focusedTab != nil, focusedTab != tab { focusedTab = tab }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notch tabs")
    }

    /// The tabs draw their own ring (below), so the system's blue one would double it.
    private struct OwnFocusRing: ViewModifier {
        func body(content: Content) -> some View {
            if #available(macOS 14, *) { content.focusEffectDisabled() } else { content }
        }
    }

    /// Selected fill is white, so a white focus ring would disappear.
    private func focusRing(selected: Bool, focused: Bool) -> Color {
        guard focused else { return .clear }
        return selected ? .black : .white
    }
}

// MARK: - Apps tab

private struct AppsTab: View {
    @ObservedObject var engine: AppEngine
    @ObservedObject var ui: NotchUIState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ListHeader(engine: engine, ui: ui)
            AppList(rows: ui.listTab == .running ? engine.rows : engine.installedRows, engine: engine,
                    installed: ui.listTab == .installed, advanced: ui.advanced)
            ProofStrip(engine: engine, ui: ui)
        }
    }
}

/// The proof-of-value line: what Coremium measurably did, and what it costs.
private struct ProofStrip: View {
    @ObservedObject var engine: AppEngine
    @ObservedObject var ui: NotchUIState

    var body: some View {
        let today = engine.today
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 14)).foregroundColor(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(todayText(today)).font(.system(size: 10.5, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.9))
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(nowText).font(.system(size: 10, design: .rounded)).foregroundColor(Theme.textDim).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            Button { ui.tab = .insights } label: {
                Text("Details").font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 9).padding(.vertical, 4).foregroundColor(.black)
                    .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .help("Measured history and why Coremium made each decision. Performance cores (P-cores) are the fast ones; efficiency cores (E-cores) are the frugal ones.")
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.white.opacity(0.06)))
    }

    private func todayText(_ day: DayStats) -> String {
        if day.boostedSeconds < 1 { return "Today: nothing needed protecting yet" }
        return "Today: a boost ran for \(formatDuration(day.boostedSeconds)) · peak \(day.peakMovedProcesses) background processes moved off the performance cores"
    }

    private var nowText: String {
        let moved = engine.demotedCount == 0
            ? "No Boost running, nothing moved"
            : "\(engine.demotedCount) processes on efficiency cores now"
        return "\(moved) · Coremium overhead \(String(format: "%.1f", engine.ownCPU))% of one core"
    }
}

private struct ListHeader: View {
    @ObservedObject var engine: AppEngine
    @ObservedObject var ui: NotchUIState

    private func scopeButton(_ title: String, game: Bool) -> some View {
        let on = engine.ruleScopeIsGame == game
        return Button { engine.ruleScopeIsGame = game } label: {
            Text(title).font(.system(size: 10, weight: .semibold, design: .rounded)).lineLimit(1)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .foregroundColor(on ? .black : .white.opacity(0.6))
                .background(Capsule().fill(on ? Theme.boost : Color.clear))
        }.buttonStyle(.plain)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ListTab.allCases, id: \.self) { tab in
                Button { ui.listTab = tab } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .foregroundColor(ui.listTab == tab ? .white : .white.opacity(0.5))
                        .background(Capsule().fill(ui.listTab == tab ? Color.white.opacity(0.16) : Color.clear))
                }
                .buttonStyle(.plain)
            }
            if ui.listTab == .running, engine.boostBundleID != nil {
                HStack(spacing: 2) {
                    scopeButton("Everyone", game: false)
                    scopeButton("\(engine.boostAppName ?? "This game") only", game: true)
                }
                .padding(2).background(Capsule().fill(Color.white.opacity(0.06)))
                .help("Choose whether the Boost / Yield / Eco chips change your general rules or only the rules used while this app is boosted.")
            }
            Spacer()
            // The "found N apps" summary only belongs where you are looking at installed apps.
            if ui.listTab == .installed, !engine.detectedSummary.isEmpty {
                Text(engine.detectedSummary).font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.45)).lineLimit(1)
                    .help("Apps Coremium found on this Mac. Modes use these kinds to decide which apps to protect and which to move aside.")
            }
            Button { engine.paused.toggle() } label: {
                HStack(spacing: 4) {
                    Image(systemName: engine.paused ? "play.fill" : "pause.fill").font(.system(size: 8.5))
                    Text(engine.paused ? "Resume" : "Pause").font(.system(size: 10.5, weight: .semibold, design: .rounded)).fixedSize()
                }
                .padding(.horizontal, 9).padding(.vertical, 4)
                .foregroundColor(engine.paused ? .black : .white.opacity(0.65))
                .background(Capsule().fill(engine.paused ? Theme.warn : Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help(engine.paused ? "Resume moving apps aside." : "Pause Coremium: puts every app back to macOS default scheduling right away.")
            .accessibilityLabel("Pause Coremium")
            .accessibilityValue(engine.paused ? "On" : "Off")
        }
    }
}

private struct AppList: View {
    let rows: [AppRow]
    @ObservedObject var engine: AppEngine
    let installed: Bool
    let advanced: Bool

    var body: some View {
        FlexScroll {
            VStack(spacing: 3) {
                ForEach(rows) { row in AppRowView(row: row, engine: engine, installed: installed, advanced: advanced) }
                if rows.isEmpty {
                    Text(installed ? "Looking through your apps…" : "No apps running.")
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.4)).padding(.top, 20)
                }
            }
        }
        .frame(minHeight: 110, maxHeight: .infinity)
    }
}

struct AppRowView: View {
    let row: AppRow
    @ObservedObject var engine: AppEngine
    let installed: Bool
    var advanced = false

    var body: some View {
        HStack(spacing: 8) {
            AppIconView(path: row.path)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name).font(.system(size: 12, weight: .medium)).foregroundColor(.white)
                    .lineLimit(1).truncationMode(.tail)
                HStack(spacing: 4) {
                    Image(systemName: row.category.symbol).font(.system(size: 8))
                    Text(subtitle).font(.system(size: 9.5, weight: .regular, design: .rounded))
                        .lineLimit(1).truncationMode(.tail)
                }
                .foregroundColor(.white.opacity(0.42))
                if advanced, let detail = detailLine {
                    // Numbers on their own line so nothing gets cut off.
                    Text(detail).font(.system(size: 9, design: .monospaced)).foregroundColor(.white.opacity(0.34))
                        .lineLimit(1).truncationMode(.tail)
                }
            }
            Spacer(minLength: 4)
            if !installed, advanced {
                Text(String(format: "%.0f%%", row.cpu)).font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6)).lineLimit(1).fixedSize()
                    .help("CPU use, where 100% is one core fully busy. \(coresText(row.cpu)).")
            }
            if !installed, row.gpu >= 5 {
                Label(advanced ? "GPU \(Int(row.gpu))%" : "GPU heavy", systemImage: "square.stack.3d.up.fill")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.gpu).lineLimit(1).fixedSize()
                    .help("Using about \(Int(row.gpu))% of the GPU's time. macOS has no public way to lower another app's GPU priority, so Coremium shows it instead.")
            }
            if !installed, row.demoted || row.cpu >= 10 {
                // An outcome first ("Background", "Heavy"), the technical figure in the tooltip.
                let word = AppEngine.loadWord(row.cpu, moved: row.demoted)
                Label(word, systemImage: row.demoted ? "leaf.fill" : "gauge.with.dots.needle.33percent")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundColor(row.demoted ? Theme.eco : .white.opacity(0.5)).lineLimit(1).fixedSize()
                    .help(row.demoted
                          ? "Moved to the efficiency cores so it stays out of the way. Using about \(coresText(row.cpu))."
                          : "Using about \(coresText(row.cpu)) of CPU. One core is 100%; your Mac has \(ProcessInfo.processInfo.activeProcessorCount).")
            }
            RuleChips(row: row, engine: engine).fixedSize()
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.05)))
    }

    /// What the rule means for this app, so "Yield" is explained where it applies. Category stays in the icon and tooltip.
    private var subtitle: String {
        guard !installed, let rule = row.effective else {
            return advanced && installed ? "\(row.category.label) · \(row.bundleID ?? "?")" : row.category.label
        }
        switch rule {
        case .boost: return "Protected"
        case .auto: return "Steps aside during boosts"
        case .efficiency: return "Always on efficiency cores"
        case .normal: return row.category.label
        }
    }

    /// Advanced: pid, process counts and why the rule applies.
    private var detailLine: String? {
        if installed { return nil }
        var parts = ["pid \(row.pid)", "\(row.processes) \(row.processes == 1 ? "proc" : "procs")"]
        if row.demotedProcesses > 0 { parts.append("\(row.demotedProcesses) eco") }
        if !row.source.isEmpty { parts.append(row.source) }
        return parts.joined(separator: " · ")
    }
}

struct RuleChips: View {
    let row: AppRow
    @ObservedObject var engine: AppEngine

    var body: some View {
        HStack(spacing: 3) {
            ForEach(AppRule.allCases, id: \.self) { rule in
                let chosen = row.override == rule
                let implied = row.override == nil && row.effective == rule
                Button { engine.toggleOverride(row.bundleID, rule) } label: {
                    Text(rule.shortLabel)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .foregroundColor(chosen ? .black : (implied ? rule.tint : .white.opacity(0.5)))
                        .background(Capsule().fill(chosen ? rule.tint : Color.white.opacity(0.07)))
                        .overlay(Capsule().strokeBorder(implied ? rule.tint.opacity(0.9) : .clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(row.bundleID == nil)
                .help("\(rule.shortLabel): \(rule.meaning)")
            }
        }
        .help("Solid = your choice. Outlined = what the current mode does. Click your choice again to follow the mode.")
    }
}

struct AppIconView: View {
    let path: String?

    var body: some View {
        Group {
            if let path {
                Image(nsImage: IconCache.icon(for: path)).resizable().interpolation(.high)
            } else {
                Image(systemName: "app.fill").resizable().foregroundColor(.white.opacity(0.3))
            }
        }
        .frame(width: 22, height: 22)
    }
}

@MainActor
enum IconCache {
    private static var cache: [String: NSImage] = [:]

    static func icon(for path: String) -> NSImage {
        if let hit = cache[path] { return hit }
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: 44, height: 44)
        cache[path] = image
        return image
    }
}

/// Shown when a newer Coremium is on GitHub. Installing verifies the download's checksum and relaunches.
struct UpdateBanner: View {
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        if let info = updater.available {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill").foregroundColor(Theme.yield)
                Text(updater.state.isEmpty ? "Coremium \(info.version) is available." : updater.state)
                    .font(.system(size: 11, weight: .semibold, design: .rounded)).lineLimit(1)
                Spacer(minLength: 6)
                Button("What's new") { NSWorkspace.shared.open(info.pageURL) }
                    .buttonStyle(.plain).font(.system(size: 10.5, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.7))
                Button("Update now") { updater.install() }
                    .buttonStyle(.plain).font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10).padding(.vertical, 4).foregroundColor(.black)
                    .background(Capsule().fill(Theme.yield))
                    .disabled(!updater.state.isEmpty && !updater.state.hasPrefix("Update failed"))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.yield.opacity(0.1)))
        }
    }
}
