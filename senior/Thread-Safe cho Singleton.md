Để hiểu sâu về **"Thread-Safe" (An toàn luồng)** cho Singleton, chúng ta cần mổ xẻ vấn đề từ gốc rễ: **Tại sao nó lại KHÔNG an toàn ngay từ đầu?** và **Swift giải quyết nó như thế nào?**

Dưới đây là giải thích chi tiết theo tư duy của một Senior Developer:

---

### 1. Bản chất vấn đề: Race Condition (Cuộc đua dữ liệu)

Hãy tưởng tượng Singleton của bạn là một **Cuốn sổ ghi chép chung** đặt trên bàn.

* **Thread A (Người A)** muốn ghi vào sổ: "Tài khoản cộng thêm 100k".
* **Thread B (Người B)** muốn đọc số dư để hiển thị lên màn hình.

Nếu chỉ có 1 người dùng, mọi thứ êm đẹp. Nhưng trong môi trường đa luồng (Multi-threading), cả A và B có thể lao vào giật cuốn sổ **cùng một thời điểm**.

**Kịch bản lỗi (Crash/Sai số liệu):**

1. Ban đầu số dư là 10.
2. Thread A đọc số dư (thấy 10), định cộng thêm 1 (để thành 11).
3. Thread B đọc số dư (vẫn thấy 10), định cộng thêm 2 (để thành 12).
4. Thread A ghi số 11 vào sổ.
5. Thread B (do không biết A vừa sửa) ghi đè số 12 vào sổ.
-> **Kết quả:** Mất luôn dữ liệu của A. Đây gọi là **Race Condition**.

> **"Thread-Safe"** nghĩa là: Bạn thiết kế code sao cho dù có 100 người (thread) lao vào cùng lúc, cuốn sổ vẫn được chuyền tay từng người một cách trật tự, không ai bị ghi đè, không ai đọc sai.

---

### 2. Hai cấp độ của Thread-Safe trong Singleton

Khi phỏng vấn hoặc làm việc, bạn cần phân biệt rõ 2 loại an toàn này:

#### Cấp độ 1: An toàn khi Khởi tạo (Initialization Safety)

Làm sao để đảm bảo chỉ có **DUY NHẤT** một instance được tạo ra?

* **Tin vui:** Từ Swift 1.2 trở đi, dòng code `static let shared = MySingleton()` đã **tự động Thread-Safe**.
* **Cơ chế:** Swift sử dụng `dispatch_once` ngầm bên dưới. Dù 10 thread gọi `shared` cùng lúc, Swift đảm bảo code khởi tạo chỉ chạy đúng 1 lần. Bạn không cần làm gì thêm ở bước này.

#### Cấp độ 2: An toàn khi Truy cập/Sửa đổi (Read/Write Safety) - *Đây là cái ảnh bạn gửi đề cập*

Instance thì duy nhất rồi, nhưng các biến (properties) bên trong nó (ví dụ `var array: [String]`) thì chưa an toàn.

Để bảo vệ các biến này, chúng ta dùng cơ chế **"Khóa" (Locking)**. Có 3 cách phổ biến:

---

### 3. Giải phẫu các giải pháp bảo vệ (Deep Dive)

#### Cách 1: NSLock (Khóa cửa thủ công)

Đây là cách cổ điển nhất. Trước khi làm gì thì khóa cửa lại. Làm xong mở cửa ra.

```swift
class Singleton {
    private let lock = NSLock()
    private var data = [String]()

    func add(_ item: String) {
        lock.lock()   // 🔒 Chốt cửa
        data.append(item)
        lock.unlock() // 🔓 Mở cửa
    }
}

```

* **Nhược điểm:** Dễ quên mở khóa (gây Deadlock - treo app vĩnh viễn). Hiệu năng trung bình.

#### Cách 2: Serial Queue (Xếp hàng lần lượt) - *Approach 1 trong ảnh*

Tạo một đường ống hẹp. Ai muốn đọc/ghi phải xếp hàng.

* **Ưu điểm:** Dễ hiểu, không bao giờ bị Race Condition.
* **Nhược điểm:** Chậm. Nếu có 100 người chỉ muốn "đọc" (việc đọc vốn vô hại), họ vẫn phải chờ nhau.

#### Cách 3: Concurrent Queue + Barrier (Rào chắn) - *Approach 2 trong ảnh (Khuyên dùng)*

Đây là mô hình **Readers-Writers Lock** kinh điển.

* **Tư duy:**
* **Đọc (Read):** Cho phép chạy song song (`concurrent`). 100 người đọc cùng lúc cũng được. -> **Rất nhanh.**
* **Ghi (Write):** Là hành động nguy hiểm, cần độc quyền. Ta dùng cờ `.barrier`.


* **Cơ chế Barrier:** Khi lệnh `.barrier` xuất hiện, nó như cảnh sát giao thông:
1. Chặn tất cả request mới.
2. Đợi các request cũ (đang đọc dở) chạy xong.
3. Thực hiện việc Ghi (một mình một đường).
4. Ghi xong -> Mở đường cho mọi người đọc tiếp.



---

### 4. Giải pháp hiện đại nhất: Actors (Swift 5.5+)

Nếu bạn đang code Swift hiện đại, các cách trên (dùng GCD) được coi là "hơi cũ". Swift giới thiệu **Actor** để tự động hóa việc này.

```swift
// Chỉ cần thay 'class' bằng 'actor'
actor UserStore {
    var scores: [String: Int] = [:]
    
    // Mặc định các hàm trong actor đều Thread-Safe
    func updateScore(user: String, score: Int) {
        scores[user] = score
    }
}

```

