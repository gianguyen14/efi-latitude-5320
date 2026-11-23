# psi_extract.py

**Mục đích:** lấy ảnh PSI ra khỏi container FLS của Intel (file `*_Secureboot.fls` trong gói Dell); chỉ đọc file vào. Cú pháp: `psi_extract.py <Secureboot.fls> <out_dir>`. Ghi `psi.bin` (ảnh không kèm tiền tố 16 byte) và in sha256 cùng 16 byte đầu.

**Cách hoạt động (script tuyến tính):**
- Container = header 0x28 byte rồi các record `[type u32][len u32]...`; vòng lặp duyệt từ offset 0x28, thoát nếu `len < 8` hoặc vượt cuối file.
- Record `type == 0xC` là dữ liệu thành phần: `idx`, `sub` rồi payload bắt đầu ở `pos + 24`; lưu theo khoá `(idx, sub)`.
- Lấy thành phần `(0, 0)` (theo docstring là `psi_flash_signed.fls`, 64 KiB), kiểm trường kích thước ở tiền tố bằng `payload - 16` bằng `assert`, rồi ghi phần sau 16 byte tiền tố.

**Phụ thuộc:** không gọi file nào của dự án. Liên quan tới `xmm_psi.py` (trạng thái 3 "no PSI data compiled in") nhưng file này không nhắc cách `psi.bin` được đưa vào kext [suy đoán về luồng dùng].

**Lưu ý:**
- Docstring ghi rõ: **không commit đầu ra**, vì là firmware của hãng.
- `comps[(0, 0)]` ném `KeyError` nếu thiếu thành phần; `assert` ném `AssertionError` nếu kích thước lệch; không xử lý lỗi thân thiện.
- Khi có hai record trùng `(idx, sub)` thì bản sau ghi đè bản trước, không cảnh báo.
