# Chuẩn bị phỏng vấn iOS Senior Developer

## Yêu cầu: Algorithms, Analytical, Problem-Solving & App Performance

Đây là một yêu cầu khá rộng, tôi sẽ chia thành từng mảng cụ thể để bạn dễ chuẩn bị.

---

## 1. Algorithms & Data Structures

Đây là nền tảng, nhà tuyển dụng thường hỏi trực tiếp hoặc lồng ghép vào bài toán thực tế iOS.

**Cần nắm vững:**

Về **Data Structures**, bạn cần thành thạo Array, Dictionary, Set (và hiểu cách Swift implement chúng dưới dạng hash table), Stack, Queue, LinkedList, Tree (đặc biệt Binary Tree), Graph, và Heap/Priority Queue.

Về **Algorithms**, tập trung vào Sorting (biết khi nào dùng gì, Swift dùng TimSort), Binary Search, BFS/DFS (rất hay gặp trong bài toán UI hierarchy), Dynamic Programming (mức cơ bản đến trung bình), và Two Pointers / Sliding Window.

**Cách luyện:** Giải LeetCode mỗi ngày, ưu tiên các bài Medium. Mục tiêu khoảng 100–150 bài, tập trung vào pattern hơn là số lượng.

---

## 2. Analytical & Problem-Solving Skills

Phần này không chỉ là giải thuật mà còn là cách bạn **tư duy và phân tích** một vấn đề kỹ thuật.

**Trong phỏng vấn, bạn thường gặp dạng câu hỏi như:**

"Ứng dụng bị lag khi scroll tableview với hàng nghìn item, bạn sẽ xử lý thế nào?" — Ở đây họ muốn thấy bạn phân tích nguyên nhân có hệ thống: cell reuse đúng chưa, image loading có async không, có tính toán nặng trên main thread không, layout có quá phức tạp không...

"Thiết kế một hệ thống caching cho ảnh" — Họ muốn thấy bạn cân nhắc trade-off giữa memory cache vs disk cache, eviction policy (LRU), thread safety, và cache invalidation.

**Kỹ năng cần rèn:** Luôn hỏi rõ yêu cầu trước khi giải, phân tích từ high-level xuống detail, đưa ra nhiều phương án và so sánh trade-off, rồi mới chọn giải pháp tối ưu.

---

## 3. Improving Application Performance (Trọng tâm cho iOS Senior)

Đây là phần **quan trọng nhất** và khác biệt rõ ràng giữa Senior và Junior.

### 3.1 — UI/Rendering Performance
Bạn cần hiểu Main Thread vs Background Thread, tại sao UI phải update trên main thread. Nắm vững cách hoạt động của **Core Animation pipeline** (Layout → Display → Prepare → Commit). Hiểu khái niệm offscreen rendering, blending, và cách tránh chúng. Biết cách dùng `CALayer` hiệu quả, tránh `cornerRadius` + `masksToBounds` gây offscreen render.

### 3.2 — Memory Management
Hiểu sâu về ARC, retain cycle, weak/unowned reference. Biết cách phát hiện memory leak bằng **Instruments (Leaks, Allocations)**. Hiểu autorelease pool và khi nào cần dùng thủ công. Nắm rõ value type vs reference type và ảnh hưởng đến memory.

### 3.3 — Networking & Data
Biết cách tối ưu API calls (batching, pagination, prefetching). Hiểu caching strategy (URLCache, custom cache). Nắm vững image loading optimization (downsampling, progressive loading). Biết dùng **Codable** hiệu quả và khi nào nên dùng lazy parsing.

### 3.4 — App Launch Time
Hiểu pre-main time vs post-main time. Biết cách giảm dynamic library loading, tối ưu `didFinishLaunching`. Hiểu dyld, rebase/binding process.

### 3.5 — Công cụ Profiling (Rất hay bị hỏi)
Thành thạo **Xcode Instruments**: Time Profiler (tìm bottleneck CPU), Allocations & Leaks (memory issues), Core Animation instrument (FPS, offscreen rendering), Network instrument, và **MetricKit / Xcode Organizer** để theo dõi performance trên production.

---

## 4. Lộ trình luyện tập đề xuất

**Tuần 1–2:** Ôn lại data structures & algorithms, giải 5–7 bài LeetCode/ngày, tập trung pattern.

**Tuần 3–4:** Đào sâu iOS performance — đọc WWDC sessions về performance (đặc biệt "Practical Approaches to Great App Performance", "Eliminate animation hitches"). Thực hành dùng Instruments trên project thật.

**Tuần 5–6:** Luyện system design câu hỏi kiểu "Design an image caching library", "Design an offline-first app". Tập trình bày có cấu trúc.

**Xuyên suốt:** Mock interview với bạn bè hoặc dùng các nền tảng như Pramp, interviewing.io.

---

# giải thích tại sao cornerRadius + masksToBounds lại gây offscreen render.

# Tại sao `cornerRadius` + `masksToBounds` gây Offscreen Rendering

## Trước tiên, hiểu Rendering Pipeline của iOS

Khi iOS vẽ UI lên màn hình, nó đi qua một pipeline gồm các bước chính. CPU chuẩn bị layer tree (layout, tạo backing store), sau đó commit cho GPU. GPU nhận các layer và thực hiện compositing — tức là gộp từng layer lại với nhau theo thứ tự từ dưới lên, rồi xuất ra frame buffer để hiển thị trên màn hình.

Bình thường, GPU render mỗi layer **một lần, theo thứ tự**, trực tiếp vào frame buffer. Đây gọi là **on-screen rendering** — nhanh và hiệu quả.

## Vấn đề xảy ra khi nào?

Khi bạn chỉ set `cornerRadius` mà **không** bật `masksToBounds`, thực tế chỉ có `backgroundColor` và `border` của layer được bo góc. Các sublayer và content bên trong vẫn vẽ bình thường, không bị cắt. GPU không cần làm gì đặc biệt.

Nhưng khi bạn bật cả hai:

```swift
view.layer.cornerRadius = 10
view.layer.masksToBounds = true // hoặc view.clipsToBounds = true
```

Lúc này bạn đang yêu cầu: "Hãy bo góc layer, **và cắt bỏ** mọi thứ vượt ra ngoài vùng bo góc đó — kể cả sublayers, content, shadow..."

