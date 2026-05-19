# State Consistency trong iOS Development

State consistency nghĩa là: **tại bất kỳ thời điểm nào, toàn bộ các thành phần liên quan đều phản ánh cùng một trạng thái dữ liệu**. Khi một mutation xảy ra, nếu có bất kỳ thành phần nào "lệch pha" — crash hoặc bug sẽ xuất hiện.

---

## 1. Vấn đề kinh điển: Data Source vs UITableView/UICollectionView

Đây là nơi state inconsistency xảy ra nhiều nhất trên iOS.

### UIKit yêu cầu gì?

UIKit có một "hợp đồng ngầm": **số lượng và cấu trúc mà `numberOfSections` / `numberOfRowsInSection` trả về phải luôn khớp với data source tại thời điểm UIKit hỏi**. Nếu không → crash ngay với exception nổi tiếng:

```
*** Terminating app due to uncaught exception 'NSInternalInconsistencyException',
reason: 'Invalid update: invalid number of rows in section 0. 
The number of rows contained in an existing section after the update (3) 
must be equal to the number of rows contained in that section before the update (5), 
plus or minus the number of rows inserted or deleted from that section 
(0 inserted, 0 deleted) and plus or minus the number of rows moved 
into or out of that section (0 moved in, 0 moved out).'
```

### Ví dụ crash cơ bản:

```swift
class ChatViewController: UIViewController, UITableViewDataSource {
    var messages: [Message] = []
    
    func deleteMessage(at index: Int) {
        // Bước 1: Xoá khỏi data
        messages.remove(at: index)
        
        // ⚠️ Nếu giữa bước 1 và bước 2, UIKit gọi lại numberOfRowsInSection
        // (ví dụ do layout cycle, scroll, hoặc animation khác đang chạy)
        // → data nói 4 items, nhưng tableView nghĩ vẫn 5 → 💥 CRASH
        
        // Bước 2: Update UI
        tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
    }
}
```

### Sửa đúng cách — đảm bảo atomic update:

```swift
func deleteMessage(at index: Int) {
    // performBatchUpdates đảm bảo data mutation và UI update
    // được UIKit xem như MỘT thao tác atomic
    tableView.performBatchUpdates {
        messages.remove(at: index)
        tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
    } completion: { _ in
        // safe to do post-delete work here
    }
}
```

Bên trong `performBatchUpdates`, UIKit sẽ **defer việc gọi lại data source** cho đến khi block hoàn tất. Nghĩa là data và UI được sync trong cùng một transaction.

---

## 2. Giải pháp hiện đại: DiffableDataSource

Apple giới thiệu `DiffableDataSource` từ iOS 13 để **loại bỏ hoàn toàn lớp bug state inconsistency** này:

```swift
class ChatViewController: UIViewController {
    enum Section { case main }
    
    var dataSource: UITableViewDiffableDataSource<Section, Message>!
    
    func setup() {
        dataSource = UITableViewDiffableDataSource(tableView: tableView) { 
            tableView, indexPath, message in
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "Cell", for: indexPath
            ) as! MessageCell
            cell.configure(with: message)
            return cell
        }
    }
    
    func deleteMessage(_ message: Message) {
        // Chỉ cần mô tả "trạng thái cuối cùng mong muốn"
        // DiffableDataSource tự tính diff và apply animation
        var snapshot = dataSource.snapshot()
        snapshot.deleteItems([message])
        dataSource.apply(snapshot, animatingDifferences: true)
        
        // KHÔNG BAO GIỜ bị inconsistency vì:
        // - snapshot IS the single source of truth
        // - UIKit đọc data từ snapshot, không phải từ array riêng
        // - diff + UI update là atomic
    }
}
```

**Tại sao DiffableDataSource giải quyết được vấn đề?**

Với cách cũ (`numberOfRows` + mảng riêng), có **hai nguồn truth**: mảng data và trạng thái nội bộ của tableView. Developer phải tự sync hai nguồn này. Với DiffableDataSource, **snapshot chính là single source of truth** — UIKit đọc trực tiếp từ snapshot, không bao giờ lệch.

---

## 3. State Consistency ở cấp Object — "Impossible States"

Ngoài UIKit, state inconsistency còn xảy ra ở cấp model/logic khi design cho phép tồn tại **trạng thái vô nghĩa**:

