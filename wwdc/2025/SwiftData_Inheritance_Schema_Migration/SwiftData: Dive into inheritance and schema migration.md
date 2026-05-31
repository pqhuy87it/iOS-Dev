Dưới đây là tóm tắt các ý chính trong video WWDC 2025 "SwiftData: Dive into inheritance and schema migration":

**1. Hỗ trợ Kế thừa Lớp (Class Inheritance) trong iOS 26**

* **Tính năng mới:** Từ iOS 26, SwiftData chính thức hỗ trợ việc xây dựng biểu đồ dữ liệu (model graph) sử dụng cấu trúc kế thừa [[02:02](https://www.google.com/search?q=http://www.youtube.com/watch%3Fv%3DOR0C6V6lp1k%26t%3D122)].
* **Khi nào nên dùng kế thừa:** Phù hợp khi các model tạo thành một hệ thống phân cấp tự nhiên (hệ sinh thái "is-a"). Ví dụ, lớp cha `Trip` chứa các thông tin cốt lõi (điểm đến, ngày đi, ngày về), trong khi các lớp con như `PersonalTrip` hay `BusinessTrip` sẽ kế thừa và có thêm các thuộc tính đặc thù riêng như "Mục đích cá nhân" hay "Công tác phí" [[02:40](https://www.google.com/search?q=http://www.youtube.com/watch%3Fv%3DOR0C6V6lp1k%26t%3D160)].
* **Khi nào KHÔNG nên dùng:** Nếu các model chỉ chia sẻ với nhau một hoặc hai thuộc tính chung chung và không có mối quan hệ phân cấp, bạn nên sử dụng `Protocol` (Giao thức) thay vì kế thừa để tránh làm hệ thống dữ liệu trở nên phức tạp quá mức [[05:24](https://www.google.com/search?q=http://www.youtube.com/watch%3Fv%3DOR0C6V6lp1k%26t%3D324)].
* **Truy vấn với lớp con:** Lập trình viên có thể sử dụng từ khóa `is` trong khai báo `#Predicate` (ví dụ: `$0 is PersonalTrip`) để lọc và truy vấn chính xác danh sách các đối tượng thuộc một lớp con cụ thể [[07:11](https://www.google.com/search?q=http://www.youtube.com/watch%3Fv%3DOR0C6V6lp1k%26t%3D431)].

**2. Chiến lược Di chuyển Cấu trúc Dữ liệu (Schema Migration)**

* **Tiến hóa phiên bản:** Video hướng dẫn cách quản lý và nâng cấp dữ liệu qua từng hệ điều hành, từ `Version 1` (trên iOS 17) cho đến `Version 4` (trên iOS 26) [[08:10](https://www.google.com/search?q=http://www.youtube.com/watch%3Fv%3DOR0C6V6lp1k%26t%3D490)].
* **Cập nhật dữ liệu hạng nhẹ (Lightweight Migration):** Khi bạn áp dụng tính năng kế thừa bằng cách thêm lớp con trong iOS 26, bạn cần khởi tạo `VersionSchema` mới và sử dụng lightweight migration cho các model mới này [[09:45](https://www.google.com/search?q=http://www.youtube.com/watch%3Fv%3DOR0C6V6lp1k%26t%3D585)].
* **Sử dụng SchemaMigrationPlan:** Bạn cần gom tất cả các phiên bản (schemas) và các giai đoạn di chuyển (migration stages) vào một `SchemaMigrationPlan` và truyền nó vào `ModelContainer`. Điều này đảm bảo quá trình di chuyển an toàn và dữ liệu của người dùng luôn được giữ nguyên khi nâng cấp ứng dụng [[10:14](https://www.google.com/search?q=http://www.youtube.com/watch%3Fv%3DOR0C6V6lp1k%26t%3D614)].

**3. Tối ưu hóa Truy vấn và Lấy dữ liệu (Tailoring Fetches & Queries)**

* **Chỉ lấy những thuộc tính cần thiết:** Khi thực thi các đoạn mã di chuyển (migration), nếu bạn chỉ cần một vài thuộc tính để kiểm tra (như kiểm tra trùng lặp), hãy sử dụng `propertiesToFetch` để tránh việc tải toàn bộ model lên bộ nhớ [[12:39](https://www.google.com/search?q=http://www.youtube.com/watch%3Fv%3DOR0C6V6lp1k%26t%3D759)].
* **Pre-fetching (Tải trước liên kết):** Có thể sử dụng `relationshipKeyPathsForPrefetching` để tải sẵn các đối tượng có quan hệ (relationships) ngay từ lần query đầu tiên, giúp cải thiện tốc độ và tránh lỗi fetch chậm [[13:06](https://www.google.com/search?q=http://www.youtube.com/watch%3Fv%3DOR0C6V6lp1k%26t%3D786)].
* **Giới hạn truy xuất (Fetch Limit):** Rất hữu ích cho việc tối ưu hiệu năng của các Widget; bằng cách dùng `fetchLimit`, bạn có thể ra lệnh cho SwiftData chỉ lấy đúng 1 kết quả (như chuyến đi sắp tới) thay vì đọc toàn bộ danh sách [[13:40](https://www.google.com/search?q=http://www.youtube.com/watch%3Fv%3DOR0C6V6lp1k%26t%3D820)].

**4. Theo dõi và Cập nhật Thay đổi Dữ liệu (Observing Changes)**

* **Dữ liệu thay đổi nội bộ:** Sử dụng API `withObservationTracking` để lắng nghe những thay đổi trên model (ví dụ: người dùng đổi ngày đi chuyến bay) và phản hồi lại lên UI ngay lập tức [[14:06](https://www.google.com/search?q=http://www.youtube.com/watch%3Fv%3DOR0C6V6lp1k%26t%3D846)].
* **Dữ liệu thay đổi từ bên ngoài (Persistent History):** Khi dữ liệu bị thay đổi bởi Widget, App Extensions hoặc các tiến trình khác, chúng sẽ không tự phản ánh nếu dùng hàm fetch thủ công [[14:39](https://www.google.com/search?q=http://www.youtube.com/watch%3Fv%3DOR0C6V6lp1k%26t%3D879)]. Giải pháp cho việc này là sử dụng Persistent History (lịch sử dữ liệu).
* **Tính năng History trên iOS 26:** SwiftData cập nhật thêm tham số `sortBy` trong `HistoryDescriptor`. Thuộc tính này cho phép bạn truy xuất `history token` mới nhất cực kỳ nhanh chóng thay vì phải load tất cả các bản ghi lịch sử [[16:37](https://www.google.com/search?q=http://www.youtube.com/watch%3Fv%3DOR0C6V6lp1k%26t%3D997)].
* Sau khi có được token mới nhất, bạn có thể tạo các `Compound Predicate` để lọc chính xác những model nào đã bị thay đổi (tạo mới/xoá/sửa) từ bên ngoài kể từ lần kiểm tra cuối cùng [[17:32](https://www.google.com/search?q=http://www.youtube.com/watch%3Fv%3DOR0C6V6lp1k%26t%3D1052)].

**Nguồn tham khảo:** [https://www.youtube.com/watch?v=OR0C6V6lp1k](https://www.youtube.com/watch?v=OR0C6V6lp1k)
