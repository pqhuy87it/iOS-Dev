https://developer.apple.com/videos/play/wwdc2026/275/

Video **"Code-along: Add persistence with SwiftData" (WWDC26, session 275)**. Đây là một code-along thực hành: thêm khả năng lưu trữ dữ liệu (persistence) bằng SwiftData vào một app mẫu có sẵn tên **Wishlist** (app lên kế hoạch du lịch).

---

## Tóm tắt các mục chính

1. **Introduction (0:00)** — Giới thiệu app mẫu Wishlist và 3 bước áp dụng SwiftData: xác định state cần lưu, định nghĩa schemas, định nghĩa quan hệ giữa các model.
2. **Identify relevant state (1:05)** — Xác định các kiểu dữ liệu/biến trong app (trip collections, trạng thái goal, DataSource) sẽ trở thành SwiftData models kết nối qua `ModelContext`.
3. **Define your schemas (3:17)** — Chuyển `Activity`, `Trip`, `Goal` thành `@Model`, xử lý property observers, refactor enum `Goal` thành class hierarchy dùng inheritance, inline thumbnail data.
4. **Define model relationships (9:41)** — Khai báo quan hệ to-many bằng `@Relationship`, gỡ bỏ helper cũ (`DataSource`, `TripEditModel`), gắn `.modelContainer`.
5. **Update the view layer (13:33)** — Thay DataSource trong environment bằng `@Query` + `FetchDescriptor`, xử lý autosave, hiển thị lỗi runtime, và bật lại property observer bằng API mới `withContinuousObservation`.
6. **Next steps (21:47)** — Đúc kết: thiết kế schema hợp lý, cân bằng bộ nhớ/đĩa bằng query có mục tiêu, và tính đến khả năng tương tác & mở rộng.

---

## Chi tiết từng mục

### 1. Introduction — Tổng quan
App mẫu **Wishlist** hiện đang giữ toàn bộ dữ liệu trong bộ nhớ (in-memory), nghĩa là dữ liệu mất khi đóng app. Mục tiêu là thêm persistence để lưu xuống đĩa. Session vạch ra quy trình 3 bước chuẩn khi adopt SwiftData:
- Xác định state nào cần được lưu bền vững.
- Định nghĩa schema (các model).
- Định nghĩa quan hệ giữa các model.

Đây là code-along nên bạn có thể tải sample project ("Wishlist: Planning travel in a SwiftUI app") và code theo.

### 2. Identify relevant state — Xác định state cần lưu
Bước tư duy trước khi code: rà soát app tìm những dữ liệu cần tồn tại lâu dài. Trong Wishlist đó là:
- **Trip collections** (bộ sưu tập chuyến đi — theo mùa: spring, summer, fall, winter).
- **Goal statuses** (trạng thái mục tiêu đã đạt/chưa đạt).
- Một object trung tâm gọi là **`DataSource`** đang giữ dữ liệu in-memory — object này sẽ được thay thế.

Ý tưởng cốt lõi: những gì đang là biến/`@State`/object thủ công sẽ chuyển thành **SwiftData models**, được quản lý qua **`ModelContext`** (thay vì tự quản lý mảng/dictionary).

### 3. Define your schemas — Định nghĩa schema

**Chuyển class thường thành `@Model` (3:39)**
```swift
import SwiftData

@Model
class Activity {
    var name: String
    var isComplete: Bool = false
    var dateCreated = Date.now
    var dateEdited = Date.now
}
```
Chỉ cần thêm macro `@Model`. SwiftData **tự động sinh conformance với `Observable`**, nên view sẽ tự cập nhật khi dữ liệu đổi — không cần `@Observable` thủ công.

**Xử lý property observers**
Vấn đề: khi dùng `@Model`, các property observer thủ công (như `didSet` để cập nhật `dateEdited`) không hoạt động như trước, vì macro biến các thuộc tính thành computed properties truy cập vào persistent store. Session giải quyết chuyện này ở mục 5 bằng `withContinuousObservation`.

**Refactor enum thành class hierarchy (inheritance)**
`Goal` ban đầu là enum, nhưng để lưu bền và mở rộng, nó được refactor thành **class cha `Goal` với các subclass `TripGoal` và `ActivityGoal`** — tận dụng tính năng **inheritance trong SwiftData** (giới thiệu từ WWDC25). Điều này cho phép lưu các loại goal khác nhau trong cùng một truy vấn.

**Codable cho enum lồng trong model (6:06)**
Các kiểu như `TripCollection` cần conform `Codable` (và `RawRepresentable`) để SwiftData lưu được như thuộc tính:
```swift
enum TripCollection: String, CaseIterable, RawRepresentable, Codable {
    case springEscapes, summerVibes, fallGetaways, winterRetreats
}
```

**Inline thumbnail data** — Dữ liệu ảnh thumbnail nhỏ được lưu inline (`var thumbnailData: Data?`) ngay trong model thay vì tách file riêng, để truy cập nhanh.

### 4. Define model relationships — Định nghĩa quan hệ

**Quan hệ to-many với `@Relationship` (10:32)**
```swift
@Model
class Trip {
    var name: String
    var collection: TripCollection
    var photo: TripImage
    var thumbnailData: Data?

    @Relationship(deleteRule: .cascade, inverse: \Activity.trip)
    var activities: [Activity] = []

    private(set) var creationDate = Date.now
    var subtitle: String?
    var isComplete: Bool = false
}
```
Điểm quan trọng:
- Một `Trip` có nhiều `Activity` (to-many).
- `deleteRule: .cascade` — khi xóa Trip thì tự động xóa luôn các Activity con (tránh dữ liệu mồ côi).
- `inverse: \Activity.trip` — khai báo quan hệ ngược, giúp SwiftData tự đồng bộ hai chiều (activity biết nó thuộc trip nào).

