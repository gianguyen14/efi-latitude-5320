# sleep_power_test.py

**Mục đích:** đo công suất lúc ngủ qua mức hao pin (docstring: SMC đọc dòng tức thời ≈ 0 trên máy này). Dùng hai bước `begin` và `end`, giữa hai bước chạy `pmset sleepnow` rồi đánh thức sau 10+ phút.

**Hàm chính:**
- `battery()`: đọc `AppleRawCurrentCapacity` (mAh), `Voltage` (mV), `ExternalConnected` từ `ioreg -r -c AppleSmartBattery`.
- `s0ix()`: đọc nút `S0ixStandby` từ `ioreg`.
- `main()`: `begin` từ chối nếu đang cắm sạc, lưu mAh/mV/thời điểm vào `~/.s0ix_power_test.json`; `end` tính hao mAh, công suất trung bình `drop·mV/1e6/giờ` và in các thuộc tính `S0ixStandby` có chứa sleep/wake/residency/blocker/gpu/d3/last.

**Phụ thuộc:** kext `S0ixStandby` (cho phần thuộc tính); không gọi file nào khác của dự án. Kết quả `2,65 W` so với `3,85 W` trong `docs/HARDWARE_AND_PATCHES.md` liên quan tới công cụ này, nhưng file này không ghi kết quả đó.

**Lưu ý:**
- Độ phân giải thấp: hao vài mAh cho số rất thô; docstring khuyên ≥ 15 phút. Mỗi lần đo chỉ một mẫu, không có lặp.
- Dùng điện áp trung bình đầu/cuối, không tính điện áp thay đổi khi ngủ [suy đoán].
- Nếu chạy `end` mà thiếu file trạng thái thì ném lỗi `FileNotFoundError` (không có xử lý).
