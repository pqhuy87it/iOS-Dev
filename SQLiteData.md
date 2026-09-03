Tôi đã đọc README và release notes của repo (bản mới nhất là **1.10.0**, phát hành 11/08/2026). Tóm tắt:

## SQLiteData là gì

Một thư viện thay thế SwiftData, do Point-Free viết (tiến hoá từ SharingGRDB). Stack bên dưới: **GRDB** (kết nối + observation SQLite) + **StructuredQueries** (query builder type-safe, có macro `#sql`) + swift-dependencies. MIT license, iOS 16+ / macOS 13+, Swift tools 6.1.

## Các tính năng chính

**1. `@Table` thay cho `@Model`** — model là `struct` thuần (value type), không phải class:
```swift
@Table
struct Item {
  let id: UUID
  var title = ""
  var isInStock = true
}
```

**2. Property wrappers `@FetchAll` / `@FetchOne` / `@Fetch`** — tương đương `@Query` nhưng mạnh hơn và **dùng được ở mọi nơi**: SwiftUI, UIKit, `@Observable` model:
```swift
@FetchAll(Item.where(\.isInStock).order(by: \.title)) var items
@FetchOne(Item.count()) var itemsCount = 0   // đếm mà không load toàn bộ rows
```
`@Fetch` + `FetchKeyRequest` cho phép viết query phức tạp tuỳ ý (join nhiều bảng, aggregate) mà vẫn được observe tự động.

**3. Cấu hình DB qua dependency injection**, không phải `.modelContainer()`:
```swift
prepareDependencies { $0.defaultDatabase = try! appDatabase() }
```
Ghi dữ liệu thì `@Dependency(\.defaultDatabase)` rồi `database.write { db in try Item.insert { … }.execute(db) }`.

**4. CloudKit sync + CloudKit sharing** — chỉ cần khai báo `SyncEngine`:
```swift
$0.defaultSyncEngine = SyncEngine(for: $0.defaultDatabase, tables: Item.self)
```
Có cả share record với user iCloud khác (thứ mà SwiftData không hỗ trợ).

**5. Performance** — decoding gần bằng gọi SQLite C API trực tiếp. Benchmark của họ (Lighter PerformanceTestSuite, `Orders.fetchAll`): SQLiteData 8.5s vs GRDB Codable 53.3s, SQLite.swift Codable 43.3s, GRDB manual decoding 18.8s.

**6. Tính năng gần đây**: `fetchAll(sectionBy:)` cho sectioned list (1.8.x), trait `StrictDecoding` báo lỗi khi type Swift không khớp SQL affinity (1.10.0), `@FetchOne` tự observe primary-keyed record (1.10.0), enum tables qua trait `CasePaths`.

**7. Demos trong repo**: CaseStudies (SwiftUI + UIKit), Reminders (clone app Reminders, nhiều query nâng cao + CloudKit), SyncUps (Scrumdinger + sync), CloudKitDemo.

## So sánh với SwiftData

| | SQLiteData | SwiftData |
|---|---|---|
| Model | `struct`, value semantics | `class` `@Model`, reference semantics, cần init |
| Engine | SQLite trực tiếp, schema do bạn kiểm soát | Core Data bên dưới, schema ẩn |
| Migration | Bạn tự viết migration bằng SQL | Tự động / lightweight migration |
| Query | Toàn bộ SQL: JOIN, GROUP BY, aggregate, CTE, window function, `#sql` | `#Predicate` — không aggregate, không order theo `Bool`, không count mà không load |
| Observation | GRDB `ValueObservation`, dùng ở SwiftUI/UIKit/`@Observable` | `@Query` chỉ dùng trong SwiftUI `View` |
| Relationship | Foreign key + join thủ công | `@Relationship`, lazy loading tự động |
| Testing | DI + in-memory DB, dễ isolate | Khó hơn, phụ thuộc `ModelContainer` |
| CloudKit | Sync + **sharing**, ít ràng buộc schema | Sync có, sharing không; buộc mọi property optional/có default, không unique constraint, không delete rule |
| Debug | Mở file `.sqlite` bằng bất kỳ tool nào | Store khá đóng |
| Platform floor | iOS 16 | iOS 17 |
| Rủi ro | Third-party, phụ thuộc 4 package | First-party Apple |

## Đánh giá thực tế

README nói thẳng: **"SQLite knowledge required"** — thư viện chủ ý không che SQL đi. Bạn cần biết schema design, normalization, join, index. Đây vừa là điểm mạnh (kiểm soát hoàn toàn, dễ tối ưu, dễ debug) vừa là chi phí học.

Chọn SQLiteData nếu: query phức tạp/nhiều join & aggregate, cần support iOS 16, dùng UIKit hoặc kiến trúc `@Observable`/TCA, coi trọng testability, hoặc cần CloudKit sharing. Chọn SwiftData nếu: model đơn giản, muốn giữ first-party, team không mạnh SQL, hoặc dự án đã dùng SwiftData ổn định.

Với hướng bạn hay làm (Clean Architecture + offline-first, TCA/Riverpod-style unidirectional flow), SQLiteData khớp hơn nhiều so với SwiftData — vì repository layer trả về `struct` immutable, và `@Fetch` cho phép đặt query ở tầng data thay vì rải `@Query` trong View.
