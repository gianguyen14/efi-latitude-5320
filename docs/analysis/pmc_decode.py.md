# pmc_decode.py

**Mục đích:** giải mã trang PMC mà `S0ixStandby` xuất khi boot với `-s0ixpmcdump` (chỉ đọc). Dùng sau một lần ngủ Deep Idle để xem LTR, trạng thái LPM và cổng PPFEAR.

**Hàm chính:**
- `ltr_text(half)`: đổi 16 bit LTR (giá trị 9:0, scale 12:10, bit 15 = có yêu cầu) thành ns/µs; scale > 5 coi là không hợp lệ.
- `page(node, key)`: lấy thuộc tính nhị phân ≥ 0x1000 byte từ nút registry.
- `dw(p, off)`: đọc dword tại offset PWRM tuyệt đối (trang bắt đầu ở PWRM+0x1000).
- `show(name, p)`: in `LTR_IGNORE` 0x1B0C, bảng LTR (0x1B50-0x1BF8), LPM status chốt/trực tiếp (0x1C3C, 0x1C5C), `LPM_EN` 0x1C78, PPFEAR 0x1D90, bộ đếm SLP_S0 0x193C.
- `main()`: chạy `ioreg -r -n S0ixStandby -a`, in các trang "PMC page at boot / at halt / after halt".

**Phụ thuộc:** cần kext `S0ixStandby` (có trong `EFI/OC/Kexts/`) xuất các thuộc tính trên. Offset lấy theo driver `intel_pmc_core` của Linux cho Tiger Lake (docstring); file này không tự kiểm lại.

**Lưu ý:** tên thuộc tính ("PMC page at boot" ...) và offset gắn cứng; nếu phiên bản `S0ixStandby` đổi tên thì in "no PMC page properties". Không ghi gì vào máy.
