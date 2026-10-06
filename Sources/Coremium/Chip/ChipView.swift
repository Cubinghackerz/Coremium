import CoremiumCore
import SwiftUI

/// The chip graphic: a brushed-metal package with pins, the Apple Silicon logo (an SF Symbol drawn at runtime, never
/// shipped as an image) and the chip name. Glows while a boost session is running.
struct ChipDie: View {
    let chip: ChipInfo
    let active: Bool

    var body: some View {
        GeometryReader { proxy in
            die(scale: min(1, max(0.6, min(proxy.size.width, proxy.size.height) / 120)))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func die(scale k: CGFloat) -> some View {
        ZStack {
            PinRing(count: k < 0.85 ? 7 : 9)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.36), Color(white: 0.15), Color(white: 0.27)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(11)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0.06)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                .padding(11)
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.black.opacity(0.58))
                .padding(27 * k)
            VStack(spacing: 3) {
                if chip.isAppleSilicon {
                    Image(systemName: "apple.logo").font(.system(size: 30 * k, weight: .regular))
                }
                Text(chip.shortName)
                    .font(.system(size: (chip.isAppleSilicon ? 11 : 10) * max(k, 0.85), weight: .semibold, design: .rounded))
                    .tracking(0.6)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
            }
            .foregroundStyle(LinearGradient(colors: [Color(white: 0.98), Color(white: 0.62)], startPoint: .top, endPoint: .bottom))
            .padding(.horizontal, 22)
        }
        .shadow(color: active ? Theme.accent.opacity(0.55) : Color.clear, radius: 14)
        .animation(.easeInOut(duration: 0.4), value: active)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chip: \(chip.brand)")
    }
}

private struct PinRing: View {
    var count = 9

    var body: some View {
        Canvas { context, size in
            let pinWidth: CGFloat = 4
            let pinLength: CGFloat = 8
            let inset: CGFloat = 22
            let color = GraphicsContext.Shading.color(Color.white.opacity(0.34))
            for i in 0..<count {
                let t = inset + (size.width - 2 * inset) * (CGFloat(i) + 0.5) / CGFloat(count)
                let u = inset + (size.height - 2 * inset) * (CGFloat(i) + 0.5) / CGFloat(count)
                let rects = [
                    CGRect(x: t - pinWidth / 2, y: 0, width: pinWidth, height: pinLength),
                    CGRect(x: t - pinWidth / 2, y: size.height - pinLength, width: pinWidth, height: pinLength),
                    CGRect(x: 0, y: u - pinWidth / 2, width: pinLength, height: pinWidth),
                    CGRect(x: size.width - pinLength, y: u - pinWidth / 2, width: pinLength, height: pinWidth),
                ]
                for rect in rects { context.fill(Path(roundedRect: rect, cornerRadius: 1), with: color) }
            }
        }
    }
}

/// Live load of each core, grouped into performance and efficiency rows. With `showNumbers`, every tile shows its percentage.
struct CoreGrid: View {
    let chip: ChipInfo
    let loads: [Double]
    var showNumbers = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            row(title: "P", cpus: chip.performanceCPUs)
            if !chip.efficiencyCPUs.isEmpty { row(title: "E", cpus: chip.efficiencyCPUs) }
        }
    }

    private func row(title: String, cpus: [Int]) -> some View {
        HStack(spacing: 3) {
            Text(title).font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.5)).frame(width: 10)
            ForEach(cpus, id: \.self) { cpu in
                let load = cpu < loads.count ? loads[cpu] : 0
                ZStack {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(tileColor(load))
                    if showNumbers {
                        Text("\(Int((load * 100).rounded()))")
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundColor(load > 0.5 ? .black.opacity(0.85) : .white.opacity(0.85))
                            .minimumScaleFactor(0.6)
                    }
                }
                .frame(height: showNumbers ? 17 : 11)
            }
        }
    }

    private func tileColor(_ load: Double) -> Color {
        let clamped = min(max(load, 0), 1)
        return Color.white.opacity(0.08 + 0.87 * clamped)
    }
}

struct ChipPanel: View {
    @ObservedObject var engine: AppEngine
    var advanced = false

