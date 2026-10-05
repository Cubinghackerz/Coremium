import CoremiumCore
import Foundation

/// Reads and writes `~/Library/Application Support/Coremium/settings.json`.
enum SettingsStore {
    static var directory: URL {
        // Tests and the preview renderer point this at a throwaway folder so they never touch real data.
        if let override = ProcessInfo.processInfo.environment["COREMIUM_DATA_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Coremium", isDirectory: true)
    }

    static var settingsURL: URL { directory.appendingPathComponent("settings.json") }
    static var ledgerURL: URL { directory.appendingPathComponent("demoted.json") }
    static var indexURL: URL { directory.appendingPathComponent("app-index.json") }
    static var usageURL: URL { directory.appendingPathComponent("usage.json") }
    static var learningURL: URL { directory.appendingPathComponent("learning.json") }

    static func load() -> RuleSet {
        guard let data = try? Data(contentsOf: settingsURL),
              let rules = try? JSONDecoder().decode(RuleSet.self, from: data) else { return .defaults }
        return rules
    }

    static func save(_ rules: RuleSet) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(rules).write(to: settingsURL, options: .atomic)
        } catch {
            NSLog("Coremium: could not save settings: \(error)")
        }
    }
}
