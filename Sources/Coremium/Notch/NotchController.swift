import AppKit
import Combine
import SwiftUI

/// Borderless panel that never activates the app, floats above the menu bar and shows in every Space.
final class NotchPanel: NSPanel {
    var onDismiss: (() -> Void)?
    var onNavigate: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// AppKit normally pushes windows below the menu bar. The pill must sit flush with the top edge of the screen.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    override func cancelOperation(_ sender: Any?) { onDismiss?() }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onNavigate?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }
}

/// Reports the mouse entering or leaving the pill.
final class HoverHostingView<Content: View>: NSHostingView<Content> {
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { onEnter?() }
    override func mouseExited(with event: NSEvent) { onExit?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Owns the notch panel: placement, hover/click expansion and screen changes.
@MainActor
final class NotchController: NSObject {
    private let engine: AppEngine
    let ui: NotchUIState
    private var enabled = true
    private let panel: NotchPanel
    private let hostView: HoverHostingView<NotchRootView>
    private var screen: NSScreen
    private var expandWork: DispatchWorkItem?
    private var collapseWork: DispatchWorkItem?
    // Hover cancellation must never cancel the resize that removes the expanded window's invisible hit area.
    private var resizeWork: DispatchWorkItem?
    private var clickMonitors: [Any] = []
    private var pinned = false
    private var cancellables = Set<AnyCancellable>()

    init(engine: AppEngine, showsPanel: Bool = true, defaults: UserDefaults = .standard) {
        self.engine = engine
        let (screen, geometry) = NotchGeometry.current()
        self.screen = screen
        ui = NotchUIState(geometry: geometry, defaults: defaults)

        panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true      // must come before `level`: this setter resets the level to .floating
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        hostView = HoverHostingView(rootView: NotchRootView(engine: engine, ui: ui))
        hostView.sizingOptions = []
        hostView.autoresizingMask = [.width, .height]
        panel.contentView = hostView
        super.init()

        ui.onHide = { [weak self] in self?.collapse() }
        panel.onDismiss = { [weak self] in self?.collapse() }
        panel.onNavigate = { [weak self] event in self?.navigate(with: event) ?? false }
        ui.onFocusTabs = { [weak self] in
            if showsPanel { self?.panel.makeKey() }
        }
        hostView.onEnter = { [weak self] in self?.hoverBegan() }
        hostView.onExit = { [weak self] in self?.hoverEnded() }
        if showsPanel { installDismissMonitors() }

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.screenChanged() }.store(in: &cancellables)
        // While a boost app (a game) is in front, the pill ignores the mouse so it can never get in the way.
        engine.$boostAppFocused.sink { [weak self] focused in
            guard let self else { return }
            self.panel.ignoresMouseEvents = focused && !self.ui.expanded
        }.store(in: &cancellables)

        // Each new decision drops out of the notch for a moment, Dynamic Island style. Click-through, never blocks you.
        engine.$decisions.dropFirst().compactMap(\.first).removeDuplicates { $0.id == $1.id }
            .sink { [weak self] decision in self?.showToast(decision) }.store(in: &cancellables)

        engine.$latestReport.compactMap { $0 }.removeDuplicates()
            .sink { [weak self] r in self?.showToast(Decision(date: r.end, headline: "Session report", detail: r.summary)) }
            .store(in: &cancellables)
        Updater.shared.$available.compactMap { $0 }.removeDuplicates()
            .sink { [weak self] info in self?.showToast(Decision(date: Date(), headline: "Coremium \(info.version) is available",
                                                                  detail: "Open the panel to update.")) }
            .store(in: &cancellables)

        applyFrame(expanded: false)
        if showsPanel { panel.orderFrontRegardless() }
    }

    private var toastWork: DispatchWorkItem?

    private func showToast(_ decision: Decision) {
        guard enabled, !ui.expanded, resizeWork == nil, ui.showIndicators, ui.decisionToasts,
              decision.headline != "Standing by" || ui.toast != nil else { return }
        toastWork?.cancel()
        ui.toast = decision
        panel.ignoresMouseEvents = true
        applyFrame(expanded: false)
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.ui.toast = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                guard !self.ui.expanded, self.ui.toast == nil else { return }
                self.applyFrame(expanded: false)
                self.panel.ignoresMouseEvents = self.engine.boostAppFocused
            }
        }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4, execute: work)
    }

    // MARK: - Public

    /// Shows or hides the pill (App style hides it).
    func setEnabled(_ on: Bool) {
        enabled = on
        if on {
            applyFrame(expanded: ui.expanded)
            panel.orderFrontRegardless()
        } else {
            collapse()
            panel.orderOut(nil)
        }
    }

    func toggle() {
        if ui.expanded { collapse() } else { expand(pinned: true) }
    }

    func expand(pinned: Bool = false) {
        guard enabled else { return }
        collapseWork?.cancel()
        expandWork?.cancel()
        if pinned { self.pinned = true; panel.makeKey() }
        guard !ui.expanded else { return }
        resizeWork?.cancel()
        resizeWork = nil
        toastWork?.cancel()
        ui.toast = nil
        panel.ignoresMouseEvents = false
        applyFrame(expanded: true)
        engine.isPanelExpanded = true
        ui.expanded = true
    }

    func collapse() {
        expandWork?.cancel()
        collapseWork?.cancel()
        pinned = false
        guard ui.expanded else { return }
        ui.expanded = false
        engine.isPanelExpanded = false
        panel.ignoresMouseEvents = engine.boostAppFocused
        // Shrink the panel only after the close animation, so the content is never clipped mid-way.
        resizeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.ui.expanded else { return }
            self.applyFrame(expanded: false)
            self.resizeWork = nil
        }
        resizeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + NotchLayout.animationDuration + 0.05, execute: work)
    }

    private func installDismissMonitors() {
        let dismissOutside: () -> Void = { [weak self] in
            guard let self, self.ui.expanded, !self.panel.frame.contains(NSEvent.mouseLocation) else { return }
            self.collapse()
        }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { _ in dismissOutside() }) {
            clickMonitors.append(monitor)
        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { event in
            dismissOutside()
            return event
        }) { clickMonitors.append(monitor) }
    }

    /// Panel-local shortcuts only. Hover never installs a global keyboard monitor or steals a game's shortcuts.
    private func navigate(with event: NSEvent) -> Bool {
        guard ui.expanded, !ui.showingOnboarding, !ui.showingTour else { return false }
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if flags == .command, let characters = event.charactersIgnoringModifiers,
           let number = Int(characters), (1...NotchTab.allCases.count).contains(number) {
            ui.selectTab(NotchTab.allCases[number - 1])
            return true
        }
        if event.keyCode == 48, flags == .control || flags == [.control, .shift] {
            ui.selectTab(ui.tab.next(offset: flags.contains(.shift) ? -1 : 1))
            return true
        }
        return false
    }

    deinit { clickMonitors.forEach(NSEvent.removeMonitor) }

    // MARK: - Hover

    private func hoverBegan() {
        guard enabled else { return }
        collapseWork?.cancel()
        guard !ui.expanded else { return }
        let work = DispatchWorkItem { [weak self] in self?.expand() }
        expandWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func hoverEnded() {
        expandWork?.cancel()
        guard ui.expanded, !pinned else { return }
        let work = DispatchWorkItem { [weak self] in self?.collapse() }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    // MARK: - Geometry

    private func screenChanged() {
        let (newScreen, geometry) = NotchGeometry.current()
        screen = newScreen
        ui.geometry = geometry
        applyFrame(expanded: ui.expanded)
    }

    private func applyFrame(expanded: Bool) {
        let toasting = !expanded && ui.toast != nil
        let size = expanded
            ? NotchLayout.expandedSize
            : CGSize(width: ui.geometry.collapsedWidth + (toasting ? NotchLayout.toastExtra.width : 0),
                     height: ui.geometry.notchHeight + (toasting ? NotchLayout.toastExtra.height : 0))
        let frame = screen.frame
        let rect = NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
        panel.setFrame(rect, display: true)
    }
}

#if PREVIEW
extension NotchController {
    /// Exercise AppKit's actual frame and the hover timers without displaying a window or changing app priorities.
    @MainActor static func runRegressionChecks(engine: AppEngine) async -> Bool {
        let suiteName = "Coremium.NotchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let controller = NotchController(engine: engine, showsPanel: false, defaults: defaults)
        controller.expand()
        controller.collapse()
        controller.hoverBegan()
        controller.hoverEnded()
        try? await Task.sleep(nanoseconds: 650_000_000)
        let compact = controller.panel.frame.width == controller.ui.geometry.collapsedWidth
        print("\(compact ? "PASS" : "FAIL") brief hover during collapse restores compact frame (width \(controller.panel.frame.width))")
        controller.expand()
        controller.collapse()
        controller.expand(pinned: true)
        try? await Task.sleep(nanoseconds: 650_000_000)
        let reopened = controller.ui.expanded && controller.panel.frame.width == NotchLayout.expandedSize.width
        print("\(reopened ? "PASS" : "FAIL") reopening cancels an obsolete compact resize")
        controller.panel.cancelOperation(nil)
        try? await Task.sleep(nanoseconds: 650_000_000)
        let escaped = !controller.ui.expanded && controller.panel.frame.width == controller.ui.geometry.collapsedWidth
        print("\(escaped ? "PASS" : "FAIL") Escape dismisses a pinned panel")
        controller.expand(pinned: true)
        controller.ui.showingOnboarding = true
        controller.ui.finishOnboarding()
        let live = controller.ui.expanded && controller.ui.tab == .apps && controller.ui.onboardingCompleted
            && !controller.ui.showingOnboarding && !controller.ui.showingTour
        print("\(live ? "PASS" : "FAIL") first-use completion keeps the live panel open")
        let restoredUI = NotchUIState(geometry: controller.ui.geometry, defaults: defaults)
        let remembered = restoredUI.onboardingCompleted
        print("\(remembered ? "PASS" : "FAIL") returning users keep onboarding completion")
        controller.ui.finishOnboarding(tab: .simulate)
        let simulated = controller.ui.tab == .simulate && controller.ui.expanded
        print("\(simulated ? "PASS" : "FAIL") simulation is reachable directly from first use")
        func key(_ text: String, code: UInt16, flags: NSEvent.ModifierFlags) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                windowNumber: controller.panel.windowNumber, context: nil, characters: text,
                charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)!
        }
        let jump = controller.navigate(with: key("7", code: 26, flags: .command)) && controller.ui.tab == .settings
        let next = controller.navigate(with: key("\t", code: 48, flags: .control)) && controller.ui.tab == .apps
        let previous = controller.navigate(with: key("\t", code: 48, flags: [.control, .shift])) && controller.ui.tab == .settings
        let stayed = controller.ui.tab
        let rejectedZero = !controller.navigate(with: key("0", code: 29, flags: .command)) && controller.ui.tab == stayed
        let rejectedEight = !controller.navigate(with: key("8", code: 28, flags: .command)) && controller.ui.tab == stayed
        controller.ui.showingTour = true
        let tourShielded = !controller.navigate(with: key("1", code: 18, flags: .command))
        controller.ui.showingTour = false
        controller.collapse()
        let closedShielded = !controller.navigate(with: key("1", code: 18, flags: .command))
        let navigation = jump && next && previous && rejectedZero && rejectedEight && tourShielded && closedShielded
        print("\(jump ? "PASS" : "FAIL") command-7 selects settings")
        print("\(next ? "PASS" : "FAIL") control-tab wraps to apps")
        print("\(previous ? "PASS" : "FAIL") control-shift-tab wraps to settings")
        print("\(rejectedZero && rejectedEight ? "PASS" : "FAIL") command-0 and command-8 do not change tabs")
        print("\(tourShielded && closedShielded ? "PASS" : "FAIL") inactive-panel and tour shield tab shortcuts")
        controller.panel.orderOut(nil)
        return compact && reopened && escaped && live && remembered && simulated && navigation
    }
}
#endif
