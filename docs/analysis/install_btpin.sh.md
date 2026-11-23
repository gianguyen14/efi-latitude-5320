# install_btpin.sh

**Mục đích:** build `btpin` và cài thành LaunchDaemon. Chạy bằng `sudo`.

**Các bước (theo thứ tự trong file):**
1. `cd` vào thư mục của script, `clang -O2 -Wall btpin.c -o /tmp/btpin`, ký ad hoc bằng `codesign -s - -f`.
2. Cài binary vào `/usr/local/libexec/btpin` (root:wheel, 755), xoá bản trong `/tmp`.
3. Cài `com.gianguyen14.btpin.plist` vào `/Library/LaunchDaemons/` (644).
4. `launchctl bootout` (bỏ qua lỗi) rồi `launchctl bootstrap system ...`.
5. Chờ 2 s và in `/var/log/btpin.log`.

**Phụ thuộc:** `PostInstall/Tools/btpin.c` và `PostInstall/Tools/com.gianguyen14.btpin.plist` (cùng thư mục). Đường cài `/usr/local/libexec/btpin` khớp với tiến trình đang chạy khi kiểm tra trên máy.

**Lưu ý:**
- Biên dịch ra đường cố định `/tmp/btpin` bằng quyền root, rồi cài vào đường hệ thống; thư mục `/tmp` ai cũng ghi được nên về nguyên tắc có rủi ro thay file giữa hai bước [suy đoán, chưa kiểm chứng].
- Sau mỗi lần macOS cập nhật `bluetoothd`, cần chạy lại để quét lại các khối (theo `README.md` mục 2.5, không kiểm trong file này).
