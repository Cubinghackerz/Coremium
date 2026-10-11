import CoremiumCore
import SwiftUI

/// The busiest processes right now, with CPU and memory. Sampled every two seconds while this tab is open, and only
/// then. Coremium reads the process table itself; it never runs ps or top, and it changes nothing.
struct ActivityTab: View {
    let chip: ChipInfo
    @StateObject private var monitor: ActivityMonitor

    init(chip: ChipInfo, movedProcesses: @escaping @MainActor () -> Set<Int32>) {
        self.chip = chip
        _monitor = StateObject(wrappedValue: ActivityMonitor(logicalCPUs: chip.logicalCPUs, movedProvider: movedProcesses))
    }

    var body: some View {
        let snapshot = monitor.snapshot
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionLabel(text: "Activity")
                Spacer()
                Text("Every 2 s, only while open").font(.system(size: 10, design: .rounded)).foregroundColor(Theme.textDim)
            }
            HStack(spacing: 8) {
                summary("Processes", "\(snapshot.processCount)", "running")
                summary("CPU", String(format: "%.0f%%", snapshot.totalPercentOfMachine), "of \(chip.logicalCPUs) cores")
                let top = snapshot.processes.first
                summary("Busiest", top?.name ?? "–", top.map { String(format: "%.0f%% of a core", $0.cpuPercent) } ?? "")
            }
            header
            FlexScroll {
                VStack(spacing: 4) {
                    if snapshot.processes.isEmpty {
                        Text("Reading processes…").font(.system(size: 11, design: .rounded)).foregroundColor(Theme.textDim)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                    }
                    ForEach(snapshot.processes) { row($0) }
                }
            }
            Text("Each process is read once per sample. Nothing is sent anywhere, and nothing is changed.")
                .font(.system(size: 10, design: .rounded)).foregroundColor(Theme.textDim.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    private func summary(_ title: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 9.5, design: .rounded)).foregroundColor(Theme.textDim)
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.white).lineLimit(1).monospacedDigit()
            if !detail.isEmpty {
                Text(detail).font(.system(size: 9.5, design: .rounded)).foregroundColor(Theme.textDim).lineLimit(1)
            }
        }
        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.05)))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Process").frame(maxWidth: .infinity, alignment: .leading)
            Text("CPU").frame(width: 130, alignment: .trailing)
            Text("Memory").frame(width: 72, alignment: .trailing)
        }
        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
        .foregroundColor(Theme.textDim)
        .padding(.horizontal, 10)
    }

    private func row(_ process: ActivityProcess) -> some View {
        HStack(spacing: 8) {
            Text(process.name)
                .font(.system(size: 11.5, weight: .medium, design: .rounded)).foregroundColor(.white)
                .lineLimit(1).truncationMode(.middle)
            if process.isMoved { Tag(text: "Moved", color: Theme.eco) }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(Theme.yield).frame(width: 56 * CGFloat(min(process.cpuPercent, 100) / 100))
                }
                .frame(width: 56, height: 4)
                Text(String(format: "%.1f%%", process.cpuPercent))
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced)).foregroundColor(.white.opacity(0.9))
                    .frame(width: 50, alignment: .trailing)
            }
            .frame(width: 130, alignment: .trailing)
            Text(ByteCountFormatter.string(fromByteCount: Int64(process.memoryBytes), countStyle: .memory))
                .font(.system(size: 10.5, design: .monospaced)).foregroundColor(.white.opacity(0.75))
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.04)))
        .accessibilityElement(children: .combine)
    }
}