### Ví dụ: Order processing

```swift
// ❌ Thiết kế cho phép "impossible states"
class Order {
    var status: OrderStatus = .pending
    var shippingTrackingNumber: String? = nil
    var deliveredDate: Date? = nil
    var cancelReason: String? = nil
    
    // Vấn đề: không gì ngăn ai đó set:
    //   status = .pending
    //   deliveredDate = Date()      ← vô lý: chưa gửi sao đã giao?
    //   cancelReason = "Changed mind" ← vô lý: pending mà có cancel reason?
    //
    // 7 properties optional tạo ra hàng trăm combination,
    // phần lớn là INVALID, nhưng compiler không cản được
}
```

### Fix: Dùng enum với associated values

```swift
// ✅ "Make impossible states impossible" — compiler enforce consistency
enum OrderState {
    case pending
    case confirmed(estimatedDelivery: Date)
    case shipped(trackingNumber: String, carrier: Carrier)
    case delivered(date: Date, signature: String?)
    case cancelled(reason: String, refundAmount: Decimal)
}

struct Order {
    let id: UUID
    private(set) var state: OrderState
    
    // Chỉ cho phép transition hợp lệ
    mutating func ship(trackingNumber: String, carrier: Carrier) throws {
        guard case .confirmed = state else {
            throw OrderError.invalidTransition(from: state, to: "shipped")
        }
        state = .shipped(trackingNumber: trackingNumber, carrier: carrier)
    }
    
    mutating func markDelivered(date: Date, signature: String?) throws {
        guard case .shipped = state else {
            throw OrderError.invalidTransition(from: state, to: "delivered")
        }
        state = .delivered(date: date, signature: signature)
    }
}

// Giờ thì:
// - Không thể có trackingNumber khi chưa shipped
// - Không thể có deliveredDate khi chưa shipped
// - Không thể cancel một order đã delivered
// - Compiler BẮT BUỘC bạn handle mọi case khi switch
```

---

## 4. State Consistency trong Multi-Step Mutation

Khi một thao tác cần thay đổi **nhiều thành phần liên quan**, nếu fail giữa chừng → trạng thái nửa cũ nửa mới:

### Ví dụ: Xoá conversation trong chat app

```swift
// ❌ Nếu bước 2 fail, data ở trạng thái inconsistent
func deleteConversation(_ conv: Conversation) {
    // Bước 1: Xoá messages thuộc conversation
    database.deleteMessages(where: conv.id)   // ✅ thành công
    
    // Bước 2: Xoá conversation record
    database.deleteConversation(conv.id)       // ❌ fail (ví dụ: disk full)
    
    // Kết quả: conversation còn tồn tại nhưng messages đã bị xoá
    // → UI hiển thị conversation rỗng, không có cách recover messages
    // → orphaned state
}
```

### Fix: Transaction — all or nothing

```swift
// ✅ Dùng database transaction (ví dụ GRDB / SQLite)
func deleteConversation(_ conv: Conversation) throws {
    try database.write { db in
        // Cả hai thao tác trong cùng một transaction
        try Message
            .filter(Column("conversationId") == conv.id)
            .deleteAll(db)
        
        try Conversation
            .filter(Column("id") == conv.id)
            .deleteAll(db)
        
        // Nếu bất kỳ bước nào fail → ROLLBACK toàn bộ
        // Data luôn ở trạng thái consistent: hoặc xoá hết, hoặc không xoá gì
    }
}
```

---

## 5. State Consistency trong Async Operations

Async là nơi state inconsistency xảy ra tinh vi nhất, vì **mutation xảy ra ở thời điểm không xác định**:

### Ví dụ: User xoá item trong khi đang load thêm

```swift
// ❌ Race condition giữa delete và pagination
class FeedViewModel {
    var items: [FeedItem] = []
    
    func loadNextPage() async {
        let newItems = try await api.fetchFeed(page: nextPage)
        items.append(contentsOf: newItems) // mutation 1
    }
    
    func delete(item: FeedItem) async {
        try await api.delete(item.id)
        items.removeAll { $0.id == item.id } // mutation 2
    }
    
    // Scenario:
    // t=0: loadNextPage() bắt đầu, fetch page 2
    // t=1: user xoá item X (item X ở page 1) → items updated, item X bị remove
    // t=2: loadNextPage() trả về, append page 2
    //       NHƯNG response có thể CHỨA item X (server chưa process delete)
    //       → item X "sống lại" trong UI 👻
}
```

