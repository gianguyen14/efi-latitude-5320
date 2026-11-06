// Metal leak check: malloc growth per sequential command buffer
// (b00t0x/WhateverXe#47). About 72 KB each means the POSH buffer leaks;
// near 0 means the driver frees it.
// Usage: mtlleak_check [count] [render]   render draws a triangle in each buffer
// Build: swiftc -O mtlleak_check.swift -o mtlleak_check
import Metal
import Darwin

func mallocInUse() -> Int {
    var stats = malloc_statistics_t()
    malloc_zone_statistics(nil, &stats)
    return Int(stats.size_in_use)
}

let args = CommandLine.arguments
let count = args.count > 1 ? Int(args[1]) ?? 1000 : 1000
let render = args.contains("render")
guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
    print("no Metal device")
    exit(1)
}

let shaders = """
#include <metal_stdlib>
using namespace metal;
vertex float4 vs(uint id [[vertex_id]]) {
    return float4(id == 1 ? 1.0 : -1.0, id == 2 ? 1.0 : -1.0, 0.0, 1.0);
}
fragment float4 fs() { return float4(1.0, 0.5, 0.0, 1.0); }
"""
var pipeline: MTLRenderPipelineState?
var target: MTLTexture?
if render {
    let library = try! device.makeLibrary(source: shaders, options: nil)
    let desc = MTLRenderPipelineDescriptor()
    desc.vertexFunction = library.makeFunction(name: "vs")
    desc.fragmentFunction = library.makeFunction(name: "fs")
    desc.colorAttachments[0].pixelFormat = .bgra8Unorm
    pipeline = try! device.makeRenderPipelineState(descriptor: desc)
    let tex = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 256, height: 256, mipmapped: false)
    tex.usage = .renderTarget
    target = device.makeTexture(descriptor: tex)
}

// Each buffer is the only active one on the queue, which is the leaking path.
func run(_ n: Int) {
    for _ in 0..<n {
        autoreleasepool {
            let buffer = queue.makeCommandBuffer()!
            if let pipeline = pipeline, let target = target {
                let pass = MTLRenderPassDescriptor()
                pass.colorAttachments[0].texture = target
                pass.colorAttachments[0].loadAction = .clear
                pass.colorAttachments[0].storeAction = .store
                let encoder = buffer.makeRenderCommandEncoder(descriptor: pass)!
                encoder.setRenderPipelineState(pipeline)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                encoder.endEncoding()
            }
            buffer.commit()
            buffer.waitUntilCompleted()
        }
    }
}
run(20)
let before = mallocInUse()
run(count)
let grown = mallocInUse() - before
print(String(format: "%@: %d %@command buffers, malloc +%.1f MB (%.1f KB each)",
             device.name, count, render ? "render " : "", Double(grown) / 1e6, Double(grown) / Double(count) / 1024))
