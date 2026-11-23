# cpulimit_probe.sh

**Mục đích:** ghi lại vì sao xung CPU tụt: chạy `powermetrics` (xung từng lõi, công suất gói, plimits, nhiệt) trong khi `cpuclock` chạy ba pha: nghỉ, 1 luồng, 8 luồng. Chạy bằng `sudo sh cpulimit_probe.sh`; kết quả ở `~/cpulimit-<giờ>.txt` của người dùng đăng nhập.

**Các bước:**
- Xác định người dùng (`SUDO_USER` hoặc chủ `/dev/console`) và thư mục home bằng `dscl`.
- Biên dịch `cpuclock.c` vào thư mục tạm bằng `clang -O1`.
- Ghi tiêu đề, `pmset -g therm`, `pmset -g batt`; chạy `powermetrics` nền 75 mẫu (nếu `--show-plimits` không có thì chạy lại bản 73 mẫu không cờ đó).
- Chờ 8 s (pha nghỉ), rồi `cpuclock 1 20` và `cpuclock 8 40`, gom log các pha vào file kết quả, xoá thư mục tạm, `chown` cho người dùng.

**Phụ thuộc:** `PostInstall/Tools/cpuclock.c` (file này `cd` vào thư mục của chính nó rồi biên dịch `cpuclock.c`), `powermetrics`, `pmset`, `clang`.

**Lưu ý:**
- Cần `sudo`; dòng tiêu đề lộ chuỗi CPU của máy trong file kết quả.
- Tổng thời gian các pha khoảng 70 s so với 75 mẫu `powermetrics`, nên các mẫu cuối là lúc máy đã nhàn rỗi [suy đoán].
- `set -e` nhưng `powermetrics` chạy nền; lỗi của nó không làm dừng script (chỉ `wait ... || true`).
