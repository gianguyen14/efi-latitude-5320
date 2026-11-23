// Display cadence probe: counts CVDisplayLink callbacks and reports the interval between them.
// A healthy 60 Hz panel gives ~16.7 ms with almost no jitter; ~33 ms means the compositor is
// running at half rate (the "all animations drop to 30 fps" symptom).
// Build: swiftc -O vsync_probe.swift -o vsync_probe -framework CoreVideo -framework AppKit   Run: vsync_probe [seconds]
import Foundation
import CoreVideo
import CoreGraphics

let seconds = CommandLine.arguments.count > 1 ? Double(CommandLine.arguments[1]) ?? 5 : 5
var tb = mach_timebase_info_data_t(); mach_timebase_info(&tb)
func ms(_ ticks: UInt64) -> Double { Double(ticks) * Double(tb.numer) / Double(tb.denom) / 1e6 }

var last: UInt64 = 0
var intervals: [Double] = []
let lock = NSLock()
var link: CVDisplayLink?
guard CVDisplayLinkCreateWithActiveCGDisplays(&link) == kCVReturnSuccess, let l = link else { print("no display link"); exit(1) }
let nominal = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(l)
CVDisplayLinkSetOutputHandler(l) { _, _, _, _, _ in
    let now = mach_absolute_time()
    lock.lock()
    if last != 0 { intervals.append(ms(now - last)) }
    last = now
    lock.unlock()
    return kCVReturnSuccess
}
CVDisplayLinkStart(l)
RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
CVDisplayLinkStop(l)

lock.lock(); let v = intervals.sorted(); lock.unlock()
guard !v.isEmpty else { print("no callbacks (display asleep or no display link)"); exit(1) }
func pct(_ p: Double) -> Double { v[min(v.count - 1, Int(p * Double(v.count)))] }
let mean = v.reduce(0, +) / Double(v.count)
let late = v.filter { $0 > 20 }.count
let nomMs = nominal.timeScale > 0 ? Double(nominal.timeValue) / Double(nominal.timeScale) * 1000 : 0
print(String(format: "nominal %.2f ms | callbacks %d in %.1f s | mean %.2f ms (%.1f Hz) | p50 %.2f p95 %.2f p99 %.2f max %.2f | >20 ms: %d (%.0f%%)",
             nomMs, v.count, seconds, mean, 1000 / mean, pct(0.5), pct(0.95), pct(0.99), v.last!, late, 100.0 * Double(late) / Double(v.count)))
