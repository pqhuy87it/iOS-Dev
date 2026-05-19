Đây là sự chuyển dịch lớn nhất trong lịch sử lập trình iOS. Đối với một Senior Developer, sự khác biệt không chỉ nằm ở cú pháp (viết code ít hơn), mà nằm ở **mô hình quản lý Thread (Threading Model)** và **Hiệu năng hệ thống (System Performance)**.

Dưới đây là so sánh chi tiết giữa GCD và Swift Concurrency:

---

### 1. Mô hình quản lý Thread (Cốt lõi)

Đây là điểm khác biệt quan trọng nhất về mặt kiến trúc.

#### **GCD: Preemptive Multithreading (Đa luồng ưu tiên)**

* **Cơ chế:** Khi bạn dispatch một task vào queue, hệ thống sẽ tìm một thread để chạy nó.
* **Vấn đề "Thread Explosion" (Bùng nổ Thread):** Nếu thread đó bị chặn (blocked) - ví dụ do đang chờ I/O, chờ `semaphore`, hay `lock` - GCD sẽ thấy CPU đang rảnh và **tạo thêm thread mới** để chạy các task khác trong hàng đợi.
* **Hậu quả:**
* App có thể sinh ra hàng chục, thậm chí hàng trăm threads.
* **Context Switching Overhead:** CPU tốn quá nhiều tài nguyên để chuyển đổi ngữ cảnh giữa các thread thay vì thực sự chạy code.
* Tăng Memory footprint (mỗi thread tốn stack memory).



#### **Swift Concurrency: Cooperative Thread Pool (Đa luồng hợp tác)**

* **Cơ chế:** Runtime tạo ra một hồ bơi thread cố định (bằng số lượng nhân CPU).
* **Không bao giờ Block, chỉ Suspend (Tạm dừng):** Khi gặp từ khóa `await`, hàm sẽ tạm dừng thực thi, lưu trạng thái hiện tại (biến cục bộ, stack frame) vào Heap, và **nhường thread đó cho task khác dùng**.
* **Lợi ích:**
* Số lượng thread luôn ổn định (ví dụ iPhone 6 nhân thì chỉ loanh quanh 6 thread).
* Giảm thiểu tối đa Context Switching.



> **Hình ảnh so sánh:**
> * **GCD:** Giống như một công ty thuê thêm nhân viên thời vụ mỗi khi nhân viên chính thức đi toilet hay ngồi chờ máy in. Quá nhiều người chen chúc trong văn phòng.
> * **Swift Concurrency:** Một nhóm nhân viên cố định. Khi nhân viên A chờ máy in, anh ta không ngồi chơi mà quay sang làm việc khác ngay lập tức.
> 
> 

---

### 2. Cú pháp & Khả năng đọc (Syntax & Readability)

#### **GCD: Callback Hell (Pyramid of Doom)**

Xử lý lỗi và luồng logic rất rời rạc.

```swift
func fetchImage(completion: @escaping (Result<UIImage, Error>) -> Void) {
    downloadData { result in
        switch result {
        case .success(let data):
            resizeImage(data) { result in
                switch result {
                case .success(let image):
                    completion(.success(image))
                case .failure(let error):
                    completion(.failure(error)) // Phải nhớ gọi completion ở mọi nhánh
                }
            }
        case .failure(let error):
            completion(.failure(error))
        }
    }
}

```

#### **Async/Await: Linear Code (Code tuyến tính)**

Code chạy bất đồng bộ nhưng viết như code đồng bộ tuần tự.

```swift
func fetchImage() async throws -> UIImage {
    let data = try await downloadData() // Tạm dừng ở đây, chờ data
    let image = try await resizeImage(data) // Tạm dừng ở đây, chờ resize
    return image
}

```

---

### 3. Safety & Error Handling

* **GCD:**
* Rất dễ quên gọi `completion` handler khi có lỗi xảy ra (dẫn đến app treo loading mãi mãi).
* Dễ tạo ra Retain Cycle do capture `self` trong closure (`[weak self]`).


* **Swift Concurrency:**
* Sử dụng cơ chế `try/catch` tự nhiên của Swift. Nếu quên xử lý lỗi, compiler sẽ báo lỗi ngay.
* Giảm thiểu việc dùng `[weak self]` nếu task nằm trong lifecycle của structured concurrency.



---

### 4. Structured Concurrency (Tính cấu trúc)

* **GCD: Unstructured (Phi cấu trúc)**
* Khi bạn `DispatchQueue.global().async`, bạn "bắn và quên" (fire and forget).
* Nếu người dùng thoát màn hình, task đó vẫn chạy ngầm, ăn pin và data. Muốn cancel phải dùng `DispatchWorkItem` rất thủ công và phức tạp.


* **Swift Concurrency: Structured**
* Có mối quan hệ cha-con.
* **Automatic Cancellation Propagation:** Khi task cha bị hủy (ví dụ ViewModel bị deinit), tất cả các task con (đang download, đang parse json) sẽ tự động nhận tín hiệu hủy để dừng lại.



---

### 5. Data Race & Synchronization

* **GCD:**
* Bạn phải tự quản lý việc truy cập data bằng `DispatchQueue` (serial queue) hoặc `NSLock`.
* Rất dễ quên dispatch code UI về `MainQueue` -> Crash.


* **Swift Concurrency:**
* Dùng **Actors** để bảo vệ trạng thái thay đổi (mutable state). Actor đảm bảo tại một thời điểm chỉ có 1 task được truy cập vào dữ liệu của nó (Tương tự Serial Queue nhưng cao cấp hơn).
* Dùng `@MainActor` để compiler đảm bảo code UI luôn chạy trên Main Thread (Compile-time check).



---

### Bảng tóm tắt (Cheat Sheet)

| Đặc điểm | GCD (Grand Central Dispatch) | Swift Concurrency (Async/Await) |
| --- | --- | --- |
| **Cơ chế Thread** | Tạo thêm thread khi bị block (Thread Explosion). | Tái sử dụng thread (Cooperative Pool). |
| **Hành vi khi chờ** | **Block** thread hiện tại. | **Suspend** (treo) function, nhả thread. |
| **Cú pháp** | Closures, Completion Handlers. | `async`, `await`. |
| **Xử lý lỗi** | `Result` type, thủ công. | `try`, `catch`, `throws`. |
| **Quản lý hủy (Cancel)** | Thủ công (`DispatchWorkItem`). | Tự động lan truyền (Structured Concurrency). |
| **Tránh Data Race** | Serial Queue, Locks. | **Actors**. |
| **Tích hợp UI** | `DispatchQueue.main.async`. | `@MainActor`. |

### Khi nào Senior Dev vẫn dùng GCD?

Async/await không thay thế 100% GCD. Bạn vẫn cần GCD trong các trường hợp ngách:

1. **DispatchSource:** Để monitor file system thay đổi, hoặc tạo timer chính xác cao.
2. **Synchronous Execution:** Khi bạn *bắt buộc* phải chạy đồng bộ một việc gì đó trên một queue cụ thể (ví dụ: tích hợp với thư viện C/C++ cũ).
3. **Specific Target Queue:** Khi bạn cần control chính xác task chạy trên queue nào với QoS cụ thể mà Actor chưa đáp ứng đủ linh hoạt.

**Kết luận:**
Chuyển sang Swift Concurrency không chỉ là để code đẹp hơn, mà là để app **ít crash hơn** (nhờ compile-time check) và **hiệu năng tốt hơn** (nhờ quản lý thread thông minh).
