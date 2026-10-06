import AppKit
import CoremiumCore

/// Works around macOS fullscreen stutter on ProMotion Macs (worst on macOS 27).
///
/// Fullscreen Metal apps normally use "Direct-to-Display", which breaks frame pacing on 120 Hz MacBook Pros.
/// Any other window on screen makes macOS composite normally instead. While a display shows a fullscreen app, this
/// keeps a tiny window on top of it: inside the notch where there are no pixels, or a single dark pixel in the
/// top-left corner on screens without a notch. It ignores clicks and never takes focus.
///
/// Displays with no fullscreen app get nothing, so ordinary windows move, tile and resize exactly as stock macOS.
@MainActor
final class FullscreenFix {
    private var windows: [CGDirectDisplayID: NSWindow] = [:]
    private var enabled = false
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    /// Runs only while a fullscreen app is showing, to notice it leaving and to keep the window above it.
    private var watchTimer: Timer?
    private var pendingChecks: [DispatchWorkItem] = []

    /// True on macOS 27 and later, where the stutter is known to be much worse.
    static var isRecommended: Bool { ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 }

    var isEnabled: Bool { enabled }

    func setEnabled(_ enabled: Bool) {
        if enabled { start() } else { stop() }
    }

    private func start() {
        guard !enabled else { return }
        enabled = true
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            observe(workspace, name)
        }
        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification)
        update()
    }

    private func stop() {
        guard enabled else { return }
        enabled = false
        observers.forEach { center, token in center.removeObserver(token) }
        observers.removeAll()
        pendingChecks.forEach { $0.cancel() }
        pendingChecks.removeAll()
        setWatching(false)
        windows.values.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleChecks() }
        }
        observers.append((center, token))
    }

    /// Fullscreen transitions animate for about a second, and games often resize just after they activate,
    /// so look again shortly after each event rather than polling all the time.
    private func scheduleChecks() {
        pendingChecks.forEach { $0.cancel() }
        pendingChecks = [0.0, 0.8, 2.0].map { delay in
            let item = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.update() } }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return item
        }
    }

    private func update() {
        guard enabled else { return }
        let screens = NSScreen.screens.compactMap { screen -> (CGDirectDisplayID, NSScreen)? in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            return (CGDirectDisplayID(id.uint32Value), screen)
        }
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let covered = FullscreenDetection.coveredDisplays(
            windows: FullscreenDetection.snapshots(from: info),
            displays: screens.map { CGDisplayBounds($0.0) },
            ownPID: ProcessInfo.processInfo.processIdentifier)
        let wanted = Set(covered.map { screens[$0].0 })

        for (id, window) in windows where !wanted.contains(id) {
            window.orderOut(nil)
            windows[id] = nil
        }
        for (id, screen) in screens where wanted.contains(id) {
            let window = windows[id] ?? makeWindow()
            windows[id] = window
            let rect = Self.rect(on: screen)
            if window.frame != rect { window.setFrame(rect, display: true) }
            window.orderFrontRegardless()
        }
        setWatching(!windows.isEmpty)
    }

    private func setWatching(_ on: Bool) {
        if on, watchTimer == nil {
            let timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.update() }
            }
            timer.tolerance = 1
            watchTimer = timer
        } else if !on {
            watchTimer?.invalidate()
            watchTimer = nil
        }
    }

    private static func rect(on screen: NSScreen) -> NSRect {
        let frame = screen.frame
        let notched = screen.safeAreaInsets.top > 0
        let size: CGFloat = notched ? 2 : 1
        let x = notched ? frame.midX - size / 2 : frame.minX
        return NSRect(x: x, y: frame.maxY - size, width: size, height: size)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1), styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        return window
    }
}
