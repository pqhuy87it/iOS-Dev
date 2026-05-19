Đối với vị trí **Senior iOS Developer**, cuộc phỏng vấn không chỉ dừng lại ở việc kiểm tra cú pháp hay cách sử dụng API. Trọng tâm sẽ chuyển sang khả năng **giải quyết vấn đề, tư duy kiến trúc (Architecture), hiệu năng (Performance) và khả năng ra quyết định kỹ thuật (Trade-offs)**.

Dưới đây là bộ câu hỏi phỏng vấn Senior iOS Developer được phân loại theo từng chủ đề chuyên sâu:

---

### 1. Kiến thức sâu về ngôn ngữ Swift (Deep Swift Knowledge)

Ở mức độ Senior, ứng viên cần hiểu rõ "dưới nắp ca-pô" (under the hood) mọi thứ hoạt động như thế nào.

* **Memory Management:**
* Hãy giải thích cơ chế **ARC (Automatic Reference Counting)**. Nó khác gì với Garbage Collection?
* Khi nào thì reference cycle xảy ra? Làm thế nào để debug và fix nó? (Kỳ vọng: Nhắc đến Xcode Memory Graph, Instruments Leaks).
* Sự khác biệt giữa `unowned` và `weak`? Khi nào bạn dám chắc chắn dùng `unowned`?


* **Swift Types:**
* Phân tích sự khác biệt giữa `Struct` (Value Type) và `Class` (Reference Type) về mặt lưu trữ bộ nhớ (Stack vs Heap) và tốc độ dispatch (Static vs Dynamic dispatch).
* **Generic** và **Protocol Oriented Programming (POP)**: Làm thế nào để sử dụng `associatedtype` trong Protocol? `some` keyword và `any` keyword khác nhau như thế nào trong Swift 5.7+?


* **Concurrency:**
* So sánh **GCD (Grand Central Dispatch)** và **Swift Concurrency (async/await)**.
* **Actors** là gì? Làm thế nào nó giải quyết vấn đề Data Race?
* Hãy giải thích về `MainActor` và khi nào cần dùng `Task.detached`.



### 2. Kiến trúc & Design Patterns (Architecture)

Đây là phần quan trọng nhất để phân loại Senior.

* **Mô hình kiến trúc:**
* Bạn thường sử dụng mô hình nào (MVC, MVVM, MVP, VIPER, TCA)? Tại sao bạn chọn nó cho dự án đó?
* **MVVM:** Làm thế nào để bind dữ liệu giữa ViewModel và View? (Kỳ vọng: Closure, Delegate, RxSwift, Combine, hoặc ObservableObject).
* **Nhược điểm của MVVM là gì?** (Câu hỏi bẫy: Cần chỉ ra việc Massive ViewModel hoặc boilerplate code).


* **Design Patterns:**
* Hãy kể về việc bạn áp dụng **Dependency Injection (DI)**. Bạn dùng thư viện (Swinject, Resolver) hay tự viết? Lợi ích thực tế là gì?
* Giải thích mô hình **Singleton**. Tại sao nhiều người coi nó là "anti-pattern" và khi nào thì việc sử dụng nó là chấp nhận được?



### 3. User Interface (UIKit & SwiftUI)

* **UIKit (Legacy & Deep dive):**
* Vòng đời (Lifecycle) của một UIViewController và UIView.
* Cơ chế **Auto Layout**: `layoutSubviews`, `setNeedsLayout`, `layoutIfNeeded` khác nhau như thế nào?
* Làm sao để tối ưu hóa FPS khi cuộn một `UITableView` hoặc `UICollectionView` chứa nhiều ảnh và layout phức tạp?


* **SwiftUI (Modern):**
* Sự khác biệt giữa `@State`, `@Binding`, `@ObservedObject`, `@StateObject`, và `@EnvironmentObject`. Khi nào dùng cái nào?
* Làm thế nào để tích hợp (interop) View của UIKit vào SwiftUI và ngược lại?
* Vấn đề về **View Identity** trong SwiftUI: Tại sao `id` trong `ForEach` lại quan trọng?



### 4. Lưu trữ dữ liệu & Networking (Data & Networking)

* **Caching & Offline:**
* Bạn thiết kế cơ chế caching cho ứng dụng như thế nào? (Memory cache vs Disk cache).
* So sánh **Core Data**, **Realm**, và **SQLite**. Khi nào nên dùng Core Data, khi nào chỉ cần `UserDefaults` hoặc File System?


* **Networking:**
* Bạn xử lý **Certificate Pinning** (SSL Pinning) như thế nào để bảo mật app?
* Làm sao để quản lý việc refresh `access_token` khi nó hết hạn trong khi đang có nhiều request chạy song song? (Kỳ vọng: nói về `RequestInterceptor` hoặc hàng đợi request).



### 5. System Design (Thiết kế hệ thống - Quan trọng)

Đây là dạng câu hỏi mở, yêu cầu ứng viên vẽ ra giải pháp tổng thể.

* **Bài toán:** "Hãy thiết kế một ứng dụng xem tin tức (News Feed) giống như Facebook/Twitter."
* *Yêu cầu cần giải quyết:*
* Phân trang (Pagination) API như thế nào?
* Caching ảnh và nội dung bài viết ra sao để đọc offline?
* Xử lý pre-fetching dữ liệu để trải nghiệm mượt mà?
* Database schema sơ bộ?





### 6. Testing, CI/CD & Tooling

* **Testing:**
* Bạn có áp dụng TDD (Test Driven Development) không?
* Sự khác biệt giữa Unit Test, Integration Test và UI Test.
* Làm sao để test một hàm network (bất đồng bộ) mà không gọi API thật? (Kỳ vọng: Mocking, Stubbing, Dependency Injection).


* **CI/CD:**
* Quy trình CI/CD bạn từng xây dựng bao gồm những bước nào? (Linting, Unit Test, Build, Upload TestFlight).
* Kinh nghiệm với **Fastlane**, **Jenkins**, **Bitrise**, hoặc **GitHub Actions**.



### 7. Câu hỏi tình huống (Behavioral & Problem Solving)

* "Hãy kể về một bug khó nhất (nasty bug) mà bạn từng gặp. Bạn đã debug nó như thế nào và bài học rút ra là gì?"
* "Nếu Product Owner yêu cầu một tính năng mà bạn biết chắc chắn sẽ làm giảm hiệu năng app hoặc gây nợ kỹ thuật (tech debt) lớn, bạn sẽ xử lý thế nào?"
* "Bạn làm thế nào để cập nhật công nghệ mới và chia sẻ kiến thức (mentoring) cho các bạn Junior trong team?"

---

### Tiêu chí đánh giá câu trả lời của Senior:

1. **Hiểu bản chất:** Không trả lời máy móc theo định nghĩa, mà giải thích được cơ chế hoạt động.
2. **Biết đánh đổi (Trade-off):** Mọi giải pháp đều có ưu/nhược điểm. Senior phải biết khi nào dùng cái gì (Ví dụ: Không phải lúc nào cũng dùng VIPER vì nó quá cồng kềnh cho app nhỏ).
3. **Tư duy mở rộng (Scalability):** Code viết ra phải dễ bảo trì và mở rộng sau này.

**Bạn có muốn tôi đi sâu vào câu trả lời mẫu cho bất kỳ câu hỏi nào ở trên không?**
