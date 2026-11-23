# SSDT-PL1.dsl

**Mục đích:** nâng giới hạn RAPL của gói CPU (PL1/PL2) lúc boot (comment dòng 2-12): firmware Latitude 5320 để PL1 rất thấp dưới macOS (~6 W, ~550 MHz khi tải đầy), macOS không có driver DPTF nên không ai nâng lại. Bảng ghi `PACKAGE_RAPL_LIMIT` (MCHBAR+0x59A0, bản sao MSR 0x610) một lần.

**Thành phần:**
- `External (CPWR, OpRegionObj)`: vùng ánh xạ RAPL của DSDT gốc (MCHBAR+0x5000).
- `Device (PL1T)` (`_HID` `PL1T0000`) với `Field` trên `\CPWR`: `PWUN` (0x938, đơn vị công suất), `PL1V` (0x9A0), `PL2V` (0x9A4).
- `PL1W = 18` W, `PL2W = 28` W, `DONE` (chỉ chạy một lần).
- `APPL()`: bỏ qua nếu đã chạy, PL2V bit 31 (khoá) đã đặt, đơn vị ngoài khoảng 2..8, hoặc PL1V = 0; tính đơn vị/W, kẹp tối đa 0x7FFF, và chỉ ghi khi giá trị mới lớn hơn giá trị hiện tại (OR với `0x18000`).
- `_INI` và `_STA` đều gọi `APPL()`.

**Phụ thuộc:** DSDT gốc phải khai báo vùng `\CPWR` (không kiểm trong file). `efi_selftest.py` (B1, S2) tìm thiết bị `PL1T` và kiểm PL1 duy trì ≥ 15 W; `SSDT-ECDPTF.dsl` giải quyết vòng kẹp ~58 s của cùng hiện tượng, theo comment của file đó.

**Lưu ý:**
- Ghi thẳng thanh ghi MCHBAR lúc boot: comment tự đánh giá "safe by construction" (không bao giờ hạ giới hạn, không làm gì nếu bị khoá); mức PL2 28 W là lựa chọn cố định, `efi_selftest.py` còn đề nghị hạ xuống ~22 W nếu chạm 99 °C.
- Giá trị 18 W lấy từ "Windows Ultra Performance" theo comment, không kiểm trong code.
- Hoàn tác: bỏ `SSDT-PL1.aml` khỏi `config.plist` (comment dòng 12).