## Tại sao điều này buộc phải Offscreen Render?

GPU bình thường composit theo kiểu **painter's algorithm** — vẽ layer nọ chồng lên layer kia, mỗi layer vẽ xong là "quên" luôn, đi tiếp layer tiếp theo. Nó không quay lại sửa những gì đã vẽ.

Nhưng với `cornerRadius` + `masksToBounds`, GPU gặp một bài toán mà nó **không thể giải trong một lượt vẽ tuần tự**:

Thứ nhất, nó phải vẽ tất cả sublayers (có thể nhiều lớp chồng nhau). Thứ hai, sau khi vẽ xong toàn bộ nội dung, nó mới có thể áp dụng rounded mask để cắt bỏ các pixel nằm ngoài vùng bo góc. Vấn đề là nó không thể cắt từng layer riêng lẻ rồi ghép lại, vì kết quả sẽ sai — nó cần **kết quả tổng hợp** của tất cả sublayers trước, rồi mới cắt một lần.

Vì vậy, GPU buộc phải tạo một **offscreen buffer** (một vùng bộ nhớ tạm nằm ngoài frame buffer), vẽ toàn bộ layer + sublayers vào đó, áp dụng mask bo góc lên kết quả tổng hợp, rồi mới copy kết quả cuối cùng vào frame buffer chính.

## Tại sao Offscreen Render lại "đắt"?

Có ba lý do chính. **Context switching** — GPU phải chuyển đổi giữa on-screen buffer và offscreen buffer, mỗi lần chuyển tốn thời gian. **Bộ nhớ thêm** — phải cấp phát vùng nhớ tạm cho offscreen buffer. **Vẽ hai lần** — nội dung vẽ vào offscreen buffer, rồi lại copy sang frame buffer, tức là cùng một pixel bị xử lý hai lần.

Nếu chỉ có một vài view thì không đáng kể. Nhưng trong một UITableView hay UICollectionView với hàng chục cell, mỗi cell có avatar bo tròn, thì mỗi frame (1/60s ≈ 16.67ms) GPU phải làm hàng chục lần offscreen render. Khi không kịp thời gian, frame bị drop và người dùng thấy giật.

## Cách khắc phục

**Cách 1 — Dùng `CALayer.cornerRadius` với `maskedCorners` (iOS 11+):** Từ iOS 11, nếu layer chỉ có `backgroundColor`, `border`, và `contents` (ví dụ UIImageView không có sublayer phức tạp), hệ thống có thể tối ưu mà không cần offscreen render. Tuy nhiên điều này không đảm bảo trong mọi trường hợp.

**Cách 2 — Vẽ ảnh đã bo góc sẵn bằng Core Graphics:**

```swift
func roundedImage(from image: UIImage, radius: CGFloat) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: image.size)
    return renderer.image { ctx in
        let rect = CGRect(origin: .zero, size: image.size)
        UIBezierPath(roundedRect: rect, cornerRadius: radius).addClip()
        image.draw(in: rect)
    }
}
```

Bạn xử lý bo góc trên CPU một lần, sau đó GPU chỉ cần vẽ ảnh phẳng — không cần offscreen render.

**Cách 3 — Dùng overlay mask:** Đặt một hình ảnh có "lỗ tròn" phía trên, tạo ảo giác bo góc mà GPU không cần mask gì cả.

**Cách 4 — `shouldRasterize`:**

```swift
view.layer.shouldRasterize = true
view.layer.rasterizationScale = UIScreen.main.scale
```

Vẫn offscreen render nhưng kết quả được **cache lại**. Chỉ hiệu quả khi layer không thay đổi thường xuyên. Nếu content thay đổi liên tục, cache bị invalidate và còn tệ hơn.

## Cách kiểm tra

Trong Simulator, vào menu **Debug → Color Off-screen Rendered** (highlight vàng). Hoặc dùng **Instruments → Core Animation** để đo FPS và phát hiện offscreen rendering trên device thật.

---

# giải thích cách hoạt động của Core Animation pipeline

# Core Animation Pipeline — Cách iOS Render UI lên Màn Hình

## Bức tranh tổng quan

Mỗi lần màn hình refresh (60fps = mỗi 16.67ms, hoặc 120fps = 8.33ms trên ProMotion), iOS phải hoàn thành một chu trình render đầy đủ. Chu trình này là sự phối hợp giữa **3 thành phần**: Application (app của bạn), Render Server (một process riêng của hệ thống), và GPU/Display.

Điều quan trọng cần hiểu là **app của bạn không trực tiếp vẽ pixel lên màn hình**. App chỉ mô tả "tôi muốn gì" thông qua layer tree, rồi giao cho Render Server và GPU thực hiện.

---

## Dòng chảy tổng thể

```
App Process                    Render Server Process           Hardware
───────────                    ────────────────────           ────────
Handle Event                   Decode layer tree              GPU compositing
  ↓                              ↓                              ↓
Layout                         Prepare textures               Frame Buffer
  ↓                              ↓                              ↓
Display                        Render (composit layers)       Display refreshes
  ↓
Prepare
  ↓
Commit → ─── IPC ──────────→
```

Toàn bộ quá trình này trải qua **hai frame liên tiếp**: frame N app commit, frame N+1 Render Server xử lý và GPU hiển thị. Nghĩa là từ lúc bạn thay đổi UI đến lúc người dùng thấy, có **ít nhất 1 frame delay**.

---

## Phase 1 — Layout

Đây là giai đoạn **tính toán vị trí và kích thước** của mọi view/layer.

Khi bạn gọi `setNeedsLayout()`, hệ thống không tính lại ngay mà đánh dấu view đó là "dirty". Đến đầu chu kỳ render, hệ thống duyệt từ trên xuống (top-down) qua layer tree và gọi `layoutSubviews()` trên những view bị đánh dấu.

Nếu bạn dùng Auto Layout, đây là lúc constraint engine giải hệ phương trình tuyến tính để xác định `frame` cho từng view. Đây cũng là lý do Auto Layout phức tạp (nhiều constraint lồng nhau) có thể gây bottleneck — constraint solving chạy trên CPU, trên main thread.

