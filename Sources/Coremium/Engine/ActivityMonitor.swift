import CoremiumCore
import Foundation

/// Feeds the Activity tab. It samples every two seconds, only between `start()` and `stop()` (the tab is on screen),
/// and does the reading on a background queue. The main actor only receives the finished snapshot.
@MainActor
final class ActivityMonitor: ObservableObject {
    @Published private(set) var snapshot = ActivitySnapshot.empty

    private static let interval: TimeInterval = 2
    private static let rowLimit = 12

    private final class Reader: @unchecked Sendable {
        // Confined to the monitor's queue.
        let sampler = ActivitySampler()
    }

    private let queue = DispatchQueue(label: "Coremium.activity", qos: .utility)
    private let reader = Reader()
    private let logicalCPUs: Int
    private let movedProvider: @MainActor () -> Set<Int32>
    private var timer: Timer?

    init(logicalCPUs: Int, movedProvider: @escaping @MainActor () -> Set<Int32>) {
        self.logicalCPUs = logicalCPUs
        self.movedProvider = movedProvider
    }

    func start() {
        guard timer == nil else { return }
        // A first reading sets each process's baseline, so the first shown numbers already cover a full interval.
        let reader = reader, cpus = logicalCPUs
        queue.async { _ = reader.sampler.sample(limit: Self.rowLimit, moved: [], logicalCPUs: cpus) }
        let newTimer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sampleNow() }
        }
        newTimer.tolerance = Self.interval * 0.25
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sampleNow() {
        let moved = movedProvider()
        let reader = reader, cpus = logicalCPUs
        queue.async { [weak self] in
            let result = reader.sampler.sample(limit: Self.rowLimit, moved: moved, logicalCPUs: cpus)
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.snapshot = result } }
        }
    }
}
