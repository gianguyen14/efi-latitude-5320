# uninstall_airplayfix.sh

**Mục đích:** gỡ bản sửa AirPlay. Chạy KHÔNG dùng `sudo`.

**Các bước (9 dòng, đảo ngược `install_airplayfix.sh`):**
1. `launchctl bootout` agent `com.gianguyen14.airplayfix` (bỏ qua lỗi).
2. `launchctl unsetenv DYLD_INSERT_LIBRARIES`.
3. `defaults delete -g enableGVATransfer`.
4. Xoá plist trong `~/Library/LaunchAgents/` và thư mục `~/Library/Application Support/AirPlayFix`.
5. `killall ControlCenter` để nạp lại sạch.

**Phụ thuộc:** không gọi file nào khác; xoá đúng những thứ `install_airplayfix.sh` tạo.

**Lưu ý:**
- Xoá hẳn khoá `enableGVATransfer` (không đặt lại về giá trị trước khi cài); nếu trước đó người dùng đã tự đặt giá trị khác thì mất [suy đoán, file không lưu giá trị cũ].
- Không có xác nhận trước khi `rm -rf`.
