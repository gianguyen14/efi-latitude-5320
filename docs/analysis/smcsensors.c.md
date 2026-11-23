# smcsensors.c

**Mục đích:** đọc cảm biến SMC (nhiệt độ CPU kiểu `sp78`, công suất gói kiểu `sp96` = giá trị thô/64 W) và in một dòng dạng `KEY(type)=giá_trị `. Build: `clang -O1 smcsensors.c -o smcsensors -framework IOKit`.

**Hàm chính:**
- `k4()`: đổi chuỗi 4 ký tự thành mã khoá SMC.
- `call()`: gọi `IOConnectCallStructMethod` selector 2 tới `AppleSMC` với struct `D`.
- `rd(key, type)`: hai lần gọi (lấy kích thước/kiểu bằng `data8=9`, rồi đọc giá trị bằng `data8=5`) và giải mã `flt `, `sp78`, `ui8 `, `ui16`, `sp96`; trả -1 khi lỗi, -2 nếu kiểu lạ.
- `main()`: mở `AppleSMC`, đọc 12 khoá (`TC0P`, `TC0D`, `TC0E`, `TC0F`, `TCXC`, `TC1C`, `TC2C`, `PC0C`, `PCPC`, `PCPG`, `PCTR`, `PC0R`).

**Phụ thuộc:** chỉ IOKit. Đầu ra `TC0P(sp78)=...` và `PCTR(sp96)=...` khớp với các biểu thức `sed` trong `PostInstall/Tools/freezewatch.sh`, nên đây là binary `smcsensors` mà `freezewatch.sh` gọi.

**Lưu ý:**
- Khoá đọc lỗi hoặc có giá trị ≤ -1 bị bỏ khỏi đầu ra (`if(v>-1)`), nên nhiệt độ âm hoặc khoá không tồn tại không hiện [suy đoán về tác động].
- Không đóng kết nối SMC và không giải phóng `io_service_t` (tiến trình thoát ngay sau đó).
- Bố cục struct `D` tự khai báo theo giao diện SMC không công khai; sai kích thước có thể làm gọi thất bại [suy đoán].
