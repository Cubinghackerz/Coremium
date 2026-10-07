import CoremiumCore
import Foundation
import os

/// What one tick asks to have measured. Built on the main actor from the engine's current state.
struct MeasureRequest {
    var apps: [AppProcess]
    var ownPid: Int32
    /// Apps whose whole process tree is measured. Others count as their main process only.
    var expand: Set<Int32>
    var samplesCPU: Bool
    var samplesDiagnostics: Bool
    var samplesFootprints: Bool
}

/// One tick's readings, taken off the main thread.
struct Measurement {
    var loads: [Double]?
    var memory: MemoryInfo?
    var snapshot: ProcessSnapshot
    var tree: [Int32: [Int32]]
    var perPid: [Int32: Double]
    /// Device reading and per-app share, when diagnostics were due. `gpuReset` clears the last per-app values.
    var gpu: (reading: GPUReading, perApp: [Int32: Double])?
    var gpuReset: Bool
    /// Bytes per app (whole tree), when footprints were due.
    var footprints: [Int32: UInt64]?
    var milliseconds: Double
}

/// Does the expensive reads (every process, CPU, GPU registry, memory footprints) on a private serial queue, so the
/// main thread only decides and publishes. Measuring could take hundreds of milliseconds and froze the notch panel.
/// The samplers keep state between ticks, so they are only ever touched on this queue.
final class EngineMeasurer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "Coremium.measure", qos: .utility)
    private let cpuSampler = ProcessCPUSampler()
    private let loadSampler = CPULoadSampler()
    private let gpuSampler = GPUSampler()
    static let signposter = OSSignposter(subsystem: "Coremium", category: "Engine")

    func measure(_ request: MeasureRequest, completion: @escaping @MainActor (Measurement) -> Void) {
        queue.async { [self] in
            let result = Self.timed { self.run(request) }
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(result) } }
        }
    }

    private static func timed(_ body: () -> Measurement) -> Measurement {
        let start = DispatchTime.now().uptimeNanoseconds
        let state = signposter.beginInterval("measure")
        var result = body()
        signposter.endInterval("measure", state)
        result.milliseconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
        return result
    }

    private func run(_ r: MeasureRequest) -> Measurement {
        let loads = r.samplesCPU ? loadSampler.sample() : nil
        let memory = r.samplesDiagnostics ? MemoryInfo.current() : nil
        let snapshot = ProcessSnapshot.capture()

        // CPU use of every process in every measured app, once per tick.
        cpuSampler.prune(keeping: Set(snapshot.entries.keys))
        var tree: [Int32: [Int32]] = [:]
        var allPids: [Int32] = []
        var seen = Set<Int32>()
        for app in r.apps {
            guard r.expand.contains(app.pid) else { tree[app.pid] = [app.pid]; continue }
            let pids = snapshot.tree(of: app.pid)
            tree[app.pid] = pids
            for pid in pids where seen.insert(pid).inserted { allPids.append(pid) }
        }
        let perPid = cpuSampler.percentages(of: allPids + [r.ownPid])

        var gpu: (GPUReading, [Int32: Double])?
        var gpuReset = false
        if r.samplesDiagnostics {
            let reading = GPUStats.read()
            let perPidGPU = gpuSampler.percentages(from: reading)
            var perApp: [Int32: Double] = [:]
            for app in r.apps { perApp[app.pid] = (tree[app.pid] ?? [app.pid]).reduce(0) { $0 + (perPidGPU[$1] ?? 0) } }
            gpu = (reading, perApp)
        } else if !r.samplesCPU {
            gpuSampler.reset()
            gpuReset = true
        }

        var footprints: [Int32: UInt64]?
        if r.samplesFootprints {
            var bytes: [Int32: UInt64] = [:]
            for app in r.apps {
                bytes[app.pid] = (tree[app.pid] ?? [app.pid]).reduce(UInt64(0)) { $0 + (ProcessCPUSampler.footprint(of: $1) ?? 0) }
            }
            footprints = bytes
        }
        return Measurement(loads: loads, memory: memory, snapshot: snapshot, tree: tree, perPid: perPid,
                           gpu: gpu, gpuReset: gpuReset, footprints: footprints, milliseconds: 0)
    }
}
