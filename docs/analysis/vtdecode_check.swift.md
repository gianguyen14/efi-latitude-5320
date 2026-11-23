# vtdecode_check.swift

**Mục đích:** báo VideoToolbox chọn bộ giải mã phần cứng hay phần mềm cho H.264 và HEVC. Chỉ tạo phiên giải mã, không gửi khung nào lên GPU (comment dòng 2). Build: `swiftc -O vtdecode_check.swift -o vtdecode_check`.

**Hàm chính:**
- `check(name, make)`: tạo `CMFormatDescription` bằng closure `make`, tạo `VTDecompressionSession`, đọc `kVTDecompressionPropertyKey_UsingHardwareAcceleratedVideoDecoder`, in "hardware" hoặc "software", rồi `Invalidate`.
- Hai lời gọi: H.264 (SPS/PPS cố định, 1280×720 High) và HEVC (VPS/SPS/PPS cố định, 1280×720 Main), các mảng byte viết cứng trong file.

**Phụ thuộc:** chỉ CoreMedia và VideoToolbox. Không gọi file nào khác của dự án. Liên quan cờ `-wexnohwdecode` (không quảng bá giải mã HEVC phần cứng) ở `docs/HARDWARE_AND_PATCHES.md`; file này là cách kiểm tra kết quả đó trên máy, nhưng chính file không nhắc tới cờ.

**Lưu ý:**
- "hardware" ở đây chỉ nói VideoToolbox *chọn* bộ giải mã phần cứng khi tạo phiên; không chứng minh giải mã thật chạy đúng trên GPU (comment: không gửi khung nào).
- Tham số SPS/PPS/VPS gắn cứng; nếu sai, in "bad parameter sets" thay vì kết quả giải mã.
