// GPU contention test. `probe <sec>`: a game-like job submits a small GPU frame every 8.3 ms and reports how long each
// frame takes from commit to completion (queueing behind other GPU work shows up as hitches). `hog <sec>`: keeps the GPU
// busy with large compute work. Build: swiftc -O gpu-contention.swift -o gpu-contention
import Foundation
import Metal

let source = """
#include <metal_stdlib>
using namespace metal;
kernel void work(device float *data [[buffer(0)]], constant uint &iters [[buffer(1)]], uint id [[thread_position_in_grid]]) {
    float x = data[id];
    for (uint i = 0; i < iters; i++) { x = fma(x, 1.000001f, 0.5f); x = sin(x) * 0.5f + x * 0.5f; }
    data[id] = x;
}
"""
let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
let pipeline = try! device.makeComputePipelineState(function: device.makeLibrary(source: source, options: nil).makeFunction(name: "work")!)

func submit(threads: Int, iters: UInt32) -> MTLCommandBuffer {
    let buffer = device.makeBuffer(length: threads * 4, options: .storageModePrivate)!
    var n = iters
    let cb = queue.makeCommandBuffer()!
    let enc = cb.makeComputeCommandEncoder()!
    enc.setComputePipelineState(pipeline)
    enc.setBuffer(buffer, offset: 0, index: 0)
    enc.setBytes(&n, length: 4, index: 1)
    enc.dispatchThreads(MTLSize(width: threads, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1))
    enc.endEncoding()
    cb.commit()
    return cb
}

let args = CommandLine.arguments
let seconds = Double(args.count > 2 ? args[2] : "5") ?? 5
let end = Date().addingTimeInterval(seconds)
if args.count > 1, args[1] == "hog" {
    while Date() < end { submit(threads: 1 << 20, iters: 4000).waitUntilCompleted() }
    exit(0)
}
var frames: [Double] = []
while Date() < end {
    let start = DispatchTime.now().uptimeNanoseconds
    submit(threads: 1 << 16, iters: 200).waitUntilCompleted()
    let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
    frames.append(ms)
    let spare = 8.3 - ms
    if spare > 0 { Thread.sleep(forTimeInterval: spare / 1000) }
}
frames.sort()
func q(_ p: Double) -> Double { frames[min(frames.count - 1, Int(Double(frames.count) * p))] }
print(String(format: "frames %d  median %.2f ms  p99 %.2f ms  worst %.1f ms  hitches(>8.3ms) %d",
             frames.count, q(0.5), q(0.99), frames.last ?? 0, frames.filter { $0 > 8.3 }.count))
