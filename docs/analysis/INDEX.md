# Phân tích mã nguồn: mục lục

Mỗi file có một tài liệu `<tên-file>.md` cùng thư mục. Chỉ ghi điều thấy trực tiếp trong code; điều suy đoán được đánh dấu "[suy đoán]". Bỏ qua `graphify-out/`, `.git/`, file nhị phân và `EFI/OC/Kexts/SMCBatteryManager.kext/Contents/Resources/SSDT-BATC.dsl` (file đi kèm kext bên thứ ba, 400 dòng).

## Bluetooth, AirPlay
- [btpin.c](btpin.c.md): daemon giữ trong RAM các khối `bluetoothd` mà BlueToolFixup/BTLEAdvFixup vá.
- [install_btpin.sh](install_btpin.sh.md): build `btpin` và cài LaunchDaemon.
- [vtbgra.c](vtbgra.c.md): thư viện interpose ép VideoToolbox giải mã ra BGRA, chỉ trong ControlCenter.
- [airplayfix.sh](airplayfix.sh.md): lúc đăng nhập khởi động lại ControlCenter kèm `vtbgra.dylib`.
- [install_airplayfix.sh](install_airplayfix.sh.md): build thư viện, cài LaunchAgent, đặt `enableGVATransfer=NO`.
- [uninstall_airplayfix.sh](uninstall_airplayfix.sh.md): gỡ bản sửa AirPlay.

## Kiểm tra video và GPU
- [vtencode_check.swift](vtencode_check.swift.md): mã hoá 120 khung 1080p bằng phần cứng, đếm khung và tốc độ.
- [vtencode_verify.swift](vtencode_verify.swift.md): mã hoá rồi giải mã và so nội dung với nguồn.
- [vtdecode_check.swift](vtdecode_check.swift.md): báo VideoToolbox chọn giải mã phần cứng hay phần mềm.
- [vtransfer_check.swift](vtransfer_check.swift.md): 12 ca pixel transfer, reproducer crash VA `+0x1336f3`.
- [gpubench.swift](gpubench.swift.md): đo FP32 duy trì và băng thông sao chép của GPU.
- [mtlleak_check.swift](mtlleak_check.swift.md): đo rò malloc theo từng command buffer Metal (#47).
- [gfx044.sh](gfx044.sh.md): nâng WhateverXe Graphics 0.4.0 lên 0.4.4 có sao lưu và hoàn tác.

## CPU, nguồn, ngủ
- [cpuclock.c](cpuclock.c.md): đo xung CPU bằng chuỗi phép cộng phụ thuộc.
- [clkwin.c](clkwin.c.md): như `cpuclock` nhưng in `ghz=` mỗi giây.
- [cpulimit_probe.sh](cpulimit_probe.sh.md): ghi `powermetrics` trong ba pha tải để tìm lý do xung tụt.
- [raplprobe.py](raplprobe.py.md): giải mã `WEXRaplProbe` (PL1/PL2, lý do giới hạn, EC) mỗi giây.
- [smcsensors.c](smcsensors.c.md): đọc nhiệt độ và công suất gói từ SMC.
- [freezewatch.sh](freezewatch.sh.md): ghi bộ nhớ nén, GPU, nhiệt mỗi 30 giây để lần treo sau có dữ liệu.
- [install_freezewatch.sh](install_freezewatch.sh.md): build `smcsensors` và cài LaunchAgent cho freezewatch.
- [pmc_decode.py](pmc_decode.py.md): giải mã trang PMC (LTR, LPM, PPFEAR) mà S0ixStandby xuất.
- [sleep_power_test.py](sleep_power_test.py.md): đo công suất lúc ngủ qua mức hao pin.
- [wexcapture.sh](wexcapture.sh.md): gom log ngủ/thức và màn hình vào một thư mục.
- [nvmesmart.c](nvmesmart.c.md): in dữ liệu SMART của ổ NVMe.

## Cấu hình EFI và ACPI
- [efi_selftest.py](efi_selftest.py.md): tự kiểm tra EFI đang chạy so với `config.plist` và lint repo.
- [set_bootarg.py](set_bootarg.py.md): thêm/bớt cờ trong `boot-args` của `config.plist`.
- [set_deviceprop.py](set_deviceprop.py.md): thêm/bớt thuộc tính trong `DeviceProperties/Add`.
- [add_to_config.py](add_to_config.py.md): thêm `SSDT-ECDPTF.aml` vào `ACPI/Add`.
- [SSDT-ECDPTF.dsl](SSDT-ECDPTF.dsl.md): báo EC có client DPTF, chữa vòng kẹp PL1 ~58 s.
- [SSDT-PL1.dsl](SSDT-PL1.dsl.md): nâng PL1/PL2 RAPL lúc boot (18 W / 28 W).
- [SSDT-DEEPIDLE.dsl](SSDT-DEEPIDLE.dsl.md): quảng bá `LPS0`/`LXEN` để macOS bật Deep Idle.
- [SSDT-PEPD-STA.dsl](SSDT-PEPD-STA.dsl.md): làm thiết bị `PEPD` hiện ra với Darwin (đi kèm ACPI patch).

## Modem WWAN XMM 7360
- [xmm_decode.py](xmm_decode.py.md): giải mã `WEXXmmProbe` (trạng thái, BAR, stage).
- [xmm_regs.py](xmm_regs.py.md): đọc/lưu/so sánh BAR0 và BAR2 của modem.
- [xmm_psi.py](xmm_psi.py.md): chạy/giải mã tải PSI (dry run và chạy thật có marker).
- [xmm_reset.py](xmm_reset.py.md): giải mã kết quả reset modem qua `_RST` của firmware.
- [psi_extract.py](psi_extract.py.md): lấy ảnh PSI ra khỏi container FLS của Intel.
- [windows_force_flash.ps1](windows_force_flash.ps1.md): ép dịch vụ Dell nạp lại firmware trên Windows (chưa chạy thử, có một lỗi đã ghi).

## Quan hệ chính giữa các file (đã đối chiếu trong code)
- `install_btpin.sh` → `btpin.c`; `install_freezewatch.sh` → `smcsensors.c` + `freezewatch.sh`; `install_airplayfix.sh` → `vtbgra.c` + `airplayfix.sh`.
- `raplprobe.py` → `clkwin.c` (định dạng `ghz=`); `cpulimit_probe.sh` → `cpuclock.c`.
- `efi_selftest.py` đọc `config.plist`, README, các `.dsl`, và kiểm kết quả của `SSDT-*`, `airplayfix`, `S0ixStandby`.
- Bộ `xmm_*` đọc các thuộc tính do WhateverXe (ngoài repo) xuất.
