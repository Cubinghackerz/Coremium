import Foundation

/// A background helper that starts with your account (a plist in ~/Library/LaunchAgents).
public struct LaunchAgent: Identifiable, Equatable, Sendable {
    public var id: String { label }
    public let label: String
    public let plistPath: String
    public let program: String
    public let runAtLoad: Bool
    public let keepAlive: Bool

    /// A readable name: the app or tool it runs, else the label.
    public var displayName: String {
        let tool = URL(fileURLWithPath: program).lastPathComponent
        if let range = program.range(of: ".app/") {
            return URL(fileURLWithPath: String(program[..<range.lowerBound])).lastPathComponent
        }
        return tool.isEmpty ? label : tool
    }
}

public enum LaunchAgents {
    public static func folder(home: URL = URL(fileURLWithPath: NSHomeDirectory())) -> URL {
        home.appendingPathComponent("Library/LaunchAgents")
    }

    public static func parse(plist url: URL) -> LaunchAgent? {
        guard let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let label = dict["Label"] as? String else { return nil }
        let program = (dict["Program"] as? String) ?? ((dict["ProgramArguments"] as? [String])?.first ?? "")
        let keepAlive: Bool = (dict["KeepAlive"] as? Bool) ?? (dict["KeepAlive"] is [String: Any])
        return LaunchAgent(label: label, plistPath: url.path, program: program,
                           runAtLoad: dict["RunAtLoad"] as? Bool ?? false, keepAlive: keepAlive)
    }

    /// Your own agents, excluding Coremium's. Read-only.
    public static func list(home: URL = URL(fileURLWithPath: NSHomeDirectory())) -> [LaunchAgent] {
        let dir = folder(home: home)
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "plist" }.compactMap(parse(plist:))
            .filter { !$0.label.lowercased().contains("coremium") }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Labels from `launchctl print-disabled gui/<uid>` output that are disabled.
    public static func disabledLabels(fromPrintDisabled output: String) -> Set<String> {
        var result = Set<String>()
        for line in output.split(whereSeparator: \.isNewline) {
            let text = line.trimmingCharacters(in: .whitespaces)
            guard text.hasPrefix("\""), text.hasSuffix("disabled") || text.contains("=> true") || text.contains("=> disabled") else { continue }
            if let end = text.dropFirst().firstIndex(of: "\"") { result.insert(String(text[text.index(after: text.startIndex)..<end])) }
        }
        return result
    }
}
