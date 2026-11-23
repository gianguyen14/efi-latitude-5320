# vtencode_verify.swift

**Mục đích:** kiểm tra nội dung mã hoá video: mã hoá 30 khung 1080p có dải xám di chuyển, giải mã lại và so với nguồn, để bắt trường hợp bộ mã hoá báo thành công nhưng ghi khung đen/rác (comment dòng 1-3 nói `vtencode_check` chỉ đếm khung). Cú pháp: `vtencode_verify [h264|hevc] [nv12|bgra] [soft]`.

**Hàm chính** (script cấp cao nhất, không có `main`):
- `gradient(x, i)`: giá trị dải tại cột `x` khung `i`, dịch 2 cột mỗi khung.
- `expectedLuma(x, i)`: luma kỳ vọng theo thang video (16 + 219·v/255).
- `fill(pb, i)`: đổ dải vào buffer BGRA hoặc vào plane luma NV12 (chroma cố định 128).
- `measure(pb, i)`: tính luma trung bình và sai lệch tuyệt đối trung bình so với nguồn, lấy mỗi hàng thứ 8.
- Phần thân: tạo `VTCompressionSession` (mặc định yêu cầu mã hoá phần cứng, `soft` cho phép phần mềm), mã hoá, giải mã bằng `VTDecompressionSession` ra NV12, in PASS/FAIL.

**Phụ thuộc:** chỉ framework hệ thống (VideoToolbox, CoreVideo, CoreMedia, Foundation). Không gọi file nào khác của dự án.

**Lưu ý:**
- PASS khi đủ 30 khung mã hoá + giải mã, không lỗi và sai lệch trung bình < 10; việc có dùng phần cứng chỉ được in (`hw=yes/no`), không ảnh hưởng PASS.
- Giải mã dùng đặc tả mặc định, nên có thể giải mã bằng phần cứng hoặc phần mềm tuỳ hệ thống [suy đoán].
- Với BGRA, nguồn là xám đều nhưng luma kỳ vọng dùng công thức thang video; ngưỡng 10 có thể che sai lệch nhỏ do ma trận màu [suy đoán].
