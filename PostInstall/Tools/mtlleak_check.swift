// Metal leak check: malloc growth per sequential command buffer
// (b00t0x/WhateverXe#47). About 72 KB each means the POSH buffer leaks;
// near 0 means the driver frees it.
// Build: swiftc -O mtlleak_check.swift -o mtlleak_check
import Metal
import Darwin

func mallocInUse() -> Int {
    var stats = malloc_statistics_t()
    malloc_zone_statistics(nil, &stats)
    return Int(stats.size_in_use)
}

let count = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 1000 : 1000
guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
    print("no Metal device")
    exit(1)
}
// Each buffer is the only active one on the queue, which is the leaking path.
func run(_ n: Int) {
    for _ in 0..<n {
        autoreleasepool {
            let buffer = queue.makeCommandBuffer()!
            buffer.commit()
            buffer.waitUntilCompleted()
        }
    }
}
run(20)
let before = mallocInUse()
run(count)
let grown = mallocInUse() - before
print(String(format: "%@: %d command buffers, malloc +%.1f MB (%.1f KB each)",
             device.name, count, Double(grown) / 1e6, Double(grown) / Double(count) / 1024))
