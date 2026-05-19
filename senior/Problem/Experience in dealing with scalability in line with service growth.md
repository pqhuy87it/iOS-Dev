# Scalability in Line with Service Growth — Góc nhìn Senior iOS Developer

Đây là một yêu cầu rất quan trọng trong job description của Senior iOS Developer. Nó không chỉ nói về backend scaling mà đề cập đến khả năng **thiết kế và duy trì một ứng dụng iOS có thể "lớn lên" cùng với sự phát triển của dịch vụ/sản phẩm** mà không bị sụp đổ về mặt kỹ thuật. Mình sẽ phân tích chi tiết từng khía cạnh.

---

## 1. Code Architecture Scalability

Khi dịch vụ phát triển, codebase sẽ ngày càng lớn. Một Senior iOS Developer cần có kinh nghiệm chọn và áp dụng kiến trúc phù hợp để codebase không trở thành "big ball of mud."

**Vấn đề thực tế:** Một app ban đầu có 5 màn hình dùng MVC hoạt động tốt, nhưng khi phát triển lên 50-100 màn hình, ViewController trở nên cồng kềnh (Massive View Controller), khó test và khó maintain.

**Cách tiếp cận:**

- Chuyển sang kiến trúc module hóa như **MVVM-C (Coordinator)**, **VIPER**, hoặc **Clean Architecture** tùy theo quy mô và đặc thù team.
- Áp dụng **modular architecture** — tách app thành các Swift Package hoặc framework độc lập (ví dụ: `NetworkingModule`, `AuthModule`, `PaymentModule`). Điều này cho phép nhiều team làm việc song song mà không conflict.
- Sử dụng **dependency injection** (ví dụ: Swinject, Factory) để các module có thể thay thế và test độc lập.

**Ví dụ thực tế:** Grab ban đầu là một app gọi xe đơn giản, sau đó mở rộng sang food delivery, payment, insurance... Mỗi vertical trở thành một module riêng, được develop bởi các team khác nhau nhưng vẫn chạy trong cùng một super-app.

---

## 2. Performance Scalability

Khi lượng data và user tăng, app phải xử lý nhiều dữ liệu hơn mà vẫn mượt mà.

**Các vấn đề thường gặp:**

- **List/Collection performance:** Hiển thị 100 items thì dễ, nhưng 10,000+ items thì cần áp dụng pagination, `UICollectionViewCompositionalLayout` với `DiffableDataSource`, hoặc prefetching strategy. Trên SwiftUI thì cần hiểu rõ cách `LazyVStack`/`LazyVGrid` hoạt động và tránh re-render không cần thiết.

- **Memory management:** Khi service mở rộng, app load nhiều image và data hơn. Cần implement image caching strategy (NSCache, disk cache), sử dụng `autoreleasepool` trong vòng lặp lớn, và profile bằng Instruments để detect memory leak và retain cycle.

- **Concurrency:** Khi có nhiều API call đồng thời (ví dụ: home screen cần gọi 10 API khác nhau), cần dùng **Swift Concurrency** (`async/await`, `TaskGroup`) hoặc **Combine** một cách hợp lý để tránh thread explosion và race condition.

```swift
// Ví dụ: Load nhiều section data đồng thời
func loadHomeScreen() async throws -> HomeData {
    async let banners = api.fetchBanners()
    async let recommendations = api.fetchRecommendations()
    async let promotions = api.fetchPromotions()
    
    return HomeData(
        banners: try await banners,
        recommendations: try await recommendations,
        promotions: try await promotions
    )
}
```

---

## 3. Network Layer Scalability

Khi service grow, số lượng API endpoint tăng lên, format có thể thay đổi, và yêu cầu về reliability cao hơn.

**Kinh nghiệm cần có:**

- **API versioning handling:** App cần support nhiều API version cùng lúc vì không phải user nào cũng update app ngay. Thiết kế network layer với abstraction layer để dễ dàng migrate giữa các version.

- **Offline-first / caching strategy:** Khi user base lớn, không phải ai cũng có mạng tốt. Cần implement caching bằng Core Data, Realm, hoặc đơn giản là `URLCache` strategy. Mô hình "cache first, network update" giúp app responsive hơn.

- **GraphQL adoption:** Khi service phức tạp, REST có thể dẫn đến over-fetching hoặc under-fetching. Nhiều company chuyển sang GraphQL (dùng Apollo iOS) để client chỉ lấy đúng data cần thiết, giảm tải cho cả client lẫn server.

- **WebSocket / real-time data:** Khi service mở rộng tính năng real-time (chat, live tracking, live pricing), cần kinh nghiệm xử lý persistent connection, reconnection strategy, và data synchronization.

---

## 4. Build & CI/CD Scalability

Codebase lớn hơn đồng nghĩa với build time tăng lên, nhiều developer hơn đồng nghĩa với merge conflict nhiều hơn.

**Kinh nghiệm cần có:**

- **Build time optimization:** Sử dụng Swift Package Manager với pre-built binary (XCFramework) cho các module ít thay đổi, giảm build time từ 15 phút xuống còn 3-4 phút.
- **Feature flags:** Dùng hệ thống feature flag (Firebase Remote Config, LaunchDarkly) để enable/disable feature mà không cần release app mới. Khi có 20+ team cùng contribute, feature flag là bắt buộc.
- **Automated testing at scale:** Unit test, UI test, snapshot test được chạy tự động trên CI (Bitrise, GitHub Actions, Jenkins). Khi codebase lớn, cần chiến lược test parallelization và selective testing (chỉ chạy test liên quan đến module bị thay đổi).

---

## 5. Data Layer Scalability

Khi lượng data local tăng (ví dụ: messaging app lưu hàng triệu tin nhắn), cần kinh nghiệm tối ưu local storage.

- **Core Data:** Sử dụng `NSFetchedResultsController` với batch fetching, `NSBatchInsertRequest` / `NSBatchDeleteRequest` cho bulk operation thay vì xử lý từng object.
- **Database migration:** Khi schema thay đổi qua nhiều version, cần lightweight migration hoặc custom migration strategy mà không làm mất data của user.
- **Data synchronization:** Implement conflict resolution khi data được thay đổi cả offline lẫn online (last-write-wins, merge strategy...).

---

## 6. Team & Process Scalability

Đây là khía cạnh "mềm" nhưng cực kỳ quan trọng ở level Senior.

- **Code review & coding convention:** Khi team từ 3 người lên 30 người, cần enforce coding standard bằng SwiftLint rules, PR template, và architecture decision records (ADR).
- **Documentation:** Viết technical documentation cho các module, API contract, và architecture decision để onboarding developer mới nhanh hơn.
- **Knowledge sharing:** Ownership model rõ ràng cho từng module, nhưng vẫn đảm bảo cross-team knowledge thông qua tech talk và code review rotation.

---

## Tóm lại

"Scalability in line with service growth" đòi hỏi Senior iOS Developer phải có tư duy **anticipate growth** — không chỉ giải quyết vấn đề hiện tại mà còn thiết kế solution có khả năng mở rộng khi user base tăng 10x, feature tăng 5x, và team size tăng 3x. Đây là sự khác biệt cốt lõi giữa một mid-level developer (giải quyết vấn đề trước mắt) và một senior developer (thiết kế cho tương lai mà không over-engineer ở hiện tại).

# 1. Áp dụng pagination, UICollectionViewCompositionalLayout với DiffableDataSource, hoặc prefetching strategy để hiển thị 10,000+ items

# Chi tiết về List/Collection Performance tại Scale lớn

## Vấn đề gốc rễ

Khi hiển thị 100 items, bạn có thể "naive" load tất cả vào một array, gán vào `dataSource`, và mọi thứ vẫn mượt. Nhưng khi lên 10,000+ items, bạn sẽ gặp các vấn đề:

**Memory:** Nếu load toàn bộ 10,000 object (mỗi object kèm image, text, metadata) vào RAM cùng lúc, app có thể dùng hàng trăm MB RAM và bị hệ thống kill.

**CPU / Main Thread:** Nếu mỗi lần data thay đổi bạn gọi `reloadData()`, UIKit phải tính toán lại layout cho toàn bộ collection — gây frame drop, UI giật lag.

**Network:** Không thể gọi API lấy 10,000 items trong một request — response sẽ rất lớn, thời gian chờ lâu, và tốn bandwidth.

Giờ mình đi vào từng giải pháp cụ thể.

---

## 1. Pagination (Phân trang)

### Bản chất

