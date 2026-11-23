# nvmesmart.c

**Mục đích:** in dữ liệu SMART/sức khoẻ của các ổ NVMe trong máy. Build: `clang -O2 nvmesmart.c -framework IOKit -framework CoreFoundation -o nvmesmart`.

**Hàm chính:** chỉ có `main()`:
- Duyệt dịch vụ `IONVMeBlockStorageDevice`, tạo plug-in `kIONVMeSMARTUserClientTypeID`, lấy `IONVMeSMARTInterface`, gọi `SMARTReadData`.
- In: cảnh báo nghiêm trọng, nhiệt độ (Kelvin trừ 273), dự phòng còn lại/ngưỡng, % đã dùng, dung lượng đọc/ghi (đơn vị 512000 byte), số lần bật nguồn, giờ bật, tắt không an toàn, lỗi media, số mục log lỗi.
- Trả 0 nếu đọc được ít nhất một ổ, 1 nếu không.

**Phụ thuộc:** chỉ framework hệ thống (header `NVMeSMARTLibExternal.h`). Không gọi file nào khác; `efi_selftest.py` (mục H4) lấy thông tin NVMe bằng `system_profiler`, không dùng binary này.

**Lưu ý:**
- Các bộ đếm 128 bit chỉ đọc phần thấp (`[0]`), đủ cho giá trị thực tế nhưng bỏ phần cao [suy đoán].
- Nếu ổ không hỗ trợ giao diện SMART trên macOS này thì bị `continue` im lặng và chương trình thoát mã 1 mà không in lý do.
