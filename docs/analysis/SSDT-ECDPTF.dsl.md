# SSDT-ECDPTF.dsl

**Mục đích:** báo cho EC của Dell rằng có một client DPTF/DTT (comment dòng 2-8): firmware chỉ tự làm điều này khi OS chạy `_OSC` Dynamic Tuning của Intel (`\_SB.PC00.LPCB.ECDV.DPST(1)`), macOS không bao giờ làm, nên thanh ghi EC 0x32 giữ 0 và gói CPU luân phiên PL1 (18 W) với khoảng 5.8 W / 400 MHz mỗi ~58 s khi tải lâu; với `DPST(1)` giữ 18 W trong suốt.

**Thành phần:**
- `External` cho `\_SB.PC00.LPCB.ECDV.DPST` và `DPRT` (phương thức của DSDT gốc).
- `Device (DPEC)` (`_HID` `DPEC0000`): `APPL()` kiểm `CondRefOf(DPRT)` rồi nếu `DPRT() != 1` gọi `DPST(1)`; `_INI` và `_STA` đều gọi `APPL()` (`_STA` trả `0x0F`).

**Phụ thuộc:** DSDT gốc phải có `ECDV.DPST` và `ECDV.DPRT` (không kiểm trong file). `add_to_config.py` (cùng thư mục) thêm `SSDT-ECDPTF.aml` vào `ACPI/Add`; `efi_selftest.py` (mục B3) biên dịch lại file này và so với `EFI/OC/ACPI/SSDT-ECDPTF.aml`.

**Lưu ý:**
- Số liệu "18 W / 5.8 W / 58 s" nằm trong comment, không kiểm được từ code.
- Comment nhắc ghi qua `ECW1` "works before the EC region is up", nhưng `ECW1` nằm trong DSDT không có ở đây [chưa kiểm].
- `_STA` có tác dụng phụ (ghi EC) mỗi lần OS gọi; idempotent nhờ kiểm `DPRT`.
