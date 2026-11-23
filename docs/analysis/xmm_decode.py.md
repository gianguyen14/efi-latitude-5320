# xmm_decode.py

**Mục đích:** giải mã thuộc tính `WEXXmmProbe` của WhateverXe (boot-arg `-wexxmmprobe`): trạng thái chỉ-đọc của modem Intel XMM 7360 (`8086:7360`). `BAR2[0]` là từ đầu tiên driver Linux `xmm7360-pci` đọc: `0x600df00d` = firmware đang chạy, `0xfeedb007` = boot ROM (docstring).

**Hàm chính:** `main()`:
- Chạy `ioreg -l -w0`, tìm `"WEXXmmProbe" = <hex>`; không có thì báo cần boot với `-wexxmmprobe`.
- Giải khối theo `revision`: ≥ 2 có 64 dword cấu hình PCI ở offset 16 và `bar2phys`, `s0`, `mode`, cờ bật tạm memory decode ở offset 272; revision 1 có bố cục ngắn hơn.
- In trạng thái probe (`STATUS`), vendor/device, thanh ghi lệnh, BAR0/BAR2, PMCSR (D-state), giá trị `BAR2[0x00]` kèm ý nghĩa (`MEANING`) và `BAR2[0x60]`.

**Phụ thuộc:** cần `kern_xmm_probe.hpp` trong workspace WhateverXe (ngoài repo) xuất khối nhị phân đúng bố cục; file này không tự kiểm bố cục.

**Lưu ý:**
- Docstring ghi `WXXmmProbe` nhưng code tìm `WEXXmmProbe` (lỗi chính tả trong docstring).
- Bảng `MEANING` gán `0xBADC0DED` là "crashed", trong khi bảng `STAGE` của `xmm_psi.py` (cùng thư mục) gán `0x8BADF00D` = CRASH và `0xBADC0DED` = CD_READY. Hai file trong repo mâu thuẫn nhau; theo nguồn driver `iosm` đã đọc ở phiên trước (ngoài repo), bảng của `xmm_psi.py` là bảng đúng.
- Chỉ giải revision ≤ 2; các trường BAR0/BAR2 dump của revision 3 do `xmm_regs.py` đọc, không phải file này.
- Dùng `ioreg -l -w0` toàn bộ nên chậm.
