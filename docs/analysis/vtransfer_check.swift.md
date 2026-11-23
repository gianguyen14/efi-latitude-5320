# vtransfer_check.swift

**Mục đích:** kiểm tra `VTPixelTransferSession` (scale, đổi màu) qua 12 cặp định dạng mà player và camera dùng. Comment dòng 2 ghi: scale 420v đi vào AppleGVA → `AppleIntelTGLGraphicsVADriver` và crash tại `+0x1336f3` (b00t0x/WhateverXe#23). `HANDOFF_CONTEXT.md` (dòng 84) gọi file này là reproducer. Cú pháp: `vtransfer_check [rounds] [case]`.

**Hàm chính:**
- `buffer(w, h, fmt)`: tạo `CVPixelBuffer` có IOSurface và tương thích Metal.
- `fill(pb, value)`: ghi một giá trị vào mọi byte mọi plane (0 đánh dấu output chưa được ghi).
- `mean(pb)`: trung bình plane đầu, lấy mẫu 256 byte đầu mỗi hàng thứ 16.
- `vaLoaded()`: duyệt ảnh dyld xem `AppleIntelTGLGraphicsVADriver` có được nạp không.
- Vòng lặp chính: chạy từng case trong mảng `cases` (yuvs, 420v, 420f, BGRA, 2vuy), in trạng thái, ms/khung, trung bình output và "VA driver loaded/not loaded".

**Phụ thuộc:** chỉ framework hệ thống (VideoToolbox, CoreVideo, MachO). Không gọi file nào khác của dự án.

**Lưu ý:**
- Chạy case lỗi có thể làm crash chính tiến trình (đó là mục đích); không có xử lý riêng.
- `mean()` chỉ nhìn một phần plane đầu, nên output ghi một phần có thể vẫn cho giá trị khác 0 [suy đoán].
