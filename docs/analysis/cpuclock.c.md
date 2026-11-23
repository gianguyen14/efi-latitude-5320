# cpuclock.c

**Mục đích:** đo xung nhịp CPU: mỗi luồng chạy chuỗi lệnh `add` phụ thuộc nhau; tốc độ (tỉ phép/giây) xấp xỉ GHz của lõi. Cú pháp: `cpuclock <số luồng> <giây>`. Build: `clang -O1 cpuclock.c -o cpuclock`.

**Hàm chính:**
- `now()`: thời gian tường (giây) từ `mach_absolute_time` đổi theo timebase.
- `run(a)`: vòng lặp `add $1` 10 triệu lần mỗi lượt cho đến hết `secs`; trả về GHz của luồng qua con trỏ `malloc`.
- `main()`: tạo `T` luồng, chờ, in một dòng `threads=%d avg per-thread %.2f GHz`.

**Phụ thuộc:** chỉ thư viện hệ thống. `efi_selftest.py` nói đầu đo xung nhúng trong nó "same method as cpuclock.c" (comment trong `efi_selftest.py`). Docstring của `raplprobe.py` nhắc file này như công cụ nguồn cho tham số `clkwin_binary`.

**Lưu ý:**
- Không kiểm tham số: thiếu `argv` làm crash; mảng `th[16]` nên `T > 16` tràn bộ nhớ.
- In một dòng tổng kết duy nhất, không in `ghz=` theo giây, nên không tương thích với cách `raplprobe.py` phân tích (`ghz=([0-9.]+)`).
- Đo theo thời gian tường, không phải thời gian CPU; `efi_selftest.py` ghi rằng đo theo CPU time từng cho 1470 MHz sai so với 4.07 GHz.
