// Pixel-transfer check: VTPixelTransferSession over the formats players and the camera use.
// 420v scaling reaches AppleGVA -> AppleIntelTGLGraphicsVADriver and crashes there at +0x1336f3 (b00t0x/WhateverXe#23).
// Build: swiftc -O vtransfer_check.swift -o vtransfer_check    Run: vtransfer_check [rounds]
import VideoToolbox
import CoreVideo
import MachO

func buffer(_ w: Int, _ h: Int, _ fmt: OSType) -> CVPixelBuffer {
    var pb: CVPixelBuffer?
    let attrs: [CFString: Any] = [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary, kCVPixelBufferMetalCompatibilityKey: true]
    CVPixelBufferCreate(nil, w, h, fmt, attrs as CFDictionary, &pb)
    return pb!
}
func vaLoaded() -> Bool {
    for i in 0..<_dyld_image_count() { if String(cString: _dyld_get_image_name(i)).contains("TGLGraphicsVADriver") { return true } }
    return false
}
let cases: [(String, OSType, OSType, Int, Int, Int, Int)] = [
    ("yuvs 720p -> BGRA 720p", kCVPixelFormatType_422YpCbCr8_yuvs, kCVPixelFormatType_32BGRA, 1280, 720, 1280, 720),
    ("420v 1080p -> 420v 720p", kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, 1920, 1080, 1280, 720),
    ("420v 1080p -> BGRA 540p", kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_32BGRA, 1920, 1080, 960, 540),
    ("BGRA 1080p -> 2vuy 1080p", kCVPixelFormatType_32BGRA, kCVPixelFormatType_422YpCbCr8, 1920, 1080, 1920, 1080),
]
let rounds = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 20 : 20
for (name, sf, df, sw, sh, dw, dh) in cases {
    var session: VTPixelTransferSession?
    VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &session)
    let src = buffer(sw, sh, sf), dst = buffer(dw, dh, df)
    var status: OSStatus = 0
    let t = CFAbsoluteTimeGetCurrent()
    for _ in 0..<rounds { status = VTPixelTransferSessionTransferImage(session!, from: src, to: dst); if status != 0 { break } }
    let ms = (CFAbsoluteTimeGetCurrent() - t) * 1000 / Double(rounds)
    print("\(name): status \(status), \(String(format: "%.1f", ms)) ms each, VA driver loaded: \(vaLoaded())")
    fflush(stdout)
    VTPixelTransferSessionInvalidate(session!)
}
