# SSDT-PEPD-STA.dsl

**Mục đích:** làm cho thiết bị Power Engine của firmware (`\_SB.PEPD`, `_HID INT33A1`, `_CID PNP0D80`) hiện ra với macOS. Theo comment, `PEPD` chỉ báo có mặt khi `OSYS >= 0x07DF` (OS trả lời `_OSI "Windows 2015"`) hoặc `OSYS >= 0x07DC` và `S0ID == 1`; macOS không thoả cả hai nên `S0ixStandby` (khớp `PNP0D80`) không thấy nó.

**Thành phần:**
- `External` cho `\_SB.PEPD` và `\_SB.PEPD.XSTA`.
- `Method (_STA)` mới trong `\_SB.PEPD`: trả `0x0F` nếu `_OSI("Darwin")`, ngược lại gọi `XSTA()` (phương thức gốc đã đổi tên).

**Phụ thuộc:** cần mục `ACPI > Patch` đổi tên `_STA` gốc thành `XSTA` (comment dòng 10-11). Đã kiểm trong `EFI/OC/config.plist`: có đúng một mục bật, "PEPD._STA to XSTA (unique AML sequence, one match)", tìm `_STA ... OSYS` thay bằng `XSTA ... OSYS`. `SSDT-PEPD-STA.aml` được bật trong `ACPI/Add`. `efi_selftest.py` (B2) kiểm thiết bị `INT33A1`/`PEPD` hiện trong registry; `S0ixStandby.kext` là bên dùng.

**Lưu ý:** hai phần (patch + SSDT) phải đi cùng nhau; thiếu patch thì bảng này thành `_STA` trùng tên với phương thức gốc; thiếu SSDT thì `PEPD` không có `_STA` (comment: "Without it this table does nothing useful"). Chuỗi byte tìm kiếm gắn với đúng bản DSDT/BIOS hiện tại; BIOS khác có thể làm nó không khớp [suy đoán].
