// CPU contention test: does moving background work into the background band (what Coremium does) help a game-like
// workload keep its frame deadlines when the Mac is oversubscribed?
//
// The "game": 4 threads at user-interactive QoS each do a fixed chunk of work per frame, paced at 120 Hz (8.33 ms).
// A frame is late if all four don't finish within the budget. Three conditions, alternated over several rounds:
//   none        no background load
//   normal      one busy-loop process per logical CPU, at normal priority
//   background  the same processes in the background band: setpriority(PRIO_DARWIN_PROCESS, pid, PRIO_DARWIN_BG),
//               the call Coremium makes (what `taskpolicy -b` does)
// Synthetic load, not real apps: it shows what the lever can do under contention, not a promise for any game.
//
// Build: swiftc -O bench/cpu-contention.swift -o /tmp/cpu-contention
// Run:   /tmp/cpu-contention [rounds=3] [seconds-per-condition=6]
import Darwin
import Foundation

let args = CommandLine.arguments
if args.count > 1, args[1] == "hog" {
    // A background busy loop: the kind of work Coremium moves aside.
    var x = 1.0
    while true { for _ in 0..<1_000_000 { x = x * 1.0000001 + 0.0000001 }; if x == 0 { print(x) } }
}

let rounds = Int(args.count > 1 ? args[1] : "3") ?? 3
let secondsPerCondition = Double(args.count > 2 ? args[2] : "6") ?? 6
let gameThreads = 4
let budgetMs = 1000.0 / 120.0
let logicalCPUs = ProcessInfo.processInfo.activeProcessorCount

// MARK: - Work calibration (target ~2.5 ms of work per thread per frame on an idle Mac)

@inline(never) func spin(_ iterations: Int) -> Double {
    var x = 1.0
    for _ in 0..<iterations { x = x * 1.0000001 + 0.0000001 }
    return x
}

func onInteractiveThread(_ body: @escaping () -> Void) {
    var attr = pthread_attr_t()
    pthread_attr_init(&attr)
    pthread_attr_set_qos_class_np(&attr, QOS_CLASS_USER_INTERACTIVE, 0)
    let box = Unmanaged.passRetained(body as AnyObject)
    var thread: pthread_t?
    pthread_create(&thread, &attr, { raw in
        let body = Unmanaged<AnyObject>.fromOpaque(raw).takeRetainedValue() as! () -> Void
        body()
        return nil
    }, box.toOpaque())
    pthread_detach(thread!)
}

func calibrate() -> Int {
    let done = DispatchSemaphore(value: 0)
    var perMs = 0.0
    onInteractiveThread {
        _ = spin(5_000_000) // warm up
        let start = DispatchTime.now().uptimeNanoseconds
        _ = spin(20_000_000)
        perMs = 20_000_000 / (Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6)
        done.signal()
    }
    done.wait()
    return Int(perMs * 2.5)
}

// MARK: - The game loop

final class Game {
    let work: Int
    var frames: [Double] = []
    private let start = DispatchSemaphore(value: 0)
    private let finished = DispatchSemaphore(value: 0)
    private var running = true

    init(work: Int) {
        self.work = work
        for _ in 0..<gameThreads {
            onInteractiveThread { [unowned self] in
                while true {
                    self.start.wait()
                    if !self.running { return }
                    _ = spin(self.work)
                    self.finished.signal()
                }
            }
        }
    }

    /// Runs frames for `seconds`, pacing each to the 120 Hz budget. Returns frame times in ms.
    func run(seconds: Double) -> [Double] {
        var times: [Double] = []
        let end = DispatchTime.now().uptimeNanoseconds + UInt64(seconds * 1e9)
        while DispatchTime.now().uptimeNanoseconds < end {
            let t0 = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<gameThreads { start.signal() }
            for _ in 0..<gameThreads { finished.wait() }
            let ms = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6
            times.append(ms)
            if ms < budgetMs { usleep(useconds_t((budgetMs - ms) * 1000)) }
        }
        return times
    }
}

// MARK: - Background load

func startHogs(background: Bool) -> [Process] {
    (0..<logicalCPUs).compactMap { _ -> Process? in
        let p = Process()
        p.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        p.arguments = ["hog"]
        guard (try? p.run()) != nil else { return nil }
        if background, setpriority(PRIO_DARWIN_PROCESS, id_t(p.processIdentifier), PRIO_DARWIN_BG) != 0 {
            print("setpriority failed for \(p.processIdentifier): errno \(errno). The background condition is invalid.")
            kill(p.processIdentifier, SIGKILL)
            exit(1)
        }
        return p
    }
}

var liveHogs: [Process] = []
signal(SIGINT) { _ in liveHogs.forEach { kill($0.processIdentifier, SIGKILL) }; exit(130) }

// MARK: - Run

let work = calibrate()
let game = Game(work: work)
_ = game.run(seconds: 1) // warm up
var results: [String: [Double]] = ["none": [], "normal": [], "background": []]
let order = ["none", "normal", "background"]
var brand = [CChar](repeating: 0, count: 128); var size = brand.count
sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
print("Coremium CPU contention test on \(String(cString: brand)), macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
print("\(gameThreads) game threads at 120 Hz vs \(logicalCPUs) busy background processes")
print("rounds \(rounds), \(Int(secondsPerCondition)) s per condition, work \(work) iterations per thread per frame")
for round in 1...rounds {
    for condition in (round % 2 == 0 ? order.reversed() : order) {
        liveHogs = condition == "none" ? [] : startHogs(background: condition == "background")
        if !liveHogs.isEmpty { usleep(300_000) } // let the scheduler settle
        let times = game.run(seconds: secondsPerCondition)
        liveHogs.forEach { kill($0.processIdentifier, SIGKILL); $0.waitUntilExit() }
        liveHogs = []
        results[condition, default: []] += times
        usleep(500_000)
    }
    print("round \(round) done")
}

func summary(_ name: String, _ times: [Double]) -> String {
    let sorted = times.sorted()
    func q(_ p: Double) -> Double { sorted[min(sorted.count - 1, Int(Double(sorted.count) * p))] }
    let late = times.filter { $0 > budgetMs }.count
    return name.padding(toLength: 11, withPad: " ", startingAt: 0) + String(format: "frames %5d  median %6.2f ms  p99 %7.2f ms  worst %7.1f ms  late %5.1f%%",
                  times.count, q(0.5), q(0.99), sorted.last ?? 0, 100 * Double(late) / Double(max(times.count, 1)))
}
print("")
for condition in order { print(summary(condition, results[condition] ?? [])) }
print("(late = frame missed the 8.33 ms budget of 120 Hz)")
