Video **"Dive into lazy stacks and scrolling with SwiftUI" (WWDC26, session 321)**, do Rens Breur trình bày. Session đào sâu cơ chế bên trong của `LazyVStack`/`LazyHStack`: cách ước lượng kích thước, load subview lười, prefetch, và cuộn programmatic — kèm nhiều best practice về hiệu năng cuộn. Ví dụ xuyên suốt là app **Origami** (danh sách các bước gấp giấy).

---

## Tóm tắt các mục chính

1. **Introduction (0:00)** — Lazy stack là thành phần cốt lõi cho nội dung cuộn dài/tùy biến.
2. **Layout (1:24)** — Cách lazy stack chỉ layout view đang hiển thị và **ước lượng** tổng kích thước; cách phối hợp offset với `ScrollView`; cách compose nhiều lazy stack.
3. **Subview loading (9:13)** — Một view struct không phải lúc nào cũng ánh xạ 1-1 thành một subview mà lazy stack "thấy"; body có thể sinh nhiều hoặc số lượng động subview.
4. **Prefetching (13:15)** — Lazy stack prefetch subview trước khi cuộn tới; đừng trì hoãn thiết lập tới `onAppear`; state cần sống sót khi cuộn khỏi màn hình phải đưa ra ngoài.
5. **Programmatic scrolling (17:40)** — Dùng `ScrollPosition` để cuộn tới view kể cả khi off-screen; các cạm bẫy về hiệu năng lặp lại.
6. **Next steps (19:55)** — Đúc kết các nguyên tắc vàng.

---

## Chi tiết từng mục

### 1. Introduction
Lazy stack (`LazyVStack`, `LazyHStack`) là công cụ thiết yếu khi bạn có **nội dung cuộn dài** hoặc bố cục cuộn tùy biến mà `List` không đáp ứng được. Khác với `VStack` thường (layout tất cả ngay lập tức), lazy stack chỉ tạo và layout view khi cần. Ví dụ nền tảng — app Origami:
```swift
ScrollView {
    LazyVStack {
        ForEach(steps) { step in
            StepView(step: step)
        }
    }
}
```

### 2. Layout — Cơ chế bố cục và ước lượng kích thước

**Chỉ layout view đang hiển thị**
Lazy stack chỉ thêm và đo các view **đang nằm trong vùng nhìn** (visible). Với các view chưa hiển thị, nó không tạo ra mà chỉ **ước lượng (estimate)** kích thước.

**Ước lượng tổng kích thước**
Vì `ScrollView` cần biết tổng chiều cao nội dung để vẽ thanh cuộn và tính toán vị trí, lazy stack phải báo một **tổng kích thước ước lượng**. Nó dựa trên kích thước các view đã đo được để suy ra kích thước các view chưa thấy. Khi bạn cuộn và các view thật được đo, **ước lượng này thay đổi** — lazy stack cập nhật lại và **phối hợp content offset với ScrollView** để việc điều chỉnh không gây giật hay nhảy vị trí. Đây là lý do có nguyên tắc "đừng dựa vào absolute content size/offset" — vì con số đó là ước lượng và biến động.

**Compose nhiều lazy stack**
Có thể lồng lazy stack để tạo bố cục phức tạp. Ví dụ: một `LazyVStack` dọc chứa các bước, rồi thêm một `Showcase` là `ScrollView(.horizontal)` chứa `LazyHStack` ảnh:
```swift
ScrollView {
    LazyVStack {
        ForEach(steps) { step in StepView(step: step) }
        Showcase()   // bên trong là ScrollView(.horizontal) { LazyHStack { ... } }
    }
}
```

**Section + pinned headers**
Dùng `Section` với `pinnedViews: [.sectionHeaders]` để header dính (pinned) khi cuộn:
```swift
LazyVStack(pinnedViews: [.sectionHeaders]) {
    ForEach(steps) { step in StepView(step: step) }
    Showcase()   // Showcase giờ là một Section { ... } header: { ... }
}
```

**Scroll effects**
`.scrollTransition` cho hiệu ứng theo vị trí cuộn của từng item (xoay, phóng to/thu nhỏ dựa trên `phase.value`):
```swift
PhotoView(photo: photo)
    .scrollTransition { effect, phase in
        effect
            .rotationEffect(.degrees(phase.value * 20))
            .scaleEffect(1 + phase.value * 0.2)
    }
```