Thay vì load toàn bộ data một lần, bạn chia data thành từng "trang" nhỏ (ví dụ: mỗi trang 20 items) và chỉ load trang tiếp theo khi user scroll gần đến cuối list.

### Hai kiểu pagination phổ biến

**Offset-based pagination:**

```
GET /api/products?offset=0&limit=20    // Trang 1: items 0-19
GET /api/products?offset=20&limit=20   // Trang 2: items 20-39
GET /api/products?offset=40&limit=20   // Trang 3: items 40-59
```

Nhược điểm: Nếu data bị insert/delete giữa 2 lần gọi, items có thể bị trùng hoặc bị bỏ sót. Ví dụ, bạn vừa load trang 1 (offset=0), rồi có 1 item mới được thêm vào đầu list → khi load trang 2 (offset=20), item cuối cùng của trang 1 sẽ xuất hiện lại ở đầu trang 2.

**Cursor-based pagination (phổ biến hơn):**

```
GET /api/products?limit=20                          // Trang 1
GET /api/products?limit=20&after=cursor_abc123      // Trang 2
GET /api/products?limit=20&after=cursor_def456      // Trang 3
```

`cursor` thường là ID hoặc timestamp của item cuối cùng trong trang trước. Cách này ổn định hơn vì nó dựa vào vị trí tuyệt đối của item, không bị ảnh hưởng bởi insert/delete.

### Implementation trong iOS

```swift
class ProductListViewModel {
    private var products: [Product] = []
    private var currentCursor: String?
    private var isLoading = false
    private var hasMoreData = true
    
    // Gọi lần đầu khi vào màn hình
    func loadInitialPage() async {
        isLoading = true
        let response = try await api.fetchProducts(limit: 20, after: nil)
        products = response.items
        currentCursor = response.nextCursor
        hasMoreData = response.nextCursor != nil
        isLoading = false
    }
    
    // Gọi khi user scroll gần cuối list
    func loadNextPageIfNeeded(currentIndex: Int) async {
        // Kiểm tra: đã đang load chưa? Còn data không?
        // currentIndex gần cuối list chưa? (threshold: 5 items trước cuối)
        guard !isLoading,
              hasMoreData,
              currentIndex >= products.count - 5 else { return }
        
        isLoading = true
        let response = try await api.fetchProducts(limit: 20, after: currentCursor)
        products.append(contentsOf: response.items)
        currentCursor = response.nextCursor
        hasMoreData = response.nextCursor != nil
        isLoading = false
    }
}
```

### Khi nào trigger load trang tiếp theo?

Bạn cần detect khi user scroll gần cuối. Có 2 cách phổ biến:

```swift
// Cách 1: Trong cellForItemAt — đơn giản nhất
func collectionView(_ collectionView: UICollectionView,
                    cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    // Khi đang configure cell gần cuối → trigger load more
    viewModel.loadNextPageIfNeeded(currentIndex: indexPath.item)
    
    let cell = collectionView.dequeueReusableCell(...)
    // configure cell...
    return cell
}

// Cách 2: Dùng UICollectionViewDataSourcePrefetching (tốt hơn)
// Sẽ giải thích chi tiết ở phần Prefetching bên dưới
```

---

## 2. DiffableDataSource

### Vấn đề với cách cũ (truyền thống)

Trước iOS 13, khi data thay đổi, bạn thường làm thế này:

```swift
// ❌ Cách cũ — nhiều vấn đề
func updateData(newProducts: [Product]) {
    self.products = newProducts
    collectionView.reloadData() // Reload TOÀN BỘ collection
}
```

**Vấn đề của `reloadData()`:**

- Không có animation — UI nhảy đột ngột, user mất context đang scroll ở đâu.
- Tốn performance — UIKit phải recalculate layout cho TẤT CẢ visible cells, kể cả cells không thay đổi.
- Trải nghiệm user kém khi list dài.

Nếu muốn animation, bạn phải tự tính diff và gọi `performBatchUpdates`:

```swift
// ❌ Cách cũ với animation — rất dễ crash
collectionView.performBatchUpdates({
    collectionView.insertItems(at: [IndexPath(item: 20, section: 0)])
    collectionView.deleteItems(at: [IndexPath(item: 5, section: 0)])
    collectionView.moveItem(at: IndexPath(item: 3, section: 0),
                            to: IndexPath(item: 10, section: 0))
}, completion: nil)
```

Cách này **cực kỳ dễ crash** với lỗi kinh điển:

> "Invalid update: invalid number of items in section 0. The number of items contained in an existing section after the update must be equal to..."

Lý do: Bạn phải đảm bảo thứ tự insert/delete/move chính xác, và số lượng items trước/sau phải khớp. Khi data phức tạp (nhiều section, items thay đổi đồng thời), việc tính toán manual này gần như không thể làm đúng 100%.

### DiffableDataSource giải quyết như thế nào

`UICollectionViewDiffableDataSource` (iOS 13+) tự động tính toán sự khác biệt giữa state cũ và state mới, rồi apply animated update chính xác.

```swift
// Bước 1: Định nghĩa data types — phải conform Hashable
enum Section: Hashable {
    case banner
    case recommended
    case allProducts
}

struct Product: Hashable {
    let id: String          // Unique identifier
    let name: String
    let price: Double
    let imageURL: URL?
    
    // Hashable dựa trên id để DiffableDataSource 
    // biết item nào là item nào
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Product, rhs: Product) -> Bool {
        // So sánh tất cả properties để detect content change
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.price == rhs.price
    }
}
```

```swift
// Bước 2: Tạo dataSource
typealias DataSource = UICollectionViewDiffableDataSource<Section, Product>

private lazy var dataSource: DataSource = {
    DataSource(collectionView: collectionView) { collectionView, indexPath, product in
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "ProductCell",
            for: indexPath
        ) as! ProductCell
        cell.configure(with: product)
        return cell
    }
}()
```

```swift
// Bước 3: Apply snapshot khi data thay đổi
func applyNewData(products: [Product]) {
    var snapshot = NSDiffableDataSourceSnapshot<Section, Product>()
    
    snapshot.appendSections([.banner, .recommended, .allProducts])
    snapshot.appendItems(bannerProducts, toSection: .banner)
    snapshot.appendItems(recommendedProducts, toSection: .recommended)
    snapshot.appendItems(products, toSection: .allProducts)
    
    // ✅ DiffableDataSource TỰ ĐỘNG:
    // 1. So sánh snapshot mới với snapshot hiện tại
    // 2. Tính ra items nào insert, delete, move, update
    // 3. Apply changes với smooth animation
    // 4. KHÔNG BAO GIỜ CRASH vì inconsistency
    dataSource.apply(snapshot, animatingDifferences: true)
}
```

### Cách diff algorithm hoạt động bên trong

Khi bạn gọi `apply(snapshot)`, hệ thống sẽ:

```
Snapshot cũ:  [A, B, C, D, E]
Snapshot mới: [A, C, F, D, E, G]

Diff result:
  - Delete: B (index 1)
  - Insert: F (index 2)  
  - Insert: G (index 5)
  - C moved from index 2 → index 1
  
→ UIKit tự động animate từng thay đổi
```

Thuật toán diff này dựa trên **Hashable** protocol — đó là lý do items phải conform Hashable. Hệ thống dùng `hash` để identify item nào là item nào, và `==` để detect content có thay đổi không.

### Pagination + DiffableDataSource kết hợp

```swift
// Load thêm trang mới — chỉ cần append vào snapshot hiện tại
func appendNewPage(newProducts: [Product]) {
    var snapshot = dataSource.snapshot() // Lấy snapshot HIỆN TẠI
    snapshot.appendItems(newProducts, toSection: .allProducts) // Thêm items mới
    dataSource.apply(snapshot, animatingDifferences: true)
    // → Chỉ có items mới được animate insert
    // → Các items cũ KHÔNG bị touch → không bị re-render
    // → Performance tối ưu
}
```

---

## 3. UICollectionViewCompositionalLayout

### Vấn đề với Flow Layout

`UICollectionViewFlowLayout` (mặc định) chỉ support layout đơn giản: grid hoặc list. Khi app scale lên, một màn hình thường có **nhiều section với layout khác nhau** — ví dụ Home screen của Shopee hay Netflix:

