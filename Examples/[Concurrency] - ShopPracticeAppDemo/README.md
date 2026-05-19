# ShopPracticeApp

Practice project demonstrating a 3-layer SwiftUI architecture:

1. **State layer** — `@Observable` stores injected via `@Environment`
2. **Event layer** — `AppEventBus` with Combine `PassthroughSubject`s for one-shot signals
3. **Persistence layer** — `SwiftData` (`@Model`, `@Query`, `ModelContext`)

## Requirements

- Xcode 15+
- iOS 17+ (uses `@Observable` and SwiftData)

## Setup

1. Tạo new iOS App project trong Xcode (SwiftUI lifecycle).
2. **Delete** `ContentView.swift` và struct `App` mặc định trong template.
3. Copy toàn bộ folder vào project, giữ nguyên cấu trúc:
   ```
   YourApp/
   ├── App/
   │   └── ShopPracticeApp.swift
   ├── Models/
   │   ├── Product.swift
   │   ├── CartItem.swift
   │   └── Order.swift
   ├── Stores/
   │   ├── UserSession.swift
   │   └── ProductCatalog.swift
   ├── Events/
   │   └── AppEventBus.swift
   └── Views/
       ├── RootTabView.swift
       ├── ShopView.swift
       ├── CartView.swift
       ├── OrdersView.swift
       ├── ProfileView.swift
       └── ToastOverlay.swift
   ```
4. Build & run.

## Luồng để thử nghiệm

1. **Shop** tab → tap `+` ở product bất kỳ → toast hiện, badge của Cart tab tăng.
2. **Cart** tab → xem total → tap **Checkout** → cart rỗng, badge của Orders tab tăng, toast fire.
3. **Orders** tab → order mới được highlight xanh 2 giây (driven by `bus.purchaseCompleted`).
4. **Profile** tab → login với username bất kỳ, quay lại Shop add thêm, rồi **Logout** → cart auto-clear.
5. Force-quit app rồi mở lại → orders + cart state persist (SwiftData).

## Quan sát kiến trúc 3 lớp

| Layer | Sống ở đâu | File trong project |
|---|---|---|
| State | In-memory, app lifecycle | `UserSession`, `ProductCatalog` |
| Events | One-shot signals, không có state | `AppEventBus` |
| Persistence | Data tồn tại qua restart | `CartItem`, `Order` |

### Điểm tinh tế cần để ý

- **State vs Event**:
  - Số lượng item trong cart = **state** → đọc qua `@Query` (auto-update).
  - "Đã checkout xong" = **event** → fire qua `bus.purchaseCompleted.send(...)`.
  - Sai lầm thường gặp: dùng NotificationCenter cho cart count → khó debug, mất source of truth.

- **Fine-grained observation**:
  - Badge của Cart tab chỉ re-render khi `cartCount` thay đổi.
  - Body của RootTabView không re-render khi `session.state` đổi (vì RootTabView không đọc session).

- **Cross-tab communication**:
  - Các tab **không bao giờ** reference lẫn nhau.
  - Tất cả đi qua shared environment hoặc shared `ModelContext`.

- **Event payload là plain struct** (`OrderEvent`):
  - Không bị couple vào SwiftData `Order` model.
  - Nếu sau này migrate SwiftData sang Core Data hoặc API, event không bị ảnh hưởng.

- **Toast là event, không phải state**:
  - Sai pattern: lưu `var currentToast: ToastMessage?` ở root store và mutate.
  - Đúng pattern: fire event, modifier tự manage local UI state với auto-dismiss timer.

## Scale lên SPM modular

Khi codebase lớn lên, có thể tách thành các SPM target như sau:

- **Domain** package: `Product`, `OrderEvent`, `ToastMessage`
- **Persistence** package: `CartItem`, `Order` (depends on Domain)
- **State** package: `UserSession`, `ProductCatalog` (depends on Domain)
- **Events** package: `AppEventBus` (depends on Domain)
- **Features** packages (Shop, Cart, Orders, Profile): mỗi feature 1 package, depends on Domain + State + Events + Persistence
- **App** target: chỉ wire dependencies, không có business logic

Architecture này keep parallel teamwork dễ — mỗi feature team work trên feature package độc lập, chỉ thấy được public API của các layer khác.

## Testing strategy

Mỗi layer test theo cách riêng:

- **Stores** (`UserSession`, `ProductCatalog`): unit test trực tiếp, không cần SwiftUI.
- **AppEventBus**: inject mock instance, subscribe test, gọi `.send(...)`, assert handler được gọi.
- **SwiftData models**: dùng in-memory `ModelContainer(configurations: .init(isStoredInMemoryOnly: true))` trong test.
- **Views**: snapshot test hoặc UI test, không nên unit test logic trong view body.

## Mở rộng làm bài tập thêm

- Thêm `FavoritesStore` (state) + persist favorites bằng SwiftData → 2 tab cùng query.
- Thêm event `cartItemAdded` mà OrdersView subscribe để hiện stats.
- Bridge từ system notification (`UIApplication.didBecomeActiveNotification`) → `AppEventBus.appBecameActive` để tất cả listener trong app dùng một interface.
- Thêm async refresh trong `OrdersView.task { ... }` listen `bus.userLoggedOut` để reset state.
