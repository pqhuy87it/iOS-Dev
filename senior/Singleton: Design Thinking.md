Đây là một câu hỏi **tư duy thiết kế (Design Thinking)**. Đối với một Junior, Singleton là "bảo bối" vì nó tiện lợi (gọi ở đâu cũng được). Nhưng đối với Senior, Singleton giống như "con dao hai lưỡi": dùng đúng thì sắc bén, dùng sai thì đứt tay (khó bảo trì, khó test).

Dưới đây là phân tích toàn diện:

---

### 1. Bản chất của Singleton

**Định nghĩa:** Singleton là một Design Pattern đảm bảo rằng một class **chỉ có duy nhất một instance** (thể hiện) tồn tại trong suốt vòng đời của ứng dụng và cung cấp một **điểm truy cập toàn cục** (global access point) đến instance đó.

**Cú pháp chuẩn trong Swift:**
Để tạo một Singleton đúng nghĩa, bạn cần 2 yếu tố: `static let` và `private init`.

```swift
class NetworkManager {
    // 1. Static constant: Đảm bảo chỉ khởi tạo 1 lần (Lazy load & Thread-safe by default in Swift)
    static let shared = NetworkManager()
    
    // 2. Private Init: QUAN TRỌNG NHẤT
    // Ngăn chặn người khác tạo instance mới: let manager = NetworkManager() -> Lỗi
    private init() {} 
    
    func fetchData() { ... }
}

// Cách dùng:
NetworkManager.shared.fetchData()

```

---

### 2. Tại sao nó bị coi là "Anti-pattern"? (Góc nhìn Senior)

Nhiều chuyên gia gọi Singleton là "Anti-pattern" hoặc "Global State được ngụy trang" vì 3 lý do chí mạng sau:

#### A. Sự phụ thuộc ẩn giấu (Hidden Dependencies / Tight Coupling)

Đây là kẻ thù của Clean Code.

* **Ví dụ:** Bạn có class `LoginViewController`.
* Nếu bạn nhìn vào hàm khởi tạo: `init()`, bạn thấy nó không cần tham số gì cả. Bạn nghĩ class này độc lập.
* Nhưng bên trong hàm `viewDidLoad`, nó lại gọi `AuthService.shared.login()`.


* **Hậu quả:** Class `LoginViewController` đã bị dính chặt (coupled) với `AuthService`. Bạn không thể bóc tách `LoginViewController` sang dự án khác mà không mang theo `AuthService`. API của class nói dối về những gì nó cần.

#### B. Ác mộng khi viết Unit Test (Testing Nightmare)

Đây là lý do lớn nhất khiến Senior ghét Singleton dùng bừa bãi.

* **Vấn đề:** Singleton sống dai dẳng suốt vòng đời App. Trạng thái (State) của nó được giữ nguyên từ Test A sang Test B.
* **Kịch bản lỗi:**
* Test A: Login thành công, `UserSession.shared.isLoggedIn = true`.
* Test B: Test màn hình yêu cầu chưa login. Nhưng vì Test A đã set `true` và Singleton không bị hủy, Test B chạy sai (Flaky Test).


* **Khó Mock:** Làm sao bạn thay thế `NetworkManager.shared` bằng một `MockNetworkManager` để test khi không có mạng? Bạn không thể thay đổi biến `static let`.

#### C. Vấn đề Đa luồng (Concurrency Issues)

* Singleton là tài nguyên chia sẻ (Shared Resource). Nếu Thread A đang đọc dữ liệu, Thread B nhảy vào ghi dữ liệu -> **Race Condition** -> Crash hoặc sai lệch data. Bạn buộc phải xử lý khóa (Locking) hoặc dùng Queue/Actor rất cẩn thận.

---

### 3. Khi nào việc sử dụng Singleton là Chấp nhận được?

Không phải lúc nào Singleton cũng xấu. Apple dùng nó đầy rẫy (`URLSession.shared`, `UserDefaults.standard`, `FileManager.default`).

