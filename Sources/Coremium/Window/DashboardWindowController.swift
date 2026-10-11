import AppKit
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

    init(engine: AppEngine) {
        self.engine = engine
        super.init()
    }

    /// Opens the window (or brings it forward). Sampling starts when the window is actually visible.
    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    var isOpen: Bool { window?.isVisible ?? false }

    private func makeWindow() -> DashboardWindow {
        let window = DashboardWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 680),
                                     styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                     backing: .buffered, defer: false)
        window.title = "Coremium"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 980, height: 600)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.setFrameAutosaveName("CoremiumDashboard")
        if !window.setFrameUsingName("CoremiumDashboard") { window.center() }
        window.delegate = self
        window.contentView = NSHostingView(rootView: DashboardWindowView(engine: engine, ui: ui))
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

    func windowWillClose(_ notification: Notification) {
        engine.isWindowVisible = false
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

/// The live graphs on the left (scrollable), the dashboard on the right.
struct DashboardWindowView: View {
    @ObservedObject var engine: AppEngine
    @ObservedObject var ui: NotchUIState

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView(.vertical, showsIndicators: false) {
                PerformancePanel(telemetry: engine.telemetry, chip: engine.chip, memoryTotal: engine.memory.totalBytes, names: appNames)
            }
            .frame(width: 380)
            DashboardColumn(engine: engine, ui: ui)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        // Room for the traffic lights, which sit over the transparent titlebar.
        .padding(.horizontal, 22)
        .padding(.top, 40)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private var appNames: [String: String] {
        var names: [String: String] = [:]
        for row in engine.rows { if let id = row.bundleID { names[id] = row.name } }
        return names
    }
}