### Fix: Centralized state với serial mutation

```swift
// ✅ Dùng Actor để serialize mọi state mutation
actor FeedStateManager {
    private(set) var items: [FeedItem] = []
    private var deletedIDs: Set<String> = []  // track locally deleted items
    
    func appendPage(_ newItems: [FeedItem]) {
        // Filter ra những item đã bị xoá locally
        let filtered = newItems.filter { !deletedIDs.contains($0.id) }
        items.append(contentsOf: filtered)
    }
    
    func delete(_ id: String) {
        deletedIDs.insert(id)
        items.removeAll { $0.id == id }
    }
}

// Hoặc SwiftUI-friendly với @MainActor:
@MainActor
class FeedViewModel: ObservableObject {
    @Published private(set) var items: [FeedItem] = []
    private var deletedIDs: Set<String> = []
    
    func loadNextPage() async {
        let newItems = try await api.fetchFeed(page: nextPage)
        // Về lại MainActor → serialize với delete
        let filtered = newItems.filter { !deletedIDs.contains($0.id) }
        items.append(contentsOf: filtered)
    }
    
    func delete(item: FeedItem) async {
        deletedIDs.insert(item.id)
        items.removeAll { $0.id == item.id }
        try? await api.delete(item.id) // fire-and-forget hoặc handle error
    }
}
```

---

## 6. State Consistency giữa UI Layer với nhau

Khi nhiều screen/component cùng observe một data, mutation ở một chỗ phải reflect ở mọi chỗ:

```swift
// Scenario: User vào Profile screen sửa tên → quay lại Feed screen
// Feed screen vẫn hiển thị tên cũ → inconsistent

// ❌ Mỗi screen tự fetch và giữ copy riêng
class FeedViewModel {
    var currentUser: User  // copy A
}
class ProfileViewModel {
    var currentUser: User  // copy B — sửa ở đây, copy A không biết
}
```

### Fix: Single Source of Truth

```swift
// ✅ Centralized store — mọi screen observe cùng một nguồn
@MainActor
@Observable
class UserStore {
    static let shared = UserStore()
    
    private(set) var currentUser: User?
    
    func updateName(_ newName: String) async throws {
        let updated = try await api.updateProfile(name: newName)
        currentUser = updated
        // Mọi screen đang observe UserStore tự động nhận giá trị mới
    }
}

// Feed screen:
struct FeedView: View {
    @State private var userStore = UserStore.shared
    var body: some View {
        Text(userStore.currentUser?.name ?? "")
        // Tự update khi Profile screen sửa tên
    }
}
```

---

## 7. Checklist đánh giá State Consistency khi Code Review

Khi review code, senior nên tự hỏi:

**Mutation safety** — sau mỗi mutation, tất cả các thành phần phụ thuộc có được notify/update đồng bộ không? Có khoảng "trống" nào giữa data change và UI update mà UIKit có thể query vào đúng lúc đó không?

**Impossible states** — type system có cho phép tồn tại tổ hợp trạng thái vô nghĩa không? Có thể dùng enum với associated values để compiler enforce không?

**Transaction boundary** — multi-step mutation có được wrap trong transaction (database) hoặc batch update (UIKit) để đảm bảo all-or-nothing không?

**Async ordering** — khi có nhiều async operation chạy đồng thời, mutation có được serialize không? Race condition nào có thể xảy ra nếu hai operation hoàn thành theo thứ tự ngược lại?

**Cross-screen consistency** — có shared data nào đang bị duplicate thành nhiều copy độc lập không? Mutation ở screen A có tự động reflect ở screen B không?

---

## Nguyên tắc tổng quát

Tư duy cốt lõi của state consistency gói gọn trong một câu: **tại mọi thời điểm, bất kỳ ai (UI, background thread, hệ thống) đọc state đều phải nhận được một bức tranh toàn vẹn, không mâu thuẫn**. Để đạt được điều này, senior iOS developer cần thiết kế sao cho "impossible states" không thể biểu diễn được trong code, mutations luôn atomic, và mọi component cùng nhìn vào một single source of truth.