```
┌─────────────────────────────┐
│  [Banner carousel]          │ ← Horizontal scroll, full width
├─────────────────────────────┤
│  [Cat1] [Cat2] [Cat3] [Cat4│ ← Horizontal scroll, small items
├─────────────────────────────┤
│  ★ Recommended for you      │
│  [──] [──] [──] →          │ ← Horizontal scroll, medium cards
├─────────────────────────────┤
│  ★ All Products             │
│  [□] [□]                    │ ← Vertical grid, 2 columns
│  [□] [□]                    │
│  [□] [□]                    │
│  ... (infinite scroll)      │
└─────────────────────────────┘
```

Với FlowLayout, bạn phải nest nhiều UICollectionView bên trong nhau (collection view trong cell của collection view khác) — code phức tạp, khó maintain, và performance kém.

### CompositionalLayout giải quyết như thế nào

`UICollectionViewCompositionalLayout` cho phép bạn define layout **khác nhau cho từng section** trong cùng MỘT collection view:

```swift
func createLayout() -> UICollectionViewCompositionalLayout {
    return UICollectionViewCompositionalLayout { sectionIndex, environment in
        switch Section(rawValue: sectionIndex) {
        case .banner:
            return self.createBannerSection()
        case .categories:
            return self.createCategoriesSection()
        case .recommended:
            return self.createHorizontalCardSection()
        case .allProducts:
            return self.createProductGridSection()
        default:
            return self.createDefaultSection()
        }
    }
}
```

```swift
// Section: Banner — full width, horizontal paging
func createBannerSection() -> NSCollectionLayoutSection {
    // Item chiếm toàn bộ group
    let item = NSCollectionLayoutItem(
        layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                         heightDimension: .fractionalHeight(1.0))
    )
    
    // Group = full width, height 200pt
    let group = NSCollectionLayoutGroup.horizontal(
        layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                         heightDimension: .absolute(200)),
        subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.orthogonalScrollingBehavior = .paging // ← Horizontal paging
    return section
}

// Section: Product Grid — 2 columns, vertical scroll
func createProductGridSection() -> NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(
        layoutSize: .init(widthDimension: .fractionalWidth(0.5),  // 50% width = 2 columns
                         heightDimension: .estimated(250))         // Dynamic height
    )
    item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4,
                                                 bottom: 4, trailing: 4)
    
    // Group chứa 2 items ngang
    let group = NSCollectionLayoutGroup.horizontal(
        layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                         heightDimension: .estimated(250)),
        subitems: [item, item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    // Không set orthogonalScrollingBehavior → scroll theo main axis (vertical)
    return section
}
```

### Tại sao điều này quan trọng cho scalability?

Khi service grow, Product team sẽ liên tục thêm section mới vào Home screen (flash sale, live streaming, stories...). Với CompositionalLayout, bạn chỉ cần thêm một case mới trong switch và define layout cho section đó — **không cần refactor existing code**. Không cần nested collection view. Tất cả trong một collection view duy nhất với một data source duy nhất.

---

## 4. Prefetching Strategy

### Bản chất

Prefetching là cơ chế **load data trước khi cell xuất hiện trên màn hình**, để khi user scroll đến, data đã sẵn sàng → không bị giật.

### UICollectionViewDataSourcePrefetching

```swift
class ProductListVC: UIViewController,
                     UICollectionViewDataSourcePrefetching {

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.prefetchDataSource = self
    }
    
    // Hệ thống gọi method này khi predict rằng 
    // các cells tại indexPaths SẮP xuất hiện
    func collectionView(_ collectionView: UICollectionView,
                        prefetchItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            let product = products[indexPath.item]
            
            // 1. Prefetch image
            ImagePrefetcher.shared.prefetch(url: product.imageURL)
            
            // 2. Trigger pagination nếu gần cuối list
            if indexPath.item >= products.count - 5 {
                Task { await viewModel.loadNextPage() }
            }
        }
    }
    
    // Khi user scroll ngược lại — cancel prefetch không cần nữa
    func collectionView(_ collectionView: UICollectionView,
                        cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            let product = products[indexPath.item]
            ImagePrefetcher.shared.cancel(url: product.imageURL)
        }
    }
}
```

### Image Prefetching chi tiết

Đây là bottleneck lớn nhất khi list có nhiều items với images:

```swift
class ImagePrefetcher {
    static let shared = ImagePrefetcher()
    
    // NSCache tự động evict khi memory pressure
    private let cache = NSCache<NSURL, UIImage>()
    // Track active tasks để có thể cancel
    private var activeTasks: [URL: Task<Void, Never>] = [:]
    
    func prefetch(url: URL?) {
        guard let url = url else { return }
        
        // Đã có trong cache → không cần fetch
        if cache.object(forKey: url as NSURL) != nil { return }
        
        // Đang fetch rồi → không duplicate
        if activeTasks[url] != nil { return }
        
        activeTasks[url] = Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    cache.setObject(image, forKey: url as NSURL)
                }
            } catch {
                // Network error — cell sẽ hiện placeholder
            }
            activeTasks[url] = nil
        }
    }
    
    func cancel(url: URL?) {
        guard let url = url else { return }
        activeTasks[url]?.cancel()
        activeTasks[url] = nil
    }
    
    func image(for url: URL?) -> UIImage? {
        guard let url = url else { return nil }
        return cache.object(forKey: url as NSURL)
    }
}
```

---

## 5. Tất cả kết hợp lại — Full Picture

Khi bạn có 10,000+ items, giải pháp hoàn chỉnh là **kết hợp cả 4 thứ trên**:

```
User mở app
    │
    ▼
Load trang 1 (20 items) từ API     ← Pagination
    │
    ▼
Apply snapshot vào DiffableDataSource  ← Animated, crash-free
    │
    ▼
CompositionalLayout render UI         ← Mỗi section layout khác nhau
    │
    ▼
User scroll xuống
    │
    ▼
Prefetching trigger                    ← Load images cho cells sắp hiện
    │
    ├─ Gần cuối list? → Load trang 2  ← Pagination tiếp
    │                      │
    │                      ▼
    │              Append vào snapshot  ← Chỉ animate items mới
    │
    ▼
User tiếp tục scroll → Cycle lặp lại
```

Mỗi thành phần giải quyết một vấn đề khác nhau, và chúng bổ sung cho nhau. Thiếu một trong bốn, app sẽ gặp vấn đề ở scale lớn: thiếu pagination thì hết RAM, thiếu DiffableDataSource thì crash hoặc giật, thiếu CompositionalLayout thì code phức tạp khi UI grow, thiếu prefetching thì user thấy loading placeholder liên tục khi scroll.

# 2.SwiftUI: Hiểu rõ cách LazyVStack/LazyVGrid hoạt động và tránh re-render không cần thiết.

# LazyVStack / LazyVGrid và vấn đề Re-render trong SwiftUI

## Trước tiên: Lazy vs Non-Lazy

### Non-Lazy (VStack / VGrid)

```swift
// ❌ Non-lazy: TẤT CẢ 10,000 views được tạo NGAY LẬP TỨC
ScrollView {
    VStack {
        ForEach(products) { product in
            ProductRow(product: product)
        }
    }
}
```

Khi SwiftUI gặp `VStack`, nó sẽ **khởi tạo body của TẤT CẢ child views ngay lập tức** — kể cả những view ở tận cuối list mà user chưa scroll đến. Với 10,000 items, điều này nghĩa là:

- 10,000 `ProductRow` body được evaluate
- 10,000 image load có thể bị trigger
- Memory spike khổng lồ
- App freeze vài giây khi mở màn hình

### Lazy (LazyVStack / LazyVGrid)

```swift
// ✅ Lazy: Chỉ tạo views KHI CHÚNG SẮP XUẤT HIỆN trên màn hình
ScrollView {
    LazyVStack {
        ForEach(products) { product in
            ProductRow(product: product)
        }
    }
}
```

`LazyVStack` chỉ khởi tạo body của child view **khi view đó sắp enter visible area**. Màn hình hiển thị 10 items → chỉ khoảng 12-15 views được tạo (thêm vài cái buffer trên dưới).

**Quan trọng:** "Lazy" ở đây nghĩa là **lazy initialization**, nhưng **KHÔNG recycle** views như `UICollectionView` của UIKit. Khi user scroll qua một view, view đó vẫn tồn tại trong memory. Scroll đến item 5,000 nghĩa là có 5,000 views đã được tạo trong memory. Đây là khác biệt rất lớn so với UIKit cell reuse.