**Những gì tốn kém ở phase này:** Hệ thống constraint quá phức tạp hoặc có nhiều lớp nested view. Gọi `layoutIfNeeded()` nhiều lần gây layout lặp lại. Tạo/xóa constraint trong `layoutSubviews()` gây vòng lặp layout vô tận.

---

## Phase 2 — Display

Sau khi biết mỗi layer nằm ở đâu và to bao nhiêu, hệ thống cần tạo **nội dung hình ảnh** (backing store / bitmap) cho những layer cần vẽ custom.

Hệ thống gọi `draw(_:)` (hoặc `drawRect:` trong Obj-C) trên những view bị đánh dấu qua `setNeedsDisplay()`. Bên trong, Core Graphics (Quartz) tạo một bitmap context, và mọi lệnh vẽ của bạn (đường thẳng, text, hình, gradient...) được rasterize vào bitmap đó. Bitmap này trở thành `contents` của CALayer.

**Lưu ý quan trọng:** Không phải mọi layer đều cần phase này. Một `UIView` với chỉ `backgroundColor` không cần backing store riêng — GPU có thể fill color trực tiếp. Chỉ khi bạn override `draw(_:)` hoặc dùng Core Graphics thì mới thực sự tạo bitmap. Đây cũng là lý do Apple khuyến khích **tránh override `draw(_:)` nếu không cần thiết** — mỗi bitmap tốn memory bằng `width × height × 4 bytes`.

---

## Phase 3 — Prepare

Giai đoạn này xử lý **image decoding và conversion**.

Khi bạn gán một UIImage (từ PNG/JPEG) cho UIImageView, ảnh đó vẫn đang ở dạng compressed. GPU không hiểu PNG hay JPEG — nó chỉ hiểu bitmap thô. Nên ở phase này, hệ thống decode ảnh nén thành bitmap (uncompressed pixel data).

Đây là lý do tại sao một ảnh JPEG 100KB có thể chiếm vài MB memory sau khi decode (ví dụ ảnh 2000×2000 pixel × 4 bytes/pixel = ~16MB bitmap). Phase này cũng xử lý image format conversion nếu ảnh không ở format mà GPU hỗ trợ trực tiếp.

**Vì sao điều này quan trọng:** Image decoding mặc định xảy ra trên main thread, ngay trước commit. Với nhiều ảnh lớn, đây là nguyên nhân phổ biến gây jank khi scroll. Giải pháp là **decode trước trên background thread**, đó chính là điều mà các thư viện như SDWebImage, Kingfisher làm.

---

## Phase 4 — Commit

Đây là bước cuối trong app process. Hệ thống đóng gói toàn bộ **layer tree** (bao gồm hierarchy, properties, bitmap contents) và gửi qua **IPC (Inter-Process Communication)** sang Render Server.

Layer tree được serialize thành một cấu trúc gọi là **render tree**. Render Server là một process riêng (`backboardd` trên iOS), chạy ở priority rất cao, chịu trách nhiệm thực sự đưa nội dung lên GPU.

**Commit transaction tốn kém khi:** Layer tree quá sâu hoặc quá nhiều layer (mỗi layer đều phải serialize). Có nhiều bitmap lớn cần truyền qua IPC. Tạo quá nhiều layer trong một frame.

---

## Sau Commit — Render Server & GPU

Sau khi nhận render tree, Render Server giải mã và chuẩn bị các drawing commands cho GPU.

