import Foundation

/// Small deterministic random generator, so simulations and their tests are repeatable.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// An illustration of the idea (not a measurement): when more apps want the fast cores than exist, a game's frames can
/// stall; with the other apps on the efficiency cores they don't. The "real test" in the app measures the actual Mac,
/// and on a lightly loaded Mac it can honestly show no difference.
public struct FrameTimeModel: Sendable {
    public var coremiumOn: Bool
    /// 0...1: how busy the other apps are.
    public var contention: Double
    private var rng: SplitMix64

    public init(coremiumOn: Bool, contention: Double, seed: UInt64 = 0xC0FFEE) {
        self.coremiumOn = coremiumOn
        self.contention = min(max(contention, 0), 1)
        rng = SplitMix64(seed: seed)
    }

    public static let baseFrameMs = 8.3   // 120 fps

    public mutating func nextFrameMs() -> Double {
        let jitter = Double.random(in: -0.35...0.35, using: &rng)
        var ms = Self.baseFrameMs + jitter
        if coremiumOn {
            // Competitors live on the efficiency cores: only tiny hitches remain.
            if Double.random(in: 0..<1, using: &rng) < 0.002 { ms += Double.random(in: 0.8...3.5, using: &rng) }
        } else {
            // Competitors fight for the performance cores: occasional stalls.
            let chance = 0.0015 + 0.012 * contention
            if Double.random(in: 0..<1, using: &rng) < chance {
                let low = 8.0, high = 90.0
                let t = Double.random(in: 0..<1, using: &rng)
                ms += low * pow(high / low, t)   // log-uniform: many small stalls, a few huge ones
            } else if Double.random(in: 0..<1, using: &rng) < 0.03 * contention {
                ms += Double.random(in: 1...6, using: &rng)
            }
        }
        return ms
    }
}

/// An app in a simulated scenario.
public struct SimApp: Identifiable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let symbol: String
    /// How many cores' worth of work it wants.
    public let demand: Double
    public let isBoost: Bool

    public init(id: Int, name: String, symbol: String, demand: Double, isBoost: Bool) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.demand = demand
        self.isBoost = isBoost
    }
}

public enum SimScenario: String, CaseIterable, Sendable {
    case gaming, professional, coding

    public var title: String {
        switch self {
        case .gaming: return "Gaming"
        case .professional: return "Professional"
        case .coding: return "Coding"
        }
    }

    public var apps: [SimApp] {
        switch self {
        case .gaming:
            return [SimApp(id: 0, name: "Game", symbol: "gamecontroller.fill", demand: 4.0, isBoost: true),
                    SimApp(id: 1, name: "Browser", symbol: "globe", demand: 2.0, isBoost: false),
                    SimApp(id: 2, name: "Code editor", symbol: "chevron.left.forwardslash.chevron.right", demand: 1.5, isBoost: false),
                    SimApp(id: 3, name: "Chat", symbol: "bubble.left.and.bubble.right.fill", demand: 0.8, isBoost: false),
                    SimApp(id: 4, name: "AI assistant", symbol: "sparkles", demand: 1.2, isBoost: false)]
        case .professional:
            return [SimApp(id: 0, name: "Video editor", symbol: "film.fill", demand: 4.5, isBoost: true),
                    SimApp(id: 1, name: "Browser", symbol: "globe", demand: 2.0, isBoost: false),
                    SimApp(id: 2, name: "Game launcher", symbol: "gamecontroller.fill", demand: 1.0, isBoost: false),
                    SimApp(id: 3, name: "Chat", symbol: "bubble.left.and.bubble.right.fill", demand: 0.8, isBoost: false),
                    SimApp(id: 4, name: "AI assistant", symbol: "sparkles", demand: 1.2, isBoost: false)]
        case .coding:
            return [SimApp(id: 0, name: "IDE + build", symbol: "chevron.left.forwardslash.chevron.right", demand: 3.5, isBoost: true),
                    SimApp(id: 1, name: "Browser", symbol: "globe", demand: 1.5, isBoost: false),
                    SimApp(id: 2, name: "Game", symbol: "gamecontroller.fill", demand: 2.0, isBoost: false),
                    SimApp(id: 3, name: "Photo editor", symbol: "paintpalette.fill", demand: 1.5, isBoost: false),
                    SimApp(id: 4, name: "Chat", symbol: "bubble.left.and.bubble.right.fill", demand: 0.5, isBoost: false)]
        }
    }
}

/// Which app uses how much of each core.
public struct SimPlacement: Equatable, Sendable {
    public typealias Slice = (app: Int, share: Double)
    public var performance: [[Int]]       // per core: app ids (shares in `performanceShares`)
    public var performanceShares: [[Double]]
    public var efficiency: [[Int]]
    public var efficiencyShares: [[Double]]
    /// Total demand sent to the performance cores, in cores.
    public var performanceDemand: Double
    public var performanceCores: Int

    public var isOverloaded: Bool { performanceDemand > Double(performanceCores) * 0.9 }

    /// Fills cores one after another, each holding up to 1.0 of work.
    private static func fill(_ items: [(Int, Double)], cores: Int) -> (ids: [[Int]], shares: [[Double]]) {
        var ids = [[Int]](repeating: [], count: cores)
        var shares = [[Double]](repeating: [], count: cores)
        var core = 0
        var room = 1.0
        for (app, demandStart) in items {
            var demand = demandStart
            while demand > 0.0001 && core < cores {
                let take = min(demand, room)
                ids[core].append(app)
                shares[core].append(take)
                demand -= take
                room -= take
                if room <= 0.0001 { core += 1; room = 1.0 }
            }
        }
        return (ids, shares)
    }

    public static func compute(apps: [SimApp], coremiumOn: Bool, performanceCores: Int, efficiencyCores: Int) -> SimPlacement {
        if coremiumOn {
            let boosted = apps.filter(\.isBoost).map { ($0.id, $0.demand) }
            let others = apps.filter { !$0.isBoost }.sorted { $0.demand > $1.demand }.map { ($0.id, $0.demand) }
            let p = fill(boosted, cores: performanceCores)
            let e = fill(others, cores: efficiencyCores)
            return SimPlacement(performance: p.ids, performanceShares: p.shares, efficiency: e.ids, efficiencyShares: e.shares,
                                performanceDemand: boosted.map(\.1).reduce(0, +), performanceCores: performanceCores)
        }
        // Everything asks for the fast cores. The scheduler spills a little onto the efficiency cores.
        let all = apps.map { ($0.id, $0.demand) }
        let total = all.map(\.1).reduce(0, +)
        let spill = min(Double(efficiencyCores) * 0.25, total * 0.15)
        let onP = all.map { ($0.0, $0.1 * (1 - spill / max(total, 0.001))) }
        let onE = all.map { ($0.0, $0.1 * spill / max(total, 0.001)) }
        let p = fill(onP, cores: performanceCores)
        let e = fill(onE, cores: efficiencyCores)
        return SimPlacement(performance: p.ids, performanceShares: p.shares, efficiency: e.ids, efficiencyShares: e.shares,
                            performanceDemand: onP.map(\.1).reduce(0, +), performanceCores: performanceCores)
    }
}
