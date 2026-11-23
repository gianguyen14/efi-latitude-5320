# gpubench.swift

**Mục đích:** kiểm tra compute Metal: đo thông lượng FP32 duy trì trong `seconds` giây (mặc định 6) rồi băng thông sao chép của GPU. Build: `swiftc -O gpubench.swift -o gpubench`.

**Thành phần:**
- Hai kernel Metal viết trong chuỗi `src`: `fma_ilp` (8 chuỗi `fma` float4 độc lập, 512 vòng, để GPU chạy song song mức lệnh) và `copy_buf` (sao chép float4).
- `run(name, grid, bufs)`: tạo pipeline, mã hoá một lệnh dispatch, chờ xong, trả thời gian GPU (`gpuEndTime - gpuStartTime`); lỗi lệnh thì in và thoát mã 1.
- Phần thân: lặp `fma_ilp` (1<<20 luồng) trong `seconds` giây rồi in GFLOPS = luồng×512×8×4×2×số lần / tổng thời gian GPU; sau đó chạy `copy_buf` 6 lần trên hai buffer 256 MiB và in GB/s của lần tốt nhất.

**Phụ thuộc:** chỉ Metal và Foundation. Không gọi file nào khác của dự án.

**Lưu ý:**
- Dùng `try!` và `!` (crash ngay nếu không có thiết bị Metal hoặc biên dịch kernel lỗi).
- Hai buffer 256 MiB cho bước băng thông có thể nặng với GPU tích hợp dùng chung RAM [suy đoán].
- Chạy kéo dài làm tăng tải GPU, có thể gặp GPU hang nếu có vấn đề driver (đây là mục đích kiểm tra, file không xử lý).
