Trước khi đi vào nội dung: WWDC 2026 diễn ra **sau** mốc dữ liệu huấn luyện của mình (cuối tháng 5/2026), và trong phiên này mình **không có web search** để fetch lại trang session. Nên phần dưới là tổng hợp từ chính những session mình và Huy đã fetch + đào sâu hồi đầu tháng 8 — tức là **có nguồn thật**, nhưng chỉ giới hạn trong 4 session đó, không phải toàn cảnh WWDC26.

## 1. SwiftUI — session 269 "What's new in SwiftUI"

**Look and feel (Liquid Glass thế hệ 2)**
- Build bằng **Xcode 27**, target **OS releases 2027 (iOS 27+)** → app tự adopt giao diện Liquid Glass mới, không cần đổi code.
- Environment value mới `appearsActive` để làm mờ UI khi window inactive (iPadOS).
- Toolbar: `visibilityPriority` cho toolbar item, `ToolbarOverflowMenu`, pinned placements, `toolbarMinimizeBehavior(.onScrollDown)`.
- `Tab(role: .prominent)` cho tab nổi bật.

**Data flow & performance — phần đáng chú ý nhất về mặt technical**
- **`@State` chuyển thành macro** → lazy initialization cho class: object chỉ được tạo **một lần** trong lifecycle của view, không còn cấp phát thừa mỗi lần `body` chạy. Quan trọng: **back-port về iOS 17 / macOS 14**, nên dùng được ngay chứ không phải chờ iOS 27.
- `AsyncImage` hỗ trợ HTTP caching chuẩn theo mặc định + API cho custom `URLRequest`/`URLSession`.
- `@ContentBuilder` mới.

**Presentation & interaction**
- Reorderable containers: kéo-thả sắp xếp trong **List, LazyVGrid**, và lần đầu trên watchOS — qua `.reorderable()` + `.reorderContainer(for:)`.
- **Swipe actions trên bất kỳ view nào**, không chỉ List — `.swipeActionsContainer()`.
- `alert` / `confirmationDialog` nhận **item binding** trực tiếp.

**Document-based apps**: `DocumentCreationSource`, protocol mới có **direct disk access** + **snapshot-based diffing**, `DocumentWriter` với progress reporting, `ReadableDocument`/`WritableDocument`, ghi nhiều format cùng lúc.

## 2. Scrolling performance — session 321 "Dive into lazy stacks and scrolling"

Session này là loại "đổi cách viết code hằng ngày", 4 rule:
- **Đừng lọc dữ liệu bằng `if` trong leaf view** — lọc ở tầng data để số subview ổn định (lazy stack ước lượng size dựa trên số subview).
- **Setup trong `init`, không phải `onAppear`** — lazy stack đã prefetch trước khi view vào màn hình; đặt ở `onAppear` là tự bỏ prefetch.
- **State quan trọng phải sống ngoài view struct** (model object / binding từ cha), vì view bị hủy khi cuộn khỏi màn hình.
- Ưu tiên **custom `Layout`** thay vì layout pass phản ứng (`onGeometryChange`).
- Programmatic scroll bằng `ScrollPosition.scrollTo(id:)` hoạt động cả khi target off-screen.

## 3. SwiftData — session 275 (code-along) + 274 "What's new in SwiftData"

Điểm mới nổi bật là **`withContinuousObservation`** + `event.matches(_:)` để biết chính xác property nào vừa đổi (thay pattern `didSet` cũ); phải giữ `token` để observation còn sống. Ngoài ra: inheritance trong schema, targeted query (predicate + `fetchLimit`) thay vì load hết, Codable interop.

## 4. Core Image — session 305: **RAW 9**

`CIRAWFilter.decoderVersion = .version9` (opt-in, không mặc định; cần iOS 27+). RAW 9 tự lo color noise reduction → `colorNoiseReductionAmount` vô tác dụng, `detailAmount`/`moireReductionAmount` bị loại. Còn 4 knob: exposure, luminance NR, sharpness, contrast. `CIImageProcessor` có 2 API mới: `apply(withTiledExtent:)` và `output.temporaryPixelBuffer(...)`.

## 5. Combine

Mình **không có thông tin nào** về session hay API change cho Combine ở WWDC26 — và đây là suy đoán chứ không phải fact đã fetch: Apple tiếp tục xu hướng từ 2023, không đầu tư thêm vào Combine, đẩy sang `AsyncSequence`/`AsyncStream` + Observation framework. Nếu Huy đang có Combine trong codebase thì đường đi vẫn là migrate dần, không phải chờ API mới.

---

Những mảng mình **chưa có dữ liệu**: Swift 6.3/7, Xcode 27 features, Foundation Models, "SwiftUI agent skills" (session 269 có nhắc trong Next steps nhưng mình chưa fetch), UIKit changes, keynote-level features.

Muốn mình đi tiếp thì có hai cách: bật web search rồi mình fetch danh sách session WWDC26 đầy đủ và lọc theo ưu tiên của Huy, hoặc Huy paste link session cụ thể như lần trước.
