Để đạt được **60 FPS** (16.6ms mỗi khung hình) hoặc **120 FPS** (trên các thiết bị ProMotion) với một Table/Collection View phức tạp, bạn cần chiến đấu trên cả hai mặt trận: **CPU** (Tính toán) và **GPU** (Hiển thị).

Dưới đây là các kỹ thuật tối ưu hóa chuyên sâu dành cho Senior Developer:

---

### 1. Tối ưu hóa Hình ảnh (Image Optimization) - Kẻ thù số 1

Sai lầm phổ biến nhất không phải là tải ảnh đồng bộ (ai cũng biết tải async rồi), mà là **tải ảnh quá khổ (Oversized Images)** và **giải mã trên Main Thread**.

* **Kỹ thuật Downsampling (Quan trọng nhất):**
* **Vấn đề:** Nếu bạn tải một ảnh 4000x3000px (12MP) từ server chỉ để hiển thị vào một `UIImageView` bé tẹo 100x100px, bạn đang giết chết bộ nhớ RAM và bắt GPU phải resize ảnh đó mỗi lần render.
* **Giải pháp:** Sử dụng `ImageIO` để **Downsample** ảnh ngay trong quá trình decode, chỉ tạo ra buffer ảnh đúng kích thước cần hiển thị.
* **Lợi ích:** Giảm lượng RAM tiêu thụ từ hàng chục MB xuống vài chục KB.


* **Decode on Background:**
* Việc giải nén định dạng JPEG/PNG thành Bitmap để hiển thị tốn nhiều CPU. Đừng để việc này xảy ra khi gán `image = ...` trên Main Thread. Hãy decode ở background queue trước rồi mới dispatch sang main để gán. (Các thư viện như Kingfisher/Nuke đã hỗ trợ việc này, hãy chắc chắn bạn đã config đúng).


* **Cancel Request:**
* Trong `prepareForReuse()`, bắt buộc phải hủy (cancel) các request tải ảnh đang chạy của cell cũ. Nếu không, khi user cuộn nhanh, cell tái sử dụng sẽ bị hiện nhầm ảnh cũ rồi mới nhảy sang ảnh mới (flashing), và mạng bị nghẽn bởi các request không còn cần thiết.



---

### 2. Tối ưu hóa GPU (Rendering) - Kẻ thù thầm lặng

GPU bị quá tải thường do **Off-screen Rendering** và **Color Blending**.

* **Loại bỏ Off-screen Rendering:**
* **Nguyên nhân:** Khi bạn dùng `cornerRadius`, `shadow`, `mask` mà không cẩn thận, GPU phải tạo một bộ đệm phụ (off-screen buffer), vẽ vào đó, rồi mới dán lại lên màn hình. Việc chuyển đổi context này cực tốn kém.
* **Giải pháp cho Shadow:** Đừng bao giờ chỉ set `layer.shadowOpacity`. Hãy luôn set **`layer.shadowPath`**. Khi có path cụ thể, iOS cache được shadow và không cần tính toán lại mỗi frame.
* **Giải pháp cho CornerRadius:**
* Nếu có thể, hãy dùng kỹ thuật **"Pre-rounded Image"** (bo góc ảnh ở background thread rồi mới hiển thị) thay vì set `layer.cornerRadius` và `clipsToBounds = true`.
* Trên iOS hiện đại, dùng `layer.cornerRadius` đơn thuần (không clipsToBounds) đã được tối ưu khá tốt, nhưng cẩn thận khi kết hợp với nội dung con.




* **Giảm thiểu Color Blending:**
* **Vấn đề:** Khi một view có màu `clear` hoặc trong suốt (alpha < 1) nằm đè lên view khác, GPU phải tính toán màu pha trộn của từng pixel.
* **Giải pháp:**
* Set `isOpaque = true` cho tất cả các view nếu có thể.
* Đảm bảo background color của Cell và các Label là màu đặc (White/Black), không để `clear` trừ khi bắt buộc.


* **Check:** Dùng Instruments -> Core Animation -> Bật "Color Blending Layers" (Màu đỏ là tệ, màu xanh là tốt).



---

### 3. Tối ưu hóa CPU (Layout & Calculation)

Mỗi lần `cellForRowAt` được gọi, Main Thread rất bận rộn. Hãy giảm tải cho nó.

* **Pre-calculation (Tính toán trước):**
* Đừng để Auto Layout tính toán chiều cao cell mỗi khi cuộn (`UITableView.automaticDimension` rất tiện nhưng chậm với layout phức tạp).
* **Chiến thuật Senior:** Tính toán trước chiều cao của Cell và Layout của các thành phần con ngay khi nhận dữ liệu JSON (trong ViewModel hoặc Background Task). Cache lại giá trị này. Khi `heightForRowAt` được gọi, chỉ việc return con số đó (O(1)).


* **Làm phẳng View Hierarchy (Flattening):**
* Càng nhiều View lồng nhau (Container trong Container), Auto Layout càng giải phương trình lâu.
* Hãy bỏ bớt các View container thừa.
* Nếu quá phức tạp, cân nhắc **viết code Layout thủ công** (override `layoutSubviews` và set frame) thay vì dùng Auto Layout cho các Cell phức tạp. Code tay nhanh hơn Auto Layout rất nhiều.


* **Tối ưu Text:**
* `UILabel` khá nặng trên Main Thread. Với các app chat hoặc news feed cực nặng, các ông lớn (Facebook/Instagram/Pinterest) thường dùng **CoreText** hoặc **TextKit** để render text thành ảnh ở background thread, sau đó hiển thị lên một `UIView` đơn giản (`layer.contents`). (Tuy nhiên đây là kỹ thuật cực khó, chỉ dùng khi đường cùng).



---

### 4. Sử dụng API thông minh

* **Prefetching API (`UITableViewDataSourcePrefetching`):**
* Implement hàm `tableView(_:prefetchRowsAt:)`.
* Hệ thống sẽ báo cho bạn biết các index sắp xuất hiện. Bạn dùng lúc này để kích hoạt việc tải ảnh hoặc tính toán layout ở background **trước khi** user cuộn tới đó.



### Tóm tắt Checklist kiểm tra (Debug Workflow):

1. **Instruments (Time Profiler):** Có hàm nào trong `cellForRow` chiếm nhiều CPU không? (Ví dụ: `DateFormatter` tạo mới liên tục -> Phải đưa ra static).
2. **Instruments (Core Animation):**
* Bật **Color Blended Layers**: Xóa bỏ màu đỏ (transparent) càng nhiều càng tốt.
* Bật **Color Off-screen Rendered Yellow**: Nếu thấy màu vàng, phải fix ngay (thêm shadowPath hoặc bỏ mask).


3. **Code Review:** Có đang decode ảnh to trên main thread không? Có đang tính toán layout nặng trong `layoutSubviews` không?

**Câu trả lời "ăn điểm":**
*"Tôi tiếp cận vấn đề theo 3 lớp. Đầu tiên là **Data**, tôi pre-calculate chiều cao cell và layout frame trong ViewModel ở background thread. Thứ hai là **Resource**, tôi dùng kỹ thuật **Downsampling** ảnh kết hợp với prefetching API để giảm tải bộ nhớ và decode time. Cuối cùng là **Rendering**, tôi sử dụng Instruments để triệt tiêu **Off-screen rendering** (bằng shadowPath) và đảm bảo **Opaque** cho các layers để giảm tải cho GPU."*
