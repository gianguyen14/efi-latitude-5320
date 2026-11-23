# install_airplayfix.sh

**Mục đích:** build `vtbgra.dylib` và cài LaunchAgent đăng nhập cho người dùng hiện tại. Chạy KHÔNG dùng `sudo`.

**Các bước:**
1. Tạo `~/Library/Application Support/AirPlayFix/`.
2. Biên dịch `vtbgra.c` thành `vtbgra.dylib` (`-arch x86_64`, liên kết VideoToolbox/CoreMedia/CoreVideo/CoreFoundation) và ký ad hoc.
3. Chép `airplayfix.sh` vào thư mục đó; sinh plist từ `com.gianguyen14.airplayfix.plist` bằng `sed` thay `__SCRIPT__` thành đường script, đặt vào `~/Library/LaunchAgents/`.
4. `defaults write -g enableGVATransfer -bool NO` (comment dòng 11: VideoToolbox đổi định dạng bằng GPU làm treo GPU Tiger Lake).
5. `launchctl bootout` rồi `bootstrap` agent. Nhắc người dùng tắt/bật lại phản chiếu AirPlay.

**Phụ thuộc:** `vtbgra.c`, `airplayfix.sh`, `com.gianguyen14.airplayfix.plist` (cùng thư mục; mẫu plist chưa đọc ở lượt này). `efi_selftest.py` (mục G2) kiểm đúng hai thứ file này thiết lập: `enableGVATransfer=0` và agent `com.gianguyen14.airplayfix` đã nạp.

**Lưu ý:** `defaults write -g` đổi cho **toàn bộ** ứng dụng, không chỉ AirPlay; `uninstall_airplayfix.sh` mới là chỗ hoàn tác (xem tài liệu của nó).
