import AppKit
import Combine
import CoremiumCore
import SwiftUI

/// The standard, resizable Coremium window: the live graphs beside the same dashboard the notch shows. It opens from the
/// menu bar on every Mac, notched or not. The app stays an accessory (no Dock icon) and only activates for this window.
@MainActor
final class DashboardWindowController: NSObject, NSWindowDelegate {
    private let engine: AppEngine
    /// The window's own tab and list state. Advanced mode is shared with the notch through its saved setting.
    private let ui = NotchUIState(geometry: NotchGeometry(hasNotch: false, notchWidth: 0, notchHeight: 24))
    private var window: DashboardWindow?
    private var occlusionObserver: NSObjectProtocol?

    /// Back to the notch (wired by the app).
    var onSwitchToNotch: (() -> Void)?

    init(engine: AppEngine) {
        self.engine = engine
        super.init()
        ui.onSwitchSurface = { [weak self] in self?.onSwitchToNotch?() }
    }

    /// Opens the window (or brings it forward). Sampling starts when the window is actually visible.
    func show(tab: NotchTab? = nil) {
        ui.reloadShared()
        if let tab { ui.tab = tab }
        let window = self.window ?? makeWindow()
        self.window = window
        onVisibilityChange?(true)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    var isOpen: Bool { window?.isVisible ?? false }

    /// Called with true when the window opens and false when it closes. The notch is off while the window is open.
    var onVisibilityChange: ((Bool) -> Void)?

    /// The welcome tour, shown over the window.
    func showTour() {
        ui.showingTour = true
        show()
    }

    func toggleAdvanced() { ui.advanced.toggle() }
    var advanced: Bool { ui.advanced }

    func closeIfOpen() {
        if isOpen { window?.close() }
    }

    private func makeWindow() -> DashboardWindow {
        let window = DashboardWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 680),
                                     styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                     backing: .buffered, defer: false)
        window.title = "Coremium"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 900, height: 600)
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.setFrameAutosaveName("CoremiumDashboard")
        let restored = window.setFrameUsingName("CoremiumDashboard")
        // A saved frame from a display that is gone (or on another screen) would hide the window: use the main screen.
        if !restored || !Self.fitsOnMainScreen(window.frame) {
            if let screen = NSScreen.main {
                let visible = screen.visibleFrame
                window.setContentSize(NSSize(width: min(1000, visible.width - 80), height: min(720, visible.height - 60)))
            }
            window.center()
        }
        window.delegate = self
        let host = NSHostingView(rootView: DashboardWindowView(engine: engine, ui: ui))
        // The window sets the size; long tab content scrolls instead of growing the window past the screen.
        host.sizingOptions = []
        window.contentView = host
        window.onNavigate = { [weak self] event in self?.navigate(with: event) ?? false }

        ui.onHide = { [weak window] in window?.close() }
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
        ) { [weak self, weak window] _ in
            MainActor.assumeIsolated {
                guard let self, let window else { return }
                // Hidden behind other windows, minimised or on another Space: nothing is drawn, so nothing is sampled.
                self.engine.isWindowVisible = window.isVisible && window.occlusionState.contains(.visible)
            }
        }
        return window
    }

    private static func fitsOnMainScreen(_ frame: NSRect) -> Bool {
        guard let visible = NSScreen.main?.visibleFrame else { return true }
        return visible.contains(frame)
    }

    func windowWillClose(_ notification: Notification) {
        engine.isWindowVisible = false
        onVisibilityChange?(false)
    }

    /// The same tab shortcuts as the notch: ⌘1–⌘7, and Control-Tab (Control-Shift-Tab goes back).
    private func navigate(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if flags == .command, let characters = event.charactersIgnoringModifiers, let number = Int(characters),
           (1...NotchTab.allCases.count).contains(number) {
            ui.selectTab(NotchTab.allCases[number - 1])
            return true
        }
        if event.keyCode == 48, flags == .control || flags == [.control, .shift] {
            ui.selectTab(ui.tab.next(offset: flags.contains(.shift) ? -1 : 1))
            return true
        }
        return false
    }
}

