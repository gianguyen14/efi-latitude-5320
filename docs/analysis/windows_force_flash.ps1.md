# windows_force_flash.ps1

**Mục đích:** ép dịch vụ Dell/Fibocom `FwSwitchService` nạp lại firmware cho modem DW5820e (XMM 7360) trên Windows. Chạy PowerShell quyền Admin, cắm sạc, pin > 25%. Header ghi rõ: suy ra từ chuỗi trong `FwSwitchService.exe`/`WWANFirmwareFlash.dll`, **tác giả chưa chạy thử**. Tham số `-Fls <thư mục>` bật đường nạp thủ công.

**Các bước:**
1. Tạo thư mục sao lưu `xmm_backup_<giờ>` trên Desktop; xuất và liệt kê hai khoá `HKLM:\SOFTWARE\WOW6432Node\Intel\FlashService` và `...\MBIMToolkit`, xoá các giá trị `CurrentIMEI`, `Version`, `DriverVer`, `PackageVer`.
2. Với mọi `fbconfig.ini` tìm thấy: sao lưu, bỏ dòng `FwUpdateCfgVal`, bật `CONFIG_PCIE0000_WA = 1`, đặt `FLASH_SIM_NEED = 0`.
3. Nếu có `-Fls`: xoá `*.fls` cũ trong `C:\Windows\firmware\firmwareflash`, chép ảnh chính `18500*_Secureboot.fls` thành `module_sw.fls` và `Generic_cust.001.033_signed.fls` thành `nvm.fls`, đặt `Fls_Ready=1` (DWORD).
4. Khởi động lại `FwSwitchService`, in vị trí log.

**Phụ thuộc:** gói Dell (`fbconfig.ini`, `FwSwitchService`, `L850_Secureboot`); tên giá trị registry và tên `module_sw.fls`/`nvm.fls` lấy từ chuỗi trong file thực thi, không kiểm chứng.

**Lỗi / rủi ro tìm thấy khi đọc lại:**
- Đã sửa (2026-11-23): `$t` là mảng dòng; `$t -notmatch '...'` trả về các dòng không khớp nên điều kiện luôn đúng và script luôn nối thêm `CONFIG_PCIE0000_WA = 1` (có thể trùng). Nay dùng `-not ($t | Select-String -Pattern ... -Quiet)` và `$t = @(...)` để luôn là mảng. Bản sửa chưa chạy thử trên Windows.
- `Remove-Item "$dst\*.fls"` xoá firmware đang đặt trong thư mục nạp; `Get-ChildItem "C:\Program Files*" -Recurse` quét rất rộng.
- Kiểu dữ liệu `Fls_Ready` (DWORD) là phỏng đoán.
