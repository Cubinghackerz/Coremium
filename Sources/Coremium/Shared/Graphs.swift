import CoremiumCore
import SwiftUI

/// Charts drawn from the in-memory history with Canvas. Entries sit in fixed time slots with the newest on the right,
/// so the time axis never stretches while the history fills. Gaps (the window was closed) are left blank, never bridged.
enum ChartSlots {
    /// The most recent `capacity` entries with their slot numbers (0 is the oldest slot).
    static func placed(_ entries: [TelemetryEntry], capacity: Int) -> [(slot: Int, entry: TelemetryEntry)] {
        let visible = entries.suffix(capacity)
        let first = capacity - visible.count
        return visible.enumerated().map { offset, entry in (slot: first + offset, entry: entry) }
    }

    /// Plain-words summary for VoiceOver: the latest reading and the peak, as percentages of the full scale.
    static func summary(_ entries: [TelemetryEntry], value: (TelemetrySample) -> Double?) -> String {
        let values = entries.compactMap { entry -> Double? in
            if case let .sample(sample) = entry { return value(sample) }
            return nil
        }
        guard let latest = values.last, let peak = values.max() else { return "no readings yet" }
        return "latest \(Int((latest * 100).rounded())) percent, peak \(Int((peak * 100).rounded())) percent over \(values.count) readings"
    }
}

/// One row per logical CPU, newest on the right. Each cell's brightness is that core's load in that second.
struct CoreHeatStrip: View {
    let entries: [TelemetryEntry]
    let capacity: Int
    /// Rows from top to bottom: the logical CPU index, and whether it is a performance core.
    let rows: [(cpu: Int, performance: Bool)]

    var body: some View {
        Canvas { context, size in
            guard !rows.isEmpty else { return }
            let rowHeight = size.height / CGFloat(rows.count)
            let slotWidth = size.width / CGFloat(capacity)
            for (slot, entry) in ChartSlots.placed(entries, capacity: capacity) {
                guard case let .sample(sample) = entry else { continue }
                for (row, core) in rows.enumerated() {
                    let rect = CGRect(x: CGFloat(slot) * slotWidth, y: CGFloat(row) * rowHeight,
                                      width: max(slotWidth - 0.5, 0.5), height: max(rowHeight - 1, 0.5))
                    context.fill(Path(rect), with: .color(Color.white.opacity(0.06)))
                    let load = core.cpu < sample.coreLoads.count ? min(max(sample.coreLoads[core.cpu], 0), 1) : 0
                    if load > 0.01 {
                        let base = core.performance ? Theme.yield : Theme.eco
                        context.fill(Path(rect), with: .color(base.opacity(0.18 + 0.82 * load)))
                    }
                }
            }
        }
    }
}

/// Lines for values on a 0...1 scale (drawn bottom to top). A missing value or a gap breaks the line.
struct LineSeries {
    let name: String
    let color: Color
    let value: (TelemetrySample) -> Double?
}

struct LineChart: View {
    let entries: [TelemetryEntry]
    let capacity: Int
    let series: [LineSeries]
    /// Horizontal reference lines on the 0...1 scale, such as the 85% point where a core counts as pinned.
    var references: [Double] = []

    var body: some View {
        Canvas { context, size in
            for level in references {
                var line = Path()
                let y = size.height * (1 - CGFloat(level))
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(Theme.warn.opacity(0.35)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
            }
            let slotWidth = size.width / CGFloat(capacity)
            for line in series {
                var path = Path()
                var pen = false
                for (slot, entry) in ChartSlots.placed(entries, capacity: capacity) {
                    guard case let .sample(sample) = entry, let raw = line.value(sample) else { pen = false; continue }
                    let point = CGPoint(x: (CGFloat(slot) + 0.5) * slotWidth,
                                        y: size.height * (1 - CGFloat(min(max(raw, 0), 1))))
                    if pen { path.addLine(to: point) } else { path.move(to: point) }
                    pen = true
                }
                context.stroke(path, with: .color(line.color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

/// Stacked GPU share by app, in percent of the GPU (the top of the stack is the total the charts can show).
struct StackedShareArea: View {
    let entries: [TelemetryEntry]
    let capacity: Int
    /// Bottom to top. Each key's value is its share in percent (0...100).
    let keys: [String]
    let color: (Int) -> Color
    let share: (TelemetrySample, String) -> Double

    var body: some View {
        Canvas { context, size in
            let slotWidth = size.width / CGFloat(capacity)
            var run: [(x: CGFloat, sample: TelemetrySample)] = []
            func flush() {
                guard run.count > 1 else { run.removeAll(); return }
                for layer in keys.indices {
                    var path = Path()
                    let top = run.map { point in (point.x, cumulative(point.sample, through: layer)) }
                    let bottom = run.map { point in (point.x, cumulative(point.sample, through: layer - 1)) }
                    path.move(to: CGPoint(x: top[0].0, y: size.height * (1 - top[0].1 / 100)))
                    for (x, value) in top.dropFirst() { path.addLine(to: CGPoint(x: x, y: size.height * (1 - value / 100))) }
                    for (x, value) in bottom.reversed() { path.addLine(to: CGPoint(x: x, y: size.height * (1 - value / 100))) }
                    path.closeSubpath()
                    context.fill(path, with: .color(color(layer)))
                }
                run.removeAll()
            }
            for (slot, entry) in ChartSlots.placed(entries, capacity: capacity) {
                guard case let .sample(sample) = entry else { flush(); continue }
                run.append(((CGFloat(slot) + 0.5) * slotWidth, sample))
            }
            flush()
        }
    }

    private func cumulative(_ sample: TelemetrySample, through layer: Int) -> Double {
        guard layer >= 0 else { return 0 }
        let total = keys.prefix(layer + 1).reduce(0.0) { $0 + share(sample, $1) }
        return min(total, 100)
    }
}

/// A thin amber tick along the bottom of a chart wherever a boost session was running.
struct SessionMarks: View {
    let entries: [TelemetryEntry]
    let capacity: Int

    var body: some View {
        Canvas { context, size in
            let slotWidth = size.width / CGFloat(capacity)
            for (slot, entry) in ChartSlots.placed(entries, capacity: capacity) {
                guard case let .sample(sample) = entry, sample.sessionActive else { continue }
                context.fill(Path(CGRect(x: CGFloat(slot) * slotWidth, y: size.height - 3, width: max(slotWidth, 1), height: 3)),
                             with: .color(Theme.boost))
            }
        }
    }
}
