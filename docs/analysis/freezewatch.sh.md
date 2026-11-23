# freezewatch.sh

**Mục đích:** ghi trạng thái bộ nhớ và GPU mỗi 30 giây vào `~/Library/Logs/freezewatch/<giờ boot>.log`, ghi đồng bộ xuống đĩa để dòng cuối còn lại sau lần tắt nóng, và báo khi bộ nhớ nén gần đầy (comment dòng 2-6: rò command buffer Metal, kernel chỉ giữ 16 triệu trang nén).

**Hàm chính:**
- `append()`: ghi một dòng bằng perl với `flush` và `sync`.
- `sample()`: thu `vm_stat` (bộ nhớ nén), swap, `memorystatus_level`, load, `recoveryCount` của `IntelAccelerator` qua `ioreg`, ứng dụng đang mở, top 4 ứng dụng theo bộ nhớ, nhiệt và công suất gói qua binary `smcsensors` (`TC0P`, `PCTR`).
- `alert()`: thông báo macOS khi nén ≥ 60% hoặc swap ≥ 4096 MB, giãn cách 900 s (300 s khi ≥ 85%).
- Vòng lặp chính; tham số `once` chỉ lấy một mẫu. Giữ tối đa 30 file log.

**Phụ thuộc:** binary `~/Library/Application Support/freezewatch/smcsensors` (nguồn là `PostInstall/Tools/smcsensors.c` cùng thư mục; file này không nói cách binary được tạo). Biến môi trường `FREEZEWATCH_*` đổi ngưỡng.

**Lưu ý / rủi ro:**
- Mỗi chu kỳ gọi `ioreg -rc IntelAccelerator`; nếu driver đồ họa kẹt thì `ioreg` có thể treo và làm dừng cả vòng ghi, đúng lúc cần bằng chứng [suy đoán, dựa trên một lần `ioreg` treo quan sát được].
- `alert()` dùng biến `pct`, `swap`, `now` do `sample()` đặt (biến toàn cục ngầm).
- Chữ ký cảm biến (`TC0P(sp78)`, `PCTR(sp96)`) gắn cứng theo đầu ra của `smcsensors`.
