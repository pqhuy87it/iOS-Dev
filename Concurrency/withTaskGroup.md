# `withTaskGroup` trong Swift Concurrency

`withTaskGroup` là một API thuộc structured concurrency, cho phép tạo một nhóm các **child task** chạy song song với số lượng động xác định tại runtime. Đây là điểm khác biệt quan trọng với `async let` — vốn yêu cầu số lượng task cố định tại compile time.

## Các biến thể

Swift cung cấp 4 biến thể chính:

```swift
// 1. Không throw, có collect results
await withTaskGroup(of: ChildResult.self) { group in ... }

// 2. Có throw, có collect results
try await withThrowingTaskGroup(of: ChildResult.self) { group in ... }

// 3. Discarding - không collect results, tiết kiệm memory (iOS 17+)
await withDiscardingTaskGroup { group in ... }

// 4. Throwing + Discarding (iOS 17+)
try await withThrowingDiscardingTaskGroup { group in ... }
```

## Cú pháp và cơ chế hoạt động

Mẫu sử dụng cơ bản gồm 3 bước: **thêm task**, **iterate kết quả**, và **return**.

```swift
let results = await withTaskGroup(of: Int.self) { group in
    // Bước 1: thêm child tasks
    for i in 1...5 {
        group.addTask {
            try? await Task.sleep(for: .seconds(Double.random(in: 0.1...1.0)))
            return i * 2
        }
    }
    
    // Bước 2: collect results theo thứ tự completion
    var collected: [Int] = []
    for await value in group {
        collected.append(value)
    }
    return collected
}
```

Có ba điểm cần lưu ý về cơ chế. Thứ nhất, mỗi `addTask` đưa một child task vào group và task **bắt đầu chạy ngay lập tức**, không chờ bạn gọi `for await`. Thứ hai, vòng lặp `for await ... in group` sẽ duyệt các kết quả theo **thứ tự hoàn thành** chứ không phải thứ tự add — task xong trước thì xuất hiện trước. Thứ ba, group có cơ chế **automatic awaiting**: khi closure body kết thúc, group ngầm đợi tất cả task còn lại hoàn thành rồi mới return, đảm bảo không có task nào "rò rỉ" ra ngoài scope.

## Giữ thứ tự kết quả với index

Vì kết quả về theo thứ tự completion, nếu cần đúng thứ tự input phải kèm index:

```swift
func loadImagesInOrder(urls: [URL]) async -> [UIImage?] {
    await withTaskGroup(of: (Int, UIImage?).self) { group in
        for (index, url) in urls.enumerated() {
            group.addTask {
                let image = try? await ImageLoader.load(url)
                return (index, image)
            }
        }
        
        var indexed: [(Int, UIImage?)] = []
        for await pair in group {
            indexed.append(pair)
        }
        return indexed.sorted { $0.0 < $1.0 }.map(\.1)
    }
}
```

## Ví dụ thực tế trong SwiftUI

Đây là pattern điển hình: load nhiều resource song song khi view xuất hiện, dùng `.task` modifier kết hợp `withTaskGroup`:

```swift
@MainActor
@Observable
final class GalleryViewModel {
    private(set) var images: [UIImage] = []
    private(set) var isLoading = false
    private(set) var errors: [URL: Error] = [:]
    
    func loadAll(urls: [URL]) async {
        isLoading = true
        defer { isLoading = false }
        
        let results = await withTaskGroup(
            of: (URL, Result<UIImage, Error>).self
        ) { group in
            for url in urls {
                group.addTask {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        guard let image = UIImage(data: data) else {
                            throw URLError(.cannotDecodeContentData)
                        }
                        return (url, .success(image))
                    } catch {
                        return (url, .failure(error))
                    }
                }
            }
            
            var collected: [(URL, Result<UIImage, Error>)] = []
            for await item in group {
                collected.append(item)
            }
            return collected
        }
        
        // Cập nhật state — đã ở MainActor sẵn
        for (url, result) in results {
            switch result {
            case .success(let img): images.append(img)
            case .failure(let err):  errors[url] = err
            }
        }
    }
}

struct GalleryView: View {
    @State private var vm = GalleryViewModel()
    let urls: [URL]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                ForEach(vm.images.indices, id: \.self) { idx in
                    Image(uiImage: vm.images[idx]).resizable().scaledToFill()
                }
            }
        }
        .overlay { if vm.isLoading { ProgressView() } }
        .task { await vm.loadAll(urls: urls) }
    }
}
```

