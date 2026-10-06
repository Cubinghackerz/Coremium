import AppKit
import CoremiumCore
import SwiftUI

/// Your own background helpers (~/Library/LaunchAgents): what starts with your account, and a reversible switch for each.
@MainActor
final class StartupModel: ObservableObject {
    static let shared = StartupModel()
    @Published var agents: [LaunchAgent] = []
    @Published var disabled: Set<String> = []
    @Published var running: [String: Int32] = [:]
    @Published var message = ""

    func refresh() {
        agents = LaunchAgents.list()
        let uid = getuid()
        disabled = LaunchAgents.disabledLabels(fromPrintDisabled: Self.run(["print-disabled", "gui/\(uid)"]))
        var pids: [String: Int32] = [:]
        for line in Self.run(["list"]).split(whereSeparator: \.isNewline).dropFirst() {
            let f = line.split(separator: "\t")
            if f.count == 3, let pid = Int32(f[0]) { pids[String(f[2])] = pid }
        }
        running = pids
    }

    /// Off = stop it now and keep it from starting at login. On = allow it and start it again. Both are reversible.
    func set(_ agent: LaunchAgent, on: Bool) {
        let target = "gui/\(getuid())/\(agent.label)"
        if on {
            _ = Self.run(["enable", target])
            _ = Self.run(["bootstrap", "gui/\(getuid())", agent.plistPath])
            message = "\(agent.displayName) will start with your account again."
        } else {
            _ = Self.run(["bootout", target])
            _ = Self.run(["disable", target])
            message = "\(agent.displayName) is off and won't start at login. Turn it back on any time."
        }
        refresh()
    }

    @discardableResult
    static func run(_ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        guard (try? p.run()) != nil else { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}

struct SystemTab: View {
    @ObservedObject var engine: AppEngine
    @ObservedObject var ui: NotchUIState
    @ObservedObject private var startup = StartupModel.shared
    @State private var confirmQuit: Int32?

    var body: some View {
        FlexScroll {
            VStack(alignment: .leading, spacing: 10) {
                memoryCard
                startupCard
            }
        }
        .onAppear { startup.refresh() }
    }

    private var memoryCard: some View {
        let m = engine.memory
        let used = m.totalBytes > 0 ? Double(m.usedBytes) / Double(m.totalBytes) : 0
        let pressureColor: Color = m.pressure == .normal ? Theme.good : Theme.warn
        return Card(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(text: "Memory")
                    Spacer()
                    Text("Pressure: \(m.pressure.rawValue)").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(pressureColor)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.07))
                        Capsule().fill(Color.white.opacity(0.85)).frame(width: proxy.size.width * CGFloat(used))
                    }
                }.frame(height: 6)
                HStack(spacing: 14) {
                    stat("Used", bytes(m.usedBytes) + " of " + bytes(m.totalBytes))
                    stat("Swap", m.swapUsedBytes < 1_048_576 ? "none" : bytes(m.swapUsedBytes))
                    if engine.sessionActive { stat("Swap this boost", engine.swapGrowth == 0 ? "none" : "+" + bytes(engine.swapGrowth)) }
                }
                Text(m.pressure == .normal
                     ? "Your Mac has room to spare. Apps using the most memory:"
                     : "Memory is tight, so macOS is compressing and swapping. Hiding a big app helps a little; quitting one you don't need helps most:")
                    .font(.system(size: 11, design: .rounded)).foregroundColor(Theme.textDim).fixedSize(horizontal: false, vertical: true)
                ForEach(engine.memoryHogs) { hog in hogRow(hog) }
                if engine.memoryHogs.isEmpty {
                    Text("No app is using more than 300 MB.").font(.system(size: 11, design: .rounded)).foregroundColor(Theme.textDim)
                }
            }
        }
    }

    private func hogRow(_ hog: MemoryHog) -> some View {
        let app = NSRunningApplication(processIdentifier: hog.pid)
        return HStack(spacing: 8) {
            AppIconView(path: app?.bundleURL?.path)
            Text(hog.name).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.white).lineLimit(1)
            Spacer(minLength: 6)
            Text(bytes(hog.bytes)).font(.system(size: 11.5, weight: .semibold, design: .rounded)).monospacedDigit().foregroundColor(.white.opacity(0.8))
            Button("Hide") { app?.hide() }.buttonStyle(.plain).font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7)).help("Hidden apps stop drawing, which frees a little memory and CPU. Nothing is closed.")
            if confirmQuit == hog.pid {
                Button("Quit \(hog.name)?") { app?.terminate(); confirmQuit = nil }
                    .buttonStyle(.plain).font(.system(size: 10.5, weight: .bold, design: .rounded)).foregroundColor(Theme.warn)
                    .help("Asks the app to quit normally, so it can ask you to save first.")
            } else {
                Button("Quit…") { confirmQuit = hog.pid }.buttonStyle(.plain).font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.04)))
    }

    private var startupCard: some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "Starts with your account")
                    Spacer()
                    Button("Login Items…") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
                    }.buttonStyle(.plain).font(.system(size: 10.5, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.7))
                }
                Text("Background helpers in your own LaunchAgents folder. Turning one off stops it and keeps it from starting at login; you can turn it back on any time. Apps' own login items are in System Settings.")
                    .font(.system(size: 11, design: .rounded)).foregroundColor(Theme.textDim).fixedSize(horizontal: false, vertical: true)
                ForEach(startup.agents) { agent in agentRow(agent) }
                if startup.agents.isEmpty {
                    Text("Nothing here: no helpers start from your LaunchAgents folder.").font(.system(size: 11, design: .rounded)).foregroundColor(Theme.textDim)
                }
                if !startup.message.isEmpty {
                    Text(startup.message).font(.system(size: 10.5, design: .rounded)).foregroundColor(Theme.good)
                }
            }
        }
    }

    private func agentRow(_ agent: LaunchAgent) -> some View {
        let off = startup.disabled.contains(agent.label)
        let pid = startup.running[agent.label]
        return HStack(spacing: 8) {
            Circle().fill(pid != nil ? Theme.good : Color.white.opacity(0.2)).frame(width: 6, height: 6)
                .help(pid != nil ? "Running" : "Not running")
            VStack(alignment: .leading, spacing: 0) {
                Text(agent.displayName).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.white).lineLimit(1)
                Text(ui.advanced ? agent.label : (agent.runAtLoad ? "Starts at login" : "Starts when needed") + (agent.keepAlive ? " · restarts itself" : ""))
                    .font(.system(size: 10, design: ui.advanced ? .monospaced : .rounded)).foregroundColor(Theme.textDim).lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { !off }, set: { startup.set(agent, on: $0) })).labelsHidden().toggleStyle(.switch)
                .controlSize(.mini).tint(Theme.good)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(size: 12.5, weight: .semibold, design: .rounded)).monospacedDigit().foregroundColor(.white)
            Text(title).font(.system(size: 9.5, design: .rounded)).foregroundColor(Theme.textDim)
        }
    }

    private func bytes(_ b: UInt64) -> String { ByteCountFormatter.string(fromByteCount: Int64(b), countStyle: .memory) }
}
