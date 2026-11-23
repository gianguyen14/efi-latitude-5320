// Blit-engine check: times MTLBlitCommandEncoder copies and compute copies, with a stall guard.
// Purpose: after a GPU restart the blitter ring (BCS) was seen "NOT enabled - busy" with HEAD != TAIL
// in the Intel GPU Hang Summary; this shows whether blits are still serviced.
// Build: swiftc -O blitbench.swift -o blitbench      Run: blitbench [rounds]
import Metal
import Foundation

let rounds = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 10 : 10
guard let dev = MTLCreateSystemDefaultDevice(), let q = dev.makeCommandQueue() else { print("no Metal device"); exit(1) }
let size = 64 << 20
let a = dev.makeBuffer(length: size, options: .storageModePrivate)!
let b = dev.makeBuffer(length: size, options: .storageModePrivate)!

func timed(_ label: String, _ encode: (MTLCommandBuffer) -> Void) {
    var best = Double.infinity, worst = 0.0, stalls = 0
    for _ in 0..<rounds {
        let cb = q.makeCommandBuffer()!
        encode(cb)
        let sem = DispatchSemaphore(value: 0)
        cb.addCompletedHandler { _ in sem.signal() }
        let t = Date()
        cb.commit()
        if sem.wait(timeout: .now() + 5) == .timedOut { stalls += 1; continue }
        let s = Date().timeIntervalSince(t)
        best = min(best, s); worst = max(worst, s)
        if let e = cb.error { print("\(label): command buffer error: \(e)") }
    }
    if best == .infinity { print("\(label): STALLED (\(stalls)/\(rounds) buffers did not complete in 5 s)") }
    else { print(String(format: "%@: best %.1f ms (%.1f GB/s), worst %.1f ms, stalls %d/%d", label, best * 1000, Double(size) / best / 1e9, worst * 1000, stalls, rounds)) }
}
timed("blit copy 64 MiB") { cb in
    let e = cb.makeBlitCommandEncoder()!
    e.copy(from: a, sourceOffset: 0, to: b, destinationOffset: 0, size: size)
    e.endEncoding()
}
timed("blit fill 64 MiB") { cb in
    let e = cb.makeBlitCommandEncoder()!
    e.fill(buffer: b, range: 0..<size, value: 0)
    e.endEncoding()
}