**Theo dõi trạng thái cuộn — dùng cái gì**
- `onScrollGeometryChange` — phản ứng theo **offset tuyệt đối** (ví dụ `geo.contentOffset.y <= 100`). Nhưng vì offset là ước lượng, cách này kém tin cậy với lazy stack.
- **Ưu tiên** `onScrollTargetVisibilityChange(idType:threshold:)` — phản ứng theo **ID của các view đang hiển thị** (ví dụ threshold 0.8), ổn định hơn vì không phụ thuộc con số offset ước lượng:
```swift
.onScrollTargetVisibilityChange(idType: Step.ID.self, threshold: 0.8) { visibleIDs in
    isScrollToShowcaseVisible = shouldShowScrollButton(visibleIDs: visibleIDs)
}
```

### 3. Subview loading — Cách view struct được phân giải thành subview

Điểm cốt lõi: **ánh xạ 1-1 mà bạn tưởng tượng không phải lúc nào cũng đúng**. Một `StepView` không nhất thiết là một "subview" đối với lazy stack.

**Một body → nhiều subview (10:03)**
Nếu body của `StepView` chứa nhiều view song song, lazy stack có thể "thấy" nhiều subview:
```swift
struct StepView: View {
    let step: Step
    var body: some View {
        StepDiagram(/* ... */)
        StepInstructions(/* ... */)
    }
}
```

**Số lượng subview động (10:52) — cạm bẫy hiệu năng**
Nếu body chứa điều kiện thay đổi số lượng view (ví dụ theo `detailLevel`), lazy stack phải **giải quyết (resolve) view để biết nó có sinh ra nội dung hay không** — điều này làm hỏng tính "lười":
```swift
struct StepView: View {
    let step: Step
    @Environment(\.detailLevel) var detailLevel
    var body: some View {
        if step.isVisible(in: detailLevel) {   // số subview phụ thuộc điều kiện
            VStack { /* ... */ }
        }
    }
}
```
Vì lazy stack không biết trước điều kiện này đúng/sai cho từng phần tử, nó có thể phải instantiate nhiều hơn cần thiết, hại cho hiệu năng cuộn.

**Giải pháp — lọc ở tầng dữ liệu (12:15)**
Thay vì lọc bằng điều kiện trong view (leaf view), hãy **lọc ở tầng data** để `ForEach` chỉ nhận đúng các phần tử cần hiển thị. Khi đó số subview là tĩnh, lazy stack giữ được tính lười:
```swift
struct ContentView: View {
    @Query var steps: [Step]
    init(detailLevel: DetailLevel) {
        _steps = Query(filter: #Predicate<Step> { $0.detailLevel >= detailLevel })
    }
    var body: some View { /* ... */ }
}
```

**Environment/optional không đổi số lượng thì OK (12:35)**
Điều kiện dựa trên environment mà **không thay đổi số lượng subview cuối cùng** (ví dụ `if let token`, hoặc đọc `writingStyle`) thì không gây vấn đề — vấn đề chỉ nằm ở chỗ số **lượng** subview biến động theo từng phần tử.

### 4. Prefetching — Nạp trước và vòng đời state

**Prefetch (13:15)**
Lazy stack **prefetch subview trước khi chúng cuộn vào màn hình**, thực hiện một phần công việc render sẵn để tránh **hitch** (khựng). Để tận dụng được điều này, **đừng dồn việc thiết lập vào `onAppear`** — vì `onAppear` chạy *sau khi* view đã xuất hiện, làm mất lợi ích prefetch.

**Thiết lập trong `init` thay vì `onAppear` (15:53 → 16:14)**
```swift
// KHÔNG nên: cấu hình trong onAppear (trễ, mất prefetch)
struct StepView: View {
    @State var viewModel = StepViewModel()
    var body: some View { /* ... */ }
    .onAppear { viewModel.configure(with: id) }
}

// NÊN: khởi tạo view model ngay trong init để sẵn sàng trước onAppear
struct StepView: View {
    @State var viewModel: StepViewModel
    init(id: Step.ID) {
        _viewModel = State(initialValue: StepViewModel(id: id))
    }
    var body: some View { /* ... */ }
}
```

**Load bất đồng bộ — dùng `.task` hoặc khởi tạo loader trong init (16:23 → 16:40)**
```swift
// Cách 1: .task chạy khi view active
.task { diagram = await diagramLoader.loadDiagram(id: step.id) }

// Cách 2: khởi tạo loader (@Observable) ngay trong init để bắt đầu sớm hơn
init(step: Step) {
    self.step = step
    _diagramLoader = State(initialValue: DiagramLoader(id: step.id))
}
```

**State sống sót khi cuộn khỏi màn hình (loading more content, 15:28)**
Subview được giữ lại **thêm một chút** sau khi cuộn ra khỏi màn hình, nhưng **cuối cùng vẫn bị hủy**. Do đó **state quan trọng cần tồn tại lâu phải đưa ra ngoài** view struct — vào model object hoặc binding từ view cha. Ví dụ pager để load thêm trang:
```swift
struct Showcase: View {
    @State var pager = ShowcasePager()
    var body: some View {
        ForEach(pager.pages) { PageView(page: $0) }
        if !pager.atEnd {
            ProgressView().progressViewStyle(.circular)
                .onAppear { pager.fetchPage() }
        }
    }
}
```
Ở đây `pager` sống ở `Showcase` (view cha), không sống trong từng `PageView`, nên dữ liệu đã tải không mất khi item cuộn đi.

