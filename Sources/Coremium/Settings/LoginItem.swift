import Foundation
import ServiceManagement

/// "Open at login". Uses SMAppService; if that is refused for an ad-hoc signed build,
/// falls back to a plain LaunchAgent in ~/Library/LaunchAgents.
enum LoginItem {
    private static let label = "com.cubinghackerz.coremium"

    private static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled || FileManager.default.fileExists(atPath: agentURL.path)
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        if enabled {
            do {
                try SMAppService.mainApp.register()
                return true
            } catch {
                return writeAgent()
            }
        }
        try? SMAppService.mainApp.unregister()
        try? FileManager.default.removeItem(at: agentURL)
        return true
    }

    private static func writeAgent() -> Bool {
        guard let executable = Bundle.main.executablePath else { return false }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
        ]
        do {
            try FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: agentURL, options: .atomic)
            return true
        } catch {
            NSLog("Coremium: could not enable launch at login: \(error)")
            return false
        }
    }
}
