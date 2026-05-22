Để máy Mac của bạn chính thức "bắt được việc" (nhận job) từ GitHub và chạy file `ci.yml` vừa push, bạn cần thực hiện 2 phần: Bật runner trên máy Mac và Kích hoạt Action trên GitHub.

### Bước 1: Bật bộ lắng nghe (Runner) trên máy Mac

Nếu bạn đã đóng Terminal sau khi thiết lập lệnh `./config.sh` lúc nãy, thì máy Mac hiện không còn kết nối với GitHub nữa. Bạn mở lại Terminal và làm theo 1 trong 2 cách sau:

**Cách 1: Chạy trực tiếp trên Terminal (Dùng để test)**
Di chuyển vào thư mục chứa runner bạn đã tạo lúc trước và chạy file `run.sh`:

```bash
cd actions-runner
./run.sh

```

Lúc này, Terminal sẽ hiện dòng chữ `Listening for Jobs` (Đang chờ việc). Bạn phải **giữ nguyên cửa sổ Terminal này** (không được tắt) thì máy mới nhận được lệnh build.

**Cách 2: Cài đặt chạy ngầm tự động (Khuyên dùng)**
Để tiện lợi hơn, bạn nên cài đặt runner thành một dịch vụ chạy ngầm trên macOS. Miễn là máy Mac đang bật và có mạng, nó sẽ tự động nhận job từ GitHub mà không cần bạn phải mở Terminal thủ công:

```bash
cd actions-runner
./svc.sh install
./svc.sh start

```

*(Ghi chú: Sau này nếu không muốn chạy ngầm nữa, bạn có thể chạy `./svc.sh stop` và `./svc.sh uninstall`).*

---

### Bước 2: Theo dõi quá trình chạy trên GitHub

Dựa vào file `ci.yml` bạn vừa cấu hình, Workflow sẽ tự động được kích hoạt (trigger) khi có ai đó `push` code mới hoặc tạo `pull_request` vào nhánh `main` hoặc `develop`.

Vì bạn vừa push thành công file `ci.yml` lên nhánh `develop`, **job đầu tiên rất có thể đã tự động được kích hoạt rồi!**

Để xem máy Mac của bạn đang chạy CI/CD như thế nào:

1. Mở trình duyệt, vào trang Repository **ttp-ios** của bạn trên GitHub.
2. Bấm sang tab **Actions** (nằm cạnh tab Pull requests).
3. Bạn sẽ thấy một workflow có tên là **iOS CI** (tên bạn đã đặt trong file yml).
4. Nhấp vào tên của lần chạy (Run) đang có màu vàng (In progress) hoặc xanh (Success).
5. Nhấp tiếp vào job **🔨 Build & Test** ở cột bên trái.

Tại đây, màn hình đen của GitHub sẽ trực tiếp stream (truyền phát) các dòng log từ chính máy Mac của bạn lên. Bạn sẽ thấy máy Mac đang tự động gọi Xcode, kéo các package Swift và bắt đầu chạy test.

*(Mẹo nhỏ: Nếu bạn mở ứng dụng **Activity Monitor** (Giám sát hoạt động) trên máy Mac lúc này, bạn sẽ thấy các tiến trình như `xcodebuild` và `swift` đang hoạt động công suất cao để thực thi lệnh từ GitHub gửi về).*