**Highlight state — @State cục bộ vs @Binding (17:16 → 17:33)**
Nếu trạng thái như "được highlight" cần bền vững khi item cuộn khỏi màn hình, đừng giữ nó bằng `@State` cục bộ trong `StepView` (sẽ mất khi view bị hủy). Hãy nâng nó lên view cha và truyền xuống qua `@Binding`:
```swift
// Cha giữ nguồn sự thật
struct ContentView: View {
    @State var highlighted: Set<Step.ID> = []
}
// Con nhận binding
struct StepView: View {
    let step: Step
    @Binding var highlighted: Set<Step.ID>
}
```

### 5. Programmatic scrolling — Cuộn bằng code

**`ScrollPosition` cuộn tới view kể cả off-screen (17:58)**
Dùng binding `ScrollPosition` với `.scrollPosition($scrollPosition)`. Có thể `scrollTo(id:)` tới một view **chưa được tạo/đang off-screen** — lazy stack sẽ **ước lượng vị trí** của nó để cuộn tới:
```swift
struct ContentView: View {
    @State var scrollPosition = ScrollPosition()
    var body: some View {
        ScrollView { /* ... */ }
            .scrollPosition($scrollPosition)
            .overlay(alignment: .bottom) {
                Button { scrollToShowcase() } label: { /* ... */ }
            }
    }
    func scrollToShowcase() {
        withAnimation { scrollPosition.scrollTo(id: "showcase-header") }
    }
}
```

**Cạm bẫy lặp lại**
Vì vị trí là ước lượng, các vấn đề ở trên vẫn áp dụng và làm cuộn kém mượt:
- **Số subview động trong `ForEach`** (lọc bằng điều kiện trong view) → hại hiệu năng và độ chính xác khi cuộn tới. Vẫn nên lọc ở tầng data.
- **Layout pass do `onAppear`/`onGeometryChange` gây ra** (18:53 → 19:16): thay đổi layout *sau khi* view đã xuất hiện khiến ước lượng bị lệch và cuộn giật. Ví dụ dùng `onGeometryChange` để đo chiều cao subtitle rồi đổi chiều cao diagram là pattern nên tránh:
```swift
// TRÁNH: đổi layout sau khi view xuất hiện
Subtitle(step.subtitle)
    .onGeometryChange(for: CGFloat.self, of: \.size.height) { _, value in
        subtitleHeight = value   // gây layout pass mới
    }
```
- **Giải pháp — custom `Layout` (19:17)**: khi cần bố cục phụ thuộc lẫn nhau giữa các phần, viết một `Layout` tùy biến để tính toán trong **một lần layout** thay vì phản ứng qua nhiều pass:
```swift
struct StepView: View {
    let step: Step
    var body: some View {
        StepLayout {
            StepDiagram(diagram: step.diagram)
            Title(step.title)
            Subtitle(step.subtitle)
        }
    }
}
struct StepLayout: Layout { /* ... */ }
```

### 6. Next steps — Đúc kết các nguyên tắc
- **Tránh dựa vào absolute content size/offset** với lazy stack (chúng là ước lượng, biến động) — ưu tiên API dựa trên ID/visibility như `onScrollTargetVisibilityChange`.
- **Đừng lọc dữ liệu bằng conditional content trong leaf view** — lọc ở tầng data để số subview ổn định.
- **Thiết lập view trong `init`, không phải `onAppear`** — để tận dụng prefetch.
- **Giữ state quan trọng ngoài view struct** (dễ bị hủy khi cuộn khỏi màn hình) — dùng model object hoặc binding từ view cha.
- Cân nhắc **custom `Layout`** thay vì các layout pass phản ứng (`onGeometryChange`) để cuộn mượt hơn.

Video liên quan nên xem: *"Code-along: Build powerful drag and drop in SwiftUI" (271)*, *"Compose custom layouts with SwiftUI" (WWDC22)*, *"Stacks, Grids, and Outlines in SwiftUI" (WWDC20)*.

---

Lần này trang có đầy đủ chapter summaries + toàn bộ code samples chính thức, nên chi tiết bám sát nội dung. Muốn mình dựng một demo app Origami hoàn chỉnh (có cả phần đúng/sai để bạn so sánh hiệu năng cuộn), hay đào sâu một điểm như cơ chế ước lượng offset hoặc viết `StepLayout` custom không?