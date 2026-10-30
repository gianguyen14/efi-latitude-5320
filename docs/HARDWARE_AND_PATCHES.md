# Chi Tiết Phần Cứng & Các Bản Vá Kỹ Thuật (Dell Latitude 5320)

Tài liệu này ghi lại chi tiết các giải pháp kỹ thuật, cơ chế hoạt động của kext và thiết lập kernel nhằm hiện thực hóa Hackintosh trên kiến trúc **Intel Tiger Lake (11th Gen Core)** — vốn không được Apple hỗ trợ chính thức trên các dòng máy Mac thực tế.

---

## 1. Bản Vá Đồ Họa: Intel Iris Xe Graphics (Tiger Lake-U)

### 1.1. Bối cảnh kỹ thuật
* **Phần cứng:** Intel Iris Xe Graphics G7 96 EUs (`Device ID: 0x9A49`, `Vendor ID: 0x8086`).
* **Vấn đề trên macOS:** Apple chuyển sang kiến trúc Apple Silicon (M1) ngay sau thế hệ Intel Ice Lake (10th Gen). Dòng Tiger Lake (11th Gen) sở hữu kiến trúc đồ họa mới (Intel Gen12 Xe LP) hoàn toàn khác biệt với Gen11 Ice Lake và không có driver gốc từ Apple trong macOS.
* Thông thường, các laptop 11th Gen chỉ có thể boot vào macOS ở chế độ VESA (`-igfxvesa`) không có tăng tốc đồ họa (no QE/CI), dẫn đến hiện tượng giật lag, không thể chỉnh độ sáng, không hỗ trợ Metal và các ứng dụng đồ họa bị crash.

