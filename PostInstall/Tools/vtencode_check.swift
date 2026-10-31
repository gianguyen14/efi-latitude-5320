// Hardware video encode check: encodes 120 frames of 1080p with the hardware
// encoder only and reports frames written and throughput.
// Build: swiftc -O vtencode_check.swift -o vtencode_check
import Foundation
import VideoToolbox
import CoreVideo

func check(_ name: String, _ codec: CMVideoCodecType) {
    var session: VTCompressionSession?
    let spec = [kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder: true] as CFDictionary
    let attrs = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                 kCVPixelBufferWidthKey: 1920, kCVPixelBufferHeightKey: 1080,
                 kCVPixelBufferIOSurfacePropertiesKey: [:]] as [CFString: Any] as CFDictionary
    var status = VTCompressionSessionCreate(allocator: nil, width: 1920, height: 1080, codecType: codec,
                                            encoderSpecification: spec, imageBufferAttributes: attrs,
                                            compressedDataAllocator: nil, outputCallback: nil, refcon: nil,
                                            compressionSessionOut: &session)
    guard status == noErr, let s = session else { print("\(name): create failed \(status)"); return }
    VTSessionSetProperty(s, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanFalse)
    var hw: CFBoolean?
    VTSessionCopyProperty(s, key: kVTCompressionPropertyKey_UsingHardwareAcceleratedVideoEncoder,
                          allocator: nil, valueOut: &hw)
    guard let pool = VTCompressionSessionGetPixelBufferPool(s) else { print("\(name): no pool"); return }
    var frames = 0, bytes = 0, errors = 0
    let lock = NSLock()
    let start = Date()
    for i in 0..<120 {
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
        guard let p = pb else { errors += 1; continue }
        CVPixelBufferLockBaseAddress(p, [])
        for plane in 0..<CVPixelBufferGetPlaneCount(p) {
            memset(CVPixelBufferGetBaseAddressOfPlane(p, plane), Int32((i * 2 + plane * 60) & 0xff),
                   CVPixelBufferGetBytesPerRowOfPlane(p, plane) * CVPixelBufferGetHeightOfPlane(p, plane))
        }
        CVPixelBufferUnlockBaseAddress(p, [])
        status = VTCompressionSessionEncodeFrame(s, imageBuffer: p, presentationTimeStamp: CMTime(value: Int64(i), timescale: 30),
                                                 duration: .invalid, frameProperties: nil, infoFlagsOut: nil) { st, _, sb in
            lock.lock(); defer { lock.unlock() }
            if st != noErr || sb == nil { errors += 1; return }
            frames += 1; bytes += CMSampleBufferGetTotalSampleSize(sb!)
        }
        if status != noErr { errors += 1 }
    }
    VTCompressionSessionCompleteFrames(s, untilPresentationTimeStamp: .invalid)
    let t = Date().timeIntervalSince(start)
    print(String(format: "%@: hw=%@ frames=%d errors=%d size=%d KB %.0f fps", name,
                 (hw == kCFBooleanTrue) ? "yes" : "no", frames, errors, bytes / 1024, Double(frames) / t))
    VTCompressionSessionInvalidate(s)
}

check("H.264", kCMVideoCodecType_H264)
check("HEVC", kCMVideoCodecType_HEVC)
print("HW decode H.264:", VTIsHardwareDecodeSupported(kCMVideoCodecType_H264), "HEVC:", VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC))
