// Video encode content check: encodes 30 frames of 1080p with a moving luma gradient, decodes the
// stream again and compares it with the source, so an encoder that reports success but writes black
// or garbage frames is caught (vtencode_check only counts frames).
// Build: swiftc -O vtencode_verify.swift -o vtencode_verify
// Run:   vtencode_verify [h264|hevc] [nv12|bgra] [soft]    "soft" lets VideoToolbox fall back to software.
import Foundation
import VideoToolbox
import CoreVideo
import CoreMedia

let args = CommandLine.arguments.dropFirst()
let codec: CMVideoCodecType = args.contains("hevc") ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264
let bgra = args.contains("bgra")
let software = args.contains("soft")
let width = 1920, height = 1080, count = 30
let name = (codec == kCMVideoCodecType_HEVC ? "HEVC" : "H.264") + (bgra ? " from BGRA" : " from NV12") +
    (software ? ", software allowed" : ", hardware required")

// Column x of frame i: a gradient that moves two columns per frame.
func gradient(_ x: Int, _ i: Int) -> Int { (x + 2 * i) % width * 255 / (width - 1) }
func expectedLuma(_ x: Int, _ i: Int) -> Double { 16 + 219 * Double(gradient(x, i)) / 255 }

func fill(_ pb: CVPixelBuffer, _ i: Int) {
    CVPixelBufferLockBaseAddress(pb, [])
    defer { CVPixelBufferUnlockBaseAddress(pb, []) }
    if bgra {
        let base = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(pb)
        for y in 0..<height {
            let row = base + y * stride
            for x in 0..<width {
                let v = UInt8(gradient(x, i))
                row[4 * x] = v; row[4 * x + 1] = v; row[4 * x + 2] = v; row[4 * x + 3] = 255
            }
        }
    } else {
        let luma = CVPixelBufferGetBaseAddressOfPlane(pb, 0)!.assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRowOfPlane(pb, 0)
        for y in 0..<height {
            let row = luma + y * stride
            for x in 0..<width { row[x] = UInt8(expectedLuma(x, i)) }
        }
        memset(CVPixelBufferGetBaseAddressOfPlane(pb, 1)!, 128,
               CVPixelBufferGetBytesPerRowOfPlane(pb, 1) * CVPixelBufferGetHeightOfPlane(pb, 1))
    }
}

