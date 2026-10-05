import AppKit
import Combine
import SwiftUI

/// Borderless panel that never activates the app, floats above the menu bar and shows in every Space.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// AppKit normally pushes windows below the menu bar. The pill must sit flush with the top edge of the screen.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
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
    private var pinned = false
    private var cancellables = Set<AnyCancellable>()

    init(engine: AppEngine) {
        self.engine = engine
        let (screen, geometry) = NotchGeometry.current()
        self.screen = screen
        ui = NotchUIState(geometry: geometry)

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

        ui.onOnboardingFinished = { [weak self] in self?.collapse() }
        ui.onHide = { [weak self] in self?.collapse() }
        hostView.onEnter = { [weak self] in self?.hoverBegan() }
        hostView.onExit = { [weak self] in self?.hoverEnded() }

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.screenChanged() }.store(in: &cancellables)
        // While a boost app (a game) is in front, the pill ignores the mouse so it can never get in the way.
        engine.$boostAppFocused.sink { [weak self] focused in
            guard let self else { return }
            self.panel.ignoresMouseEvents = focused && !self.ui.expanded
        }.store(in: &cancellables)

        applyFrame(expanded: false)
        panel.orderFrontRegardless()
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
        if pinned { self.pinned = true }
        guard !ui.expanded else { return }
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
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.ui.expanded else { return }
            self.applyFrame(expanded: false)
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

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
        let size = expanded
            ? NotchLayout.expandedSize
            : CGSize(width: ui.geometry.collapsedWidth, height: ui.geometry.notchHeight)
        let frame = screen.frame
        let rect = NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
        panel.setFrame(rect, display: true)
    }
}
