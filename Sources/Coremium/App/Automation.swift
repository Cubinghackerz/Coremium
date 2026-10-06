import AppIntents
import AppKit
import CoremiumCore

/// One entry point for every automation route: coremium:// links, the command line, and Shortcuts.
@MainActor
enum Automation {
    static weak var engine: AppEngine?
    static weak var notch: NotchController?

    /// coremium://mode/gaming, coremium://pause, coremium://resume, coremium://open, coremium://open/storage
    @discardableResult
    static func handle(_ url: URL) -> Bool {
        guard url.scheme == "coremium", let engine else { return false }
        let action = url.host ?? ""
        let argument = url.pathComponents.dropFirst().first?.lowercased()
        switch action {
        case "mode":
            guard let argument, let mode = mode(named: argument) else { return false }
            engine.rules.mode = mode
        case "pause": engine.paused = true
        case "resume": engine.paused = false
        case "open":
            if let argument, let tab = NotchTab.allCases.first(where: { $0.rawValue == argument }) { notch?.ui.tab = tab }
            notch?.expand(pinned: true)
        default: return false
        }
        return true
    }

    static func mode(named name: String) -> PerformanceMode? {
        let key = name.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        if key == "creator" { return .professional }
        if key == "localai" || key == "ai" { return .localAI }
        return PerformanceMode.allCases.first { $0.rawValue.lowercased() == key || $0.label.lowercased().replacingOccurrences(of: " ", with: "") == key }
    }
}

// MARK: - Shortcuts

enum CoremiumModeChoice: String, AppEnum {
    case automatic, balanced, gaming, creator, coding, localAI

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Coremium mode")
    static var caseDisplayRepresentations: [CoremiumModeChoice: DisplayRepresentation] = [
        .automatic: "Automatic", .balanced: "Balanced", .gaming: "Gaming", .creator: "Creator", .coding: "Coding", .localAI: "Local AI",
    ]
}

struct SetCoremiumModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Coremium mode"
    static var description = IntentDescription("Switches Coremium to a performance mode.")
    @Parameter(title: "Mode") var mode: CoremiumModeChoice

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = Automation.handle(URL(string: "coremium://mode/\(mode.rawValue)")!)
        return .result()
    }
}

struct PauseCoremiumIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Coremium"
    static var description = IntentDescription("Puts every app back to macOS default scheduling until resumed.")
    @MainActor func perform() async throws -> some IntentResult { _ = Automation.handle(URL(string: "coremium://pause")!); return .result() }
}

struct ResumeCoremiumIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Coremium"
    @MainActor func perform() async throws -> some IntentResult { _ = Automation.handle(URL(string: "coremium://resume")!); return .result() }
}

struct CoremiumShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SetCoremiumModeIntent(), phrases: ["Set \(.applicationName) mode"], shortTitle: "Set mode", systemImageName: "cpu")
        AppShortcut(intent: PauseCoremiumIntent(), phrases: ["Pause \(.applicationName)"], shortTitle: "Pause", systemImageName: "pause.circle")
        AppShortcut(intent: ResumeCoremiumIntent(), phrases: ["Resume \(.applicationName)"], shortTitle: "Resume", systemImageName: "play.circle")
    }
}
