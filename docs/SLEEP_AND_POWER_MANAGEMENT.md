# Hướng Dẫn Quản Lý Nguồn Điện & Chế Độ Sleep (Dell Latitude 5320)

Tài liệu này phân tích chi tiết cơ chế quản lý năng lượng (Power Management), nguyên nhân hiện tượng chậm trễ/đơ khi đi vào giấc ngủ (Sleep Deadlock) trên kiến trúc Intel Tiger Lake (11th Gen), và giải pháp cấu hình tối ưu.

---

## 1. Bản Chất Kỹ Thuật Của Vấn Đề Sleep Trên Tiger Lake Hackintosh

Trên các dòng máy Mac chính thức (Native Macs), Apple tự thiết kế kiến trúc bo mạch (SoC hoặc T2/Apple Silicon) cùng bộ điều khiển nguồn điện riêng biệt để đồng bộ trạng thái nguồn giữa CPU, GPU, NVMe và mạng không dây.

Trên **Dell Latitude 5320 (Tiger Lake i5-1145G7)** chạy macOS Sequoia, chế độ Sleep truyền thống (`S3 Standby`) phải đối mặt với **3 rào cản kỹ thuật lớn**:

### 1.1. Hiện tượng Driver Đồ Họa Phản Hồi Chậm (`AppleIntelFramebuffer`)
Trích xuất từ log hệ thống:
```text
Kernel Client Acks Delays to Sleep notifications: [AppleIntelFramebuffer driver is slow(msg: SetState to 1)(646 ms)]
```
* **Nguyên nhân:** Bản vá đồ họa `WhateverXe` đưa macOS vào một giao thức tương thích giả lập cho iGPU Iris Xe. Khi hệ thống nhận lệnh ngủ, macOS gửi tín hiệu `SetState` đến framebuffer để hạ nguồn điện GPU xuống D3Cold. Do không có vi mã (microcode) gốc từ Apple, framebuffer mất tới hơn 600ms để phản hồi, dễ khiến hệ thống vi phạm ngưỡng giới hạn thời gian (watchdog timeout) của macOS.
* **Giải pháp đã áp dụng:**
  - Bổ sung boot-arg `watchdog=0` để vô hiệu hóa việc kernel tự động ép reboot khi driver đồ họa xử lý chậm.
  - Bổ sung boot-arg `igfxonln=1` nhằm giữ kênh truyền tín hiệu hiển thị online, chống việc mất kết nối tín hiệu khi tắt/bật màn hình.

### 1.2. Hiện tượng Timeout Của Ngăn Xếp Wi-Fi (`wifip2pd`)
Trích xuất từ log hệ thống:
```text
Kernel Client Acks Delays to Sleep notifications: [wifip2pd timed out(30000 ms)]
```
* **Nguyên nhân:** Daemon mạng ngang hàng `wifip2pd` (phục vụ AirDrop/Wi-Fi Direct của Apple) cố gắng ngắt kết nối mạng qua driver không dây trước khi ngủ. Đối với card Wi-Fi Intel (chạy qua `itlwm`), tiến trình này thường bị kẹt chờ phản hồi quá 30 giây (30000 ms), làm chậm trễ quá trình hạ nguồn.

### 1.3. Ngắt Chờ USB Ngoại Vi & Cảm Biến Nội Bộ (USB Wake Assertions)
Trích xuất từ log hệ thống:
```text
Kernel Assertions: 0x4=USB owner=2.4G Receiver / owner=58200 (eventType:17)
```
* **Nguyên nhân:**
  - **Đầu thu chuột 2.4G Receiver:** Liên tục phát ngắt tín hiệu thăm dò `eventType:17` khi người dùng di chuyển hoặc cắm đầu thu, kích hoạt yêu cầu thức giấc ngay khi máy vừa chuẩn bị ngủ.
  - **Cảm biến vân tay Broadcom 58200:** Đây là thiết bị USB nội bộ không có driver trên macOS. Khi hệ thống ra lệnh hạ nguồn USB Bus xuống trạng thái D3, cảm biến này không phản hồi tín hiệu xác nhận (ACK), khiến cổng USB bị treo ở trạng thái chờ.
* **Giải pháp đã áp dụng trong USBMap:**
  - Vô hiệu hóa cổng `#port` của `HS05` (Fingerprint 58200) trong `USBMap.kext` để macOS không còn thăm dò hay yêu cầu chuyển đổi nguồn điện với cảm biến này.
  - Giữ nguyên cổng Webcam `HS04` và Bluetooth `HS06/HS10` theo chuẩn tương thích.

---

## 2. Giải Pháp Quản Lý Nguồn Hiện Tại (Display Sleep Workaround)

