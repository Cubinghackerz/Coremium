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
    private var dashboard: DashboardWindowController?
    private var cancellables = Set<AnyCancellable>()
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine = AppEngine()
        notch = NotchController(engine: engine)
        dashboard = DashboardWindowController(engine: engine)
        Automation.dashboard = dashboard
        // One surface at a time: the notch steps aside while the window is open and returns when it closes.
        // One click moves between the two: the notch's window button turns on window mode, the window's Notch button
        // turns it off and opens the notch. The choice is remembered.
        notch.ui.onSwitchSurface = { [weak self] in self?.engine.windowOnly = true }
        dashboard?.onSwitchToNotch = { [weak self] in
            guard let self else { return }
            self.engine.windowOnly = false
            self.dashboard?.closeIfOpen()
            self.notch.expand(pinned: true)
        }
        dashboard?.onVisibilityChange = { [weak self] open in
            guard let self else { return }
            self.notch.setEnabled(!open && !self.engine.windowOnly)
            self.applyActivationPolicy(windowOpen: open)
        }
        installMainMenu()

        engine.$rules.map(\.fullscreenFixEnabled).removeDuplicates()
            .sink { [weak self] enabled in self?.fullscreenFix.setEnabled(enabled) }.store(in: &cancellables)
        installStatusItem()
        // Window only: a normal app with a Dock icon, and no notch. Switching it on opens the window right away.
        engine.$windowOnly.removeDuplicates().sink { [weak self] on in
            guard let self else { return }
            self.applyStyle()
            if on, self.launched { self.dashboard?.show() }
        }.store(in: &cancellables)

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

        launched = true
        if engine.windowOnly {
            if notch.ui.onboardingCompleted { dashboard?.show() } else { dashboard?.showTour() }
        } else if !notch.ui.onboardingCompleted {
            notch.ui.showingOnboarding = true
            notch.expand(pinned: true)
        }
    }

    private var launched = false

    /// Dock icon and no notch in window-only mode; menu bar and notch otherwise.
    private func applyStyle() {
        let windowOnly = engine.windowOnly
        applyActivationPolicy()
        if windowOnly {
            notch.setEnabled(false)
        } else if !(dashboard?.isOpen ?? false) {
            notch.setEnabled(true)
        }
    }

    /// A Dock icon and the full menu bar while the window is open (always in window-only mode); otherwise Coremium
    /// lives in the notch and the menu-bar icon only.
    private func applyActivationPolicy(windowOpen: Bool? = nil) {
        let regular = engine.windowOnly || (windowOpen ?? dashboard?.isOpen ?? false)
        let policy: NSApplication.ActivationPolicy = regular ? .regular : .accessory
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
    }

    /// Opening Coremium again (Finder, Spotlight, the Dock icon) shows its window, or the notch panel in notch style.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if engine.windowOnly { dashboard?.show() } else { showPanel() }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) { engine.shutdown() }

    /// coremium://mode/gaming and friends (also used by `Coremium --mode` and Shortcuts).
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { Automation.handle(url) }
    }

    private func showTour() {
        if engine.windowOnly {
            dashboard?.showTour()
            return
        }
        dashboard?.closeIfOpen()
        notch.ui.showingOnboarding = false
        notch.ui.showingTour = true
        notch.expand(pinned: true)
    }

    /// The standard menus, shown while Coremium is a regular app (its window is open, or window-only mode).
    private func installMainMenu() {
        let mainMenu = NSMenu()
        func submenu(_ title: String, _ build: (NSMenu) -> Void) {
            let item = NSMenuItem()
            let menu = NSMenu(title: title)
            build(menu)
            item.submenu = menu
            mainMenu.addItem(item)
        }
        func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "",
                 _ modifiers: NSEvent.ModifierFlags = .command, target: AnyObject? = nil) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            item.target = target
            menu.addItem(item)
        }
        submenu("Coremium") { menu in
            add(menu, "About Coremium", #selector(NSApplication.orderFrontStandardAboutPanel(_:)))
            menu.addItem(.separator())
            add(menu, "Settings…", #selector(openSettings), ",", target: self)
            menu.addItem(.separator())
            add(menu, "Hide Coremium", #selector(NSApplication.hide(_:)), "h")
            add(menu, "Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option])
            add(menu, "Show All", #selector(NSApplication.unhideAllApplications(_:)))
            menu.addItem(.separator())
            add(menu, "Quit Coremium", #selector(quit), "q", target: self)
        }
        submenu("Edit") { menu in
            add(menu, "Undo", Selector(("undo:")), "z")
            add(menu, "Redo", Selector(("redo:")), "z", [.command, .shift])
            menu.addItem(.separator())
            add(menu, "Cut", #selector(NSText.cut(_:)), "x")
            add(menu, "Copy", #selector(NSText.copy(_:)), "c")
            add(menu, "Paste", #selector(NSText.paste(_:)), "v")
            add(menu, "Select All", #selector(NSText.selectAll(_:)), "a")
        }
        submenu("View") { menu in
            add(menu, "Advanced Mode", #selector(toggleWindowAdvanced), "a", [.command, .shift], target: self)
            menu.addItem(.separator())
            for tab in NotchTab.allCases {
                let item = NSMenuItem(title: tab.title, action: #selector(pickTab(_:)), keyEquivalent: "\(tab.shortcutNumber)")
                item.target = self
                item.representedObject = tab.rawValue
                menu.addItem(item)
            }
        }
        submenu("Window") { menu in
            add(menu, "Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
            add(menu, "Zoom", #selector(NSWindow.performZoom(_:)))
            add(menu, "Close", #selector(NSWindow.performClose(_:)), "w")
            menu.addItem(.separator())
            add(menu, "Bring All to Front", #selector(NSApplication.arrangeInFront(_:)))
            NSApp.windowsMenu = menu
        }
        submenu("Help") { menu in
            add(menu, "Coremium on GitHub", #selector(openHelp), target: self)
            NSApp.helpMenu = menu
        }
        NSApp.mainMenu = mainMenu
    }

    @objc private func openSettings() { dashboard?.show(tab: .settings) }
    @objc private func toggleWindowAdvanced() { dashboard?.toggleAdvanced() }
    @objc private func pickTab(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let tab = NotchTab(rawValue: raw) { dashboard?.show(tab: tab) }
    }
    @objc private func openHelp() {
        if let url = URL(string: "https://github.com/Cubinghackerz/Coremium") { NSWorkspace.shared.open(url) }
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
        if !engine.windowOnly {
            if notch.ui.expanded {
                menu.addItem(withTitle: "Hide Coremium", action: #selector(hidePanel), keyEquivalent: "").target = self
            } else {
                menu.addItem(withTitle: "Show Coremium", action: #selector(showPanel), keyEquivalent: "").target = self
            }
        }
        menu.addItem(withTitle: "Open Coremium Window", action: #selector(openWindow), keyEquivalent: "").target = self
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
        if !engine.windowOnly {
            addToggle(menu, "Show indicators in the notch", notch.ui.showIndicators, #selector(toggleIndicators))
        }
        addToggle(menu, "Window mode (no notch)", engine.windowOnly, #selector(toggleWindowOnly))
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

    @objc private func showPanel() {
        dashboard?.closeIfOpen()
        notch.expand(pinned: true)
    }
    @objc private func openWindow() { dashboard?.show() }
    @objc private func hidePanel() { notch.collapse() }
    @objc private func tour() { showTour() }
    @objc private func restoreAll() { engine.restoreAllNow() }
    @objc private func pickMode(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let mode = PerformanceMode(rawValue: raw) { engine.rules.mode = mode }
    }
    @objc private func toggleAdvanced() { notch.ui.advanced.toggle() }
    @objc private func toggleWindowOnly() { engine.windowOnly.toggle() }
    @objc private func toggleIndicators() { notch.ui.showIndicators.toggle() }
    @objc private func togglePause() { engine.paused.toggle() }
    @objc private func toggleFullscreenFix() { engine.rules.fullscreenFixEnabled.toggle() }
    @objc private func toggleLogin() { engine.setLaunchAtLogin(!engine.launchAtLogin) }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}
