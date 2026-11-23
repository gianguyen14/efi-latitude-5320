# raplprobe.py

**Mục đích:** giải mã thuộc tính `WEXRaplProbe` của WhateverXe (boot-arg `-wexraplprobe`) mỗi giây và in bảng PL1/PL2, công suất gói, tỉ lệ xung, lý do giới hạn (MSR 0x64F), kèm giá trị cảm biến EC và dump MMIO. Chỉ đọc, không ghi (docstring). Cú pháp: `raplprobe.py [giây] [clkwin_binary]`.

**Hàm chính:**
- `read_blob()`: chạy `ioreg -rn IGPU` (rồi `AppleIntelTGLGraphics`, cuối cùng `ioreg -l -w0`) tìm `"WEXRaplProbe" = <hex>`.
- `decode(b)`: giải khối nhị phân theo revision (MSR, giá trị EC từ rev 2, MMIO từ rev 3) vào các biến toàn cục `EC`, `MM`.
- `row()`: tính PL1/PL2 từ MSR 0x610, công suất từ chênh lệch MSR 0x611 theo đơn vị 0x606, tỉ lệ xung từ 0x198, lý do giới hạn từ 0x64F.
- `bits()` / `LIMIT_BITS`: đặt tên các bit lý do giới hạn.
- `ec()`, `ecline()`: lấy và in nhiệt độ/ngưỡng từ EC.
- `main()`: vòng lặp theo giây, in dump cuối cùng; trả 1 nếu không có thuộc tính.

**Phụ thuộc:** cần kext WhateverXe (nguồn ở workspace ngoài repo, không có trong file này) xuất `WEXRaplProbe`. Tham số thứ hai là binary `clkwin` in `ghz=`; docstring nhắc `PostInstall/Tools/cpuclock.c`, nhưng `cpuclock` chỉ in một dòng cuối, không in `ghz=` theo giây nên không khớp regex ở dòng 131; trong cùng thư mục có `clkwin.c` (xem `clkwin.c.md`).

**Lưu ý:**
- Mỗi giây gọi `ioreg`; nếu driver đồ họa kẹt thì `ioreg` có thể treo và làm đứng vòng lặp [suy đoán, dựa trên lần `ioreg` treo trong phiên làm việc].
- Địa chỉ MSR và bố cục khối được gắn cứng; đổi revision của kext mà không sửa file sẽ giải sai.
- Biến `pkg` trong `row()` được đọc nhưng không dùng.
