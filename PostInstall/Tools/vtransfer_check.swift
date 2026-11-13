// Pixel-transfer check: VTPixelTransferSession over the formats players and the camera use.
// 420v scaling reaches AppleGVA -> AppleIntelTGLGraphicsVADriver and crashes there at +0x1336f3 (b00t0x/WhateverXe#23).
// Build: swiftc -O vtransfer_check.swift -o vtransfer_check    Run: vtransfer_check [rounds] [case]
import VideoToolbox
import CoreVideo
import MachO

func buffer(_ w: Int, _ h: Int, _ fmt: OSType) -> CVPixelBuffer {
    var pb: CVPixelBuffer?
    let attrs: [CFString: Any] = [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary, kCVPixelBufferMetalCompatibilityKey: true]
    CVPixelBufferCreate(nil, w, h, fmt, attrs as CFDictionary, &pb)
    return pb!
}
// Every byte of every plane; value 0 marks an output the transfer never wrote.
func fill(_ pb: CVPixelBuffer, _ value: UInt8) {
    CVPixelBufferLockBaseAddress(pb, [])
    if CVPixelBufferIsPlanar(pb) {
        for p in 0..<CVPixelBufferGetPlaneCount(pb) {
            memset(CVPixelBufferGetBaseAddressOfPlane(pb, p), Int32(value), CVPixelBufferGetBytesPerRowOfPlane(pb, p) * CVPixelBufferGetHeightOfPlane(pb, p))
        }
    } else {
        memset(CVPixelBufferGetBaseAddress(pb), Int32(value), CVPixelBufferGetBytesPerRow(pb) * CVPixelBufferGetHeight(pb))
    }
    CVPixelBufferUnlockBaseAddress(pb, [])
}
func mean(_ pb: CVPixelBuffer) -> Double {
    CVPixelBufferLockBaseAddress(pb, .readOnly); defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
    let planar = CVPixelBufferIsPlanar(pb)
    let base = planar ? CVPixelBufferGetBaseAddressOfPlane(pb, 0)! : CVPixelBufferGetBaseAddress(pb)!
    let row = planar ? CVPixelBufferGetBytesPerRowOfPlane(pb, 0) : CVPixelBufferGetBytesPerRow(pb)
    let h = planar ? CVPixelBufferGetHeightOfPlane(pb, 0) : CVPixelBufferGetHeight(pb)
    let w = min(row, 256)
    var sum = 0
    for y in stride(from: 0, to: h, by: 16) {
        let p = base.advanced(by: y * row).assumingMemoryBound(to: UInt8.self)
        for x in 0..<w { sum += Int(p[x]) }
    }
    return Double(sum) / Double(w * ((h + 15) / 16))
}
func vaLoaded() -> Bool {
    for i in 0..<_dyld_image_count() { if String(cString: _dyld_get_image_name(i)).hasSuffix("/AppleIntelTGLGraphicsVADriver") { return true } }
    return false
}
let v420 = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, f420 = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
let bgra = kCVPixelFormatType_32BGRA, yuvs = kCVPixelFormatType_422YpCbCr8_yuvs, uyvy = kCVPixelFormatType_422YpCbCr8
let cases: [(String, OSType, OSType, Int, Int, Int, Int)] = [
    ("yuvs 720p -> BGRA 720p", yuvs, bgra, 1280, 720, 1280, 720),
    ("420v 1080p -> 420v 720p", v420, v420, 1920, 1080, 1280, 720),
    ("420v 1080p -> BGRA 540p", v420, bgra, 1920, 1080, 960, 540),
    ("BGRA 1080p -> 2vuy 1080p", bgra, uyvy, 1920, 1080, 1920, 1080),
    ("420v 1080p -> BGRA 1080p", v420, bgra, 1920, 1080, 1920, 1080),
    ("420f 720p -> BGRA 1080p", f420, bgra, 1280, 720, 1920, 1080),
    ("BGRA 1080p -> 420v 1080p", bgra, v420, 1920, 1080, 1920, 1080),
    ("BGRA 1080p -> 420v 720p", bgra, v420, 1920, 1080, 1280, 720),
    ("BGRA 1080p -> BGRA 720p", bgra, bgra, 1920, 1080, 1280, 720),
    ("yuvs 720p -> 420v 720p", yuvs, v420, 1280, 720, 1280, 720),
    ("yuvs 720p -> BGRA 1080p", yuvs, bgra, 1280, 720, 1920, 1080),
    ("2vuy 1080p -> 420v 720p", uyvy, v420, 1920, 1080, 1280, 720),
]
let rounds = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 20 : 20
let only = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) : nil
for (i, (name, sf, df, sw, sh, dw, dh)) in cases.enumerated() where only == nil || only == i {
    var session: VTPixelTransferSession?
    VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &session)
    let src = buffer(sw, sh, sf), dst = buffer(dw, dh, df)
    fill(src, 150); fill(dst, 0)
    var status: OSStatus = 0
    let t = CFAbsoluteTimeGetCurrent()
    for _ in 0..<rounds { status = VTPixelTransferSessionTransferImage(session!, from: src, to: dst); if status != 0 { break } }
    let ms = (CFAbsoluteTimeGetCurrent() - t) * 1000 / Double(rounds)
    print("\(i) \(name): status \(status), \(String(format: "%.1f", ms)) ms, output mean \(String(format: "%.0f", mean(dst))), VA driver \(vaLoaded() ? "loaded" : "not loaded")")
    fflush(stdout)
    VTPixelTransferSessionInvalidate(session!)
}
