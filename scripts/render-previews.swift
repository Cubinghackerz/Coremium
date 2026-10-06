// Renders the real SwiftUI views to PNG files, offscreen, with sample data. Never launches the app and never touches
// real settings (it uses a throwaway data folder). Used to check layouts for clipping and wrapping.
//
//   scripts/render-previews.sh <output folder>
import AppKit
import CoremiumCore
import SwiftUI

@main
struct RenderPreviews {
    @MainActor
    static func save<V: View>(_ view: V, name: String, width: CGFloat, height: CGFloat? = nil, dir: String) {
        let framed = Group {
            if let height { view.frame(width: width, height: height) } else { view.frame(width: width).fixedSize(horizontal: false, vertical: true) }
        }
        let renderer = ImageRenderer(content: framed.preferredColorScheme(.dark))
        renderer.scale = 2
        guard let cg = renderer.cgImage, let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
            print("FAILED \(name)"); return
        }
        try? png.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        print("ok \(name) \(cg.width / 2)x\(cg.height / 2)")
    }

    @MainActor
    static func main() async {
        _ = NSApplication.shared
        let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
        if CommandLine.arguments.contains("--profile-engine") {
            // The shell wrapper isolates all files; PREVIEW substitutes a backend that cannot change priorities.
            var rules = RuleSet.defaults
            rules.mode = .balanced
            rules.saveBatteryWhenUnplugged = false
            rules.keepDisplayAwakeDuringBoost = false
            SettingsStore.save(rules)
            let engine = AppEngine()
            let sampler = ProcessCPUSampler()
            let pid = ProcessInfo.processInfo.processIdentifier
            for phase in ["idle", "closed", "paused", "open"] {
                engine.paused = true
                engine.rules.mode = phase == "idle" ? .balanced : .automatic
                engine.isPanelExpanded = phase == "open"
                engine.paused = phase == "paused"
                // Exclude startup indexing and immediate mode-transition work from the steady-state interval.
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                let before = sampler.cpuNanos(of: pid) ?? 0
                let start = ProcessInfo.processInfo.systemUptime
                for _ in 0..<15 { try? await Task.sleep(nanoseconds: 1_000_000_000) }
                let elapsed = ProcessInfo.processInfo.systemUptime - start
                let cpu = Double((sampler.cpuNanos(of: pid) ?? before) - before) / 1e9 / elapsed * 100
                let mib = Double(ProcessCPUSampler.footprint(of: pid) ?? 0) / 1_048_576
                print(String(format: "PROFILE %@: %.3f%% of one CPU core, %.1f MiB footprint, %.1fs; session=%@; last tick %.2fms",
                    phase, cpu, mib, elapsed, engine.sessionActive.description, engine.tickMs))
                fflush(stdout)
            }
            engine.shutdown()
            print("Engine-only read-only profile; no native UI drawing or workload speed-up measured.")
            return
        }
        let engine = AppEngine(isPreview: true)
        if CommandLine.arguments.contains("--test-notch") {
            exit(await NotchController.runRegressionChecks(engine: engine) ? 0 : 1)
        }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        func installed(_ name: String, _ id: String, _ path: String, _ category: AppCategory) -> InstalledApp {
            InstalledApp(name: name, bundleID: id, path: path, category: category)
        }
        let apps = [
            installed("Roblox", "com.roblox.RobloxPlayer", "/Applications/Roblox.app", .game),
            installed("Google Chrome", "com.google.Chrome", "/Applications/Google Chrome.app", .browser),
            installed("Claude", "com.anthropic.claudefordesktop", "/Applications/Claude.app", .ai),
            installed("Diffusion Studio", "com.example.ds", "/Applications/Diffusion Studio.app", .creative),
            installed("Xcode", "com.apple.dt.Xcode", "/Applications/Xcode.app", .developer),
            installed("Discord", "com.hnc.Discord", "/Applications/Discord.app", .communication),
            installed("Spotify", "com.spotify.client", "/Applications/Spotify.app", .media),
            installed("LM Studio", "ai.elementlabs.lmstudio", "/Applications/LM Studio.app", .localAI),
        ]
        let rows: [AppRow] = [
            AppRow(id: "a", name: "Roblox", bundleID: "com.roblox.RobloxPlayer", path: apps[0].path, category: .game, override: nil, effective: .boost, demoted: false, cpu: 190),
            AppRow(id: "b", name: "Google Chrome", bundleID: "com.google.Chrome", path: apps[1].path, category: .browser, override: nil, effective: .auto, demoted: true, cpu: 67),
            AppRow(id: "c", name: "Claude", bundleID: "com.anthropic.claudefordesktop", path: apps[2].path, category: .ai, override: .normal, effective: .normal, demoted: false, cpu: 61),
            AppRow(id: "d", name: "Diffusion Studio", bundleID: "com.example.ds", path: apps[3].path, category: .creative, override: nil, effective: .auto, demoted: true, cpu: 62),
            AppRow(id: "e", name: "Discord with a very long name that must truncate nicely", bundleID: "com.hnc.Discord", path: apps[5].path, category: .communication, override: .efficiency, effective: .efficiency, demoted: true, cpu: 4),
            AppRow(id: "f", name: "Spotify", bundleID: "com.spotify.client", path: apps[6].path, category: .media, override: nil, effective: .normal, demoted: false, cpu: 1),
        ]
        var usage = UsageLedger()
        let now = Date()
        for offset in 0..<14 {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: now) else { continue }
            let sessions = offset % 3 == 0 ? 0 : 1 + offset % 4
            for _ in 0..<sessions { usage.record(at: day, seconds: 20, sessionActive: true, mode: .gaming, movedCoreSeconds: 0, movedProcesses: 0, hot: false, sessionStarted: true) }
            for _ in 0..<(sessions * 40) {
                usage.record(at: day, seconds: 5, sessionActive: true, mode: offset % 2 == 0 ? .gaming : .coding, movedCoreSeconds: 9 + Double(offset), movedProcesses: 10 + offset, hot: offset == 5, sessionStarted: false)
            }
        }
        let suggestions = [Suggestion(kind: .yield, bundleID: "com.example.sync", name: "Cloud Sync Helper", reason: "Kept about 1.4 cores busy in the background while you were boosting something."),
                           Suggestion(kind: .boost, bundleID: "com.example.render", name: "Render Pro", reason: "You spend a lot of focused time here and it works hard (about 2.3 cores).")]
        let loads = [0.2, 0.3, 0.1, 0.4, 0.8, 0.9, 0.95, 0.85, 0.6, 0.9, 0.3]
        engine.injectPreview(rows: rows, installed: apps, usage: usage, suggestions: suggestions, session: true,
                             boostName: "Roblox", demoted: 23, loads: loads)

        // Notch panel: every tab, normal and Advanced, plus the collapsed pill
        let geometry = NotchGeometry(hasNotch: true, notchWidth: 185, notchHeight: 32)
        let size = NotchLayout.expandedSize
        let suiteName = "Coremium.Previews.\(UUID().uuidString)"
        let previewDefaults = UserDefaults(suiteName: suiteName)!
        defer { previewDefaults.removePersistentDomain(forName: suiteName) }
        for advanced in [false, true] {
            for tab in NotchTab.allCases {
                let ui = NotchUIState(geometry: geometry, defaults: previewDefaults)
                ui.expanded = true
                ui.tab = tab
                ui.advanced = advanced
                save(ZStack(alignment: .top) { Color(white: 0.12); NotchRootView(engine: engine, ui: ui) }
                        .environment(\.renderFlat, true),
                     name: "notch-\(tab.rawValue)\(advanced ? "-advanced" : "")", width: size.width, height: size.height, dir: dir)
            }
        }
        let collapsed = NotchUIState(geometry: geometry, defaults: previewDefaults)
        save(ZStack(alignment: .top) { Color(white: 0.5); NotchRootView(engine: engine, ui: collapsed) },
             name: "notch-collapsed", width: 400, height: 60, dir: dir)
        for step in 0...5 {
            let ui = NotchUIState(geometry: geometry, defaults: previewDefaults)
            save(ZStack(alignment: .top) {
                    Color(white: 0.12)
                    ZStack(alignment: .top) {
                        NotchShape(bottomRadius: 34).fill(Color.black)
                        WelcomeTourView(engine: engine, ui: ui, initialStep: step, onFinish: {}).padding(.top, 34)
                    }
                    .frame(width: size.width, height: size.height)
                }
                .environment(\.renderFlat, true),
                name: "onboarding-\(step)", width: size.width, height: size.height, dir: dir)
        }
        let firstUse = NotchUIState(geometry: geometry, defaults: previewDefaults)
        firstUse.expanded = true
        firstUse.showingOnboarding = true
        save(NotchRootView(engine: engine, ui: firstUse).environment(\.renderFlat, true),
             name: "first-use-active", width: size.width, height: size.height, dir: dir)
        engine.injectPreview(rows: rows, installed: apps, usage: UsageLedger(), suggestions: [], session: false,
                             boostName: nil, demoted: 0, loads: loads)
        save(NotchRootView(engine: engine, ui: firstUse).environment(\.renderFlat, true),
             name: "first-use-idle", width: size.width, height: size.height, dir: dir)
    }
}
