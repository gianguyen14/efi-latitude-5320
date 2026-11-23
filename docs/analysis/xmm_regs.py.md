# xmm_regs.py

**Mục đích:** đọc (chỉ đọc) BAR0 (0x00-0xFF) và BAR2 (0x00-0x1FF) của modem XMM 7360 từ thuộc tính `WEXXmmProbe` (probe revision 3) và cho phép lưu/so sánh hai lần đọc. Cú pháp: `xmm_regs.py [save <file> | diff <file>]`; không tham số thì chỉ in.

**Hàm chính:**
- `read()`: chạy `ioreg -l -w0`, lấy blob, thoát nếu thiếu thuộc tính, revision < 3 hoặc trạng thái probe khác 0; trả 64 dword BAR0 (offset 296 của blob) và 128 dword BAR2 (offset 552).
- `show(r0, r2)`: in các hàng 4 dword khác 0.
- `main()`: `save` ghi hex ra file, `diff` in từng dword đổi `cũ -> mới` (BAR0 nếu chỉ số < 64, ngược lại BAR2).

**Phụ thuộc:** `kern_xmm_probe.hpp` trong workspace WhateverXe (ngoài repo) xuất blob revision 3; kích thước 64 và 128 dword, cùng offset 296 và 552, khớp với bố cục `xmm_decode.py` (cfg 64 dword từ offset 16, các trường BAR2 từ offset 272).

**Lưu ý:**
- `main()` được gọi ở cuối file không có `if __name__ == "__main__"`, nên import sẽ chạy ngay.
- `diff` dùng `zip`, nên nếu hai file khác độ dài thì phần dư bị bỏ qua mà không báo.
- Dùng `ioreg -l -w0` toàn bộ nên chậm; không ghi gì vào thiết bị.
