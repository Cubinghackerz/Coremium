import CoremiumCore
import SwiftUI

@MainActor
final class SimulatorState: ObservableObject {
    @Published var scenario: SimScenario = .gaming
    @Published var coremiumOn = true { didSet { model.coremiumOn = coremiumOn; frames.removeAll() } }
    @Published var contention = 0.7 { didSet { model.contention = contention } }
    /// Not @Published on purpose: only the graph redraws (via TimelineView), not the whole tab.
    private(set) var frames: [Double] = []

    static let windowSize = 240
    private var model = FrameTimeModel(coremiumOn: true, contention: 0.7)
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        let new = Timer(timeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.advance() } }
        RunLoop.main.add(new, forMode: .common)
        timer = new
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func advance() {
        for _ in 0..<3 { frames.append(model.nextFrameMs()) }
        if frames.count > Self.windowSize { frames.removeFirst(frames.count - Self.windowSize) }
    }

    var averageFPS: Double { frames.isEmpty ? 0 : 1000 / (frames.reduce(0, +) / Double(frames.count)) }
    var worstMs: Double { frames.max() ?? 0 }
    var hitches: Int { frames.filter { $0 > 16.7 }.count }
}

struct SimulateTab: View {
    @ObservedObject var engine: AppEngine
    let advanced: Bool
    @StateObject private var sim = SimulatorState()
    private static let palette: [Color] = [Theme.accent, Theme.accent, Theme.accent, Theme.accent, Theme.warn]

    var body: some View {
        FlexScroll {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Tag(text: "Illustration, not a measurement", color: Theme.warn)
                    Spacer()
                }
                controls
                coresCard
                graphCard
            }
        }
        .onAppear { sim.start() }
        .onDisappear { sim.stop() }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            ForEach(SimScenario.allCases, id: \.self) { scenario in
                let selected = sim.scenario == scenario
                Button { sim.scenario = scenario } label: {
                    Text(scenario.title).font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .foregroundColor(selected ? .black : .white.opacity(0.8))
                        .background(Capsule().fill(selected ? Theme.accent : Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 4)
            Toggle(isOn: $sim.coremiumOn) {
                Text(sim.coremiumOn ? "Coremium on" : "Coremium off").font(.system(size: 11.5, weight: .semibold, design: .rounded)).lineLimit(1)
            }
            .toggleStyle(.switch).tint(Theme.accent).fixedSize()
        }
    }

    private var coresCard: some View {
        let layout = SimPlacement.compute(apps: sim.scenario.apps, coremiumOn: sim.coremiumOn,
                                          performanceCores: max(engine.chip.performanceCores, 1),
                                          efficiencyCores: max(engine.chip.efficiencyCores, 1))
        return Card(padding: 12) {
            VStack(alignment: .leading, spacing: 9) {
                coreRow("Performance cores", layout.isOverloaded ? "Overloaded: everything fights for these" : "Free for the app that matters",
                        layout.isOverloaded, layout.performance, layout.performanceShares)
                coreRow("Efficiency cores", sim.coremiumOn ? "Everything else waits here, quietly" : "Mostly unused", false,
                        layout.efficiency, layout.efficiencyShares)
                HStack(spacing: 10) {
                    ForEach(sim.scenario.apps) { app in
                        HStack(spacing: 4) {
                            Circle().fill(Self.palette[app.id % Self.palette.count]).frame(width: 7, height: 7)
                            Text(app.name + (advanced ? String(format: " %.1f", app.demand) : "")).font(.system(size: 10, design: .rounded))
                                .lineLimit(1)
                            if app.isBoost { Image(systemName: "bolt.fill").font(.system(size: 8)).foregroundColor(Theme.accent) }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    private func coreRow(_ title: String, _ subtitle: String, _ warn: Bool, _ ids: [[Int]], _ shares: [[Double]]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.white)
                Spacer()
                Text(subtitle).font(.system(size: 10, design: .rounded)).foregroundColor(warn ? Theme.accent : Theme.textDim)
            }
            HStack(spacing: 5) {
                ForEach(ids.indices, id: \.self) { core in
                    SimCoreTile(apps: ids[core], shares: shares[core], palette: Self.palette, warn: warn)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: sim.coremiumOn)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: sim.scenario)
        }
    }

    private var graphCard: some View {
        Card(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "What the game feels like")
                    Spacer()
                    HStack(spacing: 5) {
                        Text("Other apps").font(.system(size: 10, design: .rounded)).foregroundColor(Theme.textDim)
                        Slider(value: $sim.contention, in: 0.1...1).frame(width: 80)
                    }
                }
                TimelineView(.periodic(from: .now, by: 0.05)) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Spacer()
                            Text(sim.coremiumOn ? "Steady" : (sim.hitches > 3 ? "Stuttering" : "Mostly fine"))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(sim.coremiumOn ? Theme.accent : (sim.hitches > 3 ? Theme.accent : Theme.warn))
                        }
                        SimFrameGraph(frames: sim.frames, good: sim.coremiumOn).frame(height: 96)
                        HStack(spacing: 8) {
                            mini("Frame rate", String(format: "%.0f fps", sim.averageFPS))
                            mini("Worst frame", String(format: "%.0f ms", sim.worstMs))
                            mini("Hitches", "\(sim.hitches)")
                        }
                    }
                }
            }
        }
    }

    private func mini(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text(title).font(.system(size: 9.5, design: .rounded)).foregroundColor(Theme.textDim)
        }
        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.05)))
    }
}

