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
        // 5 steps a second, twelve frames each: the same 60 frames a second of data, drawn half as often.
        let new = Timer(timeInterval: 1.0 / 5.0, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.advance() } }
        RunLoop.main.add(new, forMode: .common)
        timer = new
    }

    func stop() { timer?.invalidate(); timer = nil }

    /// Called after every model step. The graph listens here and draws its own layers, so SwiftUI does not rebuild the
    /// tab ten times a second.
    var onStep: (() -> Void)?

    private func advance() {
        for _ in 0..<12 { frames.append(model.nextFrameMs()) }
        if frames.count > Self.windowSize { frames.removeFirst(frames.count - Self.windowSize) }
        onStep?()
    }

    var averageFPS: Double { frames.isEmpty ? 0 : 1000 / (frames.reduce(0, +) / Double(frames.count)) }
    var worstMs: Double { frames.max() ?? 0 }
    var hitches: Int { frames.filter { $0 > 16.7 }.count }
}

struct SimulateTab: View {
    /// Only the core counts are read from the chip. Not observing the engine keeps its every-few-seconds updates
    /// away from this tab's 10 Hz graph.
    let chip: ChipInfo
    let advanced: Bool
    @StateObject private var sim = SimulatorState()
    private static let palette: [Color] = [Theme.boost, Theme.yield, Theme.gpu, Theme.eco, Theme.warn]

    var body: some View {
        FlexScroll {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Tag(text: "Illustration, not a measurement", color: Theme.warn)
                    Spacer()
                }
                controls
                coresCard
                FrameGraphCard(sim: sim)
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
                                          performanceCores: max(chip.performanceCores, 1),
                                          efficiencyCores: max(chip.efficiencyCores, 1))
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
                            if app.isBoost { Image(systemName: "bolt.fill").font(.system(size: 8)).foregroundColor(Theme.boost) }
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
                Text(subtitle).font(.system(size: 10, design: .rounded)).foregroundColor(warn ? Theme.warn : Theme.textDim)
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

}

/// The frame-time graph and its numbers. The numbers refresh twice a second; the graph is drawn by its own layers each
/// model step, so the scrolling tab's SwiftUI layout is not run ten times a second.
private struct FrameGraphCard: View {
    let sim: SimulatorState

