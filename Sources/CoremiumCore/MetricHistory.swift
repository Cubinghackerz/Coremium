import Foundation

/// One reading of everything the dashboard charts. Times are system uptime in seconds.
public struct TelemetrySample: Equatable, Sendable {
    public var time: TimeInterval
    /// Busy fraction (0...1) per logical CPU, indexed like `ChipInfo` (performance and efficiency cores).
    public var coreLoads: [Double]
    /// Device-wide GPU utilisation (0...100), when it was read for this sample.
    public var gpuPercent: Double?
    /// GPU share (0...100) of the apps being charted, by bundle id. The caller folds everything else into "Other".
    public var appGPUPercent: [String: Double]
    public var memoryUsedBytes: UInt64?
    public var swapBytes: UInt64?
    public var pressure: MemoryInfo.Pressure?
    /// A boost session was running (the charts mark these stretches).
    public var sessionActive: Bool

    public init(time: TimeInterval, coreLoads: [Double], gpuPercent: Double? = nil, appGPUPercent: [String: Double] = [:],
                memoryUsedBytes: UInt64? = nil, swapBytes: UInt64? = nil, pressure: MemoryInfo.Pressure? = nil,
                sessionActive: Bool = false) {
        self.time = time
        self.coreLoads = coreLoads
        self.gpuPercent = gpuPercent
        self.appGPUPercent = appGPUPercent
        self.memoryUsedBytes = memoryUsedBytes
        self.swapBytes = swapBytes
        self.pressure = pressure
        self.sessionActive = sessionActive
    }
}

/// What a chart draws: a reading, or a stretch with no readings (the window was closed or the Mac slept).
/// Charts draw a break for a gap, never an interpolated line.
public enum TelemetryEntry: Equatable, Sendable {
    case sample(TelemetrySample)
    case gap(from: TimeInterval, to: TimeInterval)
}

/// Fixed-size history, oldest first when read. Appending past capacity drops the oldest entry.
struct RingBuffer<Element> {
    private var storage: [Element] = []
    private var next = 0
    let capacity: Int

    init(capacity: Int) {
        precondition(capacity > 0, "a ring buffer needs room for at least one entry")
        self.capacity = capacity
    }

    mutating func append(_ element: Element) {
        if storage.count < capacity { storage.append(element) } else { storage[next] = element }
        next = (next + 1) % capacity
    }

    var elements: [Element] {
        storage.count < capacity ? storage : Array(storage[next...] + storage[..<next])
    }
}

/// In-memory history for the live charts: a fine series (one entry per sample, 2 minutes by default) and a coarse
/// series (one averaged entry per 10 s bucket, 30 minutes by default). Nothing here is written to disk.
public final class MetricHistory {
    public let cadence: TimeInterval
    public let coarseInterval: TimeInterval
    private var fine: RingBuffer<TelemetryEntry>
    private var coarse: RingBuffer<TelemetryEntry>
    private var lastTime: TimeInterval?
    private var pending: Bucket?

    /// - Parameters:
    ///   - cadence: the expected seconds between samples. A longer silence counts as a gap.
    ///   - fineCapacity: 120 samples at 1 s is 2 minutes.
    ///   - coarseCapacity: 180 buckets at 10 s is 30 minutes.
    public init(cadence: TimeInterval = 1, coarseInterval: TimeInterval = 10, fineCapacity: Int = 120, coarseCapacity: Int = 180) {
        self.cadence = cadence
        self.coarseInterval = coarseInterval
        fine = RingBuffer(capacity: fineCapacity)
        coarse = RingBuffer(capacity: coarseCapacity)
    }

    public func append(_ sample: TelemetrySample) {
        if let last = lastTime, sample.time - last > 2 * cadence {
            fine.append(.gap(from: last, to: sample.time))
            finishPending()
            coarse.append(.gap(from: last, to: sample.time))
        }
        fine.append(.sample(sample))
        lastTime = sample.time

        let index = (sample.time / coarseInterval).rounded(.down)
        if let bucket = pending, bucket.index != index { finishPending() }
        if pending == nil { pending = Bucket(index: index, start: index * coarseInterval) }
        pending?.add(sample)
    }

    /// Oldest first. The bucket still filling is included as its current average, so the chart is never behind.
    public var fineEntries: [TelemetryEntry] { fine.elements }

    public var coarseEntries: [TelemetryEntry] {
        var entries = coarse.elements
        if let pending { entries.append(.sample(pending.averaged())) }
        return entries
    }

    private func finishPending() {
        guard let pending else { return }
        coarse.append(.sample(pending.averaged()))
        self.pending = nil
    }

    /// Running sums for one 10 s bucket. Averages skip samples that did not carry a value (GPU and memory are read
    /// less often than the CPU); app GPU counts an absent app as 0 for that sample.
    private struct Bucket {
        let index: Double
        let start: TimeInterval
        private(set) var samples = 0
        private var coreSums: [Double] = []
        private var gpuSum = 0.0
        private var gpuCount = 0
        private var appSums: [String: Double] = [:]
        private var memorySum: Double = 0
        private var memoryCount = 0
        private var swapSum: Double = 0
        private var swapCount = 0
        private var worstPressure: MemoryInfo.Pressure?
        private var sessionSeen = false

        init(index: Double, start: TimeInterval) {
            self.index = index
            self.start = start
        }

        mutating func add(_ sample: TelemetrySample) {
            samples += 1
            if coreSums.isEmpty { coreSums = Array(repeating: 0, count: sample.coreLoads.count) }
            for (i, load) in sample.coreLoads.prefix(coreSums.count).enumerated() { coreSums[i] += load }
            if let gpu = sample.gpuPercent { gpuSum += gpu; gpuCount += 1 }
            for (bundle, percent) in sample.appGPUPercent { appSums[bundle, default: 0] += percent }
            if let used = sample.memoryUsedBytes { memorySum += Double(used); memoryCount += 1 }
            if let swap = sample.swapBytes { swapSum += Double(swap); swapCount += 1 }
            if let pressure = sample.pressure, Self.rank(pressure) > Self.rank(worstPressure) { worstPressure = pressure }
            if sample.sessionActive { sessionSeen = true }
        }

        func averaged() -> TelemetrySample {
            let n = Double(max(samples, 1))
            return TelemetrySample(
                time: start,
                coreLoads: coreSums.map { $0 / n },
                gpuPercent: gpuCount > 0 ? gpuSum / Double(gpuCount) : nil,
                appGPUPercent: appSums.mapValues { $0 / n },
                memoryUsedBytes: memoryCount > 0 ? UInt64(memorySum / Double(memoryCount)) : nil,
                swapBytes: swapCount > 0 ? UInt64(swapSum / Double(swapCount)) : nil,
                pressure: worstPressure,
                sessionActive: sessionSeen)
        }

        private static func rank(_ pressure: MemoryInfo.Pressure?) -> Int {
            switch pressure {
            case .none: return -1
            case .normal: return 0
            case .warning: return 1
            case .critical: return 2
            }
        }
    }
}
