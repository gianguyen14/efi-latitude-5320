# vtencode_check.swift

**Mục đích:** kiểm tra mã hoá video phần cứng: mã hoá 120 khung 1080p chỉ bằng bộ mã hoá phần cứng (`RequireHardwareAcceleratedVideoEncoder`) và báo số khung ghi được, lỗi, dung lượng, tốc độ. Build: `swiftc -O vtencode_check.swift -o vtencode_check`.

**Hàm chính:**
- `check(name, codec)`: tạo `VTCompressionSession` 1920×1080 NV12 (420v), tắt realtime, đọc thuộc tính "đang dùng phần cứng", lấy pixel buffer từ pool, đổ nội dung bằng `memset` (mỗi plane một giá trị đổi theo khung), gọi `EncodeFrame`, đếm khung/byte/lỗi trong callback (có `NSLock`).
- Cuối file: gọi `check` cho H.264 và HEVC, rồi in `VTIsHardwareDecodeSupported` cho hai codec.

**Phụ thuộc:** chỉ Foundation, VideoToolbox, CoreVideo. `vtencode_verify.swift` mô tả file này trong comment của nó là chỉ đếm khung ("vtencode_check only counts frames"), nên `vtencode_verify` bổ sung bước giải mã và so nội dung.

**Lưu ý:**
- Nội dung khung là các mảng đồng nhất (chỉ `memset`), nên không phát hiện được lỗi nội dung hình ảnh; một bộ mã hoá ghi khung đen vẫn "qua" kiểm tra này (đúng lý do có `vtencode_verify.swift`).
- `frames`, `bytes`, `errors` được đọc sau `CompleteFrames` mà không còn khoá; callback có thể còn chạy muộn trong trường hợp hiếm [suy đoán].
