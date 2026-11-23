# clkwin.c

**Mục đích:** đo xung CPU theo từng giây: `N` luồng bận chạy chuỗi `add` phụ thuộc, mỗi giây in `t=<s> ghz=<trung bình>`. Cú pháp: `clkwin <số luồng> <giây>`.

**Hàm chính:**
- `now()`: thời gian tường (giây) từ `mach_absolute_time`.
- `run(a)`: mỗi luồng cộng dồn số phép `add` vào `cnt[id]` theo khối 1.000.000, đến khi `stop` bật.
- `main()`: tạo luồng, mỗi giây tính chênh lệch `cnt` chia số luồng chia thời gian thực, in `t=%d ghz=%.2f`, cuối cùng đặt `stop` và `join`.

**Phụ thuộc:** chỉ thư viện hệ thống. Đầu ra `t=<s> ghz=<x>` khớp với regex `ghz=([0-9.]+)` và cách gọi `[CLK, "8", giây]` trong `PostInstall/Tools/raplprobe/raplprobe.py`, nên đây là `clkwin_binary` mà `raplprobe.py` dùng.

**Lưu ý:**
- `cnt[]` là mảng `volatile` đọc/ghi không nguyên tử giữa các luồng; sai số nhỏ vì chỉ cộng theo khối.
- Mảng `th[16]`/`cnt[16]` không kiểm tra `N > 16`; không kiểm tham số dòng lệnh.
- Biểu thức `usleep(...)` (dòng 14) có điều kiện luôn đúng; thực tế ngủ khoảng phần còn lại của giây [suy đoán, đọc từ code].
