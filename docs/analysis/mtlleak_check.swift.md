# mtlleak_check.swift

**Mục đích:** đo rò rỉ Metal: tăng `malloc` của tiến trình trên mỗi command buffer tuần tự (b00t0x/WhateverXe#47). Comment dòng 1-3: khoảng 72 KB mỗi cái nghĩa là buffer POSH bị rò, gần 0 nghĩa là driver giải phóng. Cú pháp: `mtlleak_check [count] [render]` (`render` vẽ một tam giác trong mỗi buffer). Build: `swiftc -O mtlleak_check.swift -o mtlleak_check`.

**Hàm chính:**
- `mallocInUse()`: `malloc_zone_statistics` → `size_in_use`.
- `run(n)`: n lần tạo command buffer (có hoặc không có render pass 256×256 bgra8), `commit`, `waitUntilCompleted`, mỗi lần trong `autoreleasepool` và là buffer duy nhất đang hoạt động trên queue (comment dòng 45: đây là đường dẫn gây rò).
- Phần thân: khởi động 20 lần, đo `malloc` trước/sau `count` lần (mặc định 1000), in MB tổng và KB mỗi buffer.

**Phụ thuộc:** chỉ Metal và Darwin. Liên quan tới cờ `-wexleakfix` của WhateverXe (nêu ở `CHANGELOG.md` của workspace WhateverXe, ngoài repo) và `PostInstall/Tools/freezewatch.sh` (cùng theo dõi hệ quả của #47); file này không gọi file nào khác.

**Lưu ý:**
- Đo `malloc` của chính tiến trình này, không đo bộ nhớ kernel hay bộ nhớ nén; rò ở tầng khác sẽ không thấy [suy đoán về phạm vi].
- Số trong comment (72 KB) khác số trong CHANGELOG của WhateverXe (76 KB); chưa rõ do đơn vị hay do bản đo khác nhau.
- `try!`/`!` làm crash nếu không có thiết bị Metal hoặc biên dịch shader lỗi.