```
UIKit UICollectionView:
Scroll qua 5,000 items → Chỉ ~15 cells tồn tại (reuse)

SwiftUI LazyVStack:
Scroll qua 5,000 items → 5,000 views tồn tại trong memory
(chỉ là chúng được tạo lazy, không phải upfront)
```

---

## LazyVGrid chi tiết

`LazyVGrid` là phiên bản grid của `LazyVStack` — cùng cơ chế lazy nhưng sắp xếp items theo dạng lưới.

```swift
// Grid 2 cột
let columns = [
    GridItem(.flexible(), spacing: 8),
    GridItem(.flexible(), spacing: 8)
]

ScrollView {
    LazyVGrid(columns: columns, spacing: 8) {
        ForEach(products) { product in
            ProductCard(product: product)
        }
    }
    .padding(.horizontal, 8)
}
```

### Các kiểu GridItem

```swift
// 1. Flexible — chia đều không gian có sẵn
// 2 cột flexible = mỗi cột chiếm 50% width
let columns = [
    GridItem(.flexible()),
    GridItem(.flexible())
]

// 2. Fixed — width cố định
// Mỗi cột rộng đúng 150pt
let columns = [
    GridItem(.fixed(150)),
    GridItem(.fixed(150))
]

// 3. Adaptive — TỰ ĐỘNG tính số cột dựa trên width có sẵn
// Mỗi item tối thiểu 150pt → trên iPhone hiện 2 cột, iPad hiện 4-5 cột
let columns = [
    GridItem(.adaptive(minimum: 150))
]
```

`adaptive` đặc biệt hữu ích khi app cần support nhiều screen size — bạn không cần hardcode số cột.

---

## Vấn đề cốt lõi: Re-render không cần thiết

Đây là phần quan trọng nhất. SwiftUI dùng cơ chế **declarative rendering** — bạn khai báo UI trông như thế nào dựa trên state, và SwiftUI tự quyết định khi nào re-render. Vấn đề là SwiftUI có thể **re-render nhiều hơn bạn nghĩ**.

### Cách SwiftUI quyết định re-render

SwiftUI re-evaluate body của một view khi:

1. **State thay đổi** (`@State`, `@Binding`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`)
2. **Parent view re-render** — mặc định, khi parent re-render, SwiftUI sẽ **check** tất cả child views

Quá trình check diễn ra như sau:

```
Parent body re-evaluate
    │
    ▼
SwiftUI tạo "new version" của child view
    │
    ▼
So sánh child view mới với child view cũ
    │
    ├── Nếu KHÁC → re-render child (gọi lại body)
    │
    └── Nếu GIỐNG → skip, giữ nguyên child
```

Câu hỏi là: **SwiftUI so sánh bằng cách nào?**

- Nếu view conform `Equatable` → dùng `==` để so sánh
- Nếu KHÔNG conform `Equatable` → SwiftUI compare từng stored property. Nếu **bất kỳ property nào thay đổi** (hoặc không thể so sánh được) → re-render.

---

## Các trường hợp gây re-render không cần thiết

### Trường hợp 1: ObservableObject với nhiều published properties

```swift
// ❌ MỌI view observe ViewModel đều re-render
//    khi BẤT KỲ @Published nào thay đổi
class HomeViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var banners: [Banner] = []
    @Published var cartItemCount: Int = 0     // Thay đổi thường xuyên
    @Published var searchText: String = ""     // Thay đổi mỗi keystroke
}

struct HomeView: View {
    @StateObject var vm = HomeViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack {
                // Mỗi khi user gõ searchText
                // → vm objectWillChange fire
                // → HomeView body re-evaluate
                // → TẤT CẢ ProductRow bị check lại
                ForEach(vm.products) { product in
                    ProductRow(product: product)
                }
            }
        }
    }
}
```

**Vấn đề:** `@Published var searchText` thay đổi mỗi keystroke → `objectWillChange` signal fire → SwiftUI re-evaluate toàn bộ `HomeView.body` → mọi `ProductRow` bị check. Với 1,000 items visible, điều này xảy ra **mỗi ký tự user gõ** — gây lag rõ rệt.

**Giải pháp: Tách ViewModel nhỏ hơn**

```swift
// ✅ Tách thành nhiều ViewModel nhỏ, mỗi cái chỉ chứa 
//    data liên quan đến phần UI tương ứng

class ProductListViewModel: ObservableObject {
    @Published var products: [Product] = []
}

class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
}

class CartViewModel: ObservableObject {
    @Published var itemCount: Int = 0
}

struct HomeView: View {
    @StateObject var productVM = ProductListViewModel()
    @StateObject var searchVM = SearchViewModel()
    @StateObject var cartVM = CartViewModel()
    
    var body: some View {
        VStack {
            SearchBar(vm: searchVM)
            // searchText thay đổi → CHỈ SearchBar re-render
            // ProductList KHÔNG bị ảnh hưởng
            ProductList(vm: productVM)
        }
    }
}
```

**Giải pháp iOS 17+: `@Observable` macro**

```swift
// ✅ @Observable chỉ trigger re-render cho properties
//    mà view THỰC SỰ ĐỌC trong body
@Observable
class HomeViewModel {
    var products: [Product] = []
    var banners: [Banner] = []
    var cartItemCount: Int = 0
    var searchText: String = ""
}

struct ProductList: View {
    let vm: HomeViewModel
    
    var body: some View {
        LazyVStack {
            // View này CHỈ đọc vm.products
            // → CHỈ re-render khi products thay đổi
            // → searchText, cartItemCount thay đổi → KHÔNG re-render
            ForEach(vm.products) { product in
                ProductRow(product: product)
            }
        }
    }
}
```

`@Observable` (Observation framework) theo dõi chính xác property nào được **access trong body** và chỉ trigger re-render khi property đó thay đổi. Đây là cải tiến rất lớn so với `ObservableObject` + `@Published`.

---

### Trường hợp 2: Closure và object mới mỗi lần render

```swift
// ❌ Mỗi lần HomeView re-render, mỗi ProductRow nhận
//    một CLOSURE MỚI → SwiftUI không thể so sánh → re-render tất cả
struct HomeView: View {
    @StateObject var vm = HomeViewModel()
    
    var body: some View {
        LazyVStack {
            ForEach(vm.products) { product in
                ProductRow(
                    product: product,
                    onTap: { vm.selectProduct(product) }  // ← Closure MỚI mỗi lần
                )
            }
        }
    }
}

struct ProductRow: View {
    let product: Product
    let onTap: () -> Void  // ← Closure KHÔNG Equatable
                           // → SwiftUI KHÔNG THỂ so sánh
                           // → LUÔN coi là "thay đổi" → re-render
    
    var body: some View {
        // ... UI phức tạp, load image, tính toán...
    }
}
```

**Vấn đề cốt lõi:** `() -> Void` không conform `Equatable`. SwiftUI không thể biết closure cũ và mới có "giống nhau" hay không → default là coi như khác → re-render.

**Giải pháp 1: Dùng Equatable**

```swift
// ✅ Conform Equatable, chỉ so sánh dựa trên product data
struct ProductRow: View, Equatable {
    let product: Product
    let onTap: () -> Void
    
    // Tự define equality — bỏ qua closure
    static func == (lhs: ProductRow, rhs: ProductRow) -> Bool {
        lhs.product == rhs.product
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                AsyncImage(url: product.imageURL)
                Text(product.name)
                Spacer()
                Text("$\(product.price, specifier: "%.2f")")
            }
        }
    }
}

// Sử dụng với .equatable() modifier (hoặc EquatableView)
ForEach(vm.products) { product in
    ProductRow(
        product: product,
        onTap: { vm.selectProduct(product) }
    )
    .equatable()  // ← Bảo SwiftUI dùng Equatable để compare
}
```

**Giải pháp 2: Truyền data thay vì closure (ưu tiên hơn)**

```swift
// ✅ Truyền ViewModel vào, để ProductRow tự gọi action
// Không có closure → tất cả properties đều Equatable
struct ProductRow: View {
    let product: Product
    @EnvironmentObject var vm: HomeViewModel
    
    var body: some View {
        Button {
            vm.selectProduct(product)
        } label: {
            // ... UI
        }
    }
}
```

---

### Trường hợp 3: Tạo object mới trong body

```swift
// ❌ Mỗi lần body evaluate → DateFormatter MỚI được tạo
struct ProductRow: View {
    let product: Product
    