Lưu ý cách dùng `Result<UIImage, Error>` ở đây: thay vì dùng `withThrowingTaskGroup` (sẽ hủy toàn bộ group khi một task fail), chúng ta capture lỗi từng task riêng lẻ — phù hợp khi muốn "best effort": ảnh nào load được thì hiển thị, ảnh nào lỗi thì log lại.

## Throwing task group và xử lý lỗi

Khi cần fail-fast (một task lỗi thì hủy tất cả), dùng `withThrowingTaskGroup`:

```swift
func fetchAllOrThrow(ids: [String]) async throws -> [Post] {
    try await withThrowingTaskGroup(of: Post.self) { group in
        for id in ids {
            group.addTask {
                try await PostAPI.fetch(id: id)  // có thể throw
            }
        }
        
        var posts: [Post] = []
        for try await post in group {
            posts.append(post)
        }
        return posts
    }
}
```

Có một chi tiết tinh tế về cancellation behavior trong throwing group: khi một child task throw, **lỗi đó chỉ thực sự được "phát hiện" khi `for try await` re-throw nó**. Tại thời điểm re-throw, scope `withThrowingTaskGroup` thoát khỏi closure, và lúc này các task còn lại trong group **mới được đánh dấu cancelled**. Nếu bạn muốn cancel chủ động ngay khi có lỗi đầu tiên (ví dụ: `try await` xong là cancel ngay), pattern thường dùng là:

```swift
try await withThrowingTaskGroup(of: Post.self) { group in
    for id in ids {
        group.addTask { try await PostAPI.fetch(id: id) }
    }
    
    var posts: [Post] = []
    do {
        for try await post in group {
            posts.append(post)
        }
    } catch {
        group.cancelAll()  // chủ động cancel phần còn lại
        throw error
    }
    return posts
}
```

## Cancellation chi tiết

`group.cancelAll()` đánh dấu tất cả child task đang pending hoặc running là cancelled. **Quan trọng**: cancellation trong Swift Concurrency là **cooperative** — task không tự động dừng, mà phải tự kiểm tra:

```swift
group.addTask {
    for chunk in dataChunks {
        try Task.checkCancellation()  // throw CancellationError
        // hoặc
        if Task.isCancelled { return nil }
        
        await process(chunk)
    }
    return result
}
```

Các API system như `URLSession.data(from:)`, `Task.sleep`, file I/O với async API đã hỗ trợ cancellation sẵn — chúng sẽ throw `CancellationError` khi task bị cancel. Code custom long-running (ví dụ: vòng lặp xử lý data) cần tự thêm checkpoint.

Có một biến thể hữu ích là `addTaskUnlessCancelled` — chỉ add task nếu group chưa bị cancel, trả về `Bool` cho biết task có được add hay không:

```swift
let added = group.addTaskUnlessCancelled {
    await expensiveWork()
}
if !added { print("Group đã cancel, không add nữa") }
```

## `withDiscardingTaskGroup` (iOS 17+)

Khi không cần collect kết quả (ví dụ: fire-and-forget logging, analytics, write-only operations), dùng discarding variant để tiết kiệm bộ nhớ — group sẽ release kết quả của từng task ngay khi xong thay vì giữ lại chờ iterate:

```swift
await withDiscardingTaskGroup { group in
    for event in pendingEvents {
        group.addTask {
            await Analytics.send(event)
        }
    }
    // Không có for await — group tự đợi xong tất cả rồi return
}
```

Trước iOS 17, để mô phỏng hành vi này phải dùng `withTaskGroup(of: Void.self)` và iterate `for await _ in group` — vẫn hoạt động nhưng tốn memory hơn vì group buffer kết quả `Void`.

## So sánh với `async let`

