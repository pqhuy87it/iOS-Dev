https://developer.apple.com/videos/play/wwdc2026/269/

Tôi sẽ fetch transcript đầy đủ của video để đi chi tiết hơn từng mục.Video file quá lớn để fetch. Tôi sẽ dựa trên chapters, code samples và summaries đã có (khá chi tiết) để mở rộng từng mục cho bạn.

---

## 1. Refreshed look and feel — Giao diện Liquid Glass mới

**Tự động adopt (2:12)**
Khi bạn build app bằng Xcode 27 và nhắm tới OS releases 2027, app tự động khoác lên giao diện Liquid Glass mới **mà không cần sửa code**. Các controls, toolbars, sidebars đều được render lại với chất liệu glass trong suốt, có độ sâu và phản chiếu.

**`appearsActive` environment value (3:20)**
Environment value mới cho biết window có đang active hay không (quan trọng trên iPadOS/macOS khi có nhiều cửa sổ). Dùng để làm mờ những phần UI không cần thiết khi window mất focus:
```swift
@Environment(\.appearsActive) private var appearsActive
// MyAccountView().opacity(appearsActive ? 1 : 0.5)
```

**Menu icon visibility (3:34)**
Có thể ép icon hiển thị trong menu bằng `.labelStyle(.titleAndIcon)` — trước đây menu items thường chỉ hiện text.

**Prominent tab role (5:12)**
`Tab(role: .prominent)` làm nổi bật một tab (ví dụ tab Cart/giỏ hàng) tách biệt khỏi nhóm tab thường, thu hút chú ý người dùng.

**Toolbar customization (6:15)**
- `visibilityPriority(.high)` — gán độ ưu tiên hiển thị cho nhóm toolbar items; khi không đủ chỗ, item ưu tiên thấp bị ẩn trước.
- `ToolbarOverflowMenu` — gom các item ít dùng vào menu tràn (dấu "…").
- `placement: .topBarPinnedTrailing` — ghim item luôn hiển thị (ví dụ nút Share).

**Minimize on scroll (7:37)**
```swift
.toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)
```
Toolbar/navigation bar tự thu nhỏ khi cuộn xuống để nhường không gian cho nội dung, hiện lại khi cuộn lên.

**Resizable apps** — Hướng dẫn build app co giãn linh hoạt dùng **size classes** thay vì hardcode kích thước, quan trọng cho iPad multitasking và windowing.

---

## 2. Document-based apps — Ứng dụng dạng tài liệu

**`DocumentCreationSource` (9:47)**
API mới cho phép tùy biến luồng tạo tài liệu mới. Thay vì chỉ "New Document", bạn định nghĩa nhiều nguồn tạo:
```swift
DocumentGroupLaunchScene("Create a Sticker Page") {
    NewDocumentButton("New Sticker Page", source: .blank)
    NewDocumentButton("Sticker Page from Photo…", source: .photo)
}
extension DocumentCreationSource {
    static let blank = Self(id: "blank")
    static let photo = Self(id: "photo")
}
```
`context` được truyền vào closure khởi tạo document để biết người dùng chọn nguồn nào.

**Snapshot + DocumentWriter (11:25 → 13:27)**
Đây là cải tiến hiệu năng lớn. Cơ chế:
1. Document là `@Observable` class, khai báo `writableDocumentTypes: [UTType]`.
2. Hàm `snapshot(contentType:)` chụp một bản "ảnh" bất biến của trạng thái document (`sending` — tách khỏi main actor an toàn cho concurrency).
3. `DocumentWriter` nhận snapshot đó + **snapshot trước đó (`previous`)** để thực hiện **diffing** — chỉ ghi phần thay đổi thay vì ghi toàn bộ, giúp lưu tài liệu lớn nhanh hơn.
```swift
nonisolated func write(
    snapshot: sending PageSnapshot, to destination: URL,
    previous: sending PageSnapshot?, progress: consuming Subprogress
) async throws { ... }
```
- `progress: Subprogress` — báo tiến độ ghi (progress reporting) cho tài liệu lớn.
- Việc write chạy `nonisolated` (ngoài main actor) → UI không bị block.

**Reading & nhiều format (13:27 → 14:56)**
- Conform `ReadableDocument` để đọc.
- Hỗ trợ ghi nhiều định dạng cùng lúc — ví dụ vừa format riêng `.stickerDocument` vừa export `.png`, kiểm tra bằng `contentType.conforms(to:)`:
```swift
if contentType.conforms(to: .stickerDocument) { /* write native */ }
else if contentType.conforms(to: .png) { let context = CGContext(...) ... }
```

**Direct URL access** — `FileDocument`/`ReferenceFileDocument` giờ có quyền truy cập trực tiếp URL của document trên đĩa, thay vì chỉ nhận data buffer, phù hợp với các file lớn hoặc format phức tạp.

---

## 3. Presentation and interaction — Trình bày & tương tác