### 1.2. Giải pháp: WhateverXe (Bản Tailored Custom v0.6.1) + AppleIntelTGLCompat
EFI này sử dụng giải pháp đồ họa tiên tiến được biên dịch và tùy biến chuyên sâu:
* **Kext:** [`WhateverXe.kext`](https://github.com/b00t0x/WhateverXe) — Được xây dựng và patch tùy chỉnh từ nhánh phát triển `v0.6.1` dành riêng cho cấu hình Dell Latitude 5320:
  - **Khắc phục lỗi treo GPU trên Sequoia 15.8.1 (Darwin 24.6.0):** Mở rộng cơ chế `wrapTGLRecovery` (`IGAccelFIFOChannel::resetHardwareAndReplay`) sang macOS Sequoia, cho phép kernel tự động reset và tiếp tục lập lịch khi gặp lỗi batch buffer / ring hang thay vì làm đơ toàn bộ máy.
  - **Kích hoạt `tahoeTrialScope` cho Sequoia:** Mang lại tính năng `tglSameTailRestoreEnabled` (ngăn chặn tình trạng kẹt ring khi resubmit cùng tail pointer), sửa lỗi thanh ghi GSYNC (`tglGSYNCReady` tại B0A0[2] cho stepping 1 của 0x9A49), và sửa lỗi Vol14 constant-cache invalidation.
  - **Tối ưu hóa quản lý hàng đợi lệnh:** Kích hoạt `tglHangPreStopBridge` (`IGScheduler::haltCommandStreamer`) giúp dừng hardware command streamer an toàn, tránh văng kernel panic khi ứng dụng WebGL/Metal nặng gặp sự cố.
  - **Tối ưu hóa Stack Kernel:** Tích hợp các commit mới nhất từ WhateverXe 0.6.1 (`2ab88c5`, `6427c3e`, `3013a1a`) giúp giải phóng và tái sử dụng bộ nhớ đệm hiển thị, loại bỏ hoàn toàn nguy cơ tràn kernel stack frame.
* **Framework phụ trợ:** `AppleIntelTGLCompat` kết hợp cùng `AMFIPass.kext` để vượt qua cơ chế kiểm tra chữ ký mã nguồn (AMFI) của macOS Sequoia.
* **Kết quả đạt được:**
  - Nhận diện chính xác `Intel Iris Xe Graphics` với thông số Dell Latitude 5320 trong IORegistry.
  - VRAM cấp phát động tối đa **1536 MB**.
  - Kích hoạt **Metal 2** đầy đủ, giao diện Liquid mượt mà 60 FPS.
  - Hỗ trợ màn hình trong độ phân giải Full HD (1920x1080 @ 60.00Hz ARGB8888).

### 1.3. Các boot-arg bắt buộc cho đồ họa
* `igfxonly=1`: Ép hệ thống chỉ nhận diện và khởi tạo card đồ họa tích hợp iGPU, bỏ qua việc quét GPU rời.
* `-disablegfxfirmware`: Vô hiệu hóa việc nạp Apple GuC / HuC firmware lên iGPU Intel (tránh crash khi khởi tạo driver).
* `-allow3d`: Cho phép kích hoạt pipeline dựng hình 3D / Metal context.
* `igfxonln=1`: Đảm bảo tín hiệu màn hình luôn ở trạng thái trực tuyến (online) khi thức dậy từ sleep hoặc tắt màn hình.
* `-wegnoegpu`: Ngăn chặn WhateverGreen thăm dò card đồ họa rời.

---

## 2. Bản Vá Ổ Cứng NVMe: SK hynix BC711 (`PC711Probe.kext`)

### 2.1. Vấn đề
* **Mã linh kiện:** `SK hynix BC711 HFM512GD3JX013N` (PCI ID `1C5C:174A`, Firmware `HPS1`).
* **Hiện tượng:** Dòng SSD OEM SK hynix BC711 gặp lỗi không tương thích hàng đợi ngắt MSI-X trong driver `AppleNVMeController` của Apple. Ngay khi macOS tải kernel hoặc thực hiện lệnh I/O đầu tiên, ổ đĩa sẽ bị timeout:
  ```text
  AppleNVMeController::... Command timed out
  panic(cpu 0 caller 0xffffff80...): "AppleNVMeController::... timeout"
  ```
  Lỗi này khiến máy treo cứng ngay sau mốc `[EB|#LOG:EXITBS:START]` và không thể vào bộ cài.

### 2.2. Giải pháp
* Sử dụng kext chuyên dụng [`PC711Probe.kext`](https://github.com/hrx114514x/PC711Probe) phiên bản `v1.8.1` (phát triển bởi `stationk9` & `hrx114514x`).
* **Vị trí nạp trong config.plist:** Nạp ngay sau `Lilu.kext` (vị trí ưu tiên cao nhất).
* **Phạm vi kernel:** `MinKernel: 20.0.0` (macOS 11 Big Sur) đến `MaxKernel: 24.99.99` (macOS 15 Sequoia).
* **Boot-arg:** `-pc711pdbg` để bật chế độ tương thích và ghi log chẩn đoán hàng đợi I/O của NVMe.
* **Hiệu năng:** Ổ cứng đạt tốc độ đọc/ghi NVMe PCIe 3.0 x4 đầy đủ, S.M.A.R.T Verified và hỗ trợ TRIM gốc của APFS.

---

## 3. Quản Lý Điện Năng CPU: CPUFriend & Tiger Lake HWP

### 3.1. Cấu hình
* **CPU:** Intel Core i5-1145G7 @ 2.60 GHz (Turbo boost lên tới 4.40 GHz).
* **Kext:**
  - `CPUFriend.kext` (v1.2.9)
  - `CPUFriendDataProvider.kext` (được tối ưu hóa riêng cho mã vi xử lý Tiger Lake-U và SMBIOS `MacBookPro16,2`).
* **Cơ chế:**
  - Kích hoạt tính năng Intel Speed Shift (HWP - Hardware P-States).
  - Tần số sàn (CPUFloor): 1000 MHz (1.0 GHz).
  - Tần số trần (CPUMax): 4400 MHz (4.4 GHz).
  - Tích hợp `Energy Performance Preference (EPP)` để tự động cân bằng giữa tiết kiệm pin và hiệu năng cao khi cắm sạc.
  - Quirk `ProvideCurrentCpuInfo = True` trong OpenCore giúp kernel macOS hiểu đúng cấu trúc 4 Cores / 8 Threads của vi xử lý Intel thế hệ 11.

---

## 4. Bàn Phím, Chuột & Trackpad I2C

### 4.1. Bàn phím Dell (PS/2)
* Sử dụng `VoodooPS2Controller.kext` với module `VoodooPS2Keyboard.kext`.
* Các phím đa phương tiện (tăng giảm âm lượng, play/pause, độ sáng màn hình) và đèn nền bàn phím hoạt động đầy đủ.
* Hai plugin `VoodooPS2Mouse.kext` và `VoodooPS2Trackpad.kext` được **tắt (Disabled = False)** để tránh xung đột với driver I2C.

### 4.2. Precision Touchpad (I2C HID)
* **Bộ kext điều khiển:**
  - `VoodooI2C.kext` (Core Engine)
  - `VoodooI2CServices.kext`
  - `VoodooGPIO.kext`
  - `VoodooInput.kext`
  - `VoodooI2CHID.kext` (Satellite driver cho touchpad I2C HID)
* **Boot-arg tối ưu:** `-vi2c-force-polling`
  - *Lý do:* Bộ điều khiển ngắt APIC/GPIO trên bo mạch chủ Dell 5320 thường gặp hiện tượng rớt gói tín hiệu (dropped interrupts) nếu để chế độ ngắt mặc định. Flag `-vi2c-force-polling` ép VoodooI2C hoạt động ở chế độ polling với tần số cao, mang lại trải nghiệm tracking mượt mà, phản hồi ngay lập tức và hỗ trợ đầy đủ cử chỉ đa điểm macOS (2 ngón cuộn trang, 3 ngón chuyển desktop, pinch-to-zoom).

---

## 5. Âm Thanh (Audio): Realtek ALC3254 / ALC236

* **Kext:** `AppleALC.kext` (v1.9.8)
* **Boot-arg:** `alcid=33`
* **Hỗ trợ:**
  - Loa trong stereo (Internal Speakers).
  - Micro tích hợp (Internal Microphone) ở tần số lấy mẫu 48000 Hz.
  - Tự động chuyển đổi cổng ra khi cắm tai nghe combo jack 3.5mm.

---

## 6. Mạng & Kết Nối Không Dây: Wi-Fi & Bluetooth AX201

* **Card mạng:** Intel Wi-Fi 6 AX201 (giao tiếp CNVi qua chipset Tiger Lake).
* **Wi-Fi:**
  - Sử dụng `AirportItlwm.kext` (v2.4.0-alpha từ nhánh `laobamac/itlwm` tối ưu cho macOS 15 Sequoia Darwin 24.x).
  - Hoạt động trực tiếp qua menu Wi-Fi và Control Center gốc của macOS (không cần app HeliPort).
  - Hỗ trợ đầy đủ dịch vụ định vị Location Services (Apple Maps / Find My).
  - Bổ sung boot-arg `itlwm_he=1` để kích hoạt giao thức truyền dữ liệu Wi-Fi 6 (802.11ax).
* **Bluetooth:**
  - Giao tiếp qua cổng USB nội bộ (`HS10` hoặc `HS06`).
  - Sử dụng bộ 3 kext: `IntelBluetoothFirmware.kext` + `IntelBTPatcher.kext` + `BlueToolFixup.kext`.
  - Boot-args: `-btlfxbeta -btlfxallanyaddr` (cho phép BlueToolFixup bỏ qua các giới hạn phiên bản và nạp firmware trên macOS Sequoia).

---

## 7. Chi Tiết Bản Đồ Cổng USB (USB Port Mapping)

Toàn bộ hệ thống cổng USB được ánh xạ chuẩn xác qua `USBMap.kext` cho controller `AppleUSBXHCI` (SMBIOS `MacBookPro16,2`):

| Port | Giao tiếp | Kiểu cổng (Connector) | Thiết bị phần cứng kết nối | Ghi chú |
|---|---|---|---|---|
| **HS02** | USB 2.0 | `3` (USB 3.0 Type-A) | Cổng USB-A ngoài (Bên phải) | Hỗ trợ cắm chuột, USB, ổ cứng di động |
| **HS03** | USB 2.0 | `3` (USB-A / USB-C) | Cổng USB ngoài / Thunderbolt | Hỗ trợ hub và thiết bị Type-C |
| **HS04** | USB 2.0 | `3` | **Integrated_Webcam_HD** (`3141:27145`) | Camera họp trực tuyến, FaceTime |
| **HS05** | USB 2.0 | `3` (Disabled `#port`) | **Broadcom 58200 Fingerprint** (`2652:22595`) | Cảm biến vân tay (Tắt trong map để chống kẹt D3) |
| **HS06** | USB 2.0 | `3` | Thiết bị mở rộng / Intel USB device | Giữ mở để đảm bảo định tuyến Bluetooth |
| **HS08** | USB 2.0 | `3` (USB 3.0 Type-A) | Cổng USB-A ngoài (Bên trái) | Tương thích USB 2.0 tốc độ cao |
| **HS10** | USB 2.0 | `255` (Internal) | **Intel AX201 Bluetooth** (`8087:0026`) | Cổng nội bộ bắt buộc cho Bluetooth |
| **SS01-SS04** | USB 3.0 | `3` (SuperSpeed) | Các đường truyền USB 3.0 tốc độ 5Gbps/10Gbps | Truyền dữ liệu tốc độ cao |

---

## 8. Bảng Ý Nghĩa Chi Tiết 14 Boot-Args

Dưới đây là bảng giải trình kỹ thuật cho chuỗi boot-args đang sử dụng trong EFI:

```text
igfxonly=1 -btlfxbeta -btlfxallanyaddr ipc_control_port_options=0 -amfi_get_out_of_my_way -allow3d -disablegfxfirmware watchdog=0 -wegnoegpu keepsyms=1 debug=0x100 msgbuf=1048576 -pc711pdbg alcid=33 -vi2c-force-polling igfxonln=1 itlwm_he=1
```

| STT | Boot-arg | Mục đích kỹ thuật |
|:---:|---|---|
| 1 | `igfxonly=1` | Chỉ kích hoạt card đồ họa tích hợp iGPU, bỏ qua việc khởi tạo GPU rời không tương thích. |
| 2 | `-btlfxbeta` | Cho phép `BlueToolFixup` hoạt động trên các phiên bản macOS mới nhất / beta (macOS 15 Sequoia). |
| 3 | `-btlfxallanyaddr` | Bỏ qua việc so khớp địa chỉ MAC/firmware của Bluetooth, giúp nạp patch trên mọi chipset Intel AX. |
| 4 | `ipc_control_port_options=0` | Nới lỏng kiểm tra quyền IPC Mach Port của kernel, cần thiết cho một số daemon đồ họa tùy biến. |
| 5 | `-amfi_get_out_of_my_way` | Vô hiệu hóa bộ lọc hạn chế của Apple Mobile File Integrity (kết hợp cùng `AMFIPass.kext`). |
| 6 | `-allow3d` | Mở khóa khả năng kết xuất 3D và Metal acceleration trong driver patch WhateverXe. |
| 7 | `-disablegfxfirmware` | Chặn macOS nạp Apple Intel Graphics Firmware lên card Tiger Lake, tránh lỗi panic kernel. |
| 8 | `watchdog=0` | Tắt bộ đếm thời gian kernel watchdog, chống crash tự khởi động khi driver đồ họa xử lý chậm. |
| 9 | `-wegnoegpu` | Chặn WhateverGreen thăm dò và kích hoạt GPU ngoài. |
| 10 | `keepsyms=1 debug=0x100` | Giữ lại bảng ký hiệu debug và ngăn máy tự reboot khi gặp sự cố, giúp hiển thị panic log ra màn hình. |
| 11 | `msgbuf=1048576` | Mở rộng bộ đệm log nhân kernel (dmesg buffer) lên 1 MB để không bị mất thông tin chẩn đoán. |
| 12 | `-pc711pdbg` | Bật chế độ tương thích và debug MSI-X queue cho ổ cứng NVMe SK hynix BC711. |
| 13 | `alcid=33` | Layout ID cho chip âm thanh Realtek ALC3254 / ALC236 của Dell Latitude 5320. |
| 14 | `-vi2c-force-polling` | Ép driver touchpad VoodooI2C hoạt động ở chế độ Polling, đảm bảo mượt mà tuyệt đối trên Dell. |
| 15 | `igfxonln=1` | Giữ màn hình iGPU luôn ở trạng thái online, ngăn hiện tượng đen màn hình khi thức dậy. |
| 16 | `itlwm_he=1` | Mở khóa chuẩn Wi-Fi 6 (802.11ax / High Efficiency) cho card Intel AX201 trong AirportItlwm. |