/// A normal titled window that passes tab shortcuts to its controller before the menu sees them.
final class DashboardWindow: NSWindow {
    var onNavigate: ((NSEvent) -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onNavigate?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if onNavigate?(event) == true { return }
        super.keyDown(with: event)
    }
}

/// Simple by default: a header, three live readings, the mode bar and the tabs. Advanced adds the full graphs and the
/// numbers beside the dashboard.
struct DashboardWindowView: View {
    @ObservedObject var engine: AppEngine
    @ObservedObject var ui: NotchUIState
    private let compactName = NotchGeometry.current().1.hasNotch ? "Notch" : "Pill"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            StatusLine(engine: engine, advanced: ui.advanced)
            UpdateBanner()
            HStack(alignment: .top, spacing: 22) {
                overview
                    .frame(width: ui.advanced ? 380 : 310)
                VStack(alignment: .leading, spacing: 12) {
                    ModeBar(engine: engine)
                    TabBar(ui: ui, quietFocus: true)
                    DashboardTabContent(engine: engine, ui: ui)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Room for the traffic lights, which sit over the transparent titlebar.
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(WindowBackdrop())
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.2), value: ui.advanced)
        .overlay {
            if ui.showingTour {
                ZStack {
                    Color.black.opacity(0.88).ignoresSafeArea()
                    WelcomeTourView(engine: engine, ui: ui, onFinish: { ui.finishOnboarding() })
                        .frame(width: 780, height: 462)
                        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.black))
                        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .transition(.opacity)
            }
        }
    }

    private var header: some View {
        let chip = engine.chip
        return HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(chip.shortName).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(.white)
                Text(chipSubtitle(chip)).font(.system(size: 12, design: .rounded)).foregroundColor(Theme.textDim)
            }
            Spacer(minLength: 12)
            if let switchSurface = ui.onSwitchSurface {
                Button { switchSurface() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "menubar.rectangle").font(.system(size: 11, weight: .semibold))
                        Text(compactName).font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 14).frame(minHeight: 32)
                    .foregroundColor(.white.opacity(0.8))
                    .background(Capsule().fill(Color.white.opacity(0.09)))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Switch back to the notch. The window button there brings you back here.")
                .accessibilityLabel("Switch to the notch")
            }
            Button { ui.advanced.toggle() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chart.xyaxis.line").font(.system(size: 11, weight: .semibold))
                    Text("Advanced").font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 14).frame(minHeight: 32)
                .foregroundColor(ui.advanced ? .black : .white.opacity(0.8))
                .background(Capsule().fill(ui.advanced ? Theme.accent : Color.white.opacity(0.09)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Show the live graphs and every number.")
            .accessibilityLabel("Advanced mode")
            .accessibilityValue(ui.advanced ? "On" : "Off")
        }
    }

    private func chipSubtitle(_ chip: ChipInfo) -> String {
        var parts = ["\(chip.performanceCores)P + \(chip.efficiencyCores)E cores"]
        if let gpu = chip.gpuCores { parts.append("\(gpu)-core GPU") }
        parts.append(ByteCountFormatter.string(fromByteCount: Int64(chip.memoryBytes), countStyle: .memory))
        return parts.joined(separator: " · ")
    }

    /// The left column. Simple: three live readings and every core as a bar. Advanced: the full graphs and the numbers.
    @ViewBuilder private var overview: some View {
        if ui.advanced {
            FlexScroll {
                VStack(alignment: .leading, spacing: 12) {
                    PerformancePanel(telemetry: engine.telemetry, chip: engine.chip, memoryTotal: engine.memory.totalBytes, names: appNames)
                    Card(padding: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Numbers")
                            ChipPanel(engine: engine, advanced: true).advancedStats(engine.chip)
                        }
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                LiveTiles(engine: engine, telemetry: engine.telemetry)
                CoreBars(chip: engine.chip, loads: engine.cpuLoads)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    private var appNames: [String: String] {
        var names: [String: String] = [:]
        for row in engine.rows { if let id = row.bundleID { names[id] = row.name } }
        return names
    }
}

/// Black with a faint glow at the top, so the cards have something to sit on.
private struct WindowBackdrop: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Theme.gpu.opacity(0.10), Color.clear], center: .topLeading, startRadius: 0, endRadius: 620)
            RadialGradient(colors: [Theme.yield.opacity(0.07), Color.clear], center: .topTrailing, startRadius: 0, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

/// CPU, GPU and memory right now, each with a short trail behind it.
private struct LiveTiles: View {
    @ObservedObject var engine: AppEngine
    @ObservedObject var telemetry: TelemetryStore

    var body: some View {
        let entries = telemetry.history.fineEntries
        let loads = engine.cpuLoads
        let cpu = loads.isEmpty ? 0 : loads.reduce(0, +) / Double(loads.count)
        let total = max(Double(engine.memory.totalBytes), 1)
        let memory = Double(engine.memory.usedBytes) / total
        VStack(spacing: 12) {
            tile("CPU", percent: Int((cpu * 100).rounded()), detail: "\(loads.count) cores", color: Theme.yield,
                 entries: entries) { sample in
                sample.coreLoads.isEmpty ? nil : sample.coreLoads.reduce(0, +) / Double(sample.coreLoads.count)
            }
            tile("GPU", percent: engine.gpuDevicePercent, detail: engine.chip.gpuCores.map { "\($0)-core" } ?? "graphics", color: Theme.gpu,
                 entries: entries) { sample in sample.gpuPercent.map { $0 / 100 } }
            tile("Memory", percent: Int((memory * 100).rounded()),
                 detail: "of \(ByteCountFormatter.string(fromByteCount: Int64(engine.memory.totalBytes), countStyle: .memory))",
                 color: Color.white.opacity(0.85), entries: entries) { sample in
                sample.memoryUsedBytes.map { min(Double($0) / total, 1) }
            }
        }
    }

    private func tile(_ title: String, percent: Int?, detail: String, color: Color, entries: [TelemetryEntry],
                      value: @escaping (TelemetrySample) -> Double?) -> some View {
        Card(padding: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Circle().fill(color).frame(width: 6, height: 6)
                        Text(title).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(Theme.textDim)
                    }
                    Text(percent.map { "\($0)%" } ?? "–")
                        .font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit().foregroundColor(.white)
                    Text(detail).font(.system(size: 10.5, design: .rounded)).foregroundColor(Theme.textDim.opacity(0.8)).lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
                Sparkline(entries: entries, capacity: 120, color: color, value: value)
                    .frame(height: 58)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(percent.map { "\($0) percent, \(detail)" } ?? "no reading")
    }
}

/// Every core as a live bar: performance cores first, then efficiency cores. A bar turns amber when its core is pinned.
private struct CoreBars: View {
    let chip: ChipInfo
    let loads: [Double]

    var body: some View {
        Card(padding: 14, fillsHeight: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    SectionLabel(text: "Cores")
                    Spacer()
                    legend("Performance", Theme.yield)
                    legend("Efficiency", Theme.eco)
                }
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(chip.performanceCPUs.enumerated()), id: \.offset) { index, cpu in
                        bar(cpu, label: "P\(index + 1)", color: Theme.yield, name: "Performance core \(index + 1)")
                    }
                    Spacer().frame(width: 8)
                    ForEach(Array(chip.efficiencyCPUs.enumerated()), id: \.offset) { index, cpu in
                        bar(cpu, label: "E\(index + 1)", color: Theme.eco, name: "Efficiency core \(index + 1)")
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func legend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(.system(size: 10, design: .rounded)).foregroundColor(Theme.textDim)
        }
    }

    private func bar(_ cpu: Int, label: String, color: Color, name: String) -> some View {
        let load = cpu < loads.count ? min(max(loads[cpu], 0), 1) : 0
        let tint = load > 0.85 ? Theme.warn : color
        let percent = Int((load * 100).rounded())
        return VStack(spacing: 4) {
            Text("\(percent)").font(.system(size: 9, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundColor(load > 0.05 ? tint : Theme.textDim.opacity(0.6))
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(colors: [tint, tint.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                        .frame(height: max(5, proxy.size.height * CGFloat(load)))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.4), value: load)
            Text(label).font(.system(size: 9, weight: .medium, design: .rounded)).foregroundColor(Theme.textDim)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue("\(percent) percent")
    }
}
