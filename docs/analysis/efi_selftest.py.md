# efi_selftest.py

**Mục đích:** script tự kiểm tra EFI: so cấu hình đang chạy với `EFI/OC/config.plist` trong repo, thăm dò từng phân hệ (A-H, S, W) và lint tĩnh repo (P). Không tự reboot. Cờ: `--load`, `--sudo`, `--sleep`.

**Hàm chính:**
- `check(group, id)` (decorator): chạy hàm kiểm tra ngay lúc định nghĩa, lỗi thì ghi WARN. `add()` ghi kết quả `PASS/WARN/FAIL/INFO/SKIP`.
- `sh()`, `ioreg_plist()`, `walk()`: chạy lệnh và đọc cây `ioreg`.
- Nhóm A boot-args/CSR/SMBIOS/CPUID; B ACPI (SSDT có xuất hiện trong registry, biên dịch lại `.dsl` so với `.aml`); C kext đã nạp; D xung CPU (`FREQ_C` là mã C nhúng, biên dịch bằng clang, cùng cách đo với `cpuclock.c` theo comment); E dữ liệu `S0ixStandby`; F USBMap; G GPU/AirPlay; H Wi-Fi/BT/âm thanh/HID/NVMe; P lint tĩnh; S1 so ESP với repo, S2 `powermetrics`; W1 ngủ/thức thật.
- `main()`: in báo cáo, ghi JSON vào `~/gva-research/tools/selftest_last.json`.

**Phụ thuộc:** đọc `EFI/OC/config.plist`, `EFI/OC/Kexts/*`, `README.md` (P6), `PostInstall/Tools/*/SSDT-*.dsl` (B3, cần `iasl`), tìm LaunchAgent `com.gianguyen14.airplayfix` (G2). Không file nào trong repo gọi nó (không thấy trong file này).

**Lưu ý:**
- Chạy `ioreg` rất nặng ngay lúc import (dòng 127, 187) nên khởi động chậm.
- `--sleep` ép máy ngủ thật; `--sudo` tự mount/unmount ESP; `--load` chạy 8 tiến trình `yes`.
- P5 yêu cầu SMBIOS trong repo ở dạng ẩn danh (`C02X...`), khớp quy ước không để SMBIOS thật.