**Gỡ bỏ helper cũ**
Sau khi có SwiftData quản lý dữ liệu, các lớp trung gian như **`DataSource`** và **`TripEditModel`** trở nên dư thừa → xóa đi. Đây là lợi ích lớn: giảm boilerplate quản lý state thủ công.

**Gắn `modelContainer` (13:21)**
```swift
@main
struct WishlistApp: App {
    let container: ModelContainer = {
        do {
            let modelContainer = try ModelContainer(
                for: Trip.self, Activity.self, TripImage.self,
                    Goal.self, TripGoal.self, ActivityGoal.self)
            try SampleData.seedIfNeeded(in: modelContainer.mainContext)
            return modelContainer
        } catch {
            fatalError("Could not create model container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup { ContentView() }
            .modelContainer(container)   // <- kết nối container vào toàn app
    }
}
```
`ModelContainer` khai báo tất cả model types; `.modelContainer(container)` bơm context vào environment để mọi view con dùng được `@Query`. Ở đây cũng seed dữ liệu mẫu lần đầu chạy.

### 5. Update the view layer — Cập nhật tầng view

**Thay DataSource bằng `@Query` (16:27)**
Trước đây view đọc dữ liệu từ `DataSource` trong environment; giờ dùng `@Query` với predicate có mục tiêu:
```swift
@Query(filter: #Predicate<Goal> { $0.isAchieved },
       sort: \Goal.dateAchieved, order: .reverse)
private var achievedGoals: [Goal]

@Query(filter: #Predicate<Goal> { !$0.isAchieved },
       sort: \Goal.sortOrder)
private var upcomingGoals: [Goal]
```
`@Query` tự động fetch từ store, tự cập nhật khi dữ liệu đổi, và có thể **filter + sort** ngay trong khai báo.

**Giới hạn kết quả với `FetchDescriptor` (16:49)**
Để tiết kiệm bộ nhớ, dùng `fetchLimit`:
```swift
@Query(FetchDescriptor<Trip>(
    sortBy: [SortDescriptor(\Trip.creationDate, order: .reverse)],
    fetchLimit: 5))
private var trips: [Trip]
```
Chỉ lấy 5 trip gần nhất thay vì tải toàn bộ.

**Query động trong `init` (17:26)**
Khi tiêu chí phụ thuộc tham số truyền vào view, khởi tạo query trong initializer bằng cách gán property wrapper qua `_trips`:
```swift
init(tripCollection: TripCollection, ...) {
    _trips = Query(filter: #Predicate<Trip> { $0.collection == tripCollection },
                   sort: \Trip.name)
    // ...
}
```

**Search động (18:13)**
Ví dụ thực tế: query thay đổi theo `searchText`. Khi rỗng thì hiện vài trip gần nhất và không hiện activity; khi có text thì filter theo `localizedStandardContains`:
```swift
let tripSearchPredicate = #Predicate<Trip> { $0.name.localizedStandardContains(searchText) }
_trips = Query(filter: tripSearchPredicate, sort: \Trip.name)
```

**Autosave** — SwiftData tự động lưu thay đổi (autosave) nên không cần gọi save thủ công trong luồng thông thường.

**Hiển thị lỗi runtime (19:42)**
Các thao tác có thể ném lỗi (ví dụ cập nhật goal) được bắt và surface lên UI qua view modifier `.alert(error:)`:
```swift
.onDisappear {
    do { try updateGoalAchievements() }
    catch { updateError = error; reportError(error) }
}
.alert(error: $updateError) { /* tùy biến hiển thị lỗi */ }
```

**`withContinuousObservation` — bật lại property observer (21:04)**
Đây là API **mới** để giải quyết vấn đề `didSet` không dùng được với `@Model`. Nó cho phép quan sát liên tục các thuộc tính và chạy side-effect khi chúng đổi:
```swift
activity.token = withContinuousObservation(options: .didSet) { event in
    _ = activity.name
    _ = activity.isComplete

    if event.matches(\Activity.name) {
        activity.dateEdited = .now
    }
    if event.matches(\Activity.isComplete) {
        activity.dateEdited = .now
        activity.trip?.isComplete =
            activity.trip?.activities.isEmpty == false &&
            activity.trip?.activities.allSatisfy { $0.isComplete } == true
    }
}
```
Ở đây: khi `name` đổi → cập nhật `dateEdited`; khi `isComplete` đổi → cập nhật `dateEdited` **và** tính lại xem cả trip đã hoàn thành chưa (tất cả activity đều complete). `event.matches(_:)` cho biết chính xác thuộc tính nào vừa thay đổi. `token` phải được giữ lại để observation còn sống.

### 6. Next steps — Đúc kết
- **Thiết kế schema khớp với mô hình dữ liệu thực tế** của app.
- **Cân bằng bộ nhớ và đĩa** bằng các query có mục tiêu (predicate + `fetchLimit`) thay vì tải hết dữ liệu.
- **Tính đến khả năng tương tác và mở rộng** khi app phát triển (inheritance, relationships, Codable).
- Xem tiếp video liên quan: *"What's new in SwiftData" (274)* và *"SwiftData: Dive into inheritance and schema migration" (WWDC25, 291)*.

---

Lưu ý: mình tổng hợp từ chapter summaries và toàn bộ code samples chính thức của session (không mở được transcript đầy đủ vì file video quá lớn). Nếu bạn muốn mình đào sâu một điểm cụ thể — ví dụ cơ chế `withContinuousObservation` so với `didSet` cũ, hay chiến lược inheritance cho `Goal` — cho mình biết nhé.
