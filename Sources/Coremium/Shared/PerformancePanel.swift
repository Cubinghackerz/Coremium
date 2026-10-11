import CoremiumCore
import SwiftUI

/// The live CPU, GPU and memory graphs. Shows the last 2 minutes (one point a second) or the last 30 minutes
/// (one averaged point per 10 seconds). Every number on it is a measurement; nothing is modelled.
struct PerformancePanel: View {
    @ObservedObject var telemetry: TelemetryStore
    let chip: ChipInfo
    /// Total memory, to turn bytes into a share of the full scale.
    let memoryTotal: UInt64
    /// Display names for the apps in the GPU chart, by bundle id. Unknown apps show their id.
    var names: [String: String] = [:]

    @State private var span: Span

    init(telemetry: TelemetryStore, chip: ChipInfo, memoryTotal: UInt64, names: [String: String] = [:], initialSpan: Span = .live) {
        self.telemetry = telemetry
        self.chip = chip
        self.memoryTotal = memoryTotal
        self.names = names
        _span = State(initialValue: initialSpan)
    }

    enum Span: String, CaseIterable, Identifiable {
        case live = "2 min"
        case history = "30 min"
        var id: String { rawValue }
        var capacity: Int { self == .live ? 120 : 180 }
    }

    var body: some View {
        let entries = span == .live ? telemetry.history.fineEntries : telemetry.history.coarseEntries
        let capacity = span.capacity
        let cores = coreRows()
        let appKeys = topAppKeys(entries)
        let gpuLegend = gpuLegendItems(appKeys)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Performance")
                Spacer()
                Picker("Time span", selection: $span) {
                    ForEach(Span.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150)
            }

            card(title: "CPU", legend: [("Performance cores", Theme.yield), ("Efficiency cores", Theme.eco)]) {
                CoreHeatStrip(entries: entries, capacity: capacity, rows: cores)
                    .frame(height: max(CGFloat(cores.count) * 9, 40))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Load of each CPU core, performance cores first")
                    .accessibilityValue(ChartSlots.summary(entries) { sample in
                        let loads = sample.coreLoads
                        return loads.isEmpty ? nil : loads.reduce(0, +) / Double(loads.count)
                    })
                ZStack(alignment: .bottom) {
                    LineChart(entries: entries, capacity: capacity, series: [
                        LineSeries(name: "Performance average", color: Theme.yield) { average($0, chip.performanceCPUs) },
                        LineSeries(name: "Efficiency average", color: Theme.eco) { average($0, chip.efficiencyCPUs) },
                    ], references: [0.85])
                    SessionMarks(entries: entries, capacity: capacity)
                }
                .frame(height: 64)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Performance-core average load")
                .accessibilityValue(ChartSlots.summary(entries) { average($0, chip.performanceCPUs) })
            }

            card(title: "GPU", legend: gpuLegend) {
                ZStack(alignment: .bottom) {
                    LineChart(entries: entries, capacity: capacity, series: [
                        LineSeries(name: "GPU", color: Theme.gpu) { sample in sample.gpuPercent.map { $0 / 100 } },
                    ])
                    StackedShareArea(entries: entries, capacity: capacity, keys: appKeys + [TelemetryBuilder.otherKey],
                                     color: { index in index < appKeys.count ? shade(index) : Color.white.opacity(0.2) },
                                     share: { sample, key in (sample.appGPUPercent[key] ?? 0) }
                    ).opacity(0.9)
                    SessionMarks(entries: entries, capacity: capacity)
                }
                .frame(height: 72)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("GPU utilisation, and each app's share of it")
                .accessibilityValue(ChartSlots.summary(entries) { sample in sample.gpuPercent.map { $0 / 100 } })
            }

            card(title: "Memory", legend: [("Used", Color.white.opacity(0.85)), ("Swap", Theme.warn)]) {
                ZStack(alignment: .bottom) {
                    LineChart(entries: entries, capacity: capacity, series: [
                        LineSeries(name: "Used", color: Color.white.opacity(0.85)) { sample in share(sample.memoryUsedBytes) },
                        LineSeries(name: "Swap", color: Theme.warn) { sample in share(sample.swapBytes) },
                    ])
                    SessionMarks(entries: entries, capacity: capacity)
                }
                .frame(height: 56)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Memory in use, as a share of total memory")
                .accessibilityValue(ChartSlots.summary(entries) { share($0.memoryUsedBytes) })
            }
        }
    }

    /// Performance cores first, then efficiency cores, one row each.
    private func coreRows() -> [(cpu: Int, performance: Bool)] {
        var rows: [(cpu: Int, performance: Bool)] = []
        for cpu in chip.performanceCPUs { rows.append((cpu: cpu, performance: true)) }
        for cpu in chip.efficiencyCPUs { rows.append((cpu: cpu, performance: false)) }
        return rows
    }

    private func gpuLegendItems(_ appKeys: [String]) -> [(String, Color)] {
        var items: [(String, Color)] = [("GPU", Theme.gpu)]
        for (index, key) in appKeys.enumerated() { items.append((names[key] ?? key, shade(index))) }
        if !appKeys.isEmpty { items.append(("Other", Color.white.opacity(0.2))) }
        return items
    }

    private func card<Content: View>(title: String, legend: [(String, Color)], @ViewBuilder content: () -> Content) -> some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text(title).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(.white)
                    Spacer(minLength: 8)
                    ForEach(Array(legend.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 4) {
                            Circle().fill(item.1).frame(width: 6, height: 6)
                            Text(item.0).font(.system(size: 9.5, design: .rounded)).foregroundColor(Theme.textDim).lineLimit(1)
                        }
                    }
                }
                content()
            }
        }
    }

    private func average(_ sample: TelemetrySample, _ cpus: [Int]) -> Double? {
        let values = cpus.compactMap { $0 < sample.coreLoads.count ? sample.coreLoads[$0] : nil }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    private func share(_ bytes: UInt64?) -> Double? {
        guard let bytes, memoryTotal > 0 else { return nil }
        return min(Double(bytes) / Double(memoryTotal), 1)
    }

    /// The apps with the largest GPU share across the visible history, busiest first (at most five).
    private func topAppKeys(_ entries: [TelemetryEntry]) -> [String] {
        var totals: [String: Double] = [:]
        for case let .sample(sample) in entries {
            for (key, value) in sample.appGPUPercent where key != TelemetryBuilder.otherKey { totals[key, default: 0] += value }
        }
        return totals.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(5).map(\.key)
    }

    private func shade(_ index: Int) -> Color {
        Theme.gpu.opacity([1.0, 0.75, 0.55, 0.4, 0.28][min(index, 4)])
    }
}
