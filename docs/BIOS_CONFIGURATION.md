# Cấu Hình Thiết Lập BIOS Chuẩn Cho Dell Latitude 5320 Hackintosh

Tài liệu này hướng dẫn chi tiết từng mục thiết lập trong BIOS của **Dell Latitude 5320** (Đã kiểm thử và tối ưu trên phiên bản BIOS **`1.52.0`** hoặc mới hơn) trước khi tiến hành cài đặt macOS Sequoia / Sonoma.

---

## 1. Cách Truy Cập Menu BIOS

1. Tắt máy hoàn toàn.
2. Bật nút nguồn và nhấn liên tục phím **`F2`** khi logo Dell xuất hiện cho đến khi màn hình thiết lập BIOS (Dell BIOS Setup) hiển thị.
3. *Mẹo:* Nếu bạn muốn chọn thiết bị khởi động nhanh từ USB mà không vào BIOS, nhấn phím **`F12`** (One-Time Boot Menu).

---

## 2. Bảng Danh Mục Cấu Hình Chi Tiết

### 2.1. System Configuration (Cấu hình hệ thống)
* **SATA / NVMe Operation:**
  - Chọn: **`AHCI / NVMe`**
  > [!CAUTION]
  > **BẮT BUỘC:** Tuyệt đối không chọn `RAID On`. Nếu để `RAID On`, macOS sẽ không thể tìm thấy ổ cứng NVMe SK hynix BC711.
* **Storage Interface:**
  - `M.2 PCIe SSD-0`: **Enabled** (Đánh dấu chọn).
* **USB Configuration:**
  - `Enable USB Boot Support`: **Enabled**
  - `Enable External USB Port`: **Enabled**
* **Thunderbolt / Type-C Configuration:**
  - `Enable Thunderbolt Technology Support`: **Enabled**
  - `Enable Thunderbolt Boot Support`: **Enabled** (tùy chọn)
  - `Thunderbolt Security Level`: **No Security** (hoặc `User Authorization`).
* **Miscellaneous Devices:**
  - `Enable Camera`: **Enabled** (nếu muốn dùng Webcam)

---

### 2.2. Security (Bảo mật)
* **Secure Boot:**
  - `Secure Boot Enable`: **Disabled** (BẮT BUỘC để boot vào OpenCore).
* **Intel SGX (Software Guard Extensions):**
  - `Intel SGX`: **Disabled** (Tránh xung đột bộ nhớ với kernel macOS).
* **PTT / TPM 2.0 Security:**
  - `TPM 2.0 Security`: Bật hoặc tắt đều được (macOS không sử dụng TPM của PC).
* **Admin Password / System Password:**
  - Khuyến nghị xóa trống (không đặt mật khẩu) trong quá trình cài đặt để dễ can thiệp.

---

### 2.3. Pre-boot Behavior (Hành vi trước khởi động)
* **Fastboot:**
  - Chọn: **`Thorough`**
  > [!TIP]
  > Chế độ `Thorough` giúp BIOS quét và khởi tạo toàn bộ phần cứng (bàn phím, trackpad, USB bus, cổng mạng) một cách đầy đủ trước khi chuyển quyền điều khiển cho OpenCore. Tránh hiện tượng trackpad hoặc bàn phím không nhận khi vừa bật máy.
* **Extend BIOS POST Time:**
  - `0 seconds` (hoặc `2 seconds` nếu muốn có thêm thời gian bấm F12).

---

### 2.4. Virtualization Support (Hỗ trợ ảo hóa)
* **Intel Virtualization Technology (VT-x):**
  - Chọn: **`Enabled`** (Cần thiết cho ảo hóa và hiệu năng CPU).
* **VT for Direct I/O (VT-d):**
  - Chọn: **`Enabled`** (OpenCore đã kích hoạt quirk `DisableIoMapper = True` để bảo đảm an toàn khi VT-d bật).

---

### 2.5. Power Management (Quản lý nguồn điện)
* **Wake on AC:** **Disabled**
* **Wake on Dell USB-C Dock:** **Disabled**
* **Block Sleep:** **Disabled**
* **Intel SpeedStep / Speed Shift Technology:** **Enabled** (cần thiết cho `CPUFriend`).

---

## 3. Khôi Phục Thiết Lập Mặc Định Nếu Gặp Sự Cố

Nếu hệ thống bị xung đột thiết lập hoặc không thể boot:
1. Tại góc dưới màn hình BIOS Setup, nhấn vào nút **`Restore Settings`**.
2. Chọn **`BIOS Defaults`** và nhấn OK.
3. Sau khi khôi phục, bạn chỉ cần kiểm tra lại 2 mục quan trọng nhất:
   - Đảm bảo `SATA Operation` là **`AHCI / NVMe`** (mặc định của Dell đôi khi là `RAID On`).
   - Đảm bảo `Secure Boot` là **`Disabled`**.
4. Nhấn **`Apply Changes`** và **`Exit`** để lưu lại.
