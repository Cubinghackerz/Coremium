import AppKit

/// Works around macOS fullscreen stutter on ProMotion Macs (worst on macOS 27).
///
/// Fullscreen Metal apps normally use "Direct-to-Display", which breaks frame pacing on 120 Hz MacBook Pros.
/// Any other window on screen makes macOS composite normally instead. This keeps a tiny always-on-top window
/// on every display, in every Space including fullscreen ones: inside the notch where there are no pixels, or a single
/// dark pixel in the top-left corner on screens without a notch. It ignores clicks and never takes focus.
@MainActor
final class FullscreenFix {
    private var windows: [NSWindow] = []
    private var timer: Timer?
    private var observer: NSObjectProtocol?

    /// True on macOS 27 and later, where the stutter is known to be much worse.
    static var isRecommended: Bool { ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 }

    var isEnabled: Bool { !windows.isEmpty }

    func setEnabled(_ enabled: Bool) {
        if enabled { start() } else { stop() }
    }

    private func start() {
        guard timer == nil else { return }
        rebuild()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.rebuild() } }
        // Re-order to front periodically so Space and fullscreen transitions can't bury it.
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.windows.forEach { $0.orderFrontRegardless() } }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    private func rebuild() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        for screen in NSScreen.screens {
            let frame = screen.frame
            let notched = screen.safeAreaInsets.top > 0
            let size: CGFloat = notched ? 2 : 1
            let x = notched ? frame.midX - size / 2 : frame.minX
            let rect = NSRect(x: x, y: frame.maxY - size, width: size, height: size)

            let window = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
            window.isOpaque = true
            window.backgroundColor = .black
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.setFrame(rect, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }
}
