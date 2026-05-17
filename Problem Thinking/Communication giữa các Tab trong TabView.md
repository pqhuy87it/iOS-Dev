# Communication giữa các Tab trong SwiftUI

Vấn đề bản chất: các tab là **sibling views** — không có parent-child relationship — nên không thể truyền `@Binding` trực tiếp giữa chúng. Phải "lift state up" lên một ancestor chung (root view hoặc App).

## 1. Hiểu hành vi của TabView trước

Trước khi chọn pattern, cần biết: `TabView` mặc định **giữ view của tất cả tab** trong memory sau khi chúng được hiển thị lần đầu. Subscription/observer trong tab inactive **vẫn chạy**. Đây là khác biệt quan trọng so với `NavigationStack` (pop là destroy).

→ Nghĩa là tab 2 có thể "lắng nghe" thay đổi từ tab 1 ngay cả khi nó không hiển thị, và state của nó sẽ luôn fresh khi user switch sang.

## 2. Cách 1: Lift state to App level (đơn giản nhất)

Khi state nhỏ, chỉ vài field:

```swift
@main
struct ShopApp: App {
    @State private var cartCount: Int = 0
    
    var body: some Scene {
        WindowGroup {
            TabView {
                ShopView(cartCount: $cartCount)
                    .tabItem { Label("Shop", systemImage: "bag") }
                
                CartView(cartCount: $cartCount)
                    .tabItem { Label("Cart", systemImage: "cart") }
                    .badge(cartCount)
            }
        }
    }
}
```

**Pros**: type-safe, không cần infrastructure.
**Cons**: prop drilling khi state phức tạp; binding phải xuyên qua nhiều cấp.

## 3. Cách 2: `@Observable` + `@Environment` (iOS 17+, recommended)

Đây là pattern senior-level chuẩn cho hầu hết trường hợp:

```swift
@Observable
final class CartStore {
    private(set) var items: [CartItem] = []
    var totalCount: Int { items.count }
    var totalPrice: Double { items.reduce(0) { $0 + $1.price } }
    
    func add(_ item: CartItem) { items.append(item) }
    func remove(_ item: CartItem) { items.removeAll { $0.id == item.id } }
    func clear() { items.removeAll() }
}

@main
struct ShopApp: App {
    @State private var cart = CartStore()
    
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(cart)
        }
    }
}

struct RootTabView: View {
    @Environment(CartStore.self) private var cart
    
    var body: some View {
        TabView {
            ShopView()
                .tabItem { Label("Shop", systemImage: "bag") }
            
            CartView()
                .tabItem { Label("Cart", systemImage: "cart") }
                .badge(cart.totalCount)
        }
    }
}

struct ShopView: View {
    @Environment(CartStore.self) private var cart
    
    var body: some View {
        List(products) { product in
            HStack {
                Text(product.name); Spacer()
                Button("Add") { cart.add(CartItem(from: product)) }
            }
        }
    }
}

struct CartView: View {
    @Environment(CartStore.self) private var cart
    
    var body: some View {
        List(cart.items) { Text($0.name) }
    }
}
```

Khi `cart.add()` được gọi ở Shop, `@Observable` tracking tự động → CartView (đang đọc `cart.items`) re-render → badge cũng update.

### Điểm mạnh quan trọng: fine-grained observation

Khác với `ObservableObject` (notify TẤT CẢ subscriber khi bất kỳ `@Published` nào thay đổi), `@Observable` chỉ re-render view nào **thực sự đọc** property đó. Badge chỉ đọc `totalCount` → nếu code change làm `items` đổi nhưng `totalCount` không đổi, badge không re-render. Đây là performance win lớn ở scale app thật.

## 4. Cách 3: `ObservableObject` + `@EnvironmentObject` (iOS 16-)

Pattern tương đương cho codebase chưa migrate sang `@Observable`:

