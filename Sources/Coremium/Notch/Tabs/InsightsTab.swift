import CoremiumCore
import SwiftUI

struct InsightsTab: View {
    @ObservedObject var engine: AppEngine
    let advanced: Bool
    @State private var range: Range = .week

    enum Range: String, CaseIterable {
        case today = "Today", week = "7 days", month = "30 days"
        var days: Int { self == .today ? 1 : (self == .week ? 7 : 30) }
    }

    var body: some View {
        let total = engine.usage.total(days: range.days)
        let wh = EnergyEstimate.watthours(forMovedCoreSeconds: total.movedCoreSeconds)
        FlexScroll {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(Range.allCases, id: \.self) { item in
                        Button { range = item } label: {
                            Text(item.rawValue).font(.system(size: 11, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .foregroundColor(range == item ? .white : .white.opacity(0.5))
                                .background(Capsule().fill(range == item ? Color.white.opacity(0.16) : Color.clear))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    Text("Measured on this Mac. Never leaves it.").font(.system(size: 10, design: .rounded)).foregroundColor(Theme.textDim)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 3), spacing: 8) {
                    CompactStat(symbol: "bolt.fill", tint: Theme.accent, title: "Boost sessions", value: "\(total.sessions)",
                                help: "Times Coremium protected a game, creative app, dev tool or AI job.", raw: nil)
                    CompactStat(symbol: "timer", tint: Theme.accent, title: "Boost time", value: formatDuration(total.boostedSeconds),
                                help: "How long a boost was running.", raw: advanced ? String(format: "%.0f s", total.boostedSeconds) : nil)
                    CompactStat(symbol: "leaf.fill", tint: Theme.accent, title: "Moved to eco cores", value: String(format: "%.1f core-min", total.movedCoreSeconds / 60),
                                help: "CPU work that ran on the efficiency cores because Coremium moved it there. Measured.",
                                raw: advanced ? String(format: "%.0f core-seconds", total.movedCoreSeconds) : nil)
                    CompactStat(symbol: "battery.100.bolt", tint: Theme.accent, title: "Energy saved (est.)",
                                value: wh < 0.05 ? "< 0.1 Wh" : String(format: "≈ %.1f Wh", wh),
                                help: "A rough estimate: assumes each core's worth of moved work saves about \(EnergyEstimate.assumedWattsSavedPerCore) W. Real power can't be measured without admin rights.",
                                raw: advanced ? String(format: "%.2f Wh = %.1f W/core x %.0f core-s", wh, EnergyEstimate.assumedWattsSavedPerCore, total.movedCoreSeconds) : nil)
                    CompactStat(symbol: "thermometer.medium", tint: total.hotSeconds > 0 ? .red : Theme.accent, title: "Hot during boosts",
                                value: total.hotSeconds > 0 ? formatDuration(total.hotSeconds) : "Never",
                                help: "Time macOS reported the Mac as hot during a boost. Exact temperature can't be measured without admin rights.",
                                raw: advanced ? String(format: "%.0f s", total.hotSeconds) : nil)
                    CompactStat(symbol: "square.stack.3d.up.fill", tint: Theme.accent, title: "Most moved at once", value: "\(total.peakMovedProcesses)",
                                help: "Peak number of background processes moved aside together.", raw: nil)
                }
                if range != .today { DailyChart(engine: engine, days: range.days, weekly: range == .week) }
                SessionReports(reports: Array(engine.usage.reports.suffix(4).reversed()))
                DecisionLog(decisions: engine.decisions)
                Text("Coremium doesn't claim lower temperature or longer battery life, because it can't measure them.")
                    .font(.system(size: 10, design: .rounded)).foregroundColor(Theme.textDim).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct CompactStat: View {
    let symbol: String
    let tint: Color
    let title: String
    let value: String
    let help: String
    let raw: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 10, weight: .bold)).foregroundColor(tint)
                    .frame(width: 20, height: 20).background(Circle().fill(tint.opacity(0.18)))
                Text(title).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(Theme.textDim)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
            if let raw { Text(raw).font(.system(size: 9, design: .monospaced)).foregroundColor(Theme.textDim).lineLimit(2) }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
        .help(help)
    }
}

/// One quiet strip, no axes: a cell per day, brighter the longer a boost ran.
private struct DailyChart: View {
    @ObservedObject var engine: AppEngine
    let days: Int
    let weekly: Bool

    private struct Cell: Identifiable { let id: String; let date: Date; let minutes: Double }

    private var cells: [Cell] {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        return engine.usage.lastDays(days).compactMap { day in
            parser.date(from: day.day).map { Cell(id: day.day, date: $0, minutes: day.boostedSeconds / 60) }
        }
    }

    var body: some View {
        let cells = cells
        let scale = max(30, cells.map(\.minutes).max() ?? 0)
        let total = cells.reduce(0) { $0 + $1.minutes }
        Card(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "Boost time by day")
                    Spacer()
                    Text(total < 1 ? "none yet" : formatDuration(total * 60) + " in total")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded)).foregroundColor(Theme.textDim)
                }
                HStack(spacing: weekly ? 8 : 3) {
                    ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: weekly ? 8 : 4, style: .continuous)
                                .fill(cell.minutes < 1 ? Color.white.opacity(0.07)
                                      : Theme.accent.opacity(0.25 + 0.75 * min(cell.minutes / scale, 1)))
                                .frame(height: weekly ? 34 : 22)
                            Text(weekly ? cell.date.formatted(.dateTime.weekday(.narrow)) : (index % 5 == 0 ? cell.date.formatted(.dateTime.day()) : " "))
                                .font(.system(size: 9.5, design: .rounded)).foregroundColor(Theme.textDim)
                        }
                        .frame(maxWidth: .infinity)
                        .help(cell.date.formatted(.dateTime.weekday(.wide).day().month()) + ": "
                              + (cell.minutes < 1 ? "no boost" : formatDuration(cell.minutes * 60)))
                    }
                }
                Text("A boost runs while a game, creative app, dev tool or AI job is in use: Coremium keeps other apps out of its way.")
                    .font(.system(size: 10.5, design: .rounded)).foregroundColor(Theme.textDim).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Why Coremium did what it did, newest first: makes Automatic's choices visible.
