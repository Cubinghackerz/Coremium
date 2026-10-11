import CoremiumCore
import Foundation

/// The live series the charts draw, filled once a second while the dashboard window is visible.
@MainActor
final class TelemetryStore: ObservableObject {
    let history = MetricHistory(cadence: 1)
    /// Changes whenever a sample lands, so the views that draw the history redraw.
    @Published private(set) var revision = 0

    func record(_ sample: TelemetrySample) {
        history.append(sample)
        revision &+= 1
    }
}

/// Reads CPU, memory and GPU once a second on its own queue, then hands each reading to the store on the main actor.
/// It runs only while the window is visible, so a notch-only Coremium never does this work.
///
/// GPU is read every other second, the same cost class as the engine's GPU reads (a registry walk). The last reading
/// carries over into the second in between, so the GPU series has one point per second without extra reads.
final class TelemetryService: @unchecked Sendable {
    private let store: TelemetryStore
    private let queue = DispatchQueue(label: "Coremium.telemetry", qos: .utility)
    // Confined to `queue`:
    private let cpu = CPULoadSampler()
    private let gpu = GPUSampler()
    private var timer: DispatchSourceTimer?
    private var tick = 0
    private var lastGPU: (device: Double?, apps: [String: Double]) = (nil, [:])
    // Written on the main actor, read on `queue`:
    private let treeLock = NSLock()
    private var trees: [String: [Int32]] = [:]
    private var sessionActive = false

    init(store: TelemetryStore) {
        self.store = store
    }

    /// Starts or stops the one-second timer. Stopping keeps no samples; the next start re-primes the CPU baseline.
    func setRunning(_ running: Bool) {
        queue.async { [self] in
            if running { startTimer() } else { stopTimer() }
        }
    }

    /// The process trees per app and whether a boost session is running, from the engine's latest measurement.
    func setContext(trees newTrees: [String: [Int32]], sessionActive: Bool) {
        treeLock.lock()
        trees = newTrees
        self.sessionActive = sessionActive
        treeLock.unlock()
    }

    private func startTimer() {
        guard timer == nil else { return }
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: 1, leeway: .milliseconds(100))
        source.setEventHandler { [weak self] in self?.sampleOnce() }
        source.resume()
        timer = source
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func sampleOnce() {
        let now = ProcessInfo.processInfo.systemUptime
        let loads = cpu.sample(now: now)
        let memory = MemoryInfo.current()
        treeLock.lock()
        let currentTrees = trees
        let inSession = sessionActive
        treeLock.unlock()
        if tick % 2 == 0 {
            let reading = GPUStats.read()
            let perPid = gpu.percentages(from: reading)
            lastGPU = (reading.devicePercent.map(Double.init), TelemetryBuilder.appGPU(perPid: perPid, trees: currentTrees))
        }
        tick &+= 1
        let sample = TelemetrySample(time: now, coreLoads: loads, gpuPercent: lastGPU.device, appGPUPercent: lastGPU.apps,
                                     memoryUsedBytes: memory.usedBytes, swapBytes: memory.swapUsedBytes, pressure: memory.pressure,
                                     sessionActive: inSession)
        let store = store
        DispatchQueue.main.async { MainActor.assumeIsolated { store.record(sample) } }
    }
}