```swift
final class CartStore: ObservableObject {
    @Published private(set) var items: [CartItem] = []
    func add(_ item: CartItem) { items.append(item) }
}

@main
struct ShopApp: App {
    @StateObject private var cart = CartStore()
    
    var body: some Scene {
        WindowGroup {
            RootTabView().environmentObject(cart)
        }
    }
}

struct CartView: View {
    @EnvironmentObject private var cart: CartStore
    // ...
}
```

Lưu ý: ở root dùng `@StateObject` (sở hữu lifecycle), tab dùng `@EnvironmentObject` (chỉ đọc reference). Đừng dùng `@ObservedObject` ở root — sẽ recreate mỗi lần parent re-render.

## 5. Cách 4: `NotificationCenter` cho one-time events

Khi action không phải state thay đổi mà là **sự kiện** ("đã xảy ra", "hãy refresh"), NotificationCenter rất hợp:

```swift
extension Notification.Name {
    static let didCompletePurchase = Notification.Name("didCompletePurchase")
}

struct CheckoutView: View {
    var body: some View {
        Button("Confirm Purchase") {
            // ... process purchase
            NotificationCenter.default.post(name: .didCompletePurchase, object: nil)
        }
    }
}

struct OrdersView: View {
    @State private var orders: [Order] = []
    
    var body: some View {
        List(orders) { OrderRow(order: $0) }
            .task { await loadOrders() }
            .onReceive(NotificationCenter.default.publisher(for: .didCompletePurchase)) { _ in
                Task { await loadOrders() }
            }
    }
}
```

Use case lý tưởng:
- "Trigger reload ở tab khác sau khi xong việc tab này"
- "Reset state toàn app khi user logout"
- "Show toast trên tab hiện tại khi event xảy ra ở nơi khác"

**Tuyệt đối không** dùng NotificationCenter để share state. State thuộc về store, notification thuộc về event.

## 6. Cách 5: Combine Subject — Type-safe event bus

Nâng cấp NotificationCenter lên type-safe:

```swift
@Observable
final class AppEventBus {
    let purchaseCompleted = PassthroughSubject<Order, Never>()
    let userLoggedOut = PassthroughSubject<Void, Never>()
    let cartCleared = PassthroughSubject<Void, Never>()
}

@main
struct ShopApp: App {
    @State private var bus = AppEventBus()
    
    var body: some Scene {
        WindowGroup {
            RootTabView().environment(bus)
        }
    }
}

// Send
struct CheckoutView: View {
    @Environment(AppEventBus.self) private var bus
    
    var body: some View {
        Button("Confirm") {
            bus.purchaseCompleted.send(createOrder())
        }
    }
}

// Receive
struct OrdersView: View {
    @Environment(AppEventBus.self) private var bus
    @State private var orders: [Order] = []
    
    var body: some View {
        List(orders) { OrderRow(order: $0) }
            .onReceive(bus.purchaseCompleted) { order in
                orders.insert(order, at: 0)
            }
    }
}
```

So với NotificationCenter:
- ✅ Compile-time check payload type
- ✅ Không stringly-typed Name
- ✅ Inject được → dễ test
- ✅ Chain với Combine operators tự nhiên

## 7. Cách 6: SwiftData (khi data persistent)

Nếu data cần persist, SwiftData tự sync giữa các view qua `ModelContext`:

```swift
@Model
final class CartItem {
    var productId: String
    var quantity: Int
    var addedAt: Date
    init(productId: String, quantity: Int) {
        self.productId = productId; self.quantity = quantity; self.addedAt = .now
    }
}

@main
struct ShopApp: App {
    var body: some Scene {
        WindowGroup { RootTabView() }
            .modelContainer(for: CartItem.self)
    }
}

struct ShopView: View {
    @Environment(\.modelContext) private var ctx
    
    var body: some View {
        Button("Add") {
            ctx.insert(CartItem(productId: product.id, quantity: 1))
        }
    }
}

struct CartView: View {
    @Query(sort: \CartItem.addedAt) private var items: [CartItem]
    
    var body: some View {
        List(items) { ItemRow(item: $0) }
    }
}
```

