**Xcode Memory Graph Debugger** là công cụ mạnh mẽ nhất để trực quan hóa bộ nhớ Heap, giúp bạn phát hiện **Retain Cycles (Vòng lặp tham chiếu)** và **Abandoned Memory (Bộ nhớ bị bỏ quên)**.

Dưới đây là hướng dẫn chi tiết từ khâu chuẩn bị đến cách phân tích, được tối ưu cho quy trình làm việc chuyên nghiệp.

---

### Bước 1: Chuẩn bị (Quan trọng nhất)

Trước khi chạy app, bạn **phải** bật tính năng này để Memory Graph phát huy tối đa tác dụng. Nếu không, bạn chỉ thấy object tồn tại nhưng không biết nó được tạo ra từ dòng code nào.

1. Trong Xcode, vào menu chọn **Product** -> **Scheme** -> **Edit Scheme...** (hoặc `Cmd + <`).
2. Chọn tab **Run** ở cột trái -> chọn tab **Diagnostics** ở bên phải.
3. Tích vào ô **Malloc Stack Logging**.
4. Chọn **Live Allocations Only** (để đỡ tốn tài nguyên hơn All Allocations).

> **Tại sao?** Khi bật option này, Xcode sẽ ghi lại "Backtrace" (lịch sử gọi hàm) tại thời điểm object được khởi tạo. Khi debug, bạn nhìn vào object và biết chính xác **dòng code nào đã đẻ ra nó**.

---

### Bước 2: Quy trình bắt lỗi (The Workflow)

Giả sử bạn đang nghi ngờ màn hình `DetailViewController` bị leak (không được giải phóng sau khi back ra).

1. Chạy App trên Simulator hoặc thiết bị thật.
2. Thực hiện hành động nghi ngờ: Vào màn hình `DetailViewController`, sau đó bấm Back để thoát ra. (Làm đi làm lại vài lần càng tốt).
3. Tại thanh công cụ Debug (dưới cùng Xcode), bấm vào biểu tượng **Memory Graph Debugger** (Hình 3 node tròn nối với nhau).
* *App sẽ bị tạm dừng (paused) và Xcode chụp lại snapshot bộ nhớ hiện tại.*



---

### Bước 3: Đọc và Phân tích Giao diện

Giao diện sẽ chia làm 3 phần chính:

#### 1. Cột trái (Debug Navigator)

Đây là nơi liệt kê tất cả các Class đang tồn tại trong bộ nhớ (Heap).

* **Mẹo cho Senior:** Ô tìm kiếm (Filter) ở dưới cùng cực kỳ quan trọng. Hãy gõ tên Project của bạn hoặc tên Class bạn nghi ngờ (ví dụ: `DetailVC`).
* Nếu bạn thấy `DetailViewController (1)` xuất hiện trong list mặc dù bạn đã pop nó ra khỏi navigation stack -> **Chắc chắn bị Leak.**

#### 2. Cột giữa (The Graph)

Đây là nơi hiển thị mối quan hệ.

* Bấm vào tên class bên trái, sơ đồ sẽ hiện ra.
* **Các mũi tên:**
* **Mũi tên đậm/sáng:** Đại diện cho **Strong Reference**. Đây là thủ phạm giữ object sống.
* **Mũi tên xám mờ:** Đại diện cho **Weak/Unowned Reference** (vô hại).


* **Dấu chấm than màu tím (Purple Warning):** Xcode tự động phát hiện Retain Cycle đơn giản và đánh dấu cho bạn. Tuy nhiên, các cycle phức tạp nó thường không tự báo, bạn phải tự soi.

#### 3. Cột phải (Memory Inspector)

Khi chọn một object ở giữa, cột phải sẽ hiện thông tin chi tiết.

* **Backtrace:** Nếu bạn đã làm Bước 1, bạn sẽ thấy danh sách các hàm gọi. Nó chỉ thẳng vào dòng code `let vc = DetailViewController()` hoặc nơi closure được tạo.

---

### Bước 4: Chiến thuật Debug Retain Cycle

Khi bạn thấy một object không chịu dealloc (ví dụ `DetailVC` vẫn còn trong list), hãy làm như sau:

1. **Nhìn vào graph:** Tìm xem mũi tên đậm nào đang chỉ vào `DetailVC`.
2. **Truy vết (Trace back):**
* Nếu mũi tên đến từ một `ClosureContext` (một khối block vô danh): Đây là lỗi kinh điển **Closure capture self**.
* Nếu mũi tên đến từ một Class khác (ví dụ `ViewModel`): Kiểm tra xem `ViewModel` có đang giữ `DetailVC` (như delegate) mà quên `weak` không.


3. **Xử lý `Closure Context`:**
* Trong graph, nó thường hiện là một block hình chữ nhật nhỏ.
* Bấm vào block đó -> Nhìn sang cột phải phần **Backtrace**.
* Nó sẽ chỉ cho bạn chính xác dòng code định nghĩa closure đó.
* **Fix:** Thêm `[weak self]` vào closure đó.



---

### Bước 5: Phân biệt Leak và Abandoned Memory

Không phải lúc nào Memory Graph cũng báo lỗi tím hay hiện vòng tròn khép kín.

1. **Leak (Retain Cycle):** A giữ B, B giữ A. Cả 2 cùng trôi nổi trong bộ nhớ không ai đụng tới nhưng không thể giải phóng.
* *Dấu hiệu:* Memory Graph thường vẽ được vòng tròn hoặc bạn thấy 2 object trỏ vào nhau.


2. **Abandoned Memory (Bộ nhớ bị bỏ quên):** Một object "sống dai" một cách hợp pháp (có root object giữ nó) nhưng logic nghiệp vụ không cần nó nữa.
* *Ví dụ:* Một Singleton giữ một mảng `listeners` chứa các ViewController. Khi VC deinit, bạn quên remove nó khỏi mảng `listeners` của Singleton.
* *Dấu hiệu:* Trên Graph, bạn thấy mũi tên trỏ vào VC xuất phát từ một object sống lâu dài (như `ValidationManager` hay `NotificationCenter`).



---

### Mẹo nâng cao (Pro Tips)

* **Lọc nhiễu:** Trong cột trái, bên cạnh ô filter có nút biểu tượng "giấy sách". Bấm vào đó chọn **"Show only Content from My Project"**. Nó sẽ ẩn hết hàng nghìn object hệ thống (UIKit, Foundation internal) giúp bạn đỡ rối mắt.
* **Export Memgraph:** Bạn có thể vào *File -> Export... -> chọn Memory Graph*. File `.memgraph` này có thể gửi cho đồng nghiệp. Họ có thể mở lên trên máy họ để soi như đang debug trực tiếp mà không cần chạy code.
* **Command Line:** Bạn có thể dùng terminal để phân tích file memgraph đã export:
```bash
leaks my_app_snapshot.memgraph

```


Lệnh này sẽ in ra text report về các leak tìm thấy, đôi khi rõ ràng hơn nhìn hình.

### Tóm tắt kịch bản phỏng vấn

Nếu được hỏi về cách dùng công cụ này, hãy nhấn mạnh:
*"Tôi luôn bật **Malloc Stack Logging** trong Scheme để có Backtrace. Khi debug, tôi dùng Memory Graph để chụp snapshot sau khi thực hiện 1 vòng user flow (push/pop). Tôi lọc chỉ hiển thị module của dự án, tìm các instance còn sót lại và truy ngược các đường **Strong Reference** (mũi tên đậm) để tìm xem Closure hay Delegate nào đang holding object đó."*
