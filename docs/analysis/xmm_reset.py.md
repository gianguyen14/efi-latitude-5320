# xmm_reset.py

**Mục đích:** giải mã thuộc tính `WEXXmmReset`: kết quả reset modem XMM 7360 qua chính phương thức ACPI `_RST` của firmware (WhateverXe `-wexxmmpsi`). Docstring: reset chạy một lần mỗi lần boot, ở lần đọc đầu tiên của thuộc tính, và chỉ khi file `/private/tmp/xmm_reset` tồn tại và không rỗng.

**Hàm chính:** không có hàm, script tuyến tính:
- `ioreg -l -w0`, tìm `"WEXXmmReset" = <hex>`.
- Giải 12 dword: revision, trạng thái, hai mã trả về ACPI, vendor/device sau, lệnh PCI sau, exec stage sau, thời gian chờ (ms), chip info, BAR0, BAR2.
- In trạng thái theo bảng `ST` (0 = modem về lại BOOT, 3 = `_RST` lỗi, 4 = không khôi phục config space, 5 = stage không phải BOOT, 10 = chưa kích hoạt).

**Phụ thuộc:** `kern_xmm_psi.hpp` trong workspace WhateverXe (ngoài repo) thực hiện việc reset; cùng họ với `xmm_psi.py`, `xmm_regs.py`, `xmm_decode.py`.

**Lưu ý:**
- Nhãn in `ACPI rc: WRST._RST -> ...; full path -> ...` không còn đúng: theo phiên làm việc trước (commit `fa8be39` trong workspace WhateverXe, không kiểm trong repo), kext gọi `_RST` trực tiếp trên nút PXSX, nên hai dòng này dễ gây hiểu nhầm.
- Không có `if __name__ == "__main__"`, chạy ngay khi import.
- Dùng `ioreg -l -w0` toàn bộ, chậm.