GPU thực hiện **compositing** — lấy từng layer (giờ là các texture/quad), áp dụng transform, opacity, mask, filter, rồi vẽ chồng lên nhau theo thứ tự (painter's algorithm) vào frame buffer. Khi frame buffer sẵn sàng, display controller đọc và hiển thị lên màn hình ở VSync tiếp theo.

Đây là lúc offscreen rendering xảy ra nếu GPU gặp các thao tác không thể composit trong một lượt (như `cornerRadius` + `masksToBounds`, `shadow`, complex mask...).

---

## Tổng kết bằng ví dụ thực tế

Giả sử người dùng scroll một UITableView, một cell mới xuất hiện:

Đầu tiên ở **Layout**, Auto Layout tính frame cho cell, avatar imageView, labels. Tiếp theo ở **Display**, nếu có custom drawing (ví dụ vẽ badge bằng Core Graphics), bitmap được tạo. Sau đó ở **Prepare**, ảnh avatar JPEG được decode thành bitmap thô. Cuối cùng ở **Commit**, toàn bộ layer tree của cell được gửi cho Render Server, GPU composit và hiển thị.

Tất cả phải xong trong **16.67ms** (ở 60fps). Nếu vượt quá, frame bị drop — người dùng thấy giật.

---

## Từ đây suy ra các nguyên tắc tối ưu

Ở phase Layout, giảm độ phức tạp constraint, tránh nested layout quá sâu, cân nhắc dùng manual layout cho cell phức tạp.

Ở phase Display, tránh override `draw(_:)` khi không cần thiết, dùng layer properties (backgroundColor, cornerRadius) thay vì tự vẽ.

Ở phase Prepare, decode ảnh trước trên background thread, downsample ảnh về đúng kích thước hiển thị thay vì dùng ảnh gốc lớn.

Ở phase Commit, giữ layer tree nông (flat hierarchy), tránh tạo/xóa nhiều layer mỗi frame, dùng `shouldRasterize` hợp lý để cache layer phức tạp.

Ở phía GPU, tránh offscreen rendering, giảm blending (dùng opaque view khi có thể), tránh layer quá lớn vượt kích thước max texture của GPU (4096×4096 trên các device cũ).

Bạn muốn đi sâu hơn vào phần nào? Ví dụ Auto Layout performance, image downsampling, hay cách dùng Instruments để profile từng phase?

---

# Binary Search, BFS/DFS (rất hay gặp trong bài toán UI hierarchy)

# Binary Search, BFS/DFS trong iOS

## Binary Search

### Nguyên lý cơ bản

Binary Search hoạt động trên một tập dữ liệu **đã được sắp xếp**. Thay vì duyệt từng phần tử (O(n)), mỗi bước bạn so sánh với phần tử giữa và loại bỏ một nửa, đạt được O(log n).

```swift
func binarySearch<T: Comparable>(_ array: [T], target: T) -> Int? {
    var low = 0
    var high = array.count - 1
    
    while low <= high {
        let mid = low + (high - low) / 2  // tránh integer overflow
        if array[mid] == target {
            return mid
        } else if array[mid] < target {
            low = mid + 1
        } else {
            high = mid - 1
        }
    }
    return nil
}
```

### Binary Search trong iOS thực tế

**Tìm vị trí insert trong sorted array:** Rất phổ biến khi bạn maintain một danh sách đã sort (ví dụ danh sách tin nhắn theo timestamp). Thay vì sort lại toàn bộ mỗi lần thêm tin nhắn mới (O(n log n)), bạn binary search vị trí cần insert (O(log n)).

```swift
// Tìm vị trí insert để giữ array sorted
func insertionIndex<T: Comparable>(for value: T, in array: [T]) -> Int {
    var low = 0
    var high = array.count
    
    while low < high {
        let mid = low + (high - low) / 2
        if array[mid] < value {
            low = mid + 1
        } else {
            high = mid
        }
    }
    return low
}

// Ứng dụng: insert tin nhắn mới vào đúng vị trí
var messages: [Message] = [] // đã sort theo timestamp

func insertMessage(_ newMsg: Message) {
    let index = insertionIndex(for: newMsg, in: messages)
    messages.insert(newMsg, at: index)
    tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
}
```

**UICollectionView / UITableView — tìm visible cell:** Khi bạn có hàng nghìn item với kích thước khác nhau, hệ thống cần nhanh chóng xác định "tại offset Y này, cell nào đang hiển thị?" Nếu bạn pre-calculate và lưu mảng cumulative heights (đã sorted theo bản chất), binary search cho bạn câu trả lời trong O(log n) thay vì duyệt tuyến tính.

```swift
// cachedOffsets = [0, 44, 108, 200, 310, ...]  (cumulative heights)
// Tìm cell tại scroll offset 250:
func cellIndex(at scrollOffset: CGFloat) -> Int {
    var low = 0
    var high = cachedOffsets.count - 1
    
    while low < high {
        let mid = low + (high - low) / 2
        if cachedOffsets[mid] <= scrollOffset {
            low = mid + 1
        } else {
            high = mid
        }
    }
    return low - 1  // cell chứa offset này
}
```

Thực tế, đây chính là cách `UICollectionViewFlowLayout` hoạt động bên trong khi xác định visible cells.

**Tìm kiếm trong data đã sort:** Danh bạ contacts (sort theo tên), danh sách sản phẩm (sort theo giá), search suggestion... tất cả đều là ứng dụng tự nhiên của binary search.

---

## BFS & DFS

### Tại sao liên quan đến UI?

Cấu trúc UI trong iOS **bản chất là một cây (tree)**:

```
UIWindow
  └── UIView (rootView)
        ├── UINavigationBar
        │     ├── UILabel (title)
        │     └── UIButton (back)
        └── UIView (contentView)
              ├── UIImageView (avatar)
              ├── UILabel (name)
              └── UIStackView
                    ├── UILabel (detail1)
                    └── UILabel (detail2)
```

Mỗi `UIView` có property `subviews: [UIView]` (children) và `superview: UIView?` (parent). Đây chính là một tree structure, và mọi thao tác "tìm kiếm", "duyệt qua" view hierarchy đều quy về BFS hoặc DFS.

### DFS — Depth-First Search

DFS đi sâu nhất có thể trước khi quay lại. Có hai cách implement: đệ quy (tự nhiên, dễ đọc) và dùng stack (tránh stack overflow với tree sâu).

```swift
// DFS đệ quy — tìm tất cả UILabel trong view hierarchy
func findAllLabels(in view: UIView) -> [UILabel] {
    var results: [UILabel] = []
    
    if let label = view as? UILabel {
        results.append(label)
    }
    
    for subview in view.subviews {
        results.append(contentsOf: findAllLabels(in: subview))
    }
    
    return results
}

let allLabels = findAllLabels(in: self.view)
```

```swift
// DFS dùng stack — tránh đệ quy sâu
func findAllLabelsIterative(in root: UIView) -> [UILabel] {
    var results: [UILabel] = []
    var stack: [UIView] = [root]
    
    while !stack.isEmpty {
        let current = stack.removeLast()
        
        if let label = current as? UILabel {
            results.append(label)
        }
        
        // Thêm subviews vào stack (reversed để duyệt đúng thứ tự)
        stack.append(contentsOf: current.subviews.reversed())
    }
    
    return results
}
```

**Thực tế iOS dùng DFS ở đâu?**

`hitTest(_:with:)` — hệ thống tìm view nào nhận touch event. Nó duyệt DFS từ window xuống, theo thứ tự ngược (subview cuối cùng, vì nó nằm trên cùng visually), tìm view sâu nhất chứa touch point.

```swift
// Đây là cách hitTest hoạt động bên trong (simplified)
override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
    guard self.point(inside: point, with: event) else { return nil }
    
    // Duyệt từ subview trên cùng xuống (reversed = DFS ưu tiên front-most)
    for subview in subviews.reversed() {
        let convertedPoint = subview.convert(point, from: self)
        if let hitView = subview.hitTest(convertedPoint, with: event) {
            return hitView
        }
    }
    
    return self  // không có subview nào nhận → chính mình nhận
}
```

**Responder Chain** cũng là DFS ngược — từ view sâu nhất đi lên qua superview, đến view controller, đến window, đến application, tìm ai xử lý event.

### BFS — Breadth-First Search

BFS duyệt **theo từng tầng** (level-by-level), dùng queue.

```swift
// BFS — tìm view đầu tiên thuộc kiểu T gần root nhất
func findFirstView<T: UIView>(ofType type: T.Type, in root: UIView) -> T? {
    var queue: [UIView] = [root]
    
    while !queue.isEmpty {
        let current = queue.removeFirst()
        
        if let found = current as? T {
            return found
        }
        
        queue.append(contentsOf: current.subviews)
    }
    
    return nil
}

// Tìm UITextField đầu tiên (gần nhất) trong hierarchy
let firstTextField = findFirstView(ofType: UITextField.self, in: self.view)
```

**Khi nào dùng BFS thay vì DFS?**

Khi bạn muốn tìm phần tử **gần root nhất**, BFS đảm bảo tìm thấy nó trước. Ví dụ: tìm first responder gần nhất, tìm scrollView chứa một view nào đó. Hoặc khi bạn cần xử lý theo từng "tầng" — ví dụ debug print view hierarchy theo level.

```swift
// In view hierarchy theo level (BFS)
func printHierarchy(of root: UIView) {
    var queue: [(view: UIView, depth: Int)] = [(root, 0)]
    
    while !queue.isEmpty {
        let (view, depth) = queue.removeFirst()
        let indent = String(repeating: "  ", count: depth)
        print("\(indent)\(type(of: view)) - frame: \(view.frame)")
        
        for subview in view.subviews {
            queue.append((subview, depth + 1))
        }
    }
}
```

---

## Các bài toán phỏng vấn thường gặp kết hợp BFS/DFS + iOS

**Bài 1 — Tìm Lowest Common Ancestor (LCA) của hai view:**

Cho hai UIView, tìm superview chung gần nhất. Đây là bài toán LCA kinh điển trên tree.

```swift
func lowestCommonAncestor(_ viewA: UIView, _ viewB: UIView) -> UIView? {
    // Thu thập tất cả ancestors của viewA
    var ancestors = Set<ObjectIdentifier>()
    var current: UIView? = viewA
    while let view = current {
        ancestors.insert(ObjectIdentifier(view))
        current = view.superview
    }
    
    // Đi lên từ viewB, ancestor đầu tiên nằm trong set là LCA
    current = viewB
    while let view = current {
        if ancestors.contains(ObjectIdentifier(view)) {
            return view
        }
        current = view.superview
    }
    
    return nil
}
```

Ứng dụng thực tế: khi bạn cần convert coordinate giữa hai view không cùng nhánh, hệ thống cần tìm common ancestor để tính toán transform.

**Bài 2 — Flatten view hierarchy (tối ưu performance):**

Đếm tổng số layer trong hierarchy bằng BFS/DFS, nếu quá nhiều thì cần flatten — giảm nesting depth bằng cách vẽ gộp vào một layer duy nhất.

```swift
func countLayers(in root: UIView) -> Int {
    var count = 1
    for subview in root.subviews {
        count += countLayers(in: subview)
    }
    return count
}
```

**Bài 3 — Tìm tất cả view thỏa điều kiện (generic DFS/BFS):**

```swift
extension UIView {
    func findAll(where predicate: (UIView) -> Bool) -> [UIView] {
        var results: [UIView] = []
        var stack: [UIView] = [self]
        
        while !stack.isEmpty {
            let current = stack.removeLast()
            if predicate(current) {
                results.append(current)
            }
            stack.append(contentsOf: current.subviews)
        }
        return results
    }
}

// Tìm tất cả view bị hidden
let hiddenViews = rootView.findAll { $0.isHidden }

// Tìm tất cả view có accessibility identifier
let taggedViews = rootView.findAll { $0.accessibilityIdentifier != nil }
```

---

## So sánh nhanh: khi nào dùng gì

**Binary Search** phù hợp khi dữ liệu đã sorted và bạn cần tìm/insert nhanh — ví dụ tìm vị trí cell tại offset, insert item vào sorted list, search suggestion.

**DFS** phù hợp khi cần tìm phần tử sâu nhất hoặc duyệt toàn bộ tree — ví dụ hitTest, tìm tất cả view thuộc kiểu nào đó, serialize view hierarchy.

**BFS** phù hợp khi cần tìm phần tử gần root nhất hoặc xử lý theo level — ví dụ tìm first responder gần nhất, debug print hierarchy theo tầng, tìm shortest path trong view tree.

Bạn muốn tôi đi tiếp vào Dynamic Programming, Two Pointers / Sliding Window, hay chuyển sang mảng khác?

---

# "Thiết kế một hệ thống caching cho ảnh" — trade-off giữa memory cache vs disk cache, eviction policy (LRU), thread safety, và cache invalidation.

# Thiết kế hệ thống Image Caching cho iOS

Đây là một câu hỏi system design rất phổ biến trong phỏng vấn iOS Senior. Tôi sẽ đi từ bài toán, qua từng thành phần, đến implementation.

---

## Bài toán đặt ra

Giả sử bạn có một app hiển thị feed ảnh (như Instagram, Twitter). Mỗi lần scroll, hàng chục ảnh cần hiển thị. Nếu mỗi lần đều tải từ network thì UX cực tệ — chậm, tốn data, và giật. Bạn cần một hệ thống cache sao cho ảnh đã tải một lần thì lần sau hiển thị gần như tức thì.

---

## Kiến trúc tổng thể — Two-Level Cache

```
Request ảnh
    │
    ▼
┌─────────────┐    HIT     ┌──────────────┐
│ Memory Cache │ ─────────→ │ Return image │
└─────────────┘             └──────────────┘
    │ MISS
    ▼
┌─────────────┐    HIT     ┌──────────────┐
│  Disk Cache  │ ─────────→ │ Decode → lưu │
│              │            │ vào Memory   │
└─────────────┘             │ → Return     │
    │ MISS                  └──────────────┘
    ▼
┌─────────────┐             ┌──────────────┐
│   Network   │ ──────────→ │ Lưu Disk →   │
│  Download   │             │ Decode →     │
└─────────────┘             │ lưu Memory → │
                            │ Return       │
                            └──────────────┘
```

Tại sao hai tầng? Vì mỗi tầng có đặc điểm khác nhau, và chúng bổ sung cho nhau.

---

## 1. Memory Cache vs Disk Cache — Trade-offs

### Memory Cache

Memory cache lưu ảnh **đã decode** (UIImage / bitmap) trực tiếp trong RAM.

**Ưu điểm:** Cực nhanh, truy cập nhanh ngang truy cập biến thông thường, không cần decode lại (ảnh đã ở dạng bitmap sẵn sàng render). Đây là lý do scroll mượt — GPU nhận bitmap ngay lập tức.

**Nhược điểm:** RAM có giới hạn (iPhone thường cho app dùng khoảng 1–1.5GB tuỳ device, vượt quá sẽ bị hệ thống kill). Ảnh decoded rất nặng — một ảnh 1000×1000 pixel chiếm `1000 × 1000 × 4 bytes = ~4MB` RAM. Chỉ 100 ảnh như vậy đã là 400MB. Và khi app bị background hoặc hệ thống cần RAM, memory cache bị xoá sạch.

**Trong iOS**, `NSCache` là lựa chọn tự nhiên cho memory cache vì nó tự động evict khi memory pressure cao, thread-safe sẵn, và không retain key (khác với NSDictionary).

```swift
class MemoryCache {
    private let cache = NSCache<NSString, UIImage>()
    
    init(countLimit: Int = 100, totalCostLimit: Int = 50 * 1024 * 1024) {
        // Giới hạn 100 ảnh hoặc 50MB (cái nào đạt trước)
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }
    
    func image(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func store(_ image: UIImage, forKey key: String) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
}
```

Ở đây `cost` rất quan trọng — bạn tính bằng byte thực tế của bitmap, không phải kích thước file JPEG. NSCache dùng `totalCostLimit` để biết khi nào cần evict.

### Disk Cache

Disk cache lưu ảnh **ở dạng file** (thường là data gốc, PNG/JPEG) trên ổ đĩa.

**Ưu điểm:** Dung lượng lớn hơn nhiều (có thể cho phép hàng trăm MB đến vài GB). Persist qua app restart — user mở app lại vẫn có ảnh cached. Không bị ảnh hưởng bởi memory pressure.

**Nhược điểm:** Chậm hơn memory rất nhiều — cần file I/O (đọc từ flash storage), rồi decode từ JPEG/PNG sang bitmap, cả hai đều tốn thời gian. Vì vậy disk cache **không bao giờ nên đọc trên main thread**.

```swift
class DiskCache {
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "com.app.diskcache.io",
                                         attributes: .concurrent)
    
    init(name: String, maxSize: Int = 200 * 1024 * 1024) { // 200MB
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent(name)
        
        try? fileManager.createDirectory(at: cacheDirectory,
                                          withIntermediateDirectories: true)
    }
    
    private func filePath(forKey key: String) -> URL {
        // Hash key để tránh ký tự đặc biệt trong filename
        let hashedName = key.sha256()
        return cacheDirectory.appendingPathComponent(hashedName)
    }
    
    func data(forKey key: String) -> Data? {
        let path = filePath(forKey: key)
        return try? Data(contentsOf: path)
    }
    
    func store(_ data: Data, forKey key: String) {
        let path = filePath(forKey: key)
        try? data.write(to: path)
        
        // Lưu metadata (thời gian truy cập) cho LRU
        setAccessDate(Date(), forKey: key)
    }
}
```

### Tại sao cần cả hai?

Memory cache phục vụ **tốc độ** — khi user scroll qua lại, ảnh xuất hiện ngay lập tức. Disk cache phục vụ **persistence** — khi app restart hoặc memory cache bị xoá do memory pressure, không cần tải lại từ network. Đây là pattern **L1/L2 cache** giống như trong kiến trúc CPU.

---

## 2. Eviction Policy — LRU (Least Recently Used)

Cache có giới hạn dung lượng. Khi đầy, bạn phải quyết định **xoá item nào** để nhường chỗ cho item mới. Đây gọi là eviction policy.

### Tại sao LRU?

LRU dựa trên giả định: ảnh bạn **xem gần đây nhất** có khả năng cao sẽ xem lại. Ảnh xem lâu nhất rồi thì ít khả năng cần lại. Trong ngữ cảnh feed app, điều này rất hợp lý — user scroll xuống, ảnh phía trên cùng ít khả năng quay lại xem ngay.

### LRU hoạt động thế nào?

LRU cần hai thao tác đều O(1): **get** (truy cập item → đánh dấu nó là "recently used") và **put** (thêm item mới, nếu đầy thì xoá item "least recently used").

Để đạt O(1) cho cả hai, bạn dùng **HashMap + Doubly Linked List**:

```
Doubly Linked List (thứ tự: đầu = most recent, cuối = least recent):

HEAD ↔ [Ảnh D] ↔ [Ảnh A] ↔ [Ảnh C] ↔ [Ảnh B] ↔ TAIL
         ↑           ↑           ↑           ↑
         │           │           │           │
HashMap: D→node     A→node     C→node     B→node

Khi truy cập ảnh C:
  1. HashMap tìm node C → O(1)
  2. Rút node C khỏi vị trí hiện tại → O(1)  
  3. Đưa node C lên đầu list → O(1)

HEAD ↔ [Ảnh C] ↔ [Ảnh D] ↔ [Ảnh A] ↔ [Ảnh B] ↔ TAIL

Khi cache đầy, thêm ảnh E:
  1. Xoá node cuối (Ảnh B) → O(1)
  2. Xoá B khỏi HashMap → O(1)
  3. Thêm node E vào đầu → O(1)
  4. Thêm E vào HashMap → O(1)
```

### Implementation

```swift
class LRUCache<Key: Hashable, Value> {
    private let capacity: Int
    private var map: [Key: Node<Key, Value>] = [:]
    private let list = DoublyLinkedList<Key, Value>()
    
    init(capacity: Int) {
        self.capacity = capacity
    }
    
    func get(_ key: Key) -> Value? {
        guard let node = map[key] else { return nil }
        // Di chuyển lên đầu (đánh dấu most recently used)
        list.moveToHead(node)
        return node.value
    }
    
    func put(_ key: Key, value: Value) {
        if let existingNode = map[key] {
            existingNode.value = value
            list.moveToHead(existingNode)
        } else {
            // Cache đầy → evict node cuối
            if map.count >= capacity {
                if let tail = list.removeTail() {
                    map.removeValue(forKey: tail.key)
                }
            }
            let newNode = Node(key: key, value: value)
            list.addToHead(newNode)
            map[key] = newNode
        }
    }
}

class Node<Key, Value> {
    let key: Key
    var value: Value
    var prev: Node?
    var next: Node?
    
    init(key: Key, value: Value) {
        self.key = key
        self.value = value
    }
}

class DoublyLinkedList<Key, Value> {
    // Dummy head và tail để đơn giản hoá edge cases
    private let head = Node<Key, Value>(key: nil as! Key, 
                                         value: nil as! Value)
    private let tail = Node<Key, Value>(key: nil as! Key, 
                                         value: nil as! Value)
    
    init() {
        head.next = tail
        tail.prev = head
    }
    
    func addToHead(_ node: Node<Key, Value>) {
        node.prev = head
        node.next = head.next
        head.next?.prev = node
        head.next = node
    }
    
    func removeNode(_ node: Node<Key, Value>) {
        node.prev?.next = node.next
        node.next?.prev = node.prev
    }
    
    func moveToHead(_ node: Node<Key, Value>) {
        removeNode(node)
        addToHead(node)
    }
    
    func removeTail() -> Node<Key, Value>? {
        guard let last = tail.prev, last !== head else { return nil }
        removeNode(last)
        return last
    }
}
```

### Tại sao NSCache không đủ?

`NSCache` có eviction tự động nhưng bạn **không kiểm soát được** chính sách evict. Nó không đảm bảo LRU — Apple không public thuật toán bên trong. Với memory cache, NSCache thường đủ tốt vì hệ thống sẽ evict khi memory pressure. Nhưng với disk cache, bạn cần tự implement LRU vì hệ thống không tự dọn cache directory cho bạn.

### Các policy khác cần biết khi phỏng vấn

**LFU (Least Frequently Used)** xoá item ít được truy cập nhất. Phức tạp hơn, phù hợp khi một số ảnh được xem đi xem lại rất nhiều (ví dụ avatar của chính user). **FIFO** thì đơn giản nhất nhưng không thông minh — có thể xoá ảnh đang cần. **TTL-based** (Time To Live) thì xoá theo thời gian — phù hợp khi data thay đổi thường xuyên. Trong thực tế, nhiều hệ thống kết hợp LRU + TTL.

---

## 3. Thread Safety

Image cache bị truy cập từ nhiều thread đồng thời: main thread đọc ảnh để hiển thị, background threads download và decode ảnh rồi ghi vào cache. Nếu không xử lý thread safety, bạn sẽ gặp crash do race condition.

### Vấn đề cụ thể

```swift
// Thread A (đang đọc):          Thread B (đang ghi):
let img = map["avatar"]          map["avatar"] = newImage
// → Crash! Dictionary bị mutate trong khi đang đọc
```

### Giải pháp 1 — Serial Queue

```swift
class ThreadSafeCache {
    private var storage: [String: UIImage] = [:]
    private let queue = DispatchQueue(label: "com.app.cache.serial")
    
    func image(forKey key: String) -> UIImage? {
        queue.sync {
            return storage[key]
        }
    }
    
    func store(_ image: UIImage, forKey key: String) {
        queue.sync {
            storage[key] = image
        }
    }
}
```

Đơn giản nhưng tất cả thao tác bị serialize — nếu một write đang chạy, mọi read phải đợi. Với cache bị truy cập thường xuyên, đây là bottleneck.

### Giải pháp 2 — Concurrent Queue + Barrier (Tối ưu hơn)

```swift
class ThreadSafeCache {
    private var storage: [String: UIImage] = [:]
    private let queue = DispatchQueue(label: "com.app.cache.concurrent",
                                       attributes: .concurrent)
    
    func image(forKey key: String) -> UIImage? {
        queue.sync {
            return storage[key]
        }
    }
    
    func store(_ image: UIImage, forKey key: String) {
        queue.async(flags: .barrier) {
            self.storage[key] = image
        }
    }
}
```

Đây là pattern **multiple readers, single writer**. Nhiều thread có thể đọc đồng thời (concurrent read) vì đọc không thay đổi data. Khi cần ghi, barrier flag đảm bảo: đợi tất cả read hiện tại hoàn thành, block mọi read/write mới, thực hiện write, rồi mở lại cho read.

```
Timeline:
──READ──READ──READ──│ BARRIER: WRITE │──READ──READ──
                    │   (exclusive)  │
```

### Giải pháp 3 — NSCache (đã thread-safe)

`NSCache` thread-safe sẵn nên cho memory cache, nó là lựa chọn đơn giản nhất. Nhưng disk cache vẫn cần tự handle vì file I/O không thread-safe.

### Giải pháp 4 — Actor (Swift Concurrency, modern approach)

```swift
actor ImageCache {
    private var memoryCache: [String: UIImage] = [:]
    
    func image(forKey key: String) -> UIImage? {
        return memoryCache[key]
    }
    
    func store(_ image: UIImage, forKey key: String) {
        memoryCache[key] = image
    }
}

// Sử dụng:
let cache = ImageCache()
let img = await cache.image(forKey: "avatar")
```

Actor đảm bảo **tại một thời điểm chỉ có một caller thực thi** bên trong actor — không cần lock, queue, hay barrier. Đây là hướng đi modern nhất, nhưng cần hiểu async/await.

---

## 4. Cache Invalidation

Phil Karlton từng nói: "There are only two hard things in Computer Science: cache invalidation and naming things." Cache invalidation thực sự là phần khó nhất.

### Bài toán

Ảnh trên server có thể thay đổi (user đổi avatar, ảnh sản phẩm được update). Cache cũ không biết điều này và tiếp tục trả về ảnh cũ. User thấy thông tin sai.

### Chiến lược 1 — URL-based Invalidation

Đây là cách phổ biến nhất và đơn giản nhất. Mỗi khi ảnh thay đổi, server trả về URL mới.

```
Trước: https://cdn.app.com/avatar/user123.jpg
Sau:   https://cdn.app.com/avatar/user123.jpg?v=2
Hoặc:  https://cdn.app.com/avatar/user123_a8f3b2.jpg
```

Cache dùng URL làm key, URL mới tức là key mới, tức là cache miss, tức là tải ảnh mới. Ảnh cũ sẽ bị evict tự nhiên qua LRU khi cache đầy. Đơn giản, hiệu quả, không cần logic phức tạp phía client.

### Chiến lược 2 — TTL (Time-To-Live)

Mỗi cache entry có "hạn sử dụng". Sau thời gian đó, entry bị coi là stale và cần tải lại.

```swift
struct CacheEntry {
    let image: UIImage
    let createdAt: Date
    let ttl: TimeInterval  // ví dụ: 24 * 60 * 60 = 1 ngày
    
    var isExpired: Bool {
        return Date().timeIntervalSince(createdAt) > ttl
    }
}

func image(forKey key: String) -> UIImage? {
    guard let entry = storage[key] else { return nil }
    
    if entry.isExpired {
        storage.removeValue(forKey: key)
        return nil  // cache miss → trigger re-download
    }
    
    return entry.image
}
```

TTL phù hợp cho data thay đổi theo thời gian nhưng không cần real-time. Ví dụ: ảnh sản phẩm cập nhật mỗi ngày thì TTL 12–24 giờ là hợp lý.

### Chiến lược 3 — ETag / If-Modified-Since

Client lưu ETag từ server cùng với cached image. Khi cần kiểm tra, gửi request với header `If-None-Match`. Server trả 304 Not Modified (không gửi lại data) nếu ảnh chưa đổi, hoặc 200 với ảnh mới nếu đã đổi.

```swift
func fetchImage(url: URL, cachedETag: String?) async throws -> (UIImage, String?) {
    var request = URLRequest(url: url)
    
    if let etag = cachedETag {
        request.setValue(etag, forHTTPHeaderField: "If-None-Match")
    }
    
    let (data, response) = try await URLSession.shared.data(for: request)
    let httpResponse = response as! HTTPURLResponse
    
    if httpResponse.statusCode == 304 {
        // Ảnh chưa thay đổi → dùng cache
        return (cachedImage!, cachedETag)
    }
    
    // Ảnh mới → decode và cache
    let newETag = httpResponse.value(forHTTPHeaderField: "ETag")
    let image = UIImage(data: data)!
    return (image, newETag)
}
```

Tiết kiệm bandwidth (304 response rất nhỏ) nhưng vẫn tốn một round-trip network. Phù hợp cho ảnh quan trọng cần chính xác (avatar, ảnh profile).

### Chiến lược 4 — Push-based Invalidation

Server chủ động thông báo khi ảnh thay đổi, qua WebSocket hoặc push notification. Client nhận thông báo và xoá cache entry tương ứng. Realtime nhất nhưng phức tạp nhất, cần infrastructure backend hỗ trợ.

### Trong thực tế, kết hợp nhiều chiến lược

Avatar user dùng URL-based (đổi avatar → URL mới). Ảnh sản phẩm dùng TTL 24 giờ kết hợp ETag. Ảnh banner marketing dùng TTL ngắn (1–2 giờ). Static assets (icon, illustration) thì cache "vĩnh viễn" với URL có hash.

---

## 5. Tổng hợp — Full Implementation

```swift
actor ImageCacheSystem {
    static let shared = ImageCacheSystem()
    
    // L1: Memory cache (decoded UIImage, nhanh)
    private let memoryCache = NSCache<NSString, UIImage>()
    
    // L2: Disk cache (encoded data, persist)
    private let diskCache: DiskCache
    
    // Tránh duplicate downloads
    private var inFlightRequests: [URL: Task<UIImage, Error>] = [:]
    
    init() {
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        diskCache = DiskCache(name: "ImageCache", maxSize: 200_000_000)
    }
    
    func image(for url: URL) async throws -> UIImage {
        let key = url.absoluteString
        
        // 1. Check memory cache
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        
        // 2. Check disk cache
        if let data = diskCache.data(forKey: key) {
            let image = try await decodeToBitmap(data: data, targetSize: nil)
            let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
            memoryCache.setObject(image, forKey: key as NSString, cost: cost)
            return image
        }
        
        // 3. Check if already downloading (coalesce requests)
        if let existingTask = inFlightRequests[url] {
            return try await existingTask.value
        }
        
        // 4. Download
        let task = Task<UIImage, Error> {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Lưu disk (encoded data, nhẹ)
            diskCache.store(data, forKey: key)
            
            // Decode trên background thread
            let image = try await decodeToBitmap(data: data, targetSize: nil)
            
            // Lưu memory (decoded bitmap, nhanh)
            let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
            memoryCache.setObject(image, forKey: key as NSString, cost: cost)
            
            return image
        }
        
        inFlightRequests[url] = task
        
        do {
            let image = try await task.value
            inFlightRequests.removeValue(forKey: url)
            return image
        } catch {
            inFlightRequests.removeValue(forKey: url)
            throw error
        }
    }
    
    // Downsample: decode ảnh đúng kích thước cần hiển thị
    // Ảnh 4000x4000 chỉ hiển thị 100x100 → decode luôn ở 100x100
    private func decodeToBitmap(data: Data, targetSize: CGSize?) async throws -> UIImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw CacheError.decodeFailed
        }
        
        let options: [CFString: Any]
        if let size = targetSize {
            let maxDimension = max(size.width, size.height) * UIScreen.main.scale
            options = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                kCGImageSourceShouldCacheImmediately: true
            ]
        } else {
            options = [kCGImageSourceShouldCacheImmediately: true]
        }
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, 
                                                                  options as CFDictionary) else {
            throw CacheError.decodeFailed
        }
        
        return UIImage(cgImage: cgImage)
    }
}
```

---

## 6. Những điểm nâng cao — ghi điểm trong phỏng vấn

**Request coalescing:** Khi 10 cell cùng request cùng một URL (ví dụ cùng avatar), chỉ download 1 lần. Các request sau "đợi" kết quả của request đầu. Phần `inFlightRequests` ở trên xử lý việc này.

**Image downsampling:** Ảnh gốc 4000×4000 nhưng hiển thị trong avatar 50×50. Nếu decode full size, tốn 64MB RAM cho một ảnh. Downsample khi decode tiết kiệm bộ nhớ cực lớn. Đây chính là kỹ thuật Apple recommend trong WWDC session "Images and Graphics Best Practices".

**Prefetching:** Kết hợp với `UICollectionViewDataSourcePrefetching` để tải trước ảnh sắp hiển thị, người dùng scroll đến thì ảnh đã sẵn sàng.

**Cancel không cần thiết:** Khi cell bị reuse (scroll đi), cancel download của ảnh cũ. Tránh lãng phí bandwidth và tránh ảnh sai hiển thị trên cell sai.

**Disk cache cleanup:** Chạy định kỳ (ví dụ khi app vào background) để xoá file cũ, giữ tổng dung lượng disk cache trong giới hạn, ưu tiên xoá theo LRU.

Bạn muốn tôi đi tiếp vào chủ đề nào? Ví dụ thiết kế offline-first app, hay đi sâu hơn vào image downsampling, hay chuyển sang luyện performance profiling với Instruments?

---