**Reorderable containers (15:58 → 16:48)**
Người dùng kéo để sắp xếp lại thứ tự items trong **List, LazyVGrid**, và **lần đầu tiên trên watchOS**.
```swift
List {
    ForEach(stickers) { StickerListItemView(sticker: $0) }
        .reorderable()
}
.reorderContainer(for: Sticker.self) { difference in
    difference.apply(to: &stickers)
}
```
- `.reorderable()` đánh dấu items có thể kéo thả.
- `.reorderContainer(for:)` nhận `ReorderDifference` (mô tả nguồn `sources` và đích `destination`) để bạn tự áp vào data source — thường kết hợp `OrderedDictionary` từ **swift-collections** để dời phần tử hiệu quả.
- Cùng cú pháp cho `LazyVGrid`.

**Swipe actions trên mọi view (18:12 → 18:15)**
Trước đây `.swipeActions` chỉ dùng trong `List`. Giờ có thể dùng trên bất kỳ view nào trong scroll container:
```swift
ScrollView {
    LazyVStack {
        ForEach(stickers) { sticker in
            StickerListItemView(sticker: sticker)
                .swipeActions { DeleteButton(sticker: sticker) }
        }
    }
}
.swipeActionsContainer()   // <- bật swipe actions cho container tùy ý
```

**Item-binding cho dialog/alert (18:54 → 19:35)**
`confirmationDialog` và `alert` nhận binding tới một **item optional** thay vì boolean `isPresented`. Dialog tự hiện khi item khác `nil`, và item được truyền thẳng vào closure — sạch hơn, không cần state phụ:
```swift
@State private var stickerToDelete: Sticker?
// ...
.confirmationDialog("Delete?", item: $stickerToDelete) { sticker in
    DeleteStickerButton(sticker)
}
// alert cũng dùng đúng pattern này
```

---

## 4. Data flow and performance — Luồng dữ liệu & hiệu năng

**AsyncImage caching (21:18)**
`AsyncImage` giờ hỗ trợ **HTTP caching chuẩn mặc định**. Ngoài ra có API nhận `URLRequest` và `URLSession` tùy chỉnh:
```swift
static let imageSession: URLSession = {
    let config = URLSessionConfiguration.default
    config.urlCache = URLCache(memoryCapacity: 64*1024*1024,
                               diskCapacity: 256*1024*1024)
    return URLSession(configuration: config)
}()

AsyncImage(request: URLRequest(url: pet.imageURL,
                               cachePolicy: .returnCacheDataElseLoad))
    // ...
.asyncImageURLSession(StickerStore.imageSession)
```
Cho phép kiểm soát dung lượng cache trên RAM/đĩa và cache policy — tránh tải lại ảnh liên tục.

**`@State` thành macro — lazy initialization (23:08 → 24:02)**
Đây là thay đổi quan trọng và tinh tế:
```swift
struct StickerStoreView: View {
    @State private var store = StickerStore()  // giờ khởi tạo lazy
    var body: some View { ... }
}
```
- `@State` giờ là **macro**. Với reference types (`@Observable` class), object chỉ được **tạo một lần duy nhất trong vòng đời view**, khởi tạo **lười (lazy)**.
- Trước đây biểu thức `StickerStore()` bị đánh giá lại mỗi khi struct View được tạo lại (dù SwiftUI vứt bỏ instance thừa) → gây cấp phát dư thừa. Giờ tránh được.
- **Được back-port về iOS 17, macOS 14** và các release tương ứng — không cần chờ OS 2027.

**Cạm bẫy trong `init` (23:48 → 24:02)**
Vì là macro, gán `@State` trong `init` khi vẫn còn default value gây lỗi *"used before being initialized"*. Cách sửa: **bỏ default value** khỏi khai báo:
```swift
@State private var page: StickerPage   // bỏ = StickerPage()
let title: String
init(title: String) {
    self.page = StickerPage(title: title)
    self.title = title
}
```

**`@ContentBuilder` (26:07)**
Result builder mới, dạng tổng quát hơn `@ViewBuilder` — dùng để xây dựng nội dung tùy biến (liên quan tới `ContentBuilder` type trong docs). Phù hợp cho các API nhận content không nhất thiết là View thuần.

---

## 5. Next steps — Bước tiếp theo

- **Build bằng Xcode 27** để thấy ngay giao diện Liquid Glass mới áp dụng lên app hiện có (không cần đổi code).
- **Adopt Document APIs mới** nếu bạn làm app document-based — tận dụng snapshot diffing + direct URL access để tăng hiệu năng.
- Rà soát các `@State` với reference type để hưởng lợi lazy init (nhớ vá pattern gán trong `init`).
- Dùng caching mới của `AsyncImage` cho app nhiều ảnh remote.
- **Khám phá SwiftUI agent skills** — bộ skills hỗ trợ code SwiftUI (điểm mới đáng chú ý của năm nay).

Video liên quan nên xem tiếp: *"Code-along: Build powerful drag and drop in SwiftUI" (271)* để hiểu sâu reorderable/drag-drop, và *"Modernize your UIKit app" (278)*.

Lưu ý: mình không mở được transcript đầy đủ (file video quá lớn), nên phần chi tiết trên tổng hợp từ chapter summaries và toàn bộ code samples chính thức của session — nếu bạn muốn đào sâu một mục cụ thể (ví dụ cơ chế snapshot diffing hoặc `@ContentBuilder`), nói mình biết.
