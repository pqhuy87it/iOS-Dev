Để giải thích **Multi-threading (Đa luồng)** trong Swift một cách tường tận, chúng ta cần đi từ bản chất vấn đề (Tại sao cần nó?) đến các công cụ giải quyết (GCD và Swift Concurrency).

Hãy tưởng tượng App của bạn như một **Nhà hàng**:

* **Main Thread (Luồng chính):** Là người phục vụ (Waiter) duy nhất tại quầy lễ tân. Nhiệm vụ là nhận order và cười với khách (Cập nhật UI).
* **Background Threads (Luồng phụ):** Là các đầu bếp trong bếp. Nhiệm vụ là nấu ăn (Tải ảnh, tính toán, lưu database).

Nếu người phục vụ (Main Thread) chạy vào bếp để nấu món bò kho mất 30 phút, thì quầy lễ tân sẽ trống -> **App bị đơ (Freezing)** -> Khách hàng bỏ đi (User xóa app).

Multi-threading chính là việc thuê thêm đầu bếp để người phục vụ luôn rảnh tay tiếp khách.

---

### 1. Kiến trúc Multi-threading trong Swift

Swift cung cấp 2 kỷ nguyên công nghệ để xử lý đa luồng:

#### A. Kỷ nguyên cũ: Grand Central Dispatch (GCD)

Đây là công nghệ nền tảng C-based, dùng **Queue (Hàng đợi)** để quản lý luồng.

**Cơ chế:** Bạn không quản lý Thread trực tiếp (rất khó), bạn chỉ cần ném việc vào các **Queue**. Hệ điều hành sẽ tự quyết định xem có bao nhiêu thread được tạo ra để xử lý các Queue đó.

Có 2 loại Queue chính:

1. **Serial Queue (Tuần tự):** Việc A xong -> Việc B mới được chạy. (Giống xếp hàng qua cửa an ninh).
* *Mặc định:* `Main Queue` là Serial.


2. **Concurrent Queue (Song song):** Việc A chạy, Việc B cũng chạy cùng lúc luôn, không ai chờ ai. (Giống xe chạy trên đường cao tốc nhiều làn).

**Phân biệt Sync (Đồng bộ) và Async (Bất đồng bộ):**

* **Async:** "Anh cứ làm đi, tôi đi làm việc khác, khi nào xong báo tôi". (Không chặn luồng hiện tại).
* **Sync:** "Tôi đứng đây chờ anh làm xong mới đi". (Chặn đứng luồng hiện tại - **Rất nguy hiểm nếu dùng trên Main Thread**).

#### B. Kỷ nguyên mới: Swift Concurrency (Async/Await) - Từ Swift 5.5

GCD rất mạnh nhưng dễ gây ra "Callback Hell" (các closure lồng nhau rối rắm) và khó xử lý lỗi. Swift Concurrency ra đời để code chạy bất đồng bộ trông giống như code tuần tự bình thường.

---

### 2. Chi tiết cách sử dụng (Code thực chiến)

#### Cách 1: Sử dụng GCD (Vẫn rất phổ biến)

```swift
// 1. Chuyển sang luồng phụ để làm việc nặng
DispatchQueue.global(qos: .userInitiated).async {
    // Code chạy ở Background (Vào bếp nấu ăn)
    let image = downloadImageLarge()
    let filteredImage = applyFilter(image)
    
    // 2. Quay lại luồng chính để cập nhật giao diện
    DispatchQueue.main.async {
        // Code chạy ở Main Thread (Mang món ăn ra cho khách)
        self.imageView.image = filteredImage
    }
}

```

* **Lưu ý Senior:** Tuyệt đối không update UI ở `DispatchQueue.global()`. UIKit không an toàn đa luồng (Non-thread-safe), update sai luồng sẽ gây crash hoặc lỗi hiển thị dị dạng.

#### Cách 2: Sử dụng Async/Await (Hiện đại)

```swift
// Khai báo hàm này là bất đồng bộ (async)
func processImage() async throws -> UIImage {
    let image = try await downloadImageLarge() // Tạm dừng ở đây, không chặn Main Thread
    return applyFilter(image)
}

// Gọi hàm
Task {
    // Tự động nhảy sang background để chạy processImage
    let result = try await processImage()
    
    // Tự động quay về Main Actor (Main Thread) để update UI
    self.imageView.image = result
}

```

---

### 3. Các vấn đề chí mạng trong Multi-threading

Là Senior Developer, bạn được trả lương cao để giải quyết 3 vấn đề này:

#### A. Race Condition (Cuộc đua dữ liệu)

Xảy ra khi 2 luồng cùng truy cập và sửa đổi một biến cùng lúc.

* *Ví dụ:* Thread A đọc số dư là 10. Thread B cũng đọc là 10. Cả hai cùng cộng 1 và ghi lại. Kết quả là 11 (đáng lẽ phải là 12).
* *Giải pháp:* Sử dụng `NSLock`, `Serial Queue`, hoặc **Actor** (trong Swift mới).

#### B. Deadlock (Khóa chết)

Xảy ra khi Thread A chờ Thread B xong, nhưng Thread B lại đang chờ Thread A xong. Cả 2 đứng nhìn nhau mãi mãi -> App treo vĩnh viễn.

* *Lỗi kinh điển:* Gọi `DispatchQueue.main.sync` ngay bên trong Main Thread.
```swift
override func viewDidLoad() {
    super.viewDidLoad()
    // DEADLOCK NGAY LẬP TỨC!
    // Main thread đang bận chạy viewDidLoad, lại bị bắt đứng chờ block này chạy.
    DispatchQueue.main.sync { 
        print("Hello") 
    }
}

```



#### C. Thread Explosion (Bùng nổ luồng)

Nếu bạn tạo quá nhiều Concurrent Queue và block chúng (sleep), hệ điều hành sẽ tạo ra hàng trăm thread mới để bù đắp. Việc này ngốn sạch RAM và CPU cho việc chuyển đổi ngữ cảnh (Context Switching).

* *Giải pháp:* Sử dụng Swift Concurrency (`Task`). Nó sử dụng một "Pool" cố định số lượng thread (thường bằng số nhân CPU) để tái sử dụng, tránh bùng nổ.

---

### Tóm tắt cho người phỏng vấn:

> *"Trong Swift, Multi-threading là kỹ thuật chuyển các tác vụ nặng (Networking, Image Processing, Database) ra khỏi **Main Thread** để giữ cho giao diện mượt mà (60fps).
> Tôi thường sử dụng 2 công cụ chính:
> 1. **GCD (`DispatchQueue`):** Cho các dự án cũ hoặc các tác vụ đơn giản (`main.async`, `global().async`).
> 2. **Swift Concurrency (`async/await`, `Actor`):** Cho các dự án mới vì nó giúp code dễ đọc hơn (tránh Callback Hell), an toàn hơn (tránh Race Condition bằng Actor) và quản lý hiệu năng hệ thống tốt hơn (tránh Thread Explosion)."*
> 
>
