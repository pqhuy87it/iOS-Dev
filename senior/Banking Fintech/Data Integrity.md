**Tính toàn vẹn dữ liệu (Data Integrity)** trong ngữ cảnh Mobile App (đặc biệt là Banking) không chỉ đơn thuần là "dữ liệu không bị hỏng file". Nó có nghĩa là: **Dữ liệu phải chính xác, nhất quán và đáng tin cậy trong suốt vòng đời của nó, bất chấp lỗi mạng, crash app hay hành vi bất thường của người dùng.**

Đối với Senior iOS Developer, bạn cần giải quyết bài toán này ở 3 tầng: **Network (Mạng)**, **Local State (Bộ nhớ/RAM)**, và **Storage (Lưu trữ)**.

Dưới đây là phân tích chi tiết:

---

### 1. Tính Lũy Đẳng (Idempotency) - Quan trọng nhất trong giao dịch

Đây là khái niệm "sống còn" khi làm việc với API chuyển tiền.

* **Bài toán:**
* Người dùng bấm "Chuyển tiền". App gửi request lên Server.
* Server đã nhận, đã trừ tiền, nhưng khi trả response về thì **mạng bị rớt**.
* App nhận lỗi timeout, hiện thông báo "Lỗi kết nối".
* Người dùng hoảng hốt bấm nút "Chuyển tiền" lần nữa.
* **Hậu quả:** Khách hàng bị trừ tiền 2 lần cho 1 mục đích.


* **Giải pháp: Idempotency Key.**
* Mỗi khi User bắt đầu một ý định giao dịch (bấm nút Submit), Client (iOS App) sẽ sinh ra một chuỗi unique (thường là UUID v4), gọi là `idempotency_key`.
* Gửi key này lên Server trong Header hoặc Body.
* **Logic Server:**
* Nếu thấy key này **lần đầu**: Thực hiện trừ tiền -> Lưu key vào DB -> Trả về Success.
* Nếu thấy key này **đã tồn tại**: Không trừ tiền nữa -> Trả về kết quả cũ (Success) ngay lập tức.


* **Client:** Nếu timeout, App có thể an tâm tự động retry request đó mà không sợ trừ tiền oan.



### 2. Kiểm soát Đồng thời (Concurrency Control) - Tránh Race Condition

Đây là vấn đề xảy ra ngay trong bộ nhớ của App (RAM).

* **Bài toán:**
* Bạn có biến `var balance = 100`.
* Thread A (nhận thông báo socket): Cộng 50 vào balance.
* Thread B (người dùng vừa nạp tiền): Cộng 20 vào balance.
* Nếu 2 thread chạy cùng lúc (song song), chúng có thể cùng đọc giá trị 100, cùng tính toán và ghi đè lên nhau. Kết quả có thể là 150 hoặc 120 thay vì 170.


* **Giải pháp Senior:**
* **Swift Actors (Modern):** Đưa `balance` vào một `actor`. Actor đảm bảo tại một thời điểm chỉ có 1 task được truy cập và chỉnh sửa state.
* **Serial Queue (GCD):** Tất cả lệnh ghi/đọc `balance` phải xếp hàng qua một Serial Queue.
* **NSLock / Mutex:** Khóa thủ công (ít dùng hơn trong Swift hiện đại vì dễ gây Deadlock).



### 3. Tính Nguyên Tử (Atomicity) - Local Database

Khi lưu trữ dữ liệu xuống Core Data hoặc Realm/SQLite.

* **Bài toán:**
* Quy trình lưu offline một giao dịch gồm 2 bước: (1) Lưu lịch sử giao dịch vào bảng `History`, (2) Cập nhật số dư ở bảng `Account`.
* Nếu bước (1) thành công, nhưng App bị **Crash** hoặc hết pin ngay trước bước (2).
* **Hậu quả:** Dữ liệu bị lệch (Inconsistent). Có lịch sử nhưng tiền không đổi.


* **Giải pháp:** Sử dụng **Transaction**.
* Trong Core Data hoặc Realm, bạn bọc cả 2 thao tác trong một block `write transaction`.
* Nguyên tắc **"All or Nothing"**: Nếu bước (2) lỗi, hệ thống sẽ **Rollback** (hoàn tác) bước (1). Dữ liệu trở về trạng thái ban đầu như chưa có gì xảy ra.



### 4. Data Validation & Sanitization (Đầu vào sạch)

Không bao giờ tin tưởng dữ liệu người dùng nhập hoặc thậm chí dữ liệu từ Server trả về (trong trường hợp bị Man-in-the-Middle).

* **Checksum/Hashing:** Khi tải một file quan trọng (ví dụ config file cho bảo mật) từ server, App cần kiểm tra mã Hash (SHA-256) của file đó xem có khớp với mã Hash mà Server cung cấp không. Để đảm bảo file không bị sửa đổi trên đường truyền.
* **Decimal:** Như đã giải thích ở câu hỏi trước, dùng `Decimal` thay vì `Double` để đảm bảo tính toàn vẹn về giá trị toán học.

---

### Tóm tắt câu trả lời phỏng vấn:

> *"Để đảm bảo Data Integrity, tôi tiếp cận theo 3 lớp:
> 1. **Network Layer:** Tôi bắt buộc sử dụng cơ chế **Idempotency Key** cho mọi API thay đổi trạng thái (POST/PUT). Client sinh UUID cho mỗi transaction để đảm bảo dù có retry bao nhiêu lần, server chỉ xử lý đúng 1 lần.
> 2. **Memory Layer:** Tôi giải quyết vấn đề Race Condition bằng cách sử dụng **Actors** trong Swift (hoặc Serial Queue) để bảo vệ các biến trạng thái quan trọng (như số dư, token), đảm bảo thread-safety.
> 3. **Storage Layer:** Tôi luôn sử dụng **Atomic Transactions** khi ghi dữ liệu xuống DB (Realm/Core Data). Nếu một chuỗi thao tác ghi bị lỗi giữa chừng, toàn bộ transaction phải được Rollback để tránh dữ liệu rác hoặc không đồng nhất."*
> 
>
