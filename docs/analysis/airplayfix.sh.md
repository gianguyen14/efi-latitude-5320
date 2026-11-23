# airplayfix.sh

**Mục đích:** chạy lúc đăng nhập: khởi động lại `ControlCenter` kèm `vtbgra.dylib` để bộ thu AirPlay giải mã ra BGRA (comment dòng 2).

**Các bước (8 dòng):**
1. Thư viện ở `~/Library/Application Support/AirPlayFix/vtbgra.dylib`; không có thì thoát im lặng.
2. `launchctl setenv DYLD_INSERT_LIBRARIES <thư viện>`.
3. `killall ControlCenter` (launchd tự chạy lại, lần này mang biến môi trường).
4. Chờ 5 s rồi `launchctl unsetenv DYLD_INSERT_LIBRARIES`.

**Phụ thuộc:** `vtbgra.dylib`, được build từ `PostInstall/Tools/airplayfix/vtbgra.c` (thư viện chỉ hoạt động khi `getprogname()` là `ControlCenter`). Cần `amfi_get_out_of_my_way=0x1` mới nạp được vào ControlCenter (theo `README.md` mục 2.6; không kiểm trong file này).

**Lưu ý / rủi ro:**
- `launchctl setenv` đặt biến cho **mọi** tiến trình khởi chạy trong cửa sổ 5 giây, không chỉ ControlCenter; thư viện tự bỏ qua tiến trình khác nhưng vẫn bị nạp vào chúng.
- Mỗi lần đăng nhập thanh menu nháy do ControlCenter bị tắt rồi chạy lại.
