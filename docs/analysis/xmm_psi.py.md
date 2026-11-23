# xmm_psi.py

**Mục đích:** chạy/giải mã kết quả tải PSI vào modem XMM 7360 qua WhateverXe (`-wexxmmpsi` bật cả hai thuộc tính). Hai chế độ: `dry` đọc thuộc tính `WEXXmmPsi` (chỉ dựng DMA, không ghi gì vào thiết bị); `go` đọc `WEXXmmPsiGo`, lần chạy thật chỉ xảy ra khi tồn tại file `/private/tmp/xmm_go` không rỗng (docstring: một lần mỗi lần boot, các lần đọc sau trả kết quả đã lưu).

**Hàm chính:** `main()`:
- Chọn khoá theo tham số, chạy `ioreg -l -w0`, tìm `"<khoá>" = <hex>`.
- Giải 12 dword (mode, status, lệnh PCI trước/sau, exec stage trước/sau, ROM exit code trước/sau, số lần thăm dò, trạng thái DMA, kích thước), địa chỉ IOVA 64 bit ở offset 48 và 4 dword MSI ở offset 56.
- In theo bảng `STATUS` (0-10), `STAGE` (`0xFEEDB007` BOOT, `0xFEEDBEEF` PSI, `0xFEEDCAFE` EBL, `0x600DF00D` RUN, `0x8BADF00D` CRASH, `0xBADC0DED` CD_READY) và thông tin MSI.

**Phụ thuộc:** `kern_xmm_psi.hpp` trong workspace WhateverXe (ngoài repo) tạo các thuộc tính; `xmm_regs.py`/`xmm_reset.py` đi cùng quy trình thử. `git status` ở đầu phiên ghi file này đang có thay đổi chưa commit (phần giải mã MSI).

**Lưu ý / rủi ro:**
- Phần "thực hiện" nằm ở kext: việc đọc thuộc tính qua `ioreg` kích hoạt dựng DMA (và chạy thật nếu có file marker). Một lệnh `ioreg -l` bất kỳ cũng đọc thuộc tính; marker được thiết kế để tránh chạy thật nhầm.
- Bảng `STAGE` ở đây có `0x8BADF00D` = CRASH và `0xBADC0DED` = CD_READY, khác với bảng `MEANING` trong `xmm_decode.py` (gán `0xBADC0DED` là "crashed").
- `ioreg -l -w0` toàn bộ, chậm.
