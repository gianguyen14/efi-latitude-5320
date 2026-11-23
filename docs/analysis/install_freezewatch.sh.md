# install_freezewatch.sh

**Mục đích:** cài `freezewatch` thành LaunchAgent của người dùng (không dùng `sudo`). Gỡ bằng `launchctl bootout gui/$(id -u)/com.gianguyen14.freezewatch` rồi xoá plist (chú thích dòng 3-4).

**Các bước:**
1. Tạo `~/Library/Application Support/freezewatch/` và `~/Library/LaunchAgents/`.
2. Biên dịch `smcsensors.c` thành `$support/smcsensors` (`clang -O1 ... -framework IOKit`) và ký ad hoc.
3. Cài `freezewatch.sh` vào `$support/` (755).
4. Ghi plist `com.gianguyen14.freezewatch` chạy `/bin/sh $support/freezewatch.sh` với `RunAtLoad` và `KeepAlive` bật, giới hạn phiên `Aqua`; chú thích dòng 13 nói cố ý không đặt `ProcessType Background` để khỏi bị bóp khi thiếu bộ nhớ.
5. `launchctl bootout` (bỏ qua lỗi) rồi `bootstrap`, chờ 3 s và in 2 dòng cuối của log.

**Phụ thuộc:** `PostInstall/Tools/smcsensors.c` và `PostInstall/Tools/freezewatch.sh` (cùng thư mục, file này `cd` tới đó). Đây là nơi tạo binary `smcsensors` mà `freezewatch.sh` gọi.

**Lưu ý:**
- `tail -2 .../*.log` ở cuối: nếu chưa có log nào thì lệnh lỗi (do `set -e` script thoát với mã khác 0) [suy đoán, dựa trên cách `set -e` hoạt động].
- Heredoc không đặt trong dấu nháy nên `$support` được thay ngay khi cài; đường dẫn tuyệt đối được ghi cứng vào plist.