private struct SimCoreTile: View {
    let apps: [Int]
    let shares: [Double]
    let palette: [Color]
    let warn: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.white.opacity(0.07))
                VStack(spacing: 1) {
                    Spacer(minLength: 0)
                    ForEach(apps.indices.reversed(), id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(palette[apps[i] % palette.count])
                            .frame(height: max(2, (proxy.size.height - 4) * CGFloat(min(shares[i], 1))))
                    }
                }
                .padding(2)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(warn ? Theme.accent.opacity(0.9) : Color.white.opacity(0.08), lineWidth: warn ? 1.5 : 1)
            }
        }
        .frame(height: 40)
    }
}

private struct SimFrameGraph: View {
    let frames: [Double]
    let good: Bool

    var body: some View {
        Canvas { context, size in
            let maxMs = 100.0
            func y(_ ms: Double) -> CGFloat { size.height - CGFloat(min(ms, maxMs) / maxMs) * size.height }
            for (ms, label) in [(16.7, "60"), (8.3, "120")] {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y(ms)))
                line.addLine(to: CGPoint(x: size.width, y: y(ms)))
                context.stroke(line, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                context.draw(Text(label).font(.system(size: 9, design: .rounded)).foregroundColor(.white.opacity(0.4)),
                             at: CGPoint(x: size.width - 10, y: y(ms) - 6))
            }
            guard frames.count > 1 else { return }
            let step = size.width / CGFloat(SimulatorState.windowSize - 1)
            let offset = size.width - step * CGFloat(frames.count - 1)
            var path = Path()
            for (index, ms) in frames.enumerated() {
                let point = CGPoint(x: offset + CGFloat(index) * step, y: y(ms))
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            var fill = path
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: offset, y: size.height))
            fill.closeSubpath()
            let tint: Color = good ? Theme.accent : Theme.accent
            context.fill(fill, with: .linearGradient(Gradient(colors: [tint.opacity(0.28), tint.opacity(0.02)]),
                                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            for (index, ms) in frames.enumerated() where ms > 40 {
                context.fill(Path(ellipseIn: CGRect(x: offset + CGFloat(index) * step - 2.5, y: y(ms) - 2.5, width: 5, height: 5)),
                             with: .color(Theme.warn))
            }
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.35)))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel("Frame time graph")
    }
}
