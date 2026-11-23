# add_to_config.py

**Mục đích:** thêm `SSDT-ECDPTF.aml` vào `ACPI/Add` của `config.plist` (một lần, bật, đặt cuối danh sách). Cú pháp: `add_to_config.py <config.plist>`.

**Cách hoạt động (script tuyến tính):**
- Nạp plist; nếu chưa có mục `Path == "SSDT-ECDPTF.aml"` thì thêm mục `{Comment: "Tell the EC a DPTF client is present (SSDT-ECDPTF)", Enabled: True, Path: ...}` và ghi lại bằng `plistlib.dump(..., sort_keys=False)`.
- In danh sách `Path` hiện có.

**Phụ thuộc:** `PostInstall/Tools/ecdptf/SSDT-ECDPTF.dsl` (nguồn của `SSDT-ECDPTF.aml`). Cùng kiểu với `set_bootarg.py` và `set_deviceprop.py` (sửa `config.plist` bằng `plistlib`).

**Lưu ý:**
- Idempotent: chạy lại không thêm trùng; nhưng nếu mục đã có mà đang tắt (`Enabled=False`) thì không bật lại.
- Ghi đè `config.plist` tại chỗ, không sao lưu; `plistlib` bỏ chú thích trong plist.
- Không kiểm tra file `.aml` có tồn tại trong `EFI/OC/ACPI/`.
