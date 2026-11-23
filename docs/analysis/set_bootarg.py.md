# set_bootarg.py

**Mục đích:** thêm hoặc bớt một cờ trong `boot-args` của `config.plist` (OpenCore), so khớp theo cả từ. Cú pháp: `set_bootarg.py <config.plist> add|remove <flag>`.

**Hàm chính:** script tuyến tính, không có hàm:
- Lấy chuỗi `boot-args` ở `NVRAM/Add/7C436110-AB2A-4BBB-A880-FE41995C9F82`, tách theo khoảng trắng, loại mọi từ bằng `flag`.
- Nếu `op == "add"` thì thêm `flag` vào cuối; mọi giá trị `op` khác đều chỉ xoá.
- Ghi lại file bằng `plistlib.dump(..., sort_keys=False)` và in chuỗi `boot-args` mới.

**Phụ thuộc:** chỉ `plistlib`. Cùng cách làm với `PostInstall/Tools/s0ix/set_deviceprop.py` (cả hai sửa `config.plist` bằng `plistlib`). Docstring không nói file nào gọi nó; trong phiên làm việc được dùng thủ công.

**Lưu ý:**
- Muốn bỏ cờ có giá trị phải gõ cả `tên=giá_trị` (ví dụ `amfi_get_out_of_my_way=0x1`), vì so khớp theo từ nguyên.
- Gõ sai `op` (ví dụ `rm`) vẫn chạy và ghi file như `remove`; `add` không chống trùng nhưng đã loại bản cũ trước.
- Ghi đè tại chỗ, không sao lưu; `plistlib` bỏ chú thích trong plist.
