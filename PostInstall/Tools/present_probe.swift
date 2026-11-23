// Presentation probe: shows a small CAMetalLayer window for a few seconds, presents one drawable per vsync and
// records when each frame was actually put on screen (drawable.presentedTime). Compared with vsync_probe this
// shows whether the compositor really keeps up (all animations at 30 fps while the display link still ticks at 60).
// Build: swiftc -O present_probe.swift -o present_probe -framework AppKit -framework Metal -framework QuartzCore -framework CoreVideo
// Run:   present_probe [seconds]
import AppKit
import Metal
import QuartzCore
import CoreVideo

let seconds = CommandLine.arguments.count > 1 ? Double(CommandLine.arguments[1]) ?? 6 : 6
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
guard let dev = MTLCreateSystemDefaultDevice(), let queue = dev.makeCommandQueue() else { print("no Metal device"); exit(1) }
let win = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 640, height: 360), styleMask: [.titled], backing: .buffered, defer: false)
win.title = "present_probe"
let layer = CAMetalLayer()
layer.device = dev; layer.pixelFormat = .bgra8Unorm; layer.framebufferOnly = true
layer.drawableSize = CGSize(width: 640, height: 360)
win.contentView!.wantsLayer = true
win.contentView!.layer = layer
win.makeKeyAndOrderFront(nil)

let lock = NSLock()
var presented: [Double] = [], submitted = 0, nilDrawables = 0, frame = 0
var link: CVDisplayLink?
CVDisplayLinkCreateWithActiveCGDisplays(&link)
CVDisplayLinkSetOutputHandler(link!) { _, _, _, _, _ in
    guard let d = layer.nextDrawable() else { lock.lock(); nilDrawables += 1; lock.unlock(); return kCVReturnSuccess }
    frame += 1
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = d.texture
    pass.colorAttachments[0].loadAction = .clear
    let c = Double(frame % 120) / 120
    pass.colorAttachments[0].clearColor = MTLClearColor(red: c, green: 0.3, blue: 1 - c, alpha: 1)
    pass.colorAttachments[0].storeAction = .store
    let cb = queue.makeCommandBuffer()!
    cb.makeRenderCommandEncoder(descriptor: pass)!.endEncoding()
    d.addPresentedHandler { dd in lock.lock(); if dd.presentedTime > 0 { presented.append(dd.presentedTime) }; lock.unlock() }
    cb.present(d); cb.commit()
    lock.lock(); submitted += 1; lock.unlock()
    return kCVReturnSuccess
}
CVDisplayLinkStart(link!)
RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
CVDisplayLinkStop(link!)
win.close()

lock.lock(); let p = presented; let sub = submitted; let nd = nilDrawables; lock.unlock()
guard p.count > 2 else { print("submitted \(sub), presented \(p.count): not enough presented frames (window occluded or display asleep?)"); exit(1) }
let iv = zip(p.dropFirst(), p).map { ($0 - $1) * 1000 }.sorted()
func pct(_ q: Double) -> Double { iv[min(iv.count - 1, Int(q * Double(iv.count)))] }
let mean = iv.reduce(0, +) / Double(iv.count)
let late = iv.filter { $0 > 20 }.count
print(String(format: "submitted %d, presented %d, no-drawable %d | present interval mean %.2f ms (%.1f fps) p50 %.2f p95 %.2f p99 %.2f max %.2f | >20 ms: %d (%.0f%%)",
             sub, p.count, nd, mean, 1000 / mean, pct(0.5), pct(0.95), pct(0.99), iv.last!, late, 100.0 * Double(late) / Double(iv.count)))