`@Query` tự re-fetch khi context thay đổi → CartView update mà không cần code thêm.

## 8. Decision matrix

| Scenario | Approach |
|---|---|
| Single counter/flag | Lift state to App + `@Binding` |
| State logic phức tạp, nhiều method | `@Observable` + `@Environment` |
| Codebase iOS 16- | `ObservableObject` + `@EnvironmentObject` |
| One-shot event ("xong rồi, refresh đi") | NotificationCenter |
| Multiple event types có payload typed | `AppEventBus` với Combine Subject |
| Persistent data | SwiftData `@Query` |
| Cross-feature module (modular SPM) | Combine Subject hoặc NotificationCenter |

## 9. Anti-patterns cần tránh

1. **Singleton "manager"**: `CartManager.shared` — không inject, không test, lifecycle khó kiểm soát.
2. **Re-create observable trong `body`**: phải dùng `@State` (cho `@Observable`) hoặc `@StateObject` (cho `ObservableObject`) ở owner, không khởi tạo trực tiếp trong body.
3. **Prop drilling `@Binding`**: truyền qua 4-5 cấp view → unmaintainable. Chuyển sang `@Environment`.
4. **NotificationCenter cho state**: làm state khó debug, race condition khó tìm.
5. **Observe quá rộng với `ObservableObject`**: nếu chỉ cần `cart.totalCount`, đừng `@EnvironmentObject` toàn `CartStore` rồi để view re-render mỗi khi bất kỳ field nào trong store đổi. Hoặc tách store, hoặc migrate sang `@Observable`.
6. **Quên `@Environment` injection ở preview**: crash khi preview vì `@Environment` không có giá trị. Luôn `.environment(CartStore())` trong `#Preview`.

## 10. Pattern nâng cao: Sectioned stores

Khi app lớn, chia store theo feature thay vì 1 mega-store:

```swift
@Observable final class CartStore { /* ... */ }
@Observable final class AuthStore { /* ... */ }
@Observable final class FavoritesStore { /* ... */ }

extension EnvironmentValues {
    @Entry var cart = CartStore()
    @Entry var auth = AuthStore()
    @Entry var favorites = FavoritesStore()
}

// Sử dụng
struct CartView: View {
    @Environment(\.cart) private var cart
    // ...
}
```

Macro `@Entry` (Xcode 16+) đơn giản hóa việc tạo custom `EnvironmentKey` rất nhiều, không cần boilerplate `struct CartKey: EnvironmentKey { static let defaultValue = ... }`.

### Inter-store communication

Khi store A cần phản ứng với event của store B (vd: clear favorites khi logout):

```swift
@Observable
final class FavoritesStore {
    var ids: Set<String> = []
    private var logoutTask: Task<Void, Never>?
    
    init(eventBus: AppEventBus) {
        logoutTask = Task { [weak self] in
            for await _ in eventBus.userLoggedOut.values {
                self?.ids.removeAll()
            }
        }
    }
    
    deinit { logoutTask?.cancel() }
}
```

(`Publisher.values` bridge Combine Subject sang `AsyncSequence`.)

---

## Recommendation cho project iOS 17+

Kết hợp 3 lớp:

1. **`@Observable` store + `@Environment`** làm xương sống cho **state**.
2. **`AppEventBus`** (Combine Subject) hoặc **NotificationCenter** cho **event** one-shot.
3. **SwiftData** nếu data cần persist.

Architecture này scale tốt từ app nhỏ đến app modular với SPM, dễ test, performance tốt nhờ fine-grained observation của `@Observable`.

Nếu Huy có scenario cụ thể (ví dụ: structure thật của project, kiểu data flow giữa tab Shop → Cart → Profile), tớ có thể design cụ thể hơn cho case đó.