// Mean luma and mean absolute difference from the source over every eighth row.
func measure(_ pb: CVPixelBuffer, _ i: Int) -> (mean: Double, mad: Double) {
    CVPixelBufferLockBaseAddress(pb, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
    let luma = CVPixelBufferGetBaseAddressOfPlane(pb, 0)!.assumingMemoryBound(to: UInt8.self)
    let stride = CVPixelBufferGetBytesPerRowOfPlane(pb, 0)
    let w = min(CVPixelBufferGetWidthOfPlane(pb, 0), width), h = min(CVPixelBufferGetHeightOfPlane(pb, 0), height)
    var sum = 0.0, diff = 0.0, n = 0.0
    for y in Swift.stride(from: 0, to: h, by: 8) {
        for x in 0..<w {
            let v = Double(luma[y * stride + x])
            sum += v; diff += abs(v - expectedLuma(x, i)); n += 1
        }
    }
    return (sum / n, diff / n)
}

var session: VTCompressionSession?
let spec: CFDictionary = software ? [:] as CFDictionary
    : [kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder: true] as CFDictionary
let attrs = [kCVPixelBufferPixelFormatTypeKey: bgra ? kCVPixelFormatType_32BGRA : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
             kCVPixelBufferWidthKey: width, kCVPixelBufferHeightKey: height,
             kCVPixelBufferIOSurfacePropertiesKey: [:]] as [CFString: Any] as CFDictionary
var status = VTCompressionSessionCreate(allocator: nil, width: Int32(width), height: Int32(height), codecType: codec,
                                        encoderSpecification: spec, imageBufferAttributes: attrs,
                                        compressedDataAllocator: nil, outputCallback: nil, refcon: nil,
                                        compressionSessionOut: &session)
guard status == noErr, let s = session else { print("\(name): FAIL, session create failed \(status)"); exit(1) }
VTSessionSetProperty(s, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanFalse)
VTSessionSetProperty(s, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
var hw: CFBoolean?
VTSessionCopyProperty(s, key: kVTCompressionPropertyKey_UsingHardwareAcceleratedVideoEncoder, allocator: nil, valueOut: &hw)
guard let pool = VTCompressionSessionGetPixelBufferPool(s) else { print("\(name): FAIL, no pixel buffer pool"); exit(1) }

var samples: [(index: Int, buffer: CMSampleBuffer)] = []
var encodeErrors = 0
let lock = NSLock()
let start = Date()
for i in 0..<count {
    var pb: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
    guard let p = pb else { encodeErrors += 1; continue }
    fill(p, i)
    status = VTCompressionSessionEncodeFrame(s, imageBuffer: p, presentationTimeStamp: CMTime(value: Int64(i), timescale: 30),
                                             duration: .invalid, frameProperties: nil, infoFlagsOut: nil) { st, _, sb in
        lock.lock(); defer { lock.unlock() }
        guard st == noErr, let sb = sb else { encodeErrors += 1; return }
        samples.append((Int(CMSampleBufferGetPresentationTimeStamp(sb).value), sb))
    }
    if status != noErr { encodeErrors += 1 }
}
VTCompressionSessionCompleteFrames(s, untilPresentationTimeStamp: .invalid)
let seconds = Date().timeIntervalSince(start)
VTCompressionSessionInvalidate(s)
samples.sort { $0.index < $1.index }
let usedHardware = hw == kCFBooleanTrue
guard let first = samples.first, let format = CMSampleBufferGetFormatDescription(first.buffer) else {
    print("\(name): FAIL, no encoded frames (errors \(encodeErrors))"); exit(1)
}

var decoder: VTDecompressionSession?
let outAttrs = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] as [CFString: Any] as CFDictionary
status = VTDecompressionSessionCreate(allocator: nil, formatDescription: format, decoderSpecification: nil,
                                      imageBufferAttributes: outAttrs, outputCallback: nil, decompressionSessionOut: &decoder)
guard status == noErr, let d = decoder else { print("\(name): FAIL, decoder create failed \(status)"); exit(1) }
var decoded = 0, decodeErrors = 0, meanSum = 0.0, madSum = 0.0, worst = 0.0
for sample in samples {
    status = VTDecompressionSessionDecodeFrame(d, sampleBuffer: sample.buffer, flags: [], infoFlagsOut: nil) { st, _, image, _, _ in
        lock.lock(); defer { lock.unlock() }
        guard st == noErr, let image = image else { decodeErrors += 1; return }
        let m = measure(image, sample.index)
        decoded += 1; meanSum += m.mean; madSum += m.mad; worst = max(worst, m.mad)
    }
    if status != noErr { decodeErrors += 1 }
}
VTDecompressionSessionWaitForAsynchronousFrames(d)
VTDecompressionSessionInvalidate(d)

let sourceMean = (0..<width).reduce(0.0) { $0 + expectedLuma($1, 0) } / Double(width)
let meanDecoded = decoded > 0 ? meanSum / Double(decoded) : 0, meanDiff = decoded > 0 ? madSum / Double(decoded) : 255
let ok = samples.count == count && decoded == count && encodeErrors == 0 && decodeErrors == 0 && meanDiff < 10
print(String(format: "%@: %@ hw=%@ encoded=%d/%d decoded=%d errors=%d/%d luma source %.1f decoded %.1f mean diff %.1f worst %.1f, %.0f fps",
             name, ok ? "PASS" : "FAIL", usedHardware ? "yes" : "no", samples.count, count, decoded, encodeErrors, decodeErrors,
             sourceMean, meanDecoded, meanDiff, worst, Double(samples.count) / seconds))
exit(ok ? 0 : 1)
