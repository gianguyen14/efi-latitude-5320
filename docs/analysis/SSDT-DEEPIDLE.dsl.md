# SSDT-DEEPIDLE.dsl

**Mục đích:** quảng bá cho macOS "Deep Idle" (ngủ S0) (comment dòng 4-8): AppleACPIPlatform trên Mac thật tìm `\_SB.LPS0` và `\_GPE.LXEN`; khi cả hai trả `One`, macOS xuất `IOPMDeepIdleSupported = true` và có thể chọn kiểu ngủ 7 (`kIOPMSleepTypeDeepIdle`), cho CPU nghỉ ở C-state sâu nhất thay vì S3.

**Thành phần:**
- `Method (LPS0)` trong `\_SB` và `Method (LXEN)` trong `\_GPE`: nếu `_OSI("Darwin")` thì ghi một dòng `Debug` ("S0IX: ... evaluated") và trả `One`; hệ điều hành khác nhận `Zero`.

**Phụ thuộc:** `S0ixStandby.kext` (comment nhắc "S0ixStandby experiment N1"); comment trỏ tới `docs/RESEARCH-2A.md`, nhưng file đó không có trong `docs/` của repo này (kiểm bằng `ls`). `efi_selftest.py` (B2) kiểm đúng kết quả: `IOPMrootDomain` có `IOPMDeepIdleSupported = Yes`.

**Lưu ý:**
- Comment còn các câu từ dự án gốc không áp dụng ở đây: "Test from the USB-stick EFI only", "HP DSDT", "keep the _S3 -> 7 patch"; trong repo này `SSDT-S3.aml` đang tắt (`config.plist`) và máy là Dell.
- Comment yêu cầu trước khi bật phải xác nhận DSDT chưa có `\_SB.LPS0` / `\_GPE.LXEN`; file không kiểm điều này [chưa rõ đã kiểm cho máy này chưa].
- Ghi `Debug` mỗi lần hàm được gọi, hữu ích khi gỡ lỗi nhưng chỉ có tác dụng khi bật log ACPI.
