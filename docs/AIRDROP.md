# AirDrop (AWDL) Trên Intel AX201 Với ForbiddenItlwm

## 1. Kết Quả Kiểm Định

| Hạng mục | Kết quả |
|---|---|
| Máy / macOS | Dell Latitude 5320, Sequoia 15.8.1 (24H32) |
| Card Wi-Fi | Intel AX201, `8086:a0f0` |
| Driver | **ForbiddenItlwm 0.5.4-beta.2** (bản Sequoia), thay `AirportItlwm.kext` |
| iPhone SE 2 (iOS mới) | AirDrop hoạt động |
| iPhone 7 (iOS cũ) | **Chưa nhận được**: Mac thấy tín hiệu Bluetooth nhưng `sharingd` không bật quảng bá AirDrop qua AWDL |
| Giao diện | `awdl0` lên, có IPv6; ping qua `awdl0` 0% mất gói |
| Wi-Fi thường | Vẫn kết nối (kênh 36), AWDL dùng kênh 149 |

Dự án gốc: <https://github.com/retropineaple/ForbiddenItlwm> (GPL-2.0, beta, tác giả cho biết phần lớn mã do AI viết; dùng có rủi ro kernel panic hoặc mất Wi-Fi).
Kext trong thư mục `EFI/OC/Kexts/` tải từ trang Releases bản `v0.5.4-beta.2`; SHA-256 của tệp zip:

* `ForbiddenItlwm-0.5.4-beta.2-Sequoia.zip`: `82d791b52aa05715d146e326cab08706d064fb2e9f9a82171e298d9fca42a54a`
* `BTLEAdvFixup-0.9.1-Sequoia.zip`: `54021a179519f12df3db6930b1f5cc35031ec4c0fc32cdad36cfab5df0e18de2`

## 2. Thay Đổi Trong `config.plist`

* `AirportItlwm.kext`: `Enabled = False` (giữ lại làm đường lui).
* `ForbiddenItlwm.kext`: `Enabled = True`, `MinKernel 24.0.0`, `MaxKernel 24.99.99` (chỉ Sequoia).
* `BTLEAdvFixup.kext`: `Enabled = True`, phát quảng bá BLE để iPhone thấy Mac.
* `IntelBTPatcher.kext`: `Enabled = False` (xung đột với BTLEAdvFixup, hai kext cùng hook một hàm).
* Boot-args: bỏ `itlwm_he=1` (tác giả ghi rõ Wi-Fi 6 chưa được thử với AirDrop) và thêm:

```
-btleadv -itlawdlcoexprobe -itlawdliface -itlawdlnativeup -itlawdlcoexrx -itlawdlcoextx
-itlawdlcoexmulti -itlawdlcoexdata -itlawdlmitx -itlawdlelicit -itlawdlcaps -itlawdlsvcmerge
-itlawdlawsync itlawdlintcoal=4 -itlawdlcoexbatx -itlawdlcoexpeerpause itlawdltxqueue=4096
```

Ý nghĩa từng cờ: xem `docs/BOOT-FLAGS.md` của dự án gốc. Kext chỉ khởi động AWDL trên các bản macOS đã được kiểm chứng; bản khác nó chạy như Wi-Fi thường.

## 3. Bước Bắt Buộc Ngoài EFI: Bật `wifip2pd`

Nếu `com.apple.wifip2pd` bị tắt trong launchd thì macOS không bao giờ yêu cầu driver tạo `awdl0`, dù driver chạy đúng (`ItlwmAWDLCreateRequests = 0`, `ifconfig awdl0` báo không tồn tại). Kiểm tra và bật lại:

```bash
launchctl print-disabled system | grep wifip2pd
sudo launchctl enable system/com.apple.wifip2pd
sudo launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.wifip2pd.plist
```

Dịch vụ chạy theo yêu cầu, nên mở cửa sổ AirDrop trong Finder (`Cmd+Shift+R`) hoặc reboot để nó khởi động.

## 4. Kiểm Tra Sau Khi Boot

```bash
ioreg -l -w0 | grep -E '"ItlwmAWDL(InterfaceBuild|BuildCheck)"|"ITLAWDLCoex(Added|Channel|CountryLearned)"'
ifconfig awdl0
```

Kết quả mong đợi: `BuildCheck` là `verified`, `Added` là `Yes`, `Channel` là `149`, `awdl0` ở trạng thái UP với địa chỉ IPv6 `fe80::…`.

## 5. Lưu Ý

* Cấu hình này được kiểm định trên cây EFI đang dùng thử S0ixStandby; phần AirDrop độc lập với S0ixStandby, nhưng tổ hợp đúng như trong repo chưa được boot nguyên trạng.
* Trước khi cập nhật macOS: boot một lần không có `-btleadv` (hoặc tắt BTLEAdvFixup), cập nhật, rồi kiểm tra bản mới có được hỗ trợ.
* Wi-Fi thường chậm đi khoảng 30–45% khi AirDrop đang lắng nghe vì dùng chung một radio (theo ghi nhận của dự án gốc).
* Một lần truyền từ thiết bị khác từng kẹt ở 0 byte; dự án gốc có ghi nhận lỗi tương tự ("kẹt ở Waiting").
* Đường lui: bật lại `AirportItlwm.kext`, tắt `ForbiddenItlwm.kext` và `BTLEAdvFixup.kext`, bật lại `IntelBTPatcher.kext`, rồi bỏ các cờ `-itlawdl*` và `-btleadv` khỏi boot-args.
