# set_deviceprop.py

**Mục đích:** sửa trực tiếp `DeviceProperties/Add` trong `config.plist` của OpenCore. Cú pháp: `set_deviceprop.py <config.plist> add|remove <PciRoot path> <key> [hex bytes]`. Ví dụ trong docstring: đặt `pci-aspm-default` = `02000000` cho `PciRoot(0x0)/Pci(0x1C,0x0)`.

**Hàm chính:** không có hàm, chỉ là script tuyến tính:
- `add`: tạo mục cho đường PCI nếu chưa có và gán `key` = `bytes.fromhex(argv[5])`.
- `remove`: xoá khoá, và xoá luôn đường PCI nếu rỗng.
- Ghi lại file bằng `plistlib.dump(..., sort_keys=False)` rồi in tóm tắt (giá trị > 8 byte in `...`).

**Phụ thuộc:** chỉ thư viện chuẩn `plistlib`. Không file nào của dự án gọi nó trong file này; cùng cách làm với `PostInstall/Tools/raplprobe/set_bootarg.py` (đã đối chiếu: cả hai sửa `config.plist` bằng `plistlib`).

**Lưu ý:**
- Không kiểm tham số: thiếu `hex` khi `add` gây `IndexError`; đường dẫn sai không được báo.
- Ghi đè `config.plist` tại chỗ, không sao lưu; `plistlib` làm mất chú thích và có thể đổi định dạng file.
