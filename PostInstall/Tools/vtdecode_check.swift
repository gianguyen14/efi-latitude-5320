// Reports whether VideoToolbox picks the hardware decoder for H.264 and HEVC.
// Only creates decode sessions; no frame is submitted to the GPU.
// Build: swiftc -O vtdecode_check.swift -o vtdecode_check
import CoreMedia
import VideoToolbox

func check(_ name: String, _ make: (UnsafeMutablePointer<CMFormatDescription?>) -> OSStatus) {
    var fmt: CMFormatDescription?
    guard make(&fmt) == noErr, let fmt else { print("\(name): bad parameter sets"); return }
    var session: VTDecompressionSession?
    let st = VTDecompressionSessionCreate(allocator: nil, formatDescription: fmt, decoderSpecification: nil,
                                          imageBufferAttributes: nil, outputCallback: nil, decompressionSessionOut: &session)
    guard st == noErr, let session else { print("\(name): session failed \(st)"); return }
    var hw: CFBoolean?
    VTSessionCopyProperty(session, key: kVTDecompressionPropertyKey_UsingHardwareAcceleratedVideoDecoder,
                          allocator: nil, valueOut: &hw)
    print("\(name): \(hw == kCFBooleanTrue ? "hardware" : "software")")
    VTDecompressionSessionInvalidate(session)
}

// 1280x720 High profile.
let sps: [UInt8] = [0x67, 0x64, 0x00, 0x1F, 0xAC, 0xD9, 0x40, 0x50, 0x05, 0xBB, 0x01, 0x10, 0x00, 0x00, 0x03,
                    0x00, 0x10, 0x00, 0x00, 0x03, 0x03, 0xC0, 0xF1, 0x83, 0x19, 0x60]
let pps: [UInt8] = [0x68, 0xEB, 0xE3, 0xCB, 0x22, 0xC0]
check("H.264") { out in
    sps.withUnsafeBufferPointer { s in pps.withUnsafeBufferPointer { p in
        let ptrs = [s.baseAddress!, p.baseAddress!], sizes = [sps.count, pps.count]
        return CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: nil, parameterSetCount: 2,
            parameterSetPointers: ptrs, parameterSetSizes: sizes, nalUnitHeaderLength: 4, formatDescriptionOut: out)
    } }
}

// 1280x720 Main profile.
let vps: [UInt8] = [0x40, 0x01, 0x0C, 0x01, 0xFF, 0xFF, 0x01, 0x60, 0x00, 0x00, 0x03, 0x00, 0x90, 0x00, 0x00,
                    0x03, 0x00, 0x00, 0x03, 0x00, 0x5D, 0x95, 0x98, 0x09]
let hsps: [UInt8] = [0x42, 0x01, 0x01, 0x01, 0x60, 0x00, 0x00, 0x03, 0x00, 0x90, 0x00, 0x00, 0x03, 0x00, 0x00,
                     0x03, 0x00, 0x5D, 0xA0, 0x02, 0x80, 0x80, 0x2D, 0x16, 0x59, 0x59, 0xA4, 0x93, 0x2B, 0xC0,
                     0x5A, 0x70, 0x80, 0x00, 0x01, 0xF4, 0x80, 0x00, 0x3A, 0x98, 0x04]
let hpps: [UInt8] = [0x44, 0x01, 0xC1, 0x72, 0xB4, 0x62, 0x40]
check("HEVC") { out in
    vps.withUnsafeBufferPointer { v in hsps.withUnsafeBufferPointer { s in hpps.withUnsafeBufferPointer { p in
        let ptrs = [v.baseAddress!, s.baseAddress!, p.baseAddress!], sizes = [vps.count, hsps.count, hpps.count]
        return CMVideoFormatDescriptionCreateFromHEVCParameterSets(allocator: nil, parameterSetCount: 3,
            parameterSetPointers: ptrs, parameterSetSizes: sizes, nalUnitHeaderLength: 4, extensions: nil,
            formatDescriptionOut: out)
    } } }
}