Việc sử dụng Singleton là hợp lý khi thỏa mãn các tiêu chí:

#### Trường hợp 1: Tài nguyên thực sự là Duy nhất và Toàn cục

Những thứ gắn liền với môi trường hệ thống hoặc phần cứng mà về bản chất chỉ có một.

* **Ví dụ:** `Logger` (Hệ thống ghi log), `Analytics` (Gửi sự kiện người dùng), `AudioSession` (Quản lý loa đài của thiết bị).

#### Trường hợp 2: Trạng thái Immutable (Bất biến)

Nếu Singleton chỉ cung cấp các hàm tiện ích (Helper/Utility) và không lưu trữ trạng thái thay đổi (`var`), thì nó vô hại. Nó không gây ra lỗi side-effect khi test.

#### Trường hợp 3: "Singleton Plus" Pattern (Khuyên dùng)

Thay vì ép buộc dùng Singleton (True Singleton), hãy dùng nó như một **phiên bản mặc định (Default Instance)** nhưng vẫn cho phép tạo instance mới.

**Cách làm của Apple (`URLSession`):**

* Bạn có thể dùng `URLSession.shared` cho nhanh.
* Nhưng bạn VẪN có thể `init(configuration: ...)` để tạo một session riêng biệt cho việc test hoặc config đặc thù.

```swift
class Database {
    // Shared instance cho tiện dụng
    static let default = Database()
    
    // KHÔNG dùng private init. Cho phép tạo mới nếu cần.
    init() {} 
}

// Lúc dùng bình thường:
let db = Database.default

// Lúc test:
let testDB = Database() // Instance mới tinh, không sợ dính state cũ

```

---

### 4. Giải pháp thay thế của Senior: Dependency Injection (DI)

Để giữ lại sự tiện lợi của 1 instance duy nhất mà không dính lỗi "Anti-pattern", Senior Developer sử dụng **Dependency Injection**.

Thay vì gọi trực tiếp:

```swift
class ProfileViewModel {
    func load() {
        // SAI: Gọi trực tiếp Singleton (Tight Coupling)
        APIService.shared.getUser() 
    }
}

```

Hãy tiêm (Inject) nó vào:

```swift
class ProfileViewModel {
    let apiService: APIServiceProtocol // Dùng Protocol để dễ Mock
    
    // Dependency Injection qua Init
    init(apiService: APIServiceProtocol = APIService.shared) {
        self.apiService = apiService
    }
    
    func load() {
        // ĐÚNG: Gọi qua biến local
        self.apiService.getUser()
    }
}

```

**Lợi ích:**

1. **Code thật:** Bạn vẫn dùng `ProfileViewModel()` (nó tự lấy default là Singleton).
2. **Code test:** Bạn dùng `ProfileViewModel(apiService: MockAPIService())`. -> Giải quyết hoàn toàn vấn đề Testing.

### Tóm tắt câu trả lời phỏng vấn:

> *"Singleton đảm bảo tính duy nhất và truy cập toàn cục, nhưng nó thường bị coi là Anti-pattern vì gây ra **phụ thuộc ẩn (Hidden Dependencies)** và **khó viết Unit Test** do trạng thái toàn cục (Global State) khó reset.
> Tuy nhiên, nó vẫn chấp nhận được khi dùng cho các tài nguyên hệ thống (Logger, Analytics) hoặc khi áp dụng mô hình **'Singleton Plus'** (cung cấp shared instance nhưng không cấm init mới).
> Là một Senior, tôi ưu tiên sử dụng **Dependency Injection**: Tiêm Singleton vào class thông qua hàm khởi tạo (`init`) thay vì gọi trực tiếp `Singleton.shared` bên trong hàm. Điều này giữ được sự tiện lợi nhưng vẫn đảm bảo khả năng Test (Testability) và lỏng lẻo (Loose Coupling)."*
