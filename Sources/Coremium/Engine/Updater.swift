import AppKit
import CoremiumCore
import CryptoKit

/// Checks GitHub once a day for a newer Coremium and, when you agree, installs it: downloads the zip, verifies its
/// SHA-256 against the published checksum, swaps the app and relaunches. This is Coremium's only network access, and it
/// can be turned off in Settings.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    @Published private(set) var available: ReleaseInfo?
    @Published private(set) var state = ""
    @Published var enabled: Bool { didSet { UserDefaults.standard.set(enabled, forKey: "updateChecks") } }
    private var timer: Timer?

    var current: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }

    private init() {
        enabled = UserDefaults.standard.object(forKey: "updateChecks") as? Bool ?? true
    }

    func start() {
        guard timer == nil else { return }
        check()
        let t = Timer(timeInterval: 24 * 3600, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.check() } }
        t.tolerance = 3600
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func check() {
        guard enabled else { return }
        Task { @MainActor in
            var request = URLRequest(url: UpdateCheck.latestAPI, timeoutInterval: 20)
            request.setValue("Coremium/\(current)", forHTTPHeaderField: "User-Agent")
            guard let (data, _) = try? await URLSession.shared.data(for: request),
                  let info = UpdateCheck.parse(data), UpdateCheck.isNewer(info.version, than: current) else { return }
            if available != info { available = info }
        }
    }

    func install() {
        guard let info = available, state.isEmpty || state.hasPrefix("Update failed") else { return }
        state = "Downloading \(info.version)…"
        Task { @MainActor in
            do {
                let (zipFile, _) = try await URLSession.shared.download(from: info.zipURL)
                let (sumsData, _) = try await URLSession.shared.data(from: info.checksumURL)
                let expected = UpdateCheck.checksum(for: info.zipURL.lastPathComponent, in: String(decoding: sumsData, as: UTF8.self))
                let actual = SHA256.hash(data: try Data(contentsOf: zipFile)).map { String(format: "%02x", $0) }.joined()
                guard let expected, expected == actual else { state = "Update failed: checksum mismatch. Nothing was changed."; return }
                state = "Installing…"
                let work = FileManager.default.temporaryDirectory.appendingPathComponent("coremium-update-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
                try run("/usr/bin/ditto", ["-x", "-k", zipFile.path, work.path])
                let newApp = work.appendingPathComponent("Coremium.app")
                guard FileManager.default.fileExists(atPath: newApp.path) else { state = "Update failed: the download had no app."; return }
                relaunch(replacing: Bundle.main.bundleURL, with: newApp)
            } catch {
                state = "Update failed: \(error.localizedDescription)"
            }
        }
    }

    /// A tiny detached shell waits for Coremium to quit (which restores every app), swaps the bundle and reopens it.
    private func relaunch(replacing target: URL, with newApp: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        rm -rf "\(target.path)" && /usr/bin/ditto "\(newApp.path)" "\(target.path)" && open "\(target.path)"
        """
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments = ["-c", script]
        try? shell.run()
        NSApp.terminate(nil)
    }

    private func run(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 { throw CocoaError(.fileWriteUnknown) }
    }
}
