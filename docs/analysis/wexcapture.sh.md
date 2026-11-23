# wexcapture.sh

**Mục đích:** gom dữ liệu để phân tích một lần ngủ/thức hoặc cắm lại màn hình vào `~/Library/Logs/wex-capture/<giờ>-<nhãn>/`. Cú pháp: `sh wexcapture.sh <nhãn> [phút]` (mặc định 20 phút; sau khi tắt nóng nên đặt số phút từ lúc thử để bao gồm lần boot trước).

**Việc làm:**
- Lưu `uptime`, `nvram boot-args`.
- Nguồn: sự kiện `pmset -g log` (Sleep/Wake/DarkWake/Failure...), `pmset -g`, `pmset -g assertions`, thuộc tính `IOPMrootDomain` (lý do ngủ/thức).
- Log kernel (PMRD, wake/sleep, AppleIntelFramebuffer, AGDP, IGPU, igfx, TGL, GPU hang, hotplug) và log `WindowServer`/`powerd` bằng `/usr/bin/log show`.
- Sao chép báo cáo `*.gpuRestart`, `*Sleep*`, `*.panic`, `*.ips`, `*.hang` mới hơn N phút từ hai thư mục `DiagnosticReports`.
- `system_profiler SPDisplaysDataType`, `AppleIntelFramebuffer` và các bản ghi `TGL*/WEX*/WhateverXe*` trên registry.

**Phụ thuộc:** các bản ghi `TGL*/WEX*` chỉ có khi boot với `-wexdiag` (comment dòng 9). `docs/HARDWARE_AND_PATCHES.md`/`HANDOFF_CONTEXT.md` nhắc script này trong quy trình thử [chưa đọc file đó trong lượt này]; file này không gọi file khác.

**Lưu ý:**
- Báo cáo `.panic`/`.ips` được chép nguyên, không lọc; cân nhắc trước khi chia sẻ vì có thể chứa thông tin máy [suy đoán].
- Dùng `/usr/bin/log` đầy đủ (không phải `log` của zsh), đúng ghi chú trong `HANDOFF_CONTEXT.md`.
- Cột `$4` của `pmset -g log` được dùng để lọc loại sự kiện; nếu định dạng log đổi, tệp `pmset-events.txt` có thể rỗng [suy đoán].
