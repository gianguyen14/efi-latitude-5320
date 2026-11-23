// Fence-latency probe for b00t0x/WhateverXe#130 (IOAccelFenceMachine: command completions can wait for a fixed
// 100 ms timer). Commits one tiny 64x64 render pass every `interval` ms and times commit -> completion handler.
// Healthy: median ~0.2-0.5 ms. Affected: completions cluster at ~100 ms / ~200 ms (steps of the 100 ms timer).
// Build: swiftc -O fence_probe.swift -o fence_probe -framework Metal      Run: fence_probe [seconds] [interval_ms]
import Metal
import Foundation

let seconds = CommandLine.arguments.count > 1 ? Double(CommandLine.arguments[1]) ?? 10 : 10
let intervalMs = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2]) ?? 20 : 20
guard let dev = MTLCreateSystemDefaultDevice(), let q = dev.makeCommandQueue() else { print("no Metal device"); exit(1) }
let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 64, height: 64, mipmapped: false)
desc.usage = .renderTarget; desc.storageMode = .private
let tex = dev.makeTexture(descriptor: desc)!

let lock = NSLock()
var lat: [Double] = []
var issued = 0
let end = Date(timeIntervalSinceNow: seconds)
while Date() < end {
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = tex
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    let cb = q.makeCommandBuffer()!
    cb.makeRenderCommandEncoder(descriptor: pass)!.endEncoding()
    let t0 = DispatchTime.now().uptimeNanoseconds
    cb.addCompletedHandler { _ in
        let d = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6
        lock.lock(); lat.append(d); lock.unlock()
    }
    cb.commit(); issued += 1
    usleep(UInt32(intervalMs * 1000))
}
Thread.sleep(forTimeInterval: 1.5)
lock.lock(); let v = lat.sorted(); lock.unlock()
guard !v.isEmpty else { print("no completions"); exit(1) }
func pct(_ p: Double) -> Double { v[min(v.count - 1, Int(p * Double(v.count)))] }
let bands = [("<5 ms", v.filter { $0 < 5 }.count), ("5-50", v.filter { $0 >= 5 && $0 < 50 }.count),
             ("50-150 (~1 timer step)", v.filter { $0 >= 50 && $0 < 150 }.count), (">=150", v.filter { $0 >= 150 }.count)]
print(String(format: "issued %d, completed %d | median %.2f ms p90 %.2f p99 %.2f max %.1f", issued, v.count, pct(0.5), pct(0.9), pct(0.99), v.last!))
print(bands.map { "\($0.0): \($0.1)" }.joined(separator: " | "))