struct DecisionLog: View {
    let decisions: [Decision]

    var body: some View {
        Card(padding: 12) {
            VStack(alignment: .leading, spacing: 7) {
                SectionLabel(text: "Why Coremium did what it did")
                if decisions.isEmpty {
                    Text("Decisions appear here as you switch between apps.").font(.system(size: 11, design: .rounded)).foregroundColor(Theme.textDim)
                }
                ForEach(decisions.prefix(6)) { decision in
                    HStack(alignment: .top, spacing: 8) {
                        Text(decision.date, style: .time).font(.system(size: 10, design: .monospaced)).foregroundColor(Theme.textDim)
                            .frame(width: 58, alignment: .leading)
                        (Text(decision.headline + ". ").fontWeight(.semibold).foregroundColor(.white)
                            + Text(decision.detail).foregroundColor(Theme.textDim))
                            .font(.system(size: 11, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

/// The last few boost sessions, each copyable as an image to share.
struct SessionReports: View {
    let reports: [SessionReport]
    @State private var copied: Date?

    var body: some View {
        Card(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Recent sessions")
                if reports.isEmpty {
                    Text("A report appears here after each boost of a minute or more.").font(.system(size: 11, design: .rounded)).foregroundColor(Theme.textDim)
                }
                ForEach(reports) { report in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(report.appName) · \(formatDuration(report.duration))").font(.system(size: 12, weight: .semibold, design: .rounded))
                            Text(report.summary.components(separatedBy: " · ").dropFirst(2).joined(separator: " · "))
                                .font(.system(size: 10.5, design: .rounded)).foregroundColor(Theme.textDim).lineLimit(1)
                        }
                        Spacer()
                        Button(copied == report.start ? "Copied" : "Copy image") { copy(report) }
                            .buttonStyle(.plain).font(.system(size: 10.5, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.75))
                            .help("Copies a report card image you can paste anywhere.")
                    }
                }
            }
        }
    }

    @MainActor private func copy(_ report: SessionReport) {
        let renderer = ImageRenderer(content: ReportCard(report: report))
        renderer.scale = 2
        guard let image = renderer.nsImage else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        copied = report.start
    }
}

/// A shareable, measured summary of one session.
struct ReportCard: View {
    let report: SessionReport

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                CoremiumLogo().frame(width: 30, height: 30)
                Text("Coremium").font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer()
                Text(report.end.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12, design: .rounded)).foregroundColor(.white.opacity(0.5))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(report.appName).font(.system(size: 34, weight: .bold, design: .rounded))
                Text("\(report.mode) session · \(formatDuration(report.duration))").font(.system(size: 15, design: .rounded)).foregroundColor(.white.opacity(0.6))
            }
            HStack(spacing: 12) {
                tile("\(report.peakMovedProcesses)", "background processes moved aside", Theme.eco)
                tile(String(format: "%.1f", report.movedCoreSeconds / 60), "core-minutes kept off the fast cores", Theme.yield)
                tile(report.worstPressure.capitalized, "memory pressure", report.worstPressure == "normal" ? Theme.good : Theme.warn)
            }
            Text("Measured on this Mac. Nothing was closed.").font(.system(size: 11, design: .rounded)).foregroundColor(.white.opacity(0.4))
        }
        .padding(28)
        .frame(width: 620)
        .foregroundColor(.white)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color(white: 0.05)))
        .environment(\.colorScheme, .dark)
    }

    private func tile(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(tint)
            Text(label).font(.system(size: 11.5, design: .rounded)).foregroundColor(.white.opacity(0.6)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)))
    }
}
