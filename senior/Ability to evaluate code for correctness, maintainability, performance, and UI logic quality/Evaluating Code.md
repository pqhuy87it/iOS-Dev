# Evaluating Code as a Senior iOS Developer

Đây là một trong những năng lực cốt lõi phân biệt senior với junior — không chỉ *viết* code mà còn phải *đánh giá* code một cách có hệ thống. Mình sẽ tách từng khía cạnh ra phân tích.

---

## 1. Correctness — Code có đúng không?

Đây là tầng cơ bản nhất: code có làm đúng những gì nó cần làm không?

**Một senior sẽ kiểm tra:**

**Logic nghiệp vụ** — code có cover đúng các business rules không? Ví dụ một hàm tính giá có tính đúng discount, tax, edge case như giá = 0 hay số âm không?

**Edge cases & boundary conditions** — `nil`, empty array, index out of bounds, concurrent access, race conditions. Ví dụ:

```swift
// Junior thường viết:
func getUser(at index: Int) -> User {
    return users[index] // 💥 crash nếu index ngoài range
}

// Senior sẽ hỏi: "index ngoài range thì sao?"
func getUser(at index: Int) -> User? {
    guard users.indices.contains(index) else { return nil }
    return users[index]
}
```

**Thread safety** — khi property được access từ nhiều thread, senior sẽ ngay lập tức nhìn ra potential data race:

```swift
// Đỏ flag ngay:
var cache: [String: Data] = [:]  // shared mutable state, không sync

// Senior expect:
private let queue = DispatchQueue(label: "cache.sync", attributes: .concurrent)
func read(_ key: String) -> Data? {
    queue.sync { cache[key] }
}
func write(_ key: String, _ value: Data) {
    queue.async(flags: .barrier) { self.cache[key] = value }
}
```

**State consistency** — sau mỗi mutation, object có ở trạng thái hợp lệ không? Ví dụ: sau khi xoá item khỏi data source, `tableView` đã được update chưa, hay sẽ crash vì inconsistency giữa data và UI?

---

## 2. Maintainability — Code có dễ sống chung lâu dài không?

Senior phải đánh giá code dưới góc nhìn "6 tháng sau ai đọc cũng hiểu, ai sửa cũng an toàn."

**Readability** — naming có rõ ý không? Một senior sẽ reject ngay:

```swift
// Tệ: đọc xong không biết làm gì
func process(_ d: [String: Any], _ f: Bool) -> Int

// Tốt: self-documenting
func calculateShippingCost(for order: OrderDetails, applyDiscount: Bool) -> Decimal
```

**Single Responsibility** — một class/function có đang làm quá nhiều việc không? Nếu một `ViewController` vừa gọi API, vừa parse JSON, vừa format date, vừa manage table view — đó là code smell. Senior sẽ đề xuất tách thành Service, Mapper, ViewModel riêng.

**Coupling & Dependency** — code có phụ thuộc cứng vào concrete type không? Senior sẽ hỏi: "nếu mai đổi từ Alamofire sang URLSession, phải sửa bao nhiêu file?"

```swift
// Tight coupling — sửa 1 chỗ, vỡ 20 chỗ
class ProfileViewModel {
    func load() {
        Alamofire.request("/profile")...  // gắn chặt vào Alamofire
    }
}

// Loose coupling — đổi implementation không ảnh hưởng ViewModel
protocol NetworkService {
    func fetch(_ endpoint: Endpoint) async throws -> Data
}
class ProfileViewModel {
    private let network: NetworkService
    init(network: NetworkService) { self.network = network }
}
```

**Testability** — code có viết unit test được không? Nếu phải mock cả `UIApplication.shared` để test một function, đó là dấu hiệu thiết kế sai.

---

## 3. Performance — Code có chạy hiệu quả không?

Trên iOS, performance trực tiếp ảnh hưởng UX. Senior phải nhìn ra bottleneck tiềm ẩn.

**Main thread blocking** — bất kỳ heavy work nào trên main thread đều là red flag:

```swift
// 🚨 Blocking main thread — UI freeze
func viewDidLoad() {
    let image = downsampleLargeImage(url: fileURL) // CPU-heavy
    imageView.image = image
}

// ✅ Senior expect:
func viewDidLoad() {
    Task {
        let image = await Task.detached {
            downsampleLargeImage(url: fileURL)
        }.value
        imageView.image = image
    }
}
```

**Memory** — senior sẽ kiểm tra retain cycle, đặc biệt trong closures:

```swift
// Leak: self giữ timer, timer giữ closure, closure giữ self
timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
    self.updateUI()  // strong capture → retain cycle
}

// Fix:
timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
    self?.updateUI()
}
```

**Algorithm complexity** — nếu thấy `O(n²)` trong một list có thể lên hàng nghìn item, senior sẽ flag ngay. Ví dụ: dùng `contains()` lặp lại trong vòng `for` → nên đổi sang `Set` để lookup `O(1)`.

**Cell reuse & diffing** — trong `UITableView`/`UICollectionView`, senior sẽ kiểm tra xem có dùng `reloadData()` toàn bộ thay vì diffable data source hoặc `performBatchUpdates` không, vì reloadData gây mất animation và render lại toàn bộ cells.

---

## 4. UI Logic Quality — Logic điều khiển UI có sạch không?

Đây là phần đặc thù iOS, nơi ranh giới giữa "chạy được" và "chạy đúng + dễ maintain" rất mỏng.

**State management** — UI state có được quản lý tập trung không, hay rải rác qua nhiều biến boolean tạo ra "state explosion"?

```swift
// 💀 State explosion — 2³ = 8 trạng thái có thể, nhiều cái vô nghĩa
var isLoading = false
var hasError = false
var hasData = false

// ✅ Senior expect: single source of truth
enum ViewState {
    case idle
    case loading
    case loaded(items: [Item])
    case error(Error)
}
var state: ViewState = .idle {
    didSet { render(state) }
}
```

**Separation of concerns** — logic quyết định UI nên nằm ở ViewModel, không phải ở View:

```swift
// Tệ: business logic trong View
func cellForRow(...) {
    if user.subscriptionDate > Date() && user.plan == .premium {
        badge.isHidden = false  // logic rải trong cell
    }
}

// Tốt: View chỉ bind, logic nằm ở ViewModel
// ViewModel
var shouldShowPremiumBadge: Bool {
    user.isActivePremium
}
// Cell
badge.isHidden = !viewModel.shouldShowPremiumBadge
```

**Lifecycle awareness** — senior sẽ kiểm tra xem code có xử lý đúng các lifecycle events không: `viewWillAppear` vs `viewDidLoad`, `prepareForReuse` trong cell, cancel network request khi view biến mất, unsubscribe khi `deinit`.

**Reactive binding consistency** — nếu dùng Combine hoặc async/await, senior sẽ kiểm tra xem có memory leak trong subscriptions không, có cancel đúng lúc không, và data flow có one-directional hay bị lẫn lộn.

---

## Tổng kết

Bốn trụ cột này không tách rời mà liên kết chặt với nhau. Code sai logic (correctness) thì performance vô nghĩa. Code đúng nhưng không maintain được thì sẽ sai dần theo thời gian. Code nhanh nhưng UI state hỗn loạn thì user vẫn thấy bug. Khả năng đánh giá đồng thời cả 4 khía cạnh trong một code review — đó là điều tạo nên giá trị của một senior iOS developer.