    var body: some View {
        VStack {
            Text(product.name)
            // DateFormatter() được gọi MỖI LẦN body chạy
            Text(DateFormatter.localizedString(
                from: product.createdAt,
                dateStyle: .medium,
                timeStyle: .none
            ))
            
            // Gradient mới MỖI LẦN
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
```

**Giải pháp:**

```swift
// ✅ Khai báo static/constant bên ngoài body
struct ProductRow: View {
    let product: Product
    
    // Tạo 1 lần, dùng lại mãi
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
    
    // Computed property thay vì tạo trong body
    private var formattedDate: String {
        Self.dateFormatter.string(from: product.createdAt)
    }
    
    var body: some View {
        VStack {
            Text(product.name)
            Text(formattedDate)
        }
    }
}
```

---

### Trường hợp 4: ForEach với identity không ổn định

```swift
// ❌ THẢM HỌA: id thay đổi mỗi lần → SwiftUI coi là 
//    TOÀN BỘ items mới → destroy và recreate TẤT CẢ views
ForEach(products, id: \.self.hashValue) { product in
    ProductRow(product: product)
}

// ❌ TƯƠNG TỰ: index thay đổi khi insert/delete
ForEach(Array(products.enumerated()), id: \.offset) { index, product in
    ProductRow(product: product)
}
```

**Vấn đề:** SwiftUI dùng `id` để track identity của mỗi item. Nếu id thay đổi mà data không đổi, SwiftUI nghĩ item cũ bị xóa và item mới được thêm → **destroy view cũ + tạo view mới hoàn toàn** → mất state, mất animation, tốn performance.

```swift
// ✅ Dùng stable, unique identifier
struct Product: Identifiable {
    let id: String  // UUID hoặc server ID — KHÔNG BAO GIỜ thay đổi
    var name: String
    var price: Double
}

ForEach(products) { product in  // Tự dùng \.id vì conform Identifiable
    ProductRow(product: product)
}
```

---

## Cách Debug Re-render

### Cách 1: Print trong body

```swift
struct ProductRow: View {
    let product: Product
    
    var body: some View {
        // Mỗi lần body được evaluate → print
        let _ = print("🔄 ProductRow body called: \(product.id)")
        
        HStack {
            Text(product.name)
        }
    }
}
// Nếu thấy 1,000 dòng print khi chỉ thay đổi searchText
// → bạn có vấn đề re-render
```

### Cách 2: Self._printChanges() (Debug only)

```swift
struct ProductRow: View {
    let product: Product
    
    var body: some View {
        // iOS 15+ debug tool — cho biết TẠI SAO view re-render
        let _ = Self._printChanges()
        // Output: "ProductRow: @self changed."
        // hoặc:  "ProductRow: @identity changed."
        // hoặc:  "ProductRow: _product changed."
        
        HStack { Text(product.name) }
    }
}
```

Ý nghĩa output:

- `@self changed` → struct instance mới (property nào đó khác, hoặc closure mới)
- `@identity changed` → SwiftUI coi đây là view hoàn toàn mới (id thay đổi)
- `_someProperty changed` → property cụ thể nào thay đổi

### Cách 3: Instruments — SwiftUI profiling

Xcode Instruments có **SwiftUI** instrument cho phép bạn visualize:

- View nào re-render, bao nhiêu lần
- Body evaluation mất bao lâu
- View nào gây re-render cascade

---

## Tổng hợp Best Practices cho LazyVStack/LazyVGrid tại Scale

```swift
// ✅ COMPLETE EXAMPLE — Scalable SwiftUI List

// 1. Stable identity
struct Product: Identifiable, Equatable {
    let id: String
    var name: String
    var price: Double
    var imageURL: URL?
}

// 2. iOS 17+: @Observable cho granular tracking
@Observable
class ProductListViewModel {
    var products: [Product] = []
    var isLoadingMore = false
    private var currentCursor: String?
    
    func loadNextPageIfNeeded(currentItem: Product) async {
        // Chỉ load khi item hiện tại gần cuối
        guard let index = products.firstIndex(where: { $0.id == currentItem.id }),
              index >= products.count - 5,
              !isLoadingMore else { return }
        
        isLoadingMore = true
        let response = try? await api.fetch(after: currentCursor)
        if let response {
            products.append(contentsOf: response.items)
            currentCursor = response.nextCursor
        }
        isLoadingMore = false
    }
}

// 3. Child view giữ đơn giản, Equatable
struct ProductRow: View, Equatable {
    let product: Product
    
    static func == (lhs: ProductRow, rhs: ProductRow) -> Bool {
        lhs.product == rhs.product
    }
    
    var body: some View {
        HStack {
            // AsyncImage đã có cache built-in
            AsyncImage(url: product.imageURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading) {
                Text(product.name)
                    .font(.body)
                Text("$\(product.price, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// 4. Main list view
struct ProductListView: View {
    let vm: ProductListViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(vm.products) { product in
                    ProductRow(product: product)
                        .equatable()  // Force Equatable comparison
                        .task {
                            // .task tự cancel khi view disappear
                            await vm.loadNextPageIfNeeded(currentItem: product)
                        }
                }
                
                if vm.isLoadingMore {
                    ProgressView()
                        .padding()
                }
            }
        }
    }
}
```

Điểm mấu chốt: SwiftUI rất dễ viết nhưng rất khó viết **hiệu quả** tại scale lớn. Một Senior iOS Developer cần hiểu rõ cơ chế diffing và re-render của SwiftUI để tránh những "invisible performance bugs" — app vẫn chạy đúng nhưng chậm dần khi data tăng lên, và rất khó debug nếu không nắm vững nguyên lý bên dưới.

# 3.Dùng Swift Concurrency (async/await, TaskGroup) hoặc Combine một cách hợp lý để tránh thread explosion và race condition khi gọi nhiều API.

# Concurrent API Calls, Thread Explosion và Race Condition

## Bối cảnh thực tế

Hãy hình dung Home Screen của một app thương mại điện tử như Shopee hay Grab. Khi user mở app, màn hình Home cần hiển thị:

```
┌─────────────────────────────┐
│  [User Profile + Avatar]    │ ← API 1: GET /user/profile
│  [Notification Badge: 5]    │ ← API 2: GET /notifications/count
├─────────────────────────────┤
│  [Banner 1] [Banner 2] →   │ ← API 3: GET /banners
├─────────────────────────────┤
│  [Flash Sale countdown]     │ ← API 4: GET /flash-sale
├─────────────────────────────┤
│  Categories: 🍔 🛒 💊 🚗   │ ← API 5: GET /categories
├─────────────────────────────┤
│  Recommended for you        │ ← API 6: GET /recommendations
│  [──] [──] [──] →          │
├─────────────────────────────┤
│  Recently viewed            │ ← API 7: GET /recently-viewed
├─────────────────────────────┤
│  Nearby stores              │ ← API 8: GET /stores?lat=...
├─────────────────────────────┤
│  Live streams               │ ← API 9: GET /live-streams
├─────────────────────────────┤
│  Vouchers for you           │ ← API 10: GET /vouchers
└─────────────────────────────┘
```

Câu hỏi: **Gọi 10 API này như thế nào cho hiệu quả?**

---

## Cách tiếp cận naïve và vấn đề của nó

### Cách 1: Gọi tuần tự (Sequential)

```swift
// ❌ Quá chậm — mỗi API phải đợi cái trước xong
func loadHomeScreen() async throws -> HomeData {
    let profile = try await api.fetchProfile()           // 200ms
    let notifications = try await api.fetchNotifications() // 150ms
    let banners = try await api.fetchBanners()            // 300ms
    let flashSale = try await api.fetchFlashSale()        // 250ms
    let categories = try await api.fetchCategories()      // 100ms
    let recommendations = try await api.fetchRecommendations() // 400ms
    let recentlyViewed = try await api.fetchRecentlyViewed()   // 200ms
    let stores = try await api.fetchNearbyStores()        // 350ms
    let liveStreams = try await api.fetchLiveStreams()     // 200ms
    let vouchers = try await api.fetchVouchers()          // 150ms
    
    // Tổng: 200+150+300+250+100+400+200+350+200+150 = 2,300ms
    // User phải đợi 2.3 GIÂY mới thấy Home screen
    // → Trải nghiệm rất tệ
    
    return HomeData(profile: profile, notifications: notifications, ...)
}
```

Mỗi API call phải đợi cái trước hoàn thành mới bắt đầu. Tổng thời gian = **tổng của tất cả API**.

### Cách 2: Dispatch hàng loạt bằng GCD (cách cũ)

```swift
// ❌ Thread explosion — tạo quá nhiều thread
func loadHomeScreen() {
    let group = DispatchGroup()
    
    var profile: Profile?
    var banners: [Banner]?
    var recommendations: [Product]?
    // ... 7 biến nữa
    
    group.enter()
    DispatchQueue.global().async {
        // Thread 1
        profile = try? self.api.fetchProfileSync()
        group.leave()
    }
    
    group.enter()
    DispatchQueue.global().async {
        // Thread 2
        banners = try? self.api.fetchBannersSync()
        group.leave()
    }
    
    group.enter()
    DispatchQueue.global().async {
        // Thread 3
        recommendations = try? self.api.fetchRecommendationsSync()
        group.leave()
    }
    
    // ... 7 cái nữa → 10 threads
    
    group.notify(queue: .main) {
        // Update UI khi tất cả xong
        self.updateUI(profile: profile, banners: banners, ...)
    }
}
```

Code này chạy được, nhưng sinh ra 2 vấn đề nghiêm trọng: **Thread Explosion** và **Race Condition**.

---

## Vấn đề 1: Thread Explosion

### Thread Explosion là gì?

Mỗi khi bạn dispatch một block vào `DispatchQueue.global().async`, GCD có thể **tạo một thread mới** nếu không có thread rảnh. Mỗi thread tiêu tốn khoảng **512KB - 1MB stack memory**.

```
10 API calls × 1 thread mỗi cái = 10 threads
                                 = ~5-10MB stack memory

Nhưng vấn đề thực tế NGHIÊM TRỌNG hơn nhiều:
```

**Trong production, không chỉ có Home screen.** Giả sử:

- Home screen: 10 concurrent API calls → 10 threads
- Mỗi API response cần parse JSON → dispatch parse lên background → thêm threads
- Image loading cho mỗi banner/product → mỗi image load là 1 task → thêm threads
- Analytics events fire → thêm threads
- Push notification handler đang chạy → thêm threads
- Core Data background save → thêm threads

```
Thực tế có thể xảy ra:

Thread 1:  API call /profile
Thread 2:  API call /banners  
Thread 3:  API call /recommendations
Thread 4:  API call /flash-sale
Thread 5:  API call /categories
Thread 6:  API call /stores
Thread 7:  API call /vouchers
Thread 8:  API call /live-streams
Thread 9:  API call /notifications
Thread 10: API call /recently-viewed
Thread 11: JSON parse response 1
Thread 12: JSON parse response 2
Thread 13: Image download 1
Thread 14: Image download 2
Thread 15: Image download 3
...
Thread 50: Image download 38
Thread 51: Analytics event
Thread 52: Core Data save
Thread 53: Push notification
...

→ 50-100+ threads cùng tồn tại
```

### Tại sao Thread Explosion nguy hiểm?

**1. Memory:** 64 threads × 512KB = 32MB chỉ riêng stack. Cộng thêm thread metadata, kernel resources → áp lực memory rất lớn trên thiết bị có RAM hạn chế (iPhone SE: 3GB RAM).

**2. Context Switching Overhead:** CPU chỉ có 6 cores (iPhone 15 Pro). Khi có 64 threads nhưng chỉ 6 cores, hệ điều hành phải liên tục **chuyển đổi ngữ cảnh** (context switch) giữa các thread. Mỗi context switch tốn thời gian:

```
Core 1: Thread 1 → save state → load Thread 7 → save state → load Thread 13 → ...
Core 2: Thread 2 → save state → load Thread 8 → save state → load Thread 14 → ...
...

Mỗi context switch ≈ 1-10 microseconds
64 threads, 6 cores → context switch liên tục
→ CPU dành nhiều thời gian CHUYỂN ĐỔI hơn là LÀM VIỆC THỰC SỰ
```

**3. Thread Starvation:** GCD có giới hạn tổng số thread (~64). Nếu tất cả threads đang bận (blocked waiting for network), và Main Thread cần dispatch một task → không có thread rảnh → Main Thread có thể bị ảnh hưởng → **UI freeze**.

**4. Deadlock potential:** Nếu thread A đang đợi result từ thread B, nhưng thread B không được schedule vì hết thread slot → deadlock.

---

## Vấn đề 2: Race Condition

### Race Condition là gì?

Race condition xảy ra khi **nhiều thread cùng đọc/ghi một shared resource** mà không có synchronization, dẫn đến kết quả **không xác định** (non-deterministic).

### Ví dụ cụ thể trong Home Screen

```swift
// ❌ Race condition — nhiều thread cùng ghi vào homeData
class HomeViewModel {
    var homeData = HomeData()  // Shared mutable state
    
    func loadHomeScreen() {
        let group = DispatchGroup()
        
        group.enter()
        DispatchQueue.global().async {
            let profile = try? self.api.fetchProfileSync()
            self.homeData.profile = profile  // Thread 1 GHI
            group.leave()
        }
        
        group.enter()
        DispatchQueue.global().async {
            let banners = try? self.api.fetchBannersSync()
            self.homeData.banners = banners  // Thread 2 GHI cùng lúc
            group.leave()
        }
        
        group.enter()
        DispatchQueue.global().async {
            let recs = try? self.api.fetchRecommendationsSync()
            self.homeData.recommendations = recs  // Thread 3 GHI cùng lúc
            group.leave()
        }
    }
}
```

**Vấn đề:** `homeData` là **shared mutable state**. 3 threads cùng ghi vào cùng object mà không có locking mechanism. Trong Swift, `struct` assignment không phải atomic operation — nó có thể gồm nhiều bước (allocate, copy, release old value). Nếu 2 threads ghi cùng lúc, data có thể bị **corrupt** → crash hoặc hiển thị sai.

### Race condition tinh vi hơn

```swift
// ❌ Race condition tinh vi — cart count
class CartManager {
    var itemCount = 0
    
    func addItem() {
        // Giả sử 2 thread gọi addItem() CÙNG LÚC
        // Mong đợi: 0 → 1 → 2
        
        // Thực tế có thể xảy ra:
        // Thread A: đọc itemCount = 0
        // Thread B: đọc itemCount = 0  (chưa kịp thấy Thread A ghi)
        // Thread A: ghi itemCount = 0 + 1 = 1
        // Thread B: ghi itemCount = 0 + 1 = 1  ← SAI! Phải là 2
        
        itemCount += 1  // Đây KHÔNG phải atomic operation
        // Nó thực ra là:
        // temp = itemCount (READ)
        // temp = temp + 1  (COMPUTE)
        // itemCount = temp  (WRITE)
    }
}
```

### Tại sao race condition đặc biệt nguy hiểm?

- **Không nhất quán:** Chạy 100 lần, 95 lần đúng, 5 lần sai → rất khó reproduce
- **Khó debug:** Debugger làm chậm execution → timing thay đổi → bug biến mất khi debug
- **Crash ngẫu nhiên:** `EXC_BAD_ACCESS` trong production mà không reproduce được trong development

---

## Giải pháp 1: Swift Concurrency (async/await + TaskGroup)

### async let — Concurrent nhưng bounded

```swift
// ✅ async let: Chạy đồng thời, nhưng Swift runtime quản lý threads
func loadHomeScreen() async throws -> HomeData {
    // Tất cả bắt đầu ĐỒNG THỜI khi khai báo async let
    async let profile = api.fetchProfile()
    async let notifications = api.fetchNotifications()
    async let banners = api.fetchBanners()
    async let flashSale = api.fetchFlashSale()
    async let categories = api.fetchCategories()
    async let recommendations = api.fetchRecommendations()
    async let recentlyViewed = api.fetchRecentlyViewed()
    async let stores = api.fetchNearbyStores()
    async let liveStreams = api.fetchLiveStreams()
    async let vouchers = api.fetchVouchers()
    
    // await ở đây — đợi TẤT CẢ hoàn thành
    // Tổng thời gian ≈ API chậm nhất = 400ms (recommendations)
    // Thay vì 2,300ms sequential!
    return HomeData(
        profile: try await profile,
        notifications: try await notifications,
        banners: try await banners,
        flashSale: try await flashSale,
        categories: try await categories,
        recommendations: try await recommendations,
        recentlyViewed: try await recentlyViewed,
        stores: try await stores,
        liveStreams: try await liveStreams,
        vouchers: try await vouchers
    )
}
```

### Tại sao async let không gây Thread Explosion?

Swift Concurrency dùng **Cooperative Thread Pool** — một pool có số thread **cố định**, thường bằng số CPU core (ví dụ: 6 threads cho 6-core CPU).

```
GCD (cũ):
Task 1 → Thread 1
Task 2 → Thread 2
Task 3 → Thread 3
...
Task 10 → Thread 10
→ 10 threads tồn tại đồng thời

Swift Concurrency — Cooperative Thread Pool:
┌──────────────────────────────────────┐
│  Thread Pool (6 threads cố định)     │
│                                      │
│  Thread 1: [Task 1: call API]        │
│            ↓ await network...        │
│            [SUSPEND — nhường thread] │
│            [Task 7 RESUME ở đây]     │
│                                      │
│  Thread 2: [Task 2: call API]        │
│            ↓ await network...        │
│            [SUSPEND — nhường thread] │
│            [Task 8 RESUME ở đây]     │
│                                      │
│  ... (tương tự cho Thread 3-6)       │
└──────────────────────────────────────┘
```

**Cơ chế Suspension:** Khi một task gặp `await` (đợi network response), nó **không block thread**. Thay vào đó:

1. Task bị **suspend** — state được lưu vào heap (gọi là "continuation")
2. Thread được **giải phóng** cho task khác sử dụng
3. Khi network response về → task được **resume** trên bất kỳ thread nào rảnh

```swift
// Minh họa suspension flow
func fetchProfile() async throws -> Profile {
    let request = URLRequest(url: profileURL)
    
    // Tại dòng này:
    // 1. Task suspend → thread giải phóng
    // 2. OS gửi network request
    // 3. Thread chạy task khác trong khi đợi
    // 4. Response về → task resume trên thread rảnh
    let (data, response) = try await URLSession.shared.data(for: request)
    
    // Parse JSON — chạy trên thread bình thường
    let profile = try JSONDecoder().decode(Profile.self, from: data)
    return profile
}
```

Kết quả: 10 concurrent API calls nhưng chỉ dùng **6 threads cố định**. Không bao giờ thread explosion.

### TaskGroup — Khi số lượng tasks là dynamic

`async let` phù hợp khi bạn biết trước số lượng tasks. Nhưng đôi khi số lượng tasks phụ thuộc vào data runtime:

```swift
// Ví dụ: Load chi tiết cho N sections, N không biết trước
struct HomeSection: Identifiable, Sendable {
    let id: String
    let type: SectionType
    let endpoint: String
}

func loadHomeSections(configs: [HomeSection]) async -> [String: SectionData] {
    // configs có thể là 5, 10, hoặc 20 sections
    // tuỳ theo server config cho user này
    
    await withTaskGroup(of: (String, SectionData?).self) { group in
        for config in configs {
            group.addTask {
                // Mỗi task chạy concurrent
                let data = try? await self.api.fetchSection(endpoint: config.endpoint)
                return (config.id, data)
            }
        }
        
        // Collect results
        var results: [String: SectionData] = [:]
        for await (id, data) in group {
            if let data {
                results[id] = data
            }
        }
        return results
    }
}
```

### TaskGroup với giới hạn concurrency

Đôi khi bạn muốn giới hạn số tasks chạy đồng thời (ví dụ: API rate limit chỉ cho 3 requests/giây):

```swift
// ✅ Manual concurrency throttling
func loadImages(urls: [URL]) async -> [URL: UIImage] {
    let maxConcurrent = 3
    var results: [URL: UIImage] = [:]
    
    await withTaskGroup(of: (URL, UIImage?).self) { group in
        var urlIterator = urls.makeIterator()
        
        // Khởi tạo batch đầu tiên (3 tasks)
        for _ in 0..<min(maxConcurrent, urls.count) {
            if let url = urlIterator.next() {
                group.addTask { await (url, self.downloadImage(url: url)) }
            }
        }
        
        // Mỗi khi 1 task xong → thêm 1 task mới
        // → Luôn giữ tối đa 3 tasks chạy đồng thời
        for await (url, image) in group {
            if let image { results[url] = image }
            
            if let nextURL = urlIterator.next() {
                group.addTask { await (nextURL, self.downloadImage(url: nextURL)) }
            }
        }
    }
    
    return results
}
```

Luồng hoạt động:

```
Thời điểm T0:
  Task 1: download image[0]  ← RUNNING
  Task 2: download image[1]  ← RUNNING
  Task 3: download image[2]  ← RUNNING
  image[3]...image[N]: đang đợi

Thời điểm T1 (Task 2 xong trước):
  Task 1: download image[0]  ← vẫn RUNNING
  Task 4: download image[3]  ← MỚI thay thế Task 2
  Task 3: download image[2]  ← vẫn RUNNING

→ Luôn giữ đúng 3 concurrent tasks
```

---

## Giải pháp 2: Actor — Chống Race Condition

### Actor là gì?

Actor là kiểu data type trong Swift Concurrency đảm bảo **chỉ 1 task được truy cập state tại một thời điểm** (mutual exclusion), giống như serial queue nhưng tích hợp sâu vào ngôn ngữ.

```swift
// ✅ Actor: compiler đảm bảo không có race condition
actor HomeDataStore {
    private var sections: [String: SectionData] = [:]
    private var loadedCount = 0
    
    func updateSection(id: String, data: SectionData) {
        sections[id] = data
        loadedCount += 1
        // Bên trong actor, code chạy tuần tự
        // → KHÔNG BAO GIỜ có 2 tasks cùng ghi sections đồng thời
    }
    
    func getSnapshot() -> [String: SectionData] {
        return sections
    }
    
    var progress: Double {
        Double(loadedCount) / 10.0
    }
}
```

### Tại sao Actor tốt hơn Lock/Queue truyền thống?

```swift
// ❌ Cách cũ: Dùng serial queue để protect shared state
class HomeDataStoreOld {
    private var sections: [String: SectionData] = [:]
    private let queue = DispatchQueue(label: "com.app.homedata")
    
    func updateSection(id: String, data: SectionData) {
        queue.sync {  // Dễ gây deadlock nếu gọi lồng nhau
            sections[id] = data
        }
    }
}

// ❌ Cách cũ: Dùng NSLock
class HomeDataStoreOld2 {
    private var sections: [String: SectionData] = [:]
    private let lock = NSLock()
    
    func updateSection(id: String, data: SectionData) {
        lock.lock()     // Quên unlock → deadlock
        sections[id] = data
        lock.unlock()
    }
}
```

Vấn đề với cách cũ:

- **Compiler không giúp bạn** — quên lock/unlock → bug
- **Dễ deadlock** — serial queue gọi sync vào chính nó
- **Performance** — queue.sync block thread

Actor giải quyết tất cả vì compiler **enforce** tại compile time:

```swift
let store = HomeDataStore() // actor

// Từ BÊN NGOÀI actor, bắt buộc phải dùng await
// Compiler sẽ BÁO LỖI nếu bạn quên await
await store.updateSection(id: "banner", data: bannerData)

// ❌ Compiler error — không thể truy cập actor state mà không await
// store.sections["banner"] = bannerData  // ERROR!
```

### Full example: Actor + TaskGroup

```swift
actor HomeDataStore {
    private(set) var sections: [String: SectionData] = [:]
    
    func update(id: String, data: SectionData) {
        sections[id] = data
    }
}

class HomeViewModel {
    private let store = HomeDataStore()
    
    @Published var homeSections: [String: SectionData] = [:]
    @Published var error: Error?
    
    func loadHomeScreen() async {
        let apis: [(id: String, fetch: () async throws -> SectionData)] = [
            ("profile", { try await self.api.fetchProfile().asSectionData() }),
            ("banners", { try await self.api.fetchBanners().asSectionData() }),
            ("recommendations", { try await self.api.fetchRecommendations().asSectionData() }),
            // ... thêm 7 APIs nữa
        ]
        
        await withTaskGroup(of: Void.self) { group in
            for (id, fetch) in apis {
                group.addTask {
                    do {
                        let data = try await fetch()
                        // Actor đảm bảo thread-safe
                        await self.store.update(id: id, data: data)
                        
                        // Update UI progressively
                        let snapshot = await self.store.sections
                        await MainActor.run {
                            self.homeSections = snapshot
                        }
                    } catch {
                        // Một API fail không ảnh hưởng các API khác
                        print("Failed to load \(id): \(error)")
                    }
                }
            }
        }
    }
}
```

Điểm quan trọng ở trên: mỗi API call có `do/catch` riêng → nếu `/flash-sale` API bị lỗi, các section khác vẫn hiển thị bình thường. Đây là pattern rất quan trọng trong production — **partial loading / graceful degradation**.

---

## Giải pháp 3: MainActor — Protect UI Updates

### Vấn đề UI update từ background thread

```swift
// ❌ CRASH hoặc UNDEFINED BEHAVIOR
// UIKit/SwiftUI yêu cầu UI update PHẢI trên Main Thread
DispatchQueue.global().async {
    let data = try? await api.fetchProfile()
    self.nameLabel.text = data?.name  // ← WRONG THREAD!
}
```

### MainActor

```swift
// ✅ MainActor đảm bảo code chạy trên Main Thread
@MainActor
class HomeViewModel: ObservableObject {
    // Tất cả @Published properties được access trên Main Thread
    @Published var sections: [HomeSection] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    func loadHomeScreen() async {
        isLoading = true  // ← Trên Main Thread ✅
        
        do {
            // async let chạy trên background
            async let profile = api.fetchProfile()
            async let banners = api.fetchBanners()
            
            // await tự động hop về Main Thread
            // vì function này thuộc @MainActor class
            let p = try await profile
            let b = try await banners
            
            self.sections = buildSections(profile: p, banners: b)  // Main Thread ✅
        } catch {
            self.error = error  // Main Thread ✅
        }
        
        isLoading = false  // Main Thread ✅
    }
}
```

**Quan trọng:** `@MainActor` không nghĩa là tất cả code chạy trên Main Thread. Khi gặp `await`, task suspend và network request chạy background. Chỉ khi resume sau `await`, code quay lại Main Thread. Nên không block UI.

---

## Giải pháp 4: Combine Approach

### Cách tương tự dùng Combine

```swift
class HomeViewModel: ObservableObject {
    @Published var homeData = HomeData()
    @Published var isLoading = false
    private var cancellables = Set<AnyCancellable>()
    
    func loadHomeScreen() {
        isLoading = true
        
        // Publishers.Zip gộp nhiều publishers thành 1
        // Tất cả chạy ĐỒNG THỜI, emit khi TẤT CẢ xong
        Publishers.Zip4(
            api.fetchProfilePublisher(),
            api.fetchBannersPublisher(),
            api.fetchRecommendationsPublisher(),
            api.fetchFlashSalePublisher()
        )
        .receive(on: DispatchQueue.main)  // ← Kết quả trên Main Thread
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.handleError(error)
                }
            },
            receiveValue: { [weak self] profile, banners, recs, flashSale in
                self?.homeData = HomeData(
                    profile: profile,
                    banners: banners,
                    recommendations: recs,
                    flashSale: flashSale
                )
            }
        )
        .store(in: &cancellables)
    }
}
```

### Combine: Progressive Loading với Merge

```swift
// Hiển thị từng section ngay khi nó load xong,
// thay vì đợi TẤT CẢ xong mới hiện

enum HomeSectionResult {
    case profile(Profile)
    case banners([Banner])
    case recommendations([Product])
    case flashSale(FlashSale)
}

func loadHomeScreenProgressively() {
    // Merge: emit mỗi khi BẤT KỲ publisher nào emit
    Publishers.MergeMany(
        api.fetchProfilePublisher()
            .map { HomeSectionResult.profile($0) },
        api.fetchBannersPublisher()
            .map { HomeSectionResult.banners($0) },
        api.fetchRecommendationsPublisher()
            .map { HomeSectionResult.recommendations($0) },
        api.fetchFlashSalePublisher()
            .map { HomeSectionResult.flashSale($0) }
    )
    .receive(on: DispatchQueue.main)
    .sink(
        receiveCompletion: { _ in },
        receiveValue: { [weak self] result in
            // Mỗi section xuất hiện NGAY khi API trả về
            // Không cần đợi tất cả
            switch result {
            case .profile(let p):
                self?.homeData.profile = p      // Hiện ngay sau 200ms
            case .banners(let b):
                self?.homeData.banners = b      // Hiện ngay sau 300ms
            case .recommendations(let r):
                self?.homeData.recommendations = r  // Hiện ngay sau 400ms
            case .flashSale(let f):
                self?.homeData.flashSale = f    // Hiện ngay sau 250ms
            }
        }
    )
    .store(in: &cancellables)
}
```

### Combine: Limit Concurrency

```swift
// ✅ maxPublishers giới hạn số concurrent requests
let urls: [URL] = [/* 100 image URLs */]

urls.publisher
    .flatMap(maxPublishers: .max(3)) { url in
        // Tối đa 3 downloads đồng thời
        URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
    }
    .compactMap { $0 }
    .collect()
    .receive(on: DispatchQueue.main)
    .sink { images in
        self.images = images
    }
    .store(in: &cancellables)
```

---

## So sánh: Swift Concurrency vs Combine

```
                    Swift Concurrency          Combine
                    ──────────────────         ───────────────
Thread safety       Actor (compiler-enforced)  Bạn tự quản lý
Thread explosion    Cooperative pool (6 threads) Phụ thuộc scheduler
Readability         Linear, dễ đọc             Chain operators, dốc learning curve
Error handling      try/catch quen thuộc       Completion/Failure types
Cancellation       Task.cancel() tự động       AnyCancellable.cancel()
Progressive load    TaskGroup + actor           Merge + sink
Memory              Struct-based continuations  Publisher chain giữ closures
iOS minimum        iOS 13 (backport), 15+ full iOS 13
```

Xu hướng hiện tại: **Swift Concurrency là hướng đi chính** mà Apple khuyến khích. Combine vẫn hữu ích cho reactive stream (ví dụ: debounce search text, merge nhiều data stream liên tục), nhưng cho one-shot concurrent API calls, `async/await` + `TaskGroup` sạch hơn và an toàn hơn rất nhiều.

---

## Production Pattern: Home Screen Loading

```swift
@MainActor
class HomeViewModel: ObservableObject {
    @Published var sections: [String: LoadState<SectionData>] = [:]
    
    // Mỗi section có state riêng
    enum LoadState<T> {
        case idle
        case loading
        case loaded(T)
        case failed(Error)
    }
    
    private let sectionConfigs: [(id: String, fetch: @Sendable () async throws -> SectionData)] = [
        ("profile",   { try await API.shared.fetchProfile().asSection() }),
        ("banners",   { try await API.shared.fetchBanners().asSection() }),
        ("flash_sale", { try await API.shared.fetchFlashSale().asSection() }),
        // ... thêm sections
    ]
    
    func loadHomeScreen() async {
        // 1. Set tất cả sections → loading
        for config in sectionConfigs {
            sections[config.id] = .loading
        }
        
        // 2. Load tất cả concurrently
        await withTaskGroup(of: (String, LoadState<SectionData>).self) { group in
            for (id, fetch) in sectionConfigs {
                group.addTask {
                    do {
                        let data = try await fetch()
                        return (id, .loaded(data))
                    } catch {
                        return (id, .failed(error))
                    }
                }
            }
            
            // 3. Progressive update — hiển thị từng section khi nó sẵn sàng
            for await (id, state) in group {
                sections[id] = state
                // @Published trigger UI update cho MỖI section
                // User thấy content xuất hiện dần dần
                // thay vì blank screen → full content
            }
        }
    }
}
```

```swift
// SwiftUI View
struct HomeView: View {
    @StateObject var vm = HomeViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack {
                // Mỗi section tự hiển thị theo state
                SectionView(state: vm.sections["banners"])
                SectionView(state: vm.sections["flash_sale"])
                SectionView(state: vm.sections["recommendations"])
                // ...
            }
        }
        .task {
            await vm.loadHomeScreen()
        }
    }
}

struct SectionView: View {
    let state: HomeViewModel.LoadState<SectionData>?
    
    var body: some View {
        switch state {
        case .loading, .idle, .none:
            ShimmerPlaceholder()      // Skeleton loading
        case .loaded(let data):
            ActualSectionContent(data: data)  // Real content
        case .failed:
            RetryButton()             // Error state với retry
        }
    }
}
```

Đây là pattern mà user thấy trong hầu hết production apps: mở Home screen → thấy skeleton/shimmer → từng section "hiện ra" dần dần khi API trả về → section nào lỗi thì hiện retry button, không ảnh hưởng section khác.

Tóm lại, ở level Senior, bạn không chỉ cần biết `async/await` syntax, mà cần hiểu bản chất thread pool cooperative model, tại sao nó tốt hơn GCD cho concurrent workload, và cách thiết kế flow loading phù hợp cho UX trong thực tế.
