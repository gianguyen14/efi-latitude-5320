# Dell Latitude 5320 Hackintosh (OpenCore 1.0.8)

[![OpenCore](https://img.shields.io/badge/OpenCore-1.0.8-blue.svg)](https://github.com/acidanthera/OpenCorePkg)
[![macOS](https://img.shields.io/badge/macOS-Sequoia%2015.x%20%7C%20Sonoma%2014.x-brightgreen.svg)](https://www.apple.com/macos/)
[![Hardware](https://img.shields.io/badge/CPU-Intel%20Tiger%20Lake%20i5--1145G7-orange.svg)]()
[![NVMe](https://img.shields.io/badge/SSD-SK%20hynix%20BC711%20(Patched)-success.svg)]()

Bộ cài đặt EFI OpenCore 1.0.8 đã được thẩm định và kiểm thử thực tế trên **Dell Latitude 5320**, hỗ trợ boot vào bộ cài và môi trường **macOS Sequoia (15.x)** và **macOS Sonoma (14.x)**.

---

## 1. Thông Số Phần Cứng (Hardware Specifications)

| Thành phần | Chi tiết linh kiện | Nhận dạng phần cứng / PCI ID | Trạng thái hiện tại |
|---|---|---|:---:|
| **Laptop** | Dell Latitude 5320 | BIOS Tested: `1.52.0` | Hoàn toàn tương thích |
| **CPU** | Intel Core i5-1145G7 (Tiger Lake-U) | 4 Cores / 8 Threads, 2.60 GHz up to 4.40 GHz | Hoạt động tốt |
| **iGPU** | Intel Iris Xe Graphics G7 (96 EUs) | `8086:9A49` | Chế độ VESA Framebuffer (`-igfxvesa`) cho giai đoạn cài đặt |
| **RAM** | 16 GB LPDDR4x / DDR4 3200MHz | Kênh đôi (Dual-channel) | Nhận đầy đủ |
| **SSD NVMe** | **SK hynix BC711** NVMe 512GB | `1C5C:174A` (Model: `HFM512GD3JX013N`, FW: `HPS1`) | **ĐÃ VÁ THÀNH CÔNG** qua `PC711Probe.kext` |
| **Wi-Fi** | Intel Wi-Fi 6 AX201 (CNVi) | `8086:a0f0` (rev 20) | Sẵn sàng (khuyến nghị dùng `itlwm` + HeliPort trên Sequoia) |
| **Bluetooth** | Intel AX201 Bluetooth | `8087:0026` (USB nội bộ `HS10`) | Sẵn sàng qua `IntelBluetoothFirmware` + `BlueToolFixup` |
| **Audio** | Realtek ALC3254 (ALC236) | Intel Smart Sound Technology | Chuẩn bị tích hợp AppleALC |
| **Bàn phím & Chuột** | Bàn phím Dell PS/2 + Touchpad I2C | `VoodooPS2Controller` | Bàn phím & trackpad hoạt động |

---

## 2. Các Điểm Nổi Bật & Bản Vá Đặc Biệt (Key Highlights & Patches)

### 2.1. Khắc phục triệt để lỗi Kernel Panic trên SK hynix BC711 (`PC711Probe.kext`)
* **Vấn đề:** Ổ cứng OEM **SK hynix BC711** (`1C5C:174A`) trên Dell Latitude 5320 bị treo khi macOS khởi tạo ngắt MSI-X trong driver `AppleNVMeController`, dẫn tới lỗi:
  ```text
  AppleNVMeController::... Command timed out
  panic(cpu 0 caller 0xffffff80...): "AppleNVMeController::... timeout"
  ```
* **Giải pháp:** Tích hợp [`PC711Probe.kext`](https://github.com/hrx114514x/PC711Probe) phiên bản `v1.8.1`:
  - Nạp ngay sau `Lilu.kext` (tại index 1 trong `Kernel -> Add`).
  - Cấu hình phạm vi kernel: `MinKernel = 20.0.0`, `MaxKernel = 24.99.99` (bao phủ macOS 11 Big Sur đến macOS 15 Sequoia).
  - Bổ sung boot-arg chẩn đoán `-pc711pdbg`.
  - Giúp hệ thống vượt qua mốc `EXITBS:START` và khởi động kernel mượt mà không còn bị panic timeout.

### 2.2. Đồng bộ chuẩn OpenCore 1.0.8 Release Schema
* Toàn bộ binary OpenCore (`BOOTx64.efi`, `OpenCore.efi`, `OpenRuntime.efi`, `ResetNvramEntry.efi`, `ToggleSipEntry.efi`) đồng bộ chuẩn 1.0.8 chính thức.
* Bổ sung đầy đủ các schema mới của OpenCore 1.0.8:
  - `Booter -> Quirks -> ClearTaskSwitchBit = False`
  - `HideVerbose = False` trên tất cả UEFI Drivers
  - `UEFI -> Unload = []`
* Đạt thẩm định **0 lỗi** từ công cụ kiểm tra chính thức:
  ```text
  Completed validating EFI/OC/config.plist in 1 ms. No issues found.
  ```

---

## 3. Cấu Trúc Thư Mục EFI

```text
EFI/
├── BOOT/
│   └── BOOTx64.efi
└── OC/
    ├── ACPI/
    │   └── SSDT-EC-USBX-LAPTOP.aml
    ├── Drivers/
    │   ├── HfsPlus.efi
    │   ├── OpenCanopy.efi
    │   ├── OpenRuntime.efi
    │   ├── ResetNvramEntry.efi
    │   └── ToggleSipEntry.efi
    ├── Kexts/
    │   ├── Lilu.kext (v1.6.8)
    │   ├── PC711Probe.kext (v1.8.1 - Bản vá lỗi NVMe SK hynix)
    │   ├── VirtualSMC.kext
    │   ├── SMCBatteryManager.kext
    │   ├── VoodooPS2Controller.kext (kèm 4 plugins)
    │   ├── AirportItlwm.kext (tạm tắt trong giai đoạn cài đặt)
    │   ├── IntelBluetoothFirmware.kext (tạm tắt)
    │   ├── BlueToolFixup.kext (tạm tắt)
    │   ├── USBMap.kext (tạm tắt)
    │   └── USBInjectAll.kext (tạm tắt)
    ├── Resources/
    ├── Tools/
    ├── OpenCore.efi
    └── config.plist
```

---

## 4. Thiết Lập BIOS Khuyến Nghị (Dell Latitude 5320)

Truy cập BIOS bằng phím **F2** khi bật máy và cấu hình như sau:

* **System Configuration:**
  - `SATA Operation`: **AHCI / NVMe** (Tuyệt đối không để RAID On).
* **Security:**
  - `Secure Boot`: **Disabled**.
  - `Intel SGX`: **Disabled**.
  - `PTT / TPM`: Bật hoặc tắt đều được.
* **Pre-boot Behavior:**
  - `Fastboot`: **Thorough** (giúp khởi tạo đầy đủ thiết bị phần cứng).
* **Virtualization Support:**
  - `Intel VT-x`: **Enabled**.
  - `Intel VT-d`: **Enabled** (OpenCore đã bật `DisableIoMapper = True`).

---

## 5. Hướng Dẫn Cài Đặt (Installation Guide)

> [!IMPORTANT]
> **Tạo số Serial riêng qua GenSMBIOS:**
> Bản `config.plist` công khai trên GitHub đã được che số Serial (`C02XXXXXXXXX`), `MLB` và `SystemUUID`. Vui lòng sử dụng [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) để tạo bộ thông tin SMBIOS mới cho model **`MacBookPro16,2`** và điền vào mục `PlatformInfo -> Generic` trước khi đăng nhập Apple ID/iCloud.
> 
> Xem thêm tài liệu ghi chép nhật ký kiểm định chi tiết tại [docs/WALKTHROUGH.md](docs/WALKTHROUGH.md).

1. **Chuẩn bị USB:**
   - Định dạng phân vùng đầu tiên của USB dưới dạng **FAT32** (dung lượng tối thiểu 200MB, chuẩn GPT).
   - Chép nguyên vẹn thư mục `EFI/` từ repository này vào phân vùng FAT32 của USB.
2. **Khởi động:**
   - Cắm USB vào máy Dell Latitude 5320.
   - Bật máy và nhấn liên tục phím **F12** để mở Boot Menu của Dell.
   - Chọn dòng boot USB ở chế độ **UEFI**.
3. **Menu OpenCore Picker:**
   - Nhấn phím **Spacebar** để hiện các công cụ phụ.
   - Dùng phím mũi tên chọn mục **`Reset NVRAM`** và nhấn Enter (máy sẽ tự khởi động lại để xóa biến NVRAM cũ).
   - Nhấn tiếp **F12** khi máy khởi động lại → Chọn lại USB.
   - Chọn mục **`macOS Base System`** hoặc **`Install macOS Sequoia`** để bắt đầu cài đặt.

---

## 6. Lưu Ý Hậu Cài Đặt (Post-Install Notes)

* **Về Wi-Fi trên macOS Sequoia:**
  - Apple đã thay đổi toàn diện ngăn xếp mạng không dây trong Sequoia. Để có kết nối ổn định nhất và không lo lỗi panic, hãy tải [`itlwm.kext`](https://github.com/OpenIntelWireless/itlwm) và sử dụng cùng ứng dụng [HeliPort](https://github.com/OpenIntelWireless/HeliPort).
* **Về Bluetooth & USB Mapping:**
  - Chip Bluetooth Intel AX201 nằm tại cổng USB nội bộ **`HS10`**.
  - Cần hoàn thiện bảng ánh xạ cổng (USB Port Mapping) với thuộc tính `UsbConnector = 255` (Internal) cho `HS10` để Bluetooth hoạt động ổn định và duy trì sau chế độ Sleep.
* **Về Đồ Họa (Intel Iris Xe):**
  - Giai đoạn cài đặt sử dụng `-igfxvesa` để đảm bảo tính ổn định tuyệt đối của bộ cài. Sau khi cài xong vào Desktop, có thể nghiên cứu kích hoạt tăng tốc phần cứng qua dự án `WhateverXe` hoặc `NootedGreen`.

---

## 7. Giấy Phép & Đóng Góp (Credits & License)

* [Acidanthera](https://github.com/acidanthera) cho dự án OpenCorePkg, Lilu, VirtualSMC và BlueToolFixup.
* [hrx114514x](https://github.com/hrx114514x/PC711Probe) cho kext PC711Probe giải cứu dòng SSD SK hynix BC711.
* [OpenIntelWireless](https://github.com/OpenIntelWireless) cho driver itlwm và IntelBluetoothFirmware.
* Được phát triển và kiểm định bởi [@gianguyen14](https://github.com/gianguyen14).