* **Tại sao Senior thích Actor?**
* Không cần tạo Queue, không cần Lock/Unlock.
* Compiler sẽ báo lỗi ngay nếu bạn cố truy cập sai cách (thay vì crash lúc chạy).
* Nó tự động quản lý việc xếp hàng (serialization) cực kỳ tối ưu.



### Tóm lại

Khi nói về "Thread-Safe Singleton", bạn cần nhớ:

1. **Mục đích:** Ngăn chặn **Race Condition** (ghi đè dữ liệu, crash) khi nhiều luồng cùng truy cập.
2. **Khởi tạo:** `static let` đã an toàn sẵn.
3. **Dữ liệu bên trong:** Cần bảo vệ thủ công.
* Dự án cũ/Objective-C: Dùng **GCD Barrier** (Đọc song song, Ghi độc quyền).
* Dự án mới (Swift 5.5+): Dùng **Actor**.

Dựa trên nội dung trong ảnh, đây là một bài hướng dẫn kỹ thuật về **cách đảm bảo an toàn luồng (Thread-Safety) cho Singleton pattern trong lập trình Swift**.

Dưới đây là giải thích chi tiết về quan điểm và hai phương pháp được trình bày trong ảnh:

### 1. Tại sao cần "Thread-Safe" cho Singleton?

Singleton là một đối tượng duy nhất tồn tại trong suốt vòng đời ứng dụng và có thể được truy cập từ bất kỳ đâu (global access).

* **Vấn đề:** Trong môi trường đa luồng (multithreaded), nếu luồng A đang đọc dữ liệu và luồng B nhảy vào sửa dữ liệu cùng một lúc, sẽ xảy ra xung đột (Race Condition), dẫn đến sai lệch dữ liệu hoặc Crash app.
* **Giải pháp:** Chúng ta cần cơ chế để kiểm soát việc truy cập này, đảm bảo khi một luồng đang "ghi" dữ liệu thì không ai được phép "đọc" hay "ghi" chen ngang.

Bức ảnh đưa ra 2 cách giải quyết phổ biến bằng **Grand Central Dispatch (GCD)**:

---

### 2. Cách tiếp cận 1: Sử dụng Serial Dispatch Queue (Cách đơn giản)

Đây là cách cơ bản nhất để khóa (lock) tài nguyên.

* **Cơ chế:** Tạo ra một hàng đợi tuần tự (Serial Queue). Hãy tưởng tượng nó như một **cây cầu hẹp chỉ đi được 1 chiều**.
* **Hoạt động:**
* Bất kỳ ai muốn truy cập (đọc hoặc ghi) vào tài nguyên của Singleton đều phải đi qua hàng đợi này.
* Hàng đợi Serial đảm bảo chỉ có **1 tác vụ được thực thi tại 1 thời điểm**.


* **Trong code:** Người viết dùng `queue.sync` để ép mọi tác vụ phải xếp hàng lần lượt.
* **Ưu điểm:** Dễ cài đặt, an toàn tuyệt đối.
* **Nhược điểm:** Hiệu năng thấp. Nếu có 100 luồng chỉ muốn "đọc" dữ liệu (việc đọc vốn dĩ an toàn), chúng vẫn phải xếp hàng chờ nhau, gây lãng phí thời gian.

---

### 3. Cách tiếp cận 2: Sử dụng Concurrent Queue + Barrier (Cách tối ưu)

Đây là quan điểm nâng cao, giải quyết bài toán **"Readers-Writers Problem"** (Bài toán người đọc - người viết). Nó tối ưu cho các trường hợp **Đọc nhiều - Ghi ít** (Read-Heavy).

* **Cơ chế:** Sử dụng hàng đợi song song (Concurrent Queue) kết hợp với rào chắn (Barrier). Hãy tưởng tượng nó như một **đường cao tốc nhiều làn**.
* **Hoạt động:**
1. **Đọc (Read):** Dùng `queue.sync` trên hàng đợi song song.
* Cho phép nhiều luồng cùng đọc dữ liệu một lúc (xe chạy song song trên nhiều làn). Không ai phải chờ ai nếu chỉ để xem dữ liệu.


2. **Ghi (Write):** Dùng `queue.async(flags: .barrier)`.
* Đây là "chiếc xe tải hạng nặng" hoặc "rào chắn".
* Khi lệnh `.barrier` được gọi, nó sẽ chặn tất cả các luồng khác. Nó đợi các luồng đang đọc dở làm cho xong, sau đó **chiếm quyền duy nhất** để ghi dữ liệu. Trong lúc nó ghi, không ai được đọc hay ghi khác.
* Sau khi ghi xong, rào chắn mở ra, các luồng đọc lại được tiếp tục chạy song song.




* **Phân tích đoạn code trong ảnh (Approach 2):**
* `private let queue = DispatchQueue(..., attributes: .concurrent)`: Tạo hàng đợi song song.
* **Hàm `writeToLog` (Ghi):** Sử dụng `flags: .barrier`. Đây là điểm chốt chặn để đảm bảo an toàn khi sửa đổi dữ liệu `logDict`.
* **Hàm `readFromLog` (Đọc):** Chỉ dùng `queue.sync`. Vì queue là concurrent, nên nhiều nơi có thể gọi hàm này cùng lúc mà không bị chặn, tốc độ rất nhanh.



### Tóm tắt quan điểm của tác giả

Tác giả muốn truyền tải rằng:

1. Đừng để Singleton trần trụi (non-thread-safe) trong môi trường đa luồng.
2. Nếu ứng dụng đơn giản, hãy dùng **Serial Queue** (Cách 1) cho dễ.
3. Nếu ứng dụng cần hiệu năng cao, có nhiều thao tác đọc dữ liệu liên tục, hãy dùng **Concurrent Queue + Barrier** (Cách 2) để đạt tốc độ tốt nhất mà vẫn an toàn.
