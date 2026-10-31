// Metal compute check: sustained FP32 throughput for `seconds` (default 6),
// then GPU copy bandwidth.
// Build: swiftc -O gpubench.swift -o gpubench
import Metal
import Foundation

let src = """
#include <metal_stdlib>
using namespace metal;
kernel void fma_ilp(device float4 *out [[buffer(0)]], uint id [[thread_position_in_grid]]) {
    float4 x0 = float4(id) * 1e-7, x1 = x0 + 1, x2 = x0 + 2, x3 = x0 + 3, x4 = x0 + 4, x5 = x0 + 5, x6 = x0 + 6, x7 = x0 + 7;
    const float4 m = float4(0.9999), k = float4(1e-4);
    for (int i = 0; i < 512; i++) {
        x0 = fma(x0, m, k); x1 = fma(x1, m, k); x2 = fma(x2, m, k); x3 = fma(x3, m, k);
        x4 = fma(x4, m, k); x5 = fma(x5, m, k); x6 = fma(x6, m, k); x7 = fma(x7, m, k);
    }
    out[id] = x0 + x1 + x2 + x3 + x4 + x5 + x6 + x7;
}
kernel void copy_buf(device const float4 *src [[buffer(0)]], device float4 *dst [[buffer(1)]], uint id [[thread_position_in_grid]]) {
    dst[id] = src[id];
}
"""
let seconds = CommandLine.arguments.count > 1 ? Double(CommandLine.arguments[1]) ?? 6 : 6
let dev = MTLCreateSystemDefaultDevice()!
let lib = try! dev.makeLibrary(source: src, options: nil)
let q = dev.makeCommandQueue()!

func run(_ name: String, _ grid: Int, _ bufs: [MTLBuffer]) -> Double {
    let p = try! dev.makeComputePipelineState(function: lib.makeFunction(name: name)!)
    let cb = q.makeCommandBuffer()!
    let e = cb.makeComputeCommandEncoder()!
    e.setComputePipelineState(p)
    for (i, b) in bufs.enumerated() { e.setBuffer(b, offset: 0, index: i) }
    e.dispatchThreads(MTLSize(width: grid, height: 1, depth: 1),
                      threadsPerThreadgroup: MTLSize(width: p.maxTotalThreadsPerThreadgroup, height: 1, depth: 1))
    e.endEncoding(); cb.commit(); cb.waitUntilCompleted()
    if let err = cb.error { print("error:", err); exit(1) }
    return cb.gpuEndTime - cb.gpuStartTime
}

let n = 1 << 20
let out = dev.makeBuffer(length: n * 16, options: .storageModePrivate)!
let start = Date(); var cnt = 0; var tt = 0.0
while Date().timeIntervalSince(start) < seconds { tt += run("fma_ilp", n, [out]); cnt += 1 }
print(String(format: "Sustained FP32: %.0f GFLOPS over %d runs", Double(n) * 512 * 8 * 4 * 2 * Double(cnt) / tt / 1e9, cnt))
let m = 1 << 24
let a = dev.makeBuffer(length: m * 16, options: .storageModePrivate)!
let b = dev.makeBuffer(length: m * 16, options: .storageModePrivate)!
var best = Double.infinity
for _ in 0..<6 { best = min(best, run("copy_buf", m, [a, b])) }
print(String(format: "Copy bandwidth: %.1f GB/s", Double(m * 16 * 2) / best / 1e9))