Để đảm bảo máy tính hoạt động ổn định tuyệt đối trong công việc hàng ngày, **tránh hiện tượng quạt quay, đèn nguồn sáng nhưng màn hình đen phải đè nút nguồn cưỡng bức**, cấu hình nguồn điện đã được chuyển sang chế độ **Tắt Màn Hình Tiết Kiệm Điện (Display Sleep)**.

### 2.1. Thiết lập bằng lệnh Terminal

Chạy khối lệnh sau trong macOS Terminal:

```bash
# 1. Tắt chế độ System Sleep tự động (ngăn máy rơi vào trạng thái S3/S4 lỗi)
sudo pmset -a sleep 0

# 2. Bật tắt màn hình tự động sau 5 phút không hoạt động để tiết kiệm pin
sudo pmset -a displaysleep 5

# 3. Tắt chế độ ngủ đông Hibernate (chống lỗi ghi RAM vào NVMe)
sudo pmset -a hibernatemode 0

# 4. Tắt chế độ chờ Standby & Tự động ngắt nguồn
sudo pmset -a standby 0
sudo pmset -a autopoweroff 0

# 5. Tắt toàn bộ các ngắt thức giấc từ mạng và thiết bị ngoại vi
sudo pmset -a womp 0            # Tắt Wake-on-LAN
sudo pmset -a powernap 0        # Tắt Power Nap
sudo pmset -a proximitywake 0   # Tắt thức giấc từ thiết bị Apple lân cận
sudo pmset -a tcpkeepalive 0    # Tắt giữ kết nối mạng ngầm
```

### 2.2. Ý nghĩa của từng tham số:

| Lệnh `pmset` | Giá trị | Ý nghĩa thực tế trên Dell Latitude 5320 |
|---|:---:|---|
| `sleep 0` | `0` | Hệ thống không tự động đưa toàn bộ phần cứng vào chế độ ngủ sâu S3. CPU sẽ tự động hạ xung nhịp xuống 1.0 GHz (nhờ `CPUFriend`) khi máy nhàn rỗi. |
| `displaysleep 5` | `5` | Màn hình sẽ tắt sau 5 phút không thao tác, giúp màn hình và iGPU giảm tải điện năng tiêu thụ mà không gây deadlock. |
| `hibernatemode 0` | `0` | Không ghi toàn bộ dung lượng RAM vào file `sleepimage` trên SSD NVMe (tránh hao mòn SSD và tránh lỗi timeout I/O). |
| `standby 0` | `0` | Vô hiệu hóa việc chuyển từ Sleep thường sang Deep Standby sau một khoảng thời gian nhất định. |
| `autopoweroff 0` | `0` | Tắt tính năng tự tắt nguồn theo tiêu chuẩn bảo vệ môi trường của Apple. |
| `tcpkeepalive 0` | `0` | Ngắt các tiến trình ngầm cố gắng truy cập Internet khi màn hình đã tắt. |

---

## 3. Quy Trình Sử Dụng Hằng Ngày Được Khuyến Nghị

1. **Khi rời bàn làm việc ngắn (dưới 1-2 tiếng):**
   - Chỉ cần gập màn hình hoặc nhấn tổ hợp phím `Control + Shift + Eject/Power` (hoặc phím tắt khóa màn hình).
   - Màn hình sẽ tắt ngay lập tức, CPU hạ xung về mức thấp nhất để tiết kiệm pin.
   - Khi mở máy, chỉ cần nhấn phím bất kỳ hoặc chạm vào touchpad, màn hình sẽ sáng lại ngay lập tức (không bị trễ).
2. **Khi không sử dụng trong thời gian dài (qua đêm hoặc bỏ balo di chuyển):**
   - Nên thực hiện **Shut Down (Tắt máy)** hoàn toàn. Do ổ SSD NVMe SK hynix BC711 đã được vá với `PC711Probe.kext`, thời gian khởi động lại máy chỉ mất khoảng 15-20 giây.

---

## 4. Các Lệnh Chẩn Đoán Quản Lý Nguồn Điện Hữu Ích

Để kiểm tra trạng thái năng lượng hoặc chẩn đoán khi gặp hiện tượng máy không tự tắt màn hình:

```bash
# Xem cấu hình pmset hiện tại
pmset -g

# Xem danh sách các ứng dụng hoặc thiết bị đang giữ ngắt ngăn cản giấc ngủ
pmset -g assertions

# Xem lịch sử các lần Sleep và Wake trong 24 giờ qua
pmset -g log | grep -E "Sleep|Wake|Failure|Timeout|Slow" | tail -50

# Xem lý do cụ thể khiến máy thức dậy lần gần nhất
pmset -g log | grep "Wake reason"
```