```swift
// async let — số lượng cố định, kiểu khác nhau OK
func loadProfile(userId: String) async throws -> Profile {
    async let user = userAPI.fetch(userId)
    async let posts = postsAPI.fetch(userId: userId)
    async let friends = friendsAPI.fetch(userId: userId)
    return try await Profile(user: user, posts: posts, friends: friends)
}

// withTaskGroup — số lượng động, kiểu giống nhau
func loadAvatars(userIds: [String]) async -> [UIImage] {
    await withTaskGroup(of: UIImage?.self) { group in
        for id in userIds { group.addTask { await fetchAvatar(id) } }
        var images: [UIImage] = []
        for await img in group { if let img { images.append(img) } }
        return images
    }
}
```

Quy tắc đơn giản: **biết trước số task tại compile time → `async let`**; **số task phụ thuộc input runtime → `withTaskGroup`**. Nếu các task có kiểu trả về khác nhau, dùng `async let` (hoặc enum wrapper với `withTaskGroup`).

## Sendable và capture semantics

Closure truyền vào `addTask` phải `@Sendable` — nghĩa là mọi giá trị được capture phải an toàn để truyền giữa các concurrency domain. Đây là nguồn lỗi compile phổ biến:

```swift
class ViewModel {
    var counter = 0  // không Sendable
    
    func process(items: [Item]) async {
        await withTaskGroup(of: Void.self) { group in
            for item in items {
                group.addTask {
                    self.counter += 1  // ❌ data race — counter không được bảo vệ
                    await self.handle(item)
                }
            }
        }
    }
}
```

Cách giải quyết: hoặc đưa state về actor/MainActor, hoặc collect kết quả qua return value của task rồi update state sau khi group hoàn thành (như ví dụ `GalleryViewModel` ở trên — `images` được update sau `await`, ở MainActor isolation).

## Một số pitfall thường gặp

**Pitfall 1: Quên `for await` trong non-discarding group.** Nếu bạn add task nhưng không iterate, group vẫn đợi tất cả task xong trước khi return — nhưng kết quả bị bỏ phí. Trường hợp này nên dùng `withDiscardingTaskGroup` (iOS 17+) hoặc `of: Void.self`.

**Pitfall 2: Nhầm lẫn task group với `Task { }`.** `Task { }` tạo unstructured task, không gắn với scope hiện tại — nó tiếp tục chạy kể cả khi function tạo ra nó đã return. `withTaskGroup` thì ngược lại: tất cả child task đều bị bound vào scope của closure, đảm bảo lifecycle rõ ràng.

**Pitfall 3: `next()` thay vì `for await`.** Group có method `next() async -> ChildResult?` để lấy lần lượt từng kết quả. Hữu ích khi bạn cần early-exit:

```swift
await withTaskGroup(of: SearchResult.self) { group in
    for source in sources { group.addTask { await source.search(query) } }
    
    // Lấy kết quả đầu tiên rồi cancel phần còn lại
    if let first = await group.next() {
        group.cancelAll()
        return first
    }
    return nil
}
```

**Pitfall 4: Group quá nhiều task cùng lúc.** Nếu bạn có 10000 URLs, đừng add 10000 task — sẽ quá tải hệ thống và có thể bị throttle. Pattern cap concurrency:

```swift
let maxConcurrent = 8
await withTaskGroup(of: Data?.self) { group in
    var iterator = urls.makeIterator()
    
    // Khởi tạo `maxConcurrent` task đầu tiên
    for _ in 0..<maxConcurrent {
        if let url = iterator.next() {
            group.addTask { try? await fetch(url) }
        }
    }
    
    // Mỗi khi 1 task xong, add task mới (nếu còn URL)
    while let _ = await group.next() {
        if let url = iterator.next() {
            group.addTask { try? await fetch(url) }
        }
    }
}
```

Pattern "sliding window" này giữ luôn có đúng `maxConcurrent` task chạy đồng thời, lý tưởng cho batch processing với rate limit.

## Tổng kết khi nào dùng

Dùng `withTaskGroup` khi cần parallel execution với số lượng task động và muốn structured concurrency (lifecycle rõ ràng, cancellation propagation tự động, error propagation chuẩn). Trong SwiftUI, kết hợp với `.task` modifier là pattern phổ biến nhất để load nhiều resource song song khi view xuất hiện và tự động cancel khi view biến mất — `.task` đã wrap closure trong một Task gắn với view lifecycle, nên `withTaskGroup` bên trong sẽ kế thừa cancellation chain đó một cách tự nhiên.
