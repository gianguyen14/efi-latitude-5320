# Tích Hợp AppleALC Cho Âm Thanh & Micro Trên Dell Latitude 5320

## 1. Trạng Thái Triển Khai Kỹ Thuật

Đã hoàn tất tải xuống, tích hợp kext âm thanh **[`AppleALC.kext`](file:///run/media/nguyen/EFI/EFI/OC/Kexts/AppleALC.kext) (v1.9.8 Release)** và cấu hình thử nghiệm đầu tiên **`alcid=33`** trực tiếp trên USB boot và kho lưu trữ GitHub.

| Thành phần | Chi tiết cấu hình | Trạng thái kiểm định |
|---|---|:---:|
| **Kext Âm thanh** | `AppleALC.kext` (v1.9.8 chính thức từ Acidanthera) | Đã nạp tại index 2 (sau `Lilu.kext` và `PC711Probe.kext`) |
| **Boot-arg Âm thanh** | `alcid=33` (layout ưu tiên số 1 cho dòng Dell Latitude 7210/5320) | Đã thêm vào `NVRAM -> Add -> 7C436110-... -> boot-args` |
| **Chuỗi Boot-args đầy đủ** | `-v -igfxvesa watchdog=0 -wegnoegpu keepsyms=1 debug=0x100 msgbuf=1048576 -pc711pdbg alcid=33` | Nguyên vẹn toàn bộ tham số chẩn đoán & VESA |
| **Kiểm định ocvalidate** | OpenCore 1.0.8 compatibility check | **PASS (0 lỗi)** |
| **Đồng bộ phần cứng** | Ghi dữ liệu USB (`sync`) và đẩy lên GitHub | Hoàn thành (`b86350a`) |

---

## 2. Kế Hoạch Kiểm Thử Từng Layout ALC295 (`10ec:0295`)

Sau mỗi lần khởi động vào macOS hoặc Recovery, nếu âm thanh/micro chưa nhận đúng, chỉ cần sửa giá trị `alcid` trong `config.plist` (hoặc gõ đè trực tiếp tại OpenCore Picker nếu bật chế độ nhập):

1. **`alcid=33`** (Đang nạp): Layout Dell Latitude thế hệ mới (hỗ trợ combo jack + mic).
2. **`alcid=77`**: Layout Dell Latitude 5290 / 5000-series.
3. **`alcid=13`**: Layout Dell Inspiron / Latitude 7570.
4. **`alcid=3`**: Layout ALC295 / ALC3254 tổng quát.
5. **`alcid=15`**: Layout ALC295 tổng quát thay thế.
6. **`alcid=75`**: Layout Dell Inspiron 7590.

---

## 3. Các Tiêu Chí Đánh Giá Chức Năng

* **Loa trong (Internal Speakers):** Kiểm tra âm thanh hệ thống hoặc thanh âm lượng trên menu bar.
* **Jack tai nghe 3.5mm:** Cắm tai nghe xem macOS có tự động chuyển đổi từ Internal Speakers sang Headphones không.
* **Micro tích hợp (Internal Mic - Node `0x12`):** Kiểm tra trong System Settings → Sound → Input xem có thanh đo tín hiệu âm thanh khi nói vào máy không.
* **Micro tai nghe (Headset Mic - Node `0x19`):** Cắm tai nghe có mic để kiểm tra đường thu âm analog.