    var body: some View {
        Card(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "What the game feels like")
                    Spacer()
                    Text("dashed lines: 60 and 120 fps").font(.system(size: 9.5, design: .rounded)).foregroundColor(Theme.textDim)
                }
                FrameGraphLayer(sim: sim)
                    .frame(height: 96)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Frame time graph")
                TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Spacer()
                            Text(sim.coremiumOn ? "Steady" : (sim.hitches > 3 ? "Stuttering" : "Mostly fine"))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(sim.coremiumOn ? Theme.good : Theme.warn)
                        }
                        HStack(spacing: 8) {
                            mini("Modelled fps", String(format: "%.0f", sim.averageFPS))
                            mini("Modelled worst", String(format: "%.0f ms", sim.worstMs))
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

/// Hosts the layer-drawn graph. SwiftUI only places it; each model step updates its paths directly.
private struct FrameGraphLayer: NSViewRepresentable {
    let sim: SimulatorState

    func makeNSView(context: Context) -> FrameGraphNSView {
        let view = FrameGraphNSView()
        sim.onStep = { [weak view, weak sim] in
            guard let view, let sim else { return }
            view.update(frames: sim.frames, good: sim.coremiumOn)
        }
        view.update(frames: sim.frames, good: sim.coremiumOn)
        return view
    }

    func updateNSView(_ view: FrameGraphNSView, context: Context) {}
}

final class FrameGraphNSView: NSView {
    private let guides = CAShapeLayer()
    private let area = CAShapeLayer()
    private let line = CAShapeLayer()
    private let marks = CAShapeLayer()
    // The same colours as Theme.good and Theme.warn.
    private static let goodColour = NSColor(red: 0.45, green: 0.86, blue: 0.62, alpha: 1)
    private static let warnColour = NSColor(red: 0.93, green: 0.78, blue: 0.52, alpha: 1)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        guides.strokeColor = NSColor.white.withAlphaComponent(0.18).cgColor
        guides.fillColor = nil
        guides.lineWidth = 1
        guides.lineDashPattern = [4, 4]
        line.fillColor = nil
        line.lineWidth = 1.5
        line.lineJoin = .round
        line.lineCap = .round
        marks.fillColor = Self.warnColour.cgColor
        for sublayer in [guides, area, line, marks] {
            sublayer.actions = ["path": NSNull(), "fillColor": NSNull(), "strokeColor": NSNull()]
            layer?.addSublayer(sublayer)
        }
    }

    required init?(coder: NSCoder) { fatalError("FrameGraphNSView is created in code") }

    override func layout() {
        super.layout()
        // Dashed reference lines at 60 fps (16.7 ms) and 120 fps (8.3 ms) of a 100 ms scale.
        let path = CGMutablePath()
        for ms in [16.7, 8.3] {
            let y = bounds.height * CGFloat(ms / 100)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: bounds.width, y: y))
        }
        guides.path = path
        guides.frame = bounds
    }

    /// Redraws the graph from the newest frames, newest on the right. Frames are in ms on a 0...100 ms scale.
    func update(frames: [Double], good: Bool) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let height = bounds.height
        let width = bounds.width
        let windowSize = SimulatorState.windowSize
        let step = width / CGFloat(windowSize - 1)
        let offset = width - step * CGFloat(max(frames.count - 1, 0))
        let tint = good ? Self.goodColour : Self.warnColour
        let curve = CGMutablePath()
        let spikes = CGMutablePath()
        for (index, ms) in frames.enumerated() {
            let point = CGPoint(x: offset + CGFloat(index) * step, y: height * CGFloat(min(ms, 100) / 100))
            if index == 0 { curve.move(to: point) } else { curve.addLine(to: point) }
            if ms > 40 { spikes.addEllipse(in: CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)) }
        }
        let filled = CGMutablePath()
        filled.addPath(curve)
        if frames.count > 1 {
            filled.addLine(to: CGPoint(x: width, y: 0))
            filled.addLine(to: CGPoint(x: offset, y: 0))
            filled.closeSubpath()
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        area.path = filled
        area.fillColor = tint.withAlphaComponent(0.2).cgColor
        line.path = curve
        line.strokeColor = tint.cgColor
        marks.path = spikes
        CATransaction.commit()
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
                    .strokeBorder(warn ? Theme.warn.opacity(0.9) : Color.white.opacity(0.08), lineWidth: warn ? 1.5 : 1)
            }
        }
        .frame(height: 40)
    }
}

private struct SimFrameGraph: View {
    let frames: [Double]
    let good: Bool

    /// Drawn on every redraw, so it stays to one canvas: no clipping, no overlays and no text. (Those modifiers cost
    /// far more than the drawing itself inside a transparent window.)
    var body: some View {
        Canvas { context, size in
            context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 10), with: .color(.black.opacity(0.35)))
            let maxMs = 100.0
            func y(_ ms: Double) -> CGFloat { size.height - CGFloat(min(ms, maxMs) / maxMs) * size.height }
            for ms in [16.7, 8.3] {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y(ms)))
                line.addLine(to: CGPoint(x: size.width, y: y(ms)))
                context.stroke(line, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
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
            let tint: Color = good ? Theme.good : Theme.warn
            context.fill(fill, with: .linearGradient(Gradient(colors: [tint.opacity(0.28), tint.opacity(0.02)]),
                                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            for (index, ms) in frames.enumerated() where ms > 40 {
                context.fill(Path(ellipseIn: CGRect(x: offset + CGFloat(index) * step - 2.5, y: y(ms) - 2.5, width: 5, height: 5)),
                             with: .color(Theme.warn))
            }
        }
        .accessibilityLabel("Frame time graph")
    }
}