    var body: some View {
        let chip = engine.chip
        VStack(spacing: advanced ? 9 : 12) {
            ChipDie(chip: chip, active: engine.sessionActive)
                .frame(width: advanced ? 96 : 120, height: advanced ? 96 : 120)
            VStack(alignment: .leading, spacing: 4) {
                Text(advanced ? "CORE LOAD %" : "LIVE CORE LOAD").font(.system(size: 8.5, weight: .bold, design: .rounded)).tracking(0.6)
                    .foregroundColor(.white.opacity(0.4))
                CoreGrid(chip: chip, loads: engine.cpuLoads, showNumbers: advanced)
            }
            .help("P = performance cores (fast), E = efficiency cores (frugal). Brighter means busier.")
            if advanced { advancedStats(chip) } else { basicStats(chip) }
        }
        .frame(width: 188)
    }

    private func basicStats(_ chip: ChipInfo) -> some View {
        VStack(spacing: 5) {
            stat("cpu", "\(chip.performanceCores)P + \(chip.efficiencyCores)E cores")
            if let gpu = chip.gpuCores {
                stat("square.stack.3d.up", "\(gpu)-core GPU" + (engine.gpuDevicePercent.map { " · \($0)% busy" } ?? ""))
            }
            stat("memorychip", ByteCountFormatter.string(fromByteCount: Int64(chip.memoryBytes), countStyle: .memory))
            if chip.performanceL2Bytes > 0 {
                stat("internaldrive", "L2 \(megabytes(chip.performanceL2Bytes)) P · \(megabytes(chip.efficiencyL2Bytes)) E")
            }
            stat(engine.powerSource == .battery ? "battery.50" : "powerplug.fill",
                 engine.powerSource == .battery ? "On battery" : "Plugged in")
            stat("thermometer.medium", thermalText)
        }
    }

    /// Every number, in a compact monospaced table.
    private func advancedStats(_ chip: ChipInfo) -> some View {
        let loads = engine.cpuLoads
        func average(_ cpus: [Int]) -> Double {
            let values = cpus.compactMap { $0 < loads.count ? loads[$0] : nil }
            return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count) * 100
        }
        let memory = engine.memory
        let gb = { (bytes: UInt64) in String(format: "%.1f", Double(bytes) / 1_073_741_824) }
        let usedPercent = memory.totalBytes > 0 ? Int(Double(memory.usedBytes) / Double(memory.totalBytes) * 100) : 0
        return VStack(spacing: 3.5) {
            number("P cores", String(format: "%.0f%% avg", average(chip.performanceCPUs)))
            if !chip.efficiencyCPUs.isEmpty { number("E cores", String(format: "%.0f%% avg", average(chip.efficiencyCPUs))) }
            number("All cores", String(format: "%.0f%%", average(Array(0..<chip.logicalCPUs))))
            number("Memory", "\(gb(memory.usedBytes)) / \(gb(memory.totalBytes)) GB (\(usedPercent)%)")
            number("Mem pressure", memory.pressure.rawValue)
            number("Swap used", memory.swapUsedBytes < 1_048_576 ? "0 MB" : "\(memory.swapUsedBytes / 1_048_576) MB")
            number("Cores", "\(chip.performanceCores)P+\(chip.efficiencyCores)E · \(chip.gpuCores.map { "\($0) GPU" } ?? "no GPU info")")
            number("L2", "\(megabytes(chip.performanceL2Bytes)) P · \(megabytes(chip.efficiencyL2Bytes)) E")
            if let device = engine.gpuDevicePercent { number("GPU", "\(device)% · \(engine.gpuDetail)") }
            number("Thermal", thermalName)
            number("Power", engine.powerSource == .battery ? "battery" : "AC\(engine.lowPower ? " · low-power" : "")")
            number("Moved", "\(engine.ledgerCount) procs")
        }
    }

    private func number(_ name: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(name).font(.system(size: 9, design: .monospaced)).foregroundColor(.white.opacity(0.45))
            Spacer(minLength: 2)
            Text(value).font(.system(size: 9.5, weight: .medium, design: .monospaced)).foregroundColor(.white.opacity(0.9))
                .lineLimit(1).minimumScaleFactor(0.65)
        }
    }

    private var thermalName: String {
        switch engine.thermal {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private var thermalText: String {
        switch engine.thermal {
        case .nominal: return "Cool"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Throttling"
        @unknown default: return "Unknown"
        }
    }

    private func megabytes(_ bytes: Int) -> String { bytes > 0 ? "\(bytes / 1_048_576) MB" : "–" }

    private func stat(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 9)).frame(width: 12)
                .foregroundColor(.white.opacity(0.5))
            Text(text).font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85)).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
    }
}
