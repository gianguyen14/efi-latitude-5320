# vtbgra.c

**Mục đích:** thư viện dyld-interpose chặn `VTDecompressionSessionCreate` và `...CreateWithOptions` để ép định dạng pixel đích về `32BGRA`, chỉ khi tiến trình tên `ControlCenter` (kiểm bằng `getprogname()`).

**Hàm chính:**
- `ld()` (constructor): ghi log `[vtbgra] loaded` khi nạp vào ControlCenter.
- `patched(dest, fmt)`: sao chép (hoặc tạo mới) dict đích, đặt `kCVPixelBufferPixelFormatTypeKey` = `fmt`, xoá khoá `PixelFormatTypes`.
- `my_create()`: thay `VTDecompressionSessionCreate`; ở tiến trình khác thì gọi thẳng hàm gốc.
- `my_cwo()`: thay `VTDecompressionSessionCreateWithOptions` (khai báo prototype tự viết với 8 tham số `void*`), vá tham số thứ 4 nếu là dict hoặc NULL.
- Macro `DYLD_INTERPOSE` ghi cặp thay thế vào section `__DATA,__interpose`.

**Phụ thuộc:** chỉ dùng framework hệ thống (VideoToolbox, CoreVideo). Cách nạp nằm ở `airplayfix.sh`: đặt `DYLD_INSERT_LIBRARIES` bằng `launchctl setenv` rồi khởi động lại ControlCenter. README.md mục 2.6 nói cần `amfi_get_out_of_my_way=0x1` (theo README, không kiểm trong file này).

**Lưu ý / rủi ro:**
- `my_cwo` tạo `nd` bằng `patched()` (bản sao có retain) nhưng không `CFRelease(nd)`, khác với `my_create` (dòng 23): rò một dict mỗi lần gọi.
- `my_cwo` truyền `void*` cho tham số thứ 4 mà không kiểm kiểu ngoài `CFGetTypeID`; chữ ký 8 tham số tự khai báo, sai chữ ký thật có thể gây lỗi [suy đoán].
- Log in `dest` với `%{public}@`, tức là lộ nội dung dict trong log hệ thống.
