# "Solid Understanding of Mobile Application Architecture" — Dành cho Senior iOS Developer

Đây là một trong những yêu cầu cốt lõi nhất đối với một Senior iOS Developer. Nó không chỉ đơn giản là "biết code", mà là khả năng **thiết kế, tổ chức và đưa ra quyết định kỹ thuật** cho toàn bộ ứng dụng. Mình sẽ tách ra từng khía cạnh:

---

## 1. Các Architecture Patterns phổ biến trên iOS

Một senior cần hiểu sâu và biết khi nào nên dùng pattern nào:

**MVC (Model-View-Controller)** — Pattern mặc định của Apple. Đơn giản nhưng dễ dẫn đến "Massive View Controller" khi ứng dụng phình to. Senior cần biết cách tách logic ra khỏi ViewController để tránh điều này.

**MVVM (Model-View-ViewModel)** — Tách business logic ra ViewModel, giúp ViewController "gầy" hơn và dễ viết unit test. Kết hợp rất tốt với Combine hoặc RxSwift thông qua data binding.

**VIPER (View-Interactor-Presenter-Entity-Router)** — Chia nhỏ trách nhiệm rất rõ ràng, phù hợp với team lớn và dự án phức tạp. Tuy nhiên đi kèm nhiều boilerplate code.

**Clean Architecture / TCA (The Composable Architecture)** — Clean Architecture tách ứng dụng thành các layer (Domain, Data, Presentation) với dependency rule hướng vào trong. TCA của Point-Free thì quản lý state theo kiểu unidirectional, rất phù hợp với SwiftUI.

Senior không chỉ "biết" các pattern này mà phải **đánh giá trade-off** để chọn pattern phù hợp với quy mô team, độ phức tạp của dự án và khả năng maintain lâu dài.

---

## 2. App Structure & Module Organization

**Modularization** — Tách ứng dụng thành các module độc lập (Feature modules, Core module, Networking module, UI Kit module...) bằng Swift Package Manager hoặc framework riêng. Điều này giúp giảm build time, tăng khả năng reuse và cho phép nhiều team làm song song.

**Dependency Injection** — Thay vì các class tự tạo dependency, chúng được "inject" từ bên ngoài vào. Điều này giúp code dễ test và linh hoạt hơn. Senior cần hiểu các cách triển khai: constructor injection, property injection, hoặc dùng container như Swinject.

**Coordinator / Router Pattern** — Tách navigation logic ra khỏi ViewController. Thay vì ViewController A phải "biết" ViewController B để push, một Coordinator sẽ quản lý toàn bộ flow điều hướng. Điều này giúp các màn hình độc lập và dễ tái sử dụng hơn.

---

## 3. Data Flow & State Management

Senior cần trả lời được: **"Dữ liệu đi từ đâu, qua đâu, và hiển thị như thế nào?"**

**Unidirectional Data Flow** — Dữ liệu chỉ chảy một chiều (ví dụ: User Action → State Change → UI Update). Giúp dễ debug và dự đoán hành vi ứng dụng. SwiftUI với `@State`, `@ObservedObject`, `@EnvironmentObject` được thiết kế theo hướng này.

**Reactive Programming** — Dùng Combine (native) hoặc RxSwift để xử lý luồng dữ liệu bất đồng bộ, giúp code gọn gàng hơn so với callback/delegate truyền thống.

**Source of Truth** — Luôn phải xác định rõ đâu là nguồn dữ liệu "đáng tin cậy" duy nhất cho mỗi phần dữ liệu, tránh tình trạng state bị phân mảnh và không đồng bộ giữa các nơi.

---

## 4. Networking & Data Layer

**Repository Pattern** — Tạo một lớp trung gian giữa business logic và data source. ViewModel chỉ gọi repository, không cần biết dữ liệu đến từ API, cache hay database. Khi cần đổi data source, chỉ sửa repository mà không ảnh hưởng phần còn lại.

**Offline-first Strategy** — Thiết kế để app hoạt động tốt cả khi mất mạng: dùng Core Data hoặc Swift Data làm local cache, sync khi có mạng trở lại, xử lý conflict resolution.

**API Layer Abstraction** — Đóng gói networking (URLSession, Alamofire...) sau một protocol/interface, giúp dễ mock khi test và dễ thay thế thư viện sau này.

---

## 5. Persistence Layer

Senior cần biết khi nào dùng công cụ nào:

- **UserDefaults** — Cho dữ liệu nhỏ, đơn giản (settings, flags).
- **Keychain** — Cho dữ liệu nhạy cảm (token, password).
- **Core Data / SwiftData** — Cho dữ liệu phức tạp, có quan hệ, cần query.
- **File System** — Cho file lớn (ảnh, video, document).
- **SQLite trực tiếp (GRDB, FMDB)** — Khi cần kiểm soát tối đa hiệu năng truy vấn.

---

## 6. Concurrency & Performance

**Swift Concurrency (async/await, Actor)** — Hiểu cách dùng `Task`, `TaskGroup`, `@MainActor`, `actor` để viết code bất đồng bộ an toàn, tránh data race.

**Memory Management** — Hiểu rõ ARC, retain cycle, khi nào dùng `weak`/`unowned`. Biết dùng Instruments (Leaks, Allocations) để phát hiện memory leak.

**Performance Optimization** — Lazy loading, image caching, tối ưu `UITableView`/`UICollectionView` (cell reuse, prefetching), tránh main thread blocking.

---

## 7. Testability & Scalability

Một kiến trúc tốt phải **dễ test**. Senior cần thiết kế sao cho mỗi layer có thể test độc lập: ViewModel test business logic mà không cần UI, Repository test mà không cần gọi API thật (dùng mock). Điều này chỉ đạt được khi các layer được tách rõ ràng và giao tiếp qua protocol.

Về scalability, kiến trúc phải cho phép thêm feature mới mà không cần refactor lớn, onboard thành viên mới dễ dàng, và nhiều team có thể làm việc song song trên cùng codebase.

---

## Tóm lại

"Solid understanding of mobile application architecture" với một Senior iOS Developer nghĩa là bạn có khả năng **nhìn ứng dụng như một hệ thống**, hiểu cách các thành phần kết nối và ảnh hưởng lẫn nhau, và đưa ra quyết định thiết kế có cân nhắc trade-off rõ ràng — không phải chỉ "code chạy được" mà là "code chạy tốt, dễ maintain, dễ test, và dễ mở rộng trong dài hạn".

Bạn muốn mình đi sâu hơn vào phần nào không?
