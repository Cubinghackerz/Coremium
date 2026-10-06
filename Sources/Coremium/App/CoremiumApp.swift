import AppKit
import Combine
import CoremiumCore

@main
enum CoremiumMain {
    static func main() {
        // Emergency recovery: `Coremium.app/Contents/MacOS/Coremium --restore-all` puts every app Coremium slowed back
        // to full speed and exits without showing any UI.
        // Command line: `Coremium --mode gaming`, `--pause`, `--resume`, `--open storage`. Forwarded as a coremium:// link.
        let cli = CommandLine.arguments
        for (flag, route) in [("--mode", "mode"), ("--open", "open"), ("--pause", "pause"), ("--resume", "resume")] {
            guard let index = cli.firstIndex(of: flag) else { continue }
            let value = (route == "mode" || route == "open") ? cli.dropFirst(index + 1).first.map { "/" + $0 } ?? "" : ""
            if let url = URL(string: "coremium://\(route)\(value)") {
                NSWorkspace.shared.open(url)
                print("Coremium: sent \(url.absoluteString)")
            }
            exit(0)
        }
        if CommandLine.arguments.contains("--restore-all") {
            let controller = PriorityController(ledger: DemotionLedger(url: SettingsStore.ledgerURL))
            let count = controller.demotedPids.count
            controller.restoreAll()
            print("Coremium: restored \(count) process(es) to normal priority.")
            exit(0)
        }
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            AppDelegate.retained = delegate
            app.delegate = delegate
            app.setActivationPolicy(.accessory)   // lives in the notch and menu bar: no Dock icon
            app.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static var retained: AppDelegate?

    private var engine: AppEngine!
    private var notch: NotchController!
    private let fullscreenFix = FullscreenFix()
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine = AppEngine()
        notch = NotchController(engine: engine)

        engine.$rules.map(\.fullscreenFixEnabled).removeDuplicates()
            .sink { [weak self] enabled in self?.fullscreenFix.setEnabled(enabled) }.store(in: &cancellables)
        installStatusItem()

        // Restore every app to full speed if we are asked to quit by the system or from a terminal.
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { NSApplication.shared.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }

        Updater.shared.start()
        Automation.engine = engine
        Automation.notch = notch

        // First launch: open the welcome tour in the notch.
        if !notch.ui.onboardingCompleted { showTour() }
    }

    func applicationWillTerminate(_ notification: Notification) { engine.shutdown() }

    /// coremium://mode/gaming and friends (also used by `Coremium --mode` and Shortcuts).
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { Automation.handle(url) }
    }

    private func showTour() {
        notch.ui.showingOnboarding = true
        notch.expand(pinned: true)
    }

    // MARK: - Menu bar item

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "Coremium")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(withTitle: engine.statusLine, action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())
        if notch.ui.expanded {
            menu.addItem(withTitle: "Hide Coremium", action: #selector(hidePanel), keyEquivalent: "").target = self
        } else {
            menu.addItem(withTitle: "Show Coremium", action: #selector(showPanel), keyEquivalent: "").target = self
        }
        let modes = NSMenu()
        for mode in PerformanceMode.allCases {
            let entry = NSMenuItem(title: mode.label, action: #selector(pickMode(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = mode.rawValue
            entry.state = engine.rules.mode == mode ? .on : .off
            modes.addItem(entry)
        }
        let modeItem = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        modeItem.submenu = modes
        menu.addItem(modeItem)
        addToggle(menu, "Advanced mode", notch.ui.advanced, #selector(toggleAdvanced))
        addToggle(menu, "Show indicators in the notch", notch.ui.showIndicators, #selector(toggleIndicators))
        addToggle(menu, "Pause Coremium", engine.paused, #selector(togglePause))
        addToggle(menu, FullscreenFix.isRecommended ? "Fullscreen fix (recommended)" : "Fullscreen fix (experimental)",
                  engine.rules.fullscreenFixEnabled, #selector(toggleFullscreenFix))
        addToggle(menu, "Open at login", engine.launchAtLogin, #selector(toggleLogin))
        menu.addItem(.separator())
        if let info = Updater.shared.available {
            menu.addItem(withTitle: "Update to Coremium \(info.version)…", action: #selector(update), keyEquivalent: "").target = self
        }
        menu.addItem(withTitle: "Welcome tour", action: #selector(tour), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Restore all apps now", action: #selector(restoreAll), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Coremium", action: #selector(quit), keyEquivalent: "q").target = self
    }

    @objc private func update() { Updater.shared.install() }

    private func addToggle(_ menu: NSMenu, _ title: String, _ on: Bool, _ action: Selector) {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        entry.state = on ? .on : .off
        menu.addItem(entry)
    }

    @objc private func showPanel() { notch.expand(pinned: true) }
    @objc private func hidePanel() { notch.collapse() }
    @objc private func tour() { showTour() }
    @objc private func restoreAll() { engine.restoreAllNow() }
    @objc private func pickMode(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let mode = PerformanceMode(rawValue: raw) { engine.rules.mode = mode }
    }
    @objc private func toggleAdvanced() { notch.ui.advanced.toggle() }
    @objc private func toggleIndicators() { notch.ui.showIndicators.toggle() }
    @objc private func togglePause() { engine.paused.toggle() }
    @objc private func toggleFullscreenFix() { engine.rules.fullscreenFixEnabled.toggle() }
    @objc private func toggleLogin() { engine.setLaunchAtLogin(!engine.launchAtLogin) }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}
