# btpin.c

**Mục đích:** daemon C giữ (`mlock`) trong RAM các khối 16 KiB của `/usr/sbin/bluetoothd` chứa chỗ BlueToolFixup/BTLEAdvFixup vá, để APFS không nạp lại khối đó và `bluetoothd` không chết vì `Data hash mismatch` (comment dòng 1-10).

**Hàm chính:**
- `parsePatterns()` / `matches()`: biên dịch bảng `kPatterns` (chuỗi hex, `??` là ký tự đại diện) và so khớp byte.
- `x86Slice()`: tìm đoạn x86_64 trong file Mach-O fat.
- `scan()`: đọc từng khối, tìm mẫu vá (dạng gốc và dạng đã vá `*`), gọi `addChunk()`; khối không đọc được cũng được thêm.
- `addChunk()`: ghi nhớ offset đã căn 16 KiB, tối đa `MAX_CHUNKS`=64.
- `main()`: `-n` chỉ liệt kê; ngược lại `mmap` file rồi vòng lặp vô hạn `mlock` từng khối, thử lại sau 10 s nếu còn khối chưa khoá, nghỉ 3600 s khi đã khoá hết.

**Phụ thuộc:** không gọi file dự án nào khác; chỉ dùng thư viện hệ thống và đọc `/usr/sbin/bluetoothd`. Comment dòng 13 nói chạy như LaunchDaemon qua `btpin.plist`; thực tế `install_btpin.sh` build file này rồi cài `com.gianguyen14.btpin.plist` (tên khác với comment) vào `/Library/LaunchDaemons/`.

**Lưu ý / rủi ro:**
- Các mẫu byte gắn cứng với từng bản `bluetoothd`; khi macOS đổi bản, mẫu có thể không khớp mà không báo lỗi. Khi chạy `btpin -n` trên 25G241 (quan sát của tôi, không phải trong code), chỉ thấy 5 khối và không thấy mẫu `btle-adv/scan/gate/rand`.
- Khối nào chưa khoá được (`pending`) sẽ bị thử lại mãi, không có giới hạn.
