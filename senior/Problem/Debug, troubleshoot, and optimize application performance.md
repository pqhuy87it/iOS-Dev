# Chuẩn bị phỏng vấn iOS Senior Developer: Debug, Troubleshoot & Optimize Performance

Đây là một yêu cầu rất rộng và quan trọng. Tôi sẽ chia thành các nhóm kiến thức chính mà bạn cần nắm vững.

---

## 1. Thành thạo công cụ Debug trong Xcode

**Xcode Debugger (LLDB):** Bạn cần biết đặt breakpoint có điều kiện (conditional breakpoint), symbolic breakpoint, sử dụng các lệnh như `po`, `p`, `v`, `expression`, `bt` (backtrace) để kiểm tra trạng thái runtime. Senior developer cần biết khi nào dùng breakpoint và khi nào dùng logging để hiệu quả hơn.

**View Debugger:** Dùng để kiểm tra view hierarchy, phát hiện các vấn đề như view bị che khuất, constraint conflict, hoặc layer quá phức tạp gây giảm hiệu năng render.

**Memory Graph Debugger:** Đây là công cụ quan trọng để phát hiện retain cycle và memory leak. Bạn cần hiểu rõ cách đọc memory graph, nhận diện strong reference cycle giữa các object.

---

## 2. Instruments — Công cụ cốt lõi để Profiling

Đây là phần mà interviewer thường hỏi sâu nhất:

**Time Profiler:** Phân tích CPU usage, tìm ra hàm nào đang chiếm nhiều thời gian nhất. Bạn cần biết cách đọc call tree, lọc theo thread, và phân biệt giữa thời gian trên main thread vs background thread.

**Allocations & Leaks:** Theo dõi bộ nhớ được cấp phát, phát hiện memory leak. Bạn cần hiểu sự khác biệt giữa leak (object không ai tham chiếu nhưng không được giải phóng) và abandoned memory (object vẫn được tham chiếu nhưng không còn cần thiết).

**Core Animation / Rendering:** Phát hiện offscreen rendering, blended layers, misaligned images — những thứ khiến scroll bị giật.

**Network Profiler:** Phân tích các request mạng, thời gian phản hồi, payload size.

**Energy Log:** Đo mức tiêu thụ pin — đặc biệt quan trọng với background task, location tracking, hay timer.

---

## 3. Tối ưu hiệu năng UI (phần hay bị hỏi nhất)

**Smooth scrolling (60fps / 120fps trên ProMotion):** Mỗi frame cần được render trong khoảng 16ms (60fps) hoặc 8ms (120fps). Bạn cần biết các kỹ thuật như cell reuse đúng cách, prefetching data với `UICollectionViewDataSourcePrefetching`, tránh layout phức tạp trong `cellForRowAt`, và cache chiều cao cell nếu dùng manual layout.

**Off-main-thread rendering:** Decode image trên background thread thay vì để hệ thống tự decode trên main thread. Thư viện như Kingfisher hay SDWebImage làm điều này, nhưng bạn cần hiểu bản chất bên dưới.

**Lazy loading & tránh overdraw:** Chỉ tải và render những gì người dùng thực sự nhìn thấy.

---

## 4. Quản lý bộ nhớ

**ARC và Reference Cycle:** Hiểu rõ khi nào dùng `weak`, `unowned`, và `capture list` trong closure. Một câu hỏi kinh điển là giải thích tại sao closure trong `URLSession` hay `DispatchQueue.main.async` có thể gây retain cycle và cách xử lý.

**Autorelease Pool:** Biết khi nào cần dùng `autoreleasepool` thủ công, ví dụ khi xử lý vòng lặp lớn tạo nhiều object tạm thời.

**Large asset handling:** Kỹ thuật downsample ảnh lớn bằng `ImageIO` thay vì load toàn bộ vào memory, đặc biệt khi hiển thị thumbnail.

---

## 5. Concurrency & Threading

**Tránh block main thread:** Mọi thao tác nặng (network, database, image processing) phải chạy trên background. Bạn cần thành thạo GCD (`DispatchQueue`), `OperationQueue`, và Swift Concurrency (`async/await`, `Task`, `Actor`).

**Data race & Thread safety:** Hiểu cách dùng serial queue, lock, hoặc `Actor` (Swift) để bảo vệ shared state. Biết bật Thread Sanitizer (TSan) trong Xcode để phát hiện data race.

**Main Thread Checker:** Xcode có tool này để cảnh báo khi bạn cập nhật UI từ background thread — lỗi rất phổ biến.

---

## 6. App Launch Time Optimization

Đây là chủ đề senior hay bị hỏi. Bạn cần hiểu hai giai đoạn: **pre-main** (trước khi `main()` chạy) bao gồm dylib loading, rebase/binding, ObjC runtime setup; và **post-main** (từ `main()` đến khi UI hiển thị xong). Các kỹ thuật tối ưu gồm giảm số lượng dynamic framework, dùng static linking khi có thể, defer initialization không cần thiết, và tránh làm việc nặng trong `application(_:didFinishLaunchingWithOptions:)`.

---

## 7. Network & Data Optimization

Caching response hợp lý với `URLCache` hoặc custom cache layer. Pagination và lazy loading data. Nén payload, dùng `Codable` hiệu quả. Xử lý offline gracefully và retry logic thông minh.

---

## 8. Monitoring & Crash Reporting trong Production

Senior developer không chỉ debug lúc develop mà còn cần biết cách theo dõi app sau khi release. Bạn nên biết về MetricKit (Apple's framework để thu thập performance metrics), Xcode Organizer (xem crash logs, energy reports, disk writes từ user thực), và các tool bên thứ 3 như Firebase Crashlytics hay Sentry. Biết cách symbolicate crash log cũng là kiến thức quan trọng.

---

## 9. Câu hỏi phỏng vấn thường gặp

Để bạn hình dung mức độ mà interviewer kỳ vọng, đây là một số câu hỏi điển hình:

- "UITableView trong app bạn đang giật khi scroll, bạn sẽ làm gì để debug và fix?"
- "App bạn bị crash do memory pressure, bạn tìm nguyên nhân bằng cách nào?"
- "Giải thích một lần bạn tối ưu performance thực tế trong project và kết quả đạt được?"
- "Launch time app bạn là 3 giây, làm sao giảm xuống dưới 1 giây?"
- "Làm sao phát hiện retain cycle khi không có crash, chỉ có memory tăng dần?"

---

# sử dụng các lệnh như po, p, v, expression, bt (backtrace) để kiểm tra trạng thái runtime

# LLDB Debugger Commands — Giải thích chi tiết

## Bối cảnh trước

Khi bạn đặt breakpoint và app dừng lại tại đó, bạn sẽ thấy **(lldb)** prompt ở Debug Console phía dưới Xcode. Đây là nơi bạn gõ các lệnh để "soi" trạng thái của app tại thời điểm đó.

---

## 1. `po` — Print Object Description

`po` là viết tắt của **"print object"**. Nó gọi property `.description` (hoặc `debugDescription`) của object và in ra kết quả dưới dạng mà con người đọc được.

```swift
// Giả sử bạn có biến này trong code
let user = User(name: "Minh", age: 28)
let numbers = [1, 2, 3, 4, 5]
```

```
// Tại breakpoint, gõ trong LLDB console:

(lldb) po user
▿ User
  - name: "Minh"
  - age: 28

(lldb) po numbers
▿ 5 elements
  - 0: 1
  - 1: 2
  - 2: 3
  - 3: 4
  - 4: 5

(lldb) po user.name
"Minh"

(lldb) po numbers.count
5
```

**Khi nào dùng:** Khi bạn muốn xem nhanh giá trị của một biến, đặc biệt là các object phức tạp như model, array, dictionary. Đây là lệnh bạn sẽ dùng nhiều nhất.

**Custom description:** Bạn có thể conform `CustomDebugStringConvertible` để tùy chỉnh output:

```swift
extension User: CustomDebugStringConvertible {
    var debugDescription: String {
        return "User(\(name), tuổi: \(age))"
    }
}

// Kết quả khi po:
(lldb) po user
User(Minh, tuổi: 28)
```

---

## 2. `p` — Print (Raw/Compiler-level)

`p` in ra giá trị kèm theo **kiểu dữ liệu** ở dạng thô hơn `po`. Nó sử dụng compiler để evaluate expression.

```
(lldb) p user
(MyApp.User) $R0 = {
  name = "Minh"
  age = 28
}

(lldb) p user.age
(Int) $R1 = 28

(lldb) p 5 + 10
(Int) $R2 = 15

(lldb) p numbers.count > 3
(Bool) $R3 = true
```

**Sự khác biệt giữa `p` và `po`:**

```
// po → đọc dễ hơn, gọi .description
(lldb) po user.name
"Minh"

// p → hiển thị kiểu dữ liệu, chi tiết kỹ thuật hơn
(lldb) p user.name
(String) $R4 = "Minh"
```

**Khi nào dùng:** Khi bạn cần biết chính xác kiểu dữ liệu của một giá trị, hoặc khi `po` không hoạt động tốt với kiểu primitive. Cũng hữu ích khi bạn muốn tính toán nhanh một biểu thức.

---

## 3. `v` — Frame Variable (Nhanh nhất)

`v` đọc trực tiếp giá trị từ bộ nhớ mà **không chạy qua compiler**. Điều này khiến nó nhanh hơn `p` và `po` rất nhiều.

```
(lldb) v user
(MyApp.User) user = {
  name = "Minh"
  age = 28
}

(lldb) v user.name
(String) user.name = "Minh"

(lldb) v numbers
([Int]) numbers = 5 values {
  [0] = 1
  [1] = 2
  [2] = 3
  [3] = 4
  [4] = 5
}
```

**Giới hạn quan trọng:** Vì `v` không chạy code, nó **không thể** evaluate expression hay gọi method:

```
(lldb) v user.age + 1        // ❌ Không hoạt động
(lldb) v numbers.count        // ❌ Không hoạt động (.count là computed property)
(lldb) v user.name            // ✅ Hoạt động (stored property)
```

**Khi nào dùng:** Khi bạn chỉ cần xem nhanh giá trị của stored property, đặc biệt trong những lúc debug phức tạp mà `p`/`po` chạy chậm hoặc gây side effect.

---

## 4. `expression` — Thực thi code tại runtime

Đây là lệnh mạnh nhất. `expression` (viết tắt là `e` hoặc `expr`) cho phép bạn **chạy code Swift/ObjC ngay tại thời điểm breakpoint**, thay đổi giá trị biến, gọi hàm, thậm chí thay đổi UI mà không cần build lại app.

```
// Thay đổi giá trị biến ngay lúc runtime
(lldb) expression user.name = "Hùng"
// → Từ đây trở đi, user.name sẽ là "Hùng" khi app tiếp tục chạy

// Thay đổi UI ngay lập tức
(lldb) expression view.backgroundColor = UIColor.red
(lldb) expression CATransaction.flush()
// → View sẽ chuyển sang màu đỏ ngay mà không cần chạy lại app

// Gọi hàm
(lldb) expression print("Debug: user = \(user.name)")

// Tạo biến tạm để test logic
(lldb) expression let testArray = [1, 2, 3]
(lldb) expression testArray.filter { $0 > 1 }
```

**Ứng dụng thực tế rất mạnh:**

```
// Giả sử bạn nghi ngờ một bug xảy ra khi isLoggedIn = false
// Thay vì logout rồi test lại, bạn chỉ cần:
(lldb) expr UserManager.shared.isLoggedIn = false
// → Tiếp tục chạy app, nó sẽ hoạt động như chưa login

// Force unwrap optional để test nhanh mà không sửa code
(lldb) expr let img = UIImage(named: "test_avatar")
(lldb) expr self.avatarImageView.image = img
(lldb) expr CATransaction.flush()
```

**Mẹo:** Thực ra `po` chính là alias của `expression --object-description --`, và `p` là alias của `expression --`. Nên `expression` là lệnh gốc, hai lệnh kia là shortcut.

---

## 5. `bt` — Backtrace (Call Stack)

`bt` hiển thị **call stack** — chuỗi các hàm đã được gọi để đến được dòng code hiện tại. Đây là công cụ quan trọng nhất khi bạn cần hiểu **"tại sao code này lại được gọi"**.

```
(lldb) bt
* thread #1, queue = 'com.apple.main-queue'
  * frame #0: MyApp.UserService.fetchProfile(id: "123") at UserService.swift:45
    frame #1: MyApp.ProfileViewModel.loadUser() at ProfileViewModel.swift:28
    frame #2: MyApp.ProfileViewController.viewDidLoad() at ProfileVC.swift:15
    frame #3: UIKitCore UIViewController.loadViewIfNeeded()
    frame #4: UIKitCore UINavigationController._pushViewController()
    ...
```

Đọc từ trên xuống: frame #0 là vị trí hiện tại, các frame bên dưới là chuỗi hàm đã gọi đến nó. Từ ví dụ trên bạn có thể đọc ngược: `NavigationController push → viewDidLoad → loadUser → fetchProfile`.

```
// Xem backtrace của TẤT CẢ threads (hữu ích khi debug deadlock)
(lldb) bt all

// Chỉ xem 5 frame gần nhất
(lldb) bt 5

// Di chuyển đến frame khác để kiểm tra biến ở đó
(lldb) frame select 1
// → Bây giờ bạn đang ở context của ProfileViewModel.loadUser()
(lldb) po self
// → In ra ProfileViewModel instance tại frame đó
```

**Khi nào dùng:** Khi app crash và bạn cần biết chuỗi sự kiện dẫn đến crash. Khi một hàm bị gọi bất ngờ và bạn muốn biết ai gọi nó. Khi debug deadlock, dùng `bt all` để xem tất cả thread đang làm gì.

---

## Tóm tắt so sánh

| Lệnh | Tốc độ | Gọi code? | Dùng khi |
|---|---|---|---|
| `v` | Nhanh nhất | Không | Xem nhanh stored property |
| `p` | Trung bình | Có | Cần biết kiểu dữ liệu, tính toán đơn giản |
| `po` | Trung bình | Có | Xem object dễ đọc, dùng hàng ngày |
| `expression` | Chậm nhất | Có | Thay đổi giá trị, test logic, sửa UI runtime |
| `bt` | Nhanh | Không | Xem call stack, tìm nguồn gốc lỗi |

---

## Ví dụ thực tế khi debug một bug

Giả sử UITableView hiển thị sai dữ liệu. Workflow debug sẽ như thế này:

```
// Bước 1: Đặt breakpoint tại cellForRowAt, xem data truyền vào
(lldb) po indexPath
[0, 3]

(lldb) po dataSource[indexPath.row]
▿ User
  - name: "Minh"
  - age: 28

// Bước 2: Kiểm tra toàn bộ dataSource
(lldb) po dataSource.map { $0.name }
["An", "Bình", "Chi", "Minh", "Dũng"]

// Bước 3: Nghi ngờ data bị sai từ đầu, xem ai gọi reload
(lldb) bt
* frame #0: cellForRowAt...
  frame #1: UIKitCore...
  frame #2: MyApp.HomeVC.handleResponse() at HomeVC.swift:82
  // → Ah, data đến từ handleResponse()

// Bước 4: Nhảy đến frame đó xem response
(lldb) frame select 2
(lldb) po response
// → Phát hiện API trả về data không đúng thứ tự

// Bước 5: Test fix nhanh tại runtime
(lldb) expr self.dataSource.sort { $0.name < $1.name }
(lldb) expr self.tableView.reloadData()
// → TableView reload với data đã sort, xác nhận fix đúng
```

# hiểu rõ cách đọc memory graph, nhận diện strong reference cycle giữa các object.

# Memory Graph Debugger — Đọc hiểu & Nhận diện Retain Cycle

## Bối cảnh: Tại sao cần quan tâm?

Trong Swift, ARC (Automatic Reference Counting) tự động giải phóng object khi không còn ai tham chiếu đến nó. Nhưng khi hai hay nhiều object giữ strong reference lẫn nhau, ARC không thể giải phóng bất kỳ object nào — chúng "sống mãi" trong bộ nhớ dù không ai dùng nữa. Đây gọi là **retain cycle** (hay strong reference cycle), và hậu quả là **memory leak**.

Memory leak tích tụ dần dần. App không crash ngay, nhưng bộ nhớ cứ tăng, tăng mãi cho đến khi iOS buộc phải kill app. Đây là loại bug rất khó phát hiện nếu không có công cụ.

---

## Phần 1: Hiểu Retain Cycle qua code

### Ví dụ 1 — Hai object giữ nhau

```swift
class Person {
    var name: String
    var apartment: Apartment?  // strong reference
    
    init(name: String) { self.name = name }
    
    deinit { print("\(name) được giải phóng") }
}

class Apartment {
    var unit: String
    var tenant: Person?  // strong reference ← VẤN ĐỀ Ở ĐÂY
    
    init(unit: String) { self.unit = unit }
    
    deinit { print("Apartment \(unit) được giải phóng") }
}
```

```swift
func createRetainCycle() {
    let minh = Person(name: "Minh")      // Person ref count = 1
    let apt = Apartment(unit: "101")      // Apartment ref count = 1
    
    minh.apartment = apt                  // Apartment ref count = 2
    apt.tenant = minh                     // Person ref count = 2
    
    // Khi hàm kết thúc:
    // - biến minh bị hủy → Person ref count giảm từ 2 → 1 (vẫn > 0)
    // - biến apt bị hủy  → Apartment ref count giảm từ 2 → 1 (vẫn > 0)
    // → Cả hai KHÔNG BAO GIỜ được giải phóng
    // → deinit KHÔNG BAO GIỜ được gọi
}
```

Hình dung bằng sơ đồ:

```
  ┌──────────────────────────────────────┐
  │                                      │
  │   ┌──────────┐     strong    ┌──────────────┐
  │   │  Person   │─────────────▶│  Apartment   │
  │   │  "Minh"   │◀─────────────│   "101"      │
  │   └──────────┘     strong    └──────────────┘
  │                                      │
  │   Cả hai giữ nhau → không ai giải   │
  │   phóng được → MEMORY LEAK          │
  └──────────────────────────────────────┘
```

### Ví dụ 2 — Closure retain cycle (phổ biến hơn rất nhiều)

```swift
class ProfileViewController: UIViewController {
    var name = "Minh"
    var onProfileLoaded: (() -> Void)?
    
    func loadProfile() {
        // Closure capture self (strong mặc định)
        onProfileLoaded = {
            print("Loaded: \(self.name)")
            //                    ^^^^
            //    closure giữ strong ref đến self
            //    self giữ strong ref đến closure qua property onProfileLoaded
            //    → RETAIN CYCLE
        }
    }
    
    deinit { print("ProfileVC deallocated") }  // Sẽ KHÔNG BAO GIỜ được gọi
}
```

```
  ┌─────────────────────────────────────────┐
  │                                         │
  │  ┌───────────────────┐     strong       │
  │  │ ProfileVC (self)  │────────────────┐ │
  │  │                   │                │ │
  │  │  .onProfileLoaded─┼──▶ ┌─────────┐ │ │
  │  │                   │    │ Closure  │ │ │
  │  │                   │◀───┤ captures │ │ │
  │  └───────────────────┘    │  self    │ │ │
  │         ▲    strong       └─────────┘ │ │
  │         │                             │ │
  │         └─────────────────────────────┘ │
  │                                         │
  │   self → closure → self → RETAIN CYCLE  │
  └─────────────────────────────────────────┘
```

### Ví dụ 3 — Delegate retain cycle

```swift
protocol DataManagerDelegate: AnyObject {
    func didLoadData()
}

class DataManager {
    // Nếu quên dùng weak ở đây → retain cycle
    var delegate: DataManagerDelegate?  // ❌ strong reference
    
    func fetchData() {
        // ... fetch xong
        delegate?.didLoadData()
    }
}

class HomeViewController: UIViewController, DataManagerDelegate {
    let manager = DataManager()  // HomeVC giữ strong ref đến manager
    
    override func viewDidLoad() {
        super.viewDidLoad()
        manager.delegate = self  // manager giữ strong ref đến HomeVC
        // → HomeVC ↔ DataManager giữ nhau → RETAIN CYCLE
    }
    
    func didLoadData() { /* update UI */ }
}
```

---

## Phần 2: Sử dụng Memory Graph Debugger

### Cách mở

Khi app đang chạy trong Xcode, nhấn nút **Debug Memory Graph** ở thanh debug phía dưới (biểu tượng hình 3 vòng tròn nối nhau). App sẽ tạm dừng và Xcode sẽ chụp "snapshot" toàn bộ object đang tồn tại trong bộ nhớ.

```
Vị trí nút:
┌──────────────────────────────────────────────────┐
│ Debug bar                                        │
│  [▶] [⏸] [⏹]  ...  [🔲] [📊] [⚙️]              │
│                             ^^^                  │
│                     Nút Memory Graph             │
│                  (3 circles connected)            │
└──────────────────────────────────────────────────┘
```

### Bật Malloc Stack Logging (quan trọng)

Trước khi debug, bạn cần bật tính năng này để Xcode ghi lại nơi mỗi object được tạo ra. Vào **Product → Scheme → Edit Scheme → Run → Diagnostics**, bật **Malloc Stack Logging** và chọn **"All Allocations and Free History"**. Nếu không bật, bạn sẽ chỉ thấy object tồn tại nhưng không biết nó được tạo ở đâu.

---

## Phần 3: Cách đọc Memory Graph — Chi tiết từng vùng

Khi Memory Graph mở ra, giao diện Xcode chia thành 3 phần:

```
┌─────────────────────┬─────────────────────────┬────────────────────┐
│                     │                         │                    │
│   LEFT PANEL        │    CENTER PANEL         │   RIGHT PANEL      │
│   (Object List)     │    (Visual Graph)       │   (Inspector)      │
│                     │                         │                    │
│  ┌───────────────┐  │   ┌───┐    ┌───┐       │  Backtrace:        │
│  │ ⚠ Person (2)  │  │   │ A │───▶│ B │       │  nơi object        │
│  │ ⚠ Apartment(1)│  │   │   │◀───│   │       │  được tạo ra       │
│  │  UIView (45)  │  │   └───┘    └───┘       │                    │
│  │  String (120) │  │                         │                    │
│  └───────────────┘  │                         │                    │
│                     │                         │                    │
└─────────────────────┴─────────────────────────┴────────────────────┘
```

### Left Panel — Object List

Panel bên trái liệt kê tất cả object đang sống trong bộ nhớ, nhóm theo class. Đây là nơi bạn bắt đầu.

**Dấu hiệu cần chú ý:**

Biểu tượng ⚠️ (cảnh báo tím) bên cạnh tên class nghĩa là Xcode nghi ngờ object đó bị leak. Đây là nơi bạn nên kiểm tra đầu tiên. Bạn có thể dùng bộ lọc phía dưới panel để chỉ hiện các object có vấn đề bằng cách nhấn nút filter "Show only leaked blocks".

Ngoài ra, bạn nên chú ý đến số lượng bất thường. Ví dụ nếu bạn thấy `ProfileViewController (5)` trong khi app chỉ nên có 1 instance, điều đó có nghĩa 4 instance cũ không được giải phóng.

### Center Panel — Visual Graph

Khi bạn click vào một object ở panel trái, panel giữa hiển thị đồ thị trực quan thể hiện ai đang giữ reference đến object đó.

```
Ví dụ: Click vào Person "Minh" bị leak

            ┌─────────────────┐
            │   Apartment     │
            │   "101"         │
            │                 │
            │  tenant ────────┼──────┐
            └─────────────────┘      │
                    ▲                │
                    │                ▼
                    │         ┌──────────────┐
                    │         │   Person     │
                    │         │   "Minh"     │
                    └─────────┤              │
                  apartment   └──────────────┘
```

**Cách đọc mũi tên:** Mũi tên đi từ object A đến object B nghĩa là **A đang giữ strong reference đến B**. Nhãn trên mũi tên cho biết tên property tạo ra reference đó. Nếu bạn thấy mũi tên tạo thành vòng tròn kín, đó chính là retain cycle.

### Right Panel — Inspector

Panel bên phải hiển thị thông tin chi tiết về object được chọn, bao gồm địa chỉ bộ nhớ, kiểu dữ liệu, kích thước, và quan trọng nhất là **backtrace** cho biết object này được tạo ra ở dòng code nào. Nhờ đó bạn biết chính xác cần sửa ở đâu.

---

## Phần 4: Ví dụ thực tế — Debug retain cycle từ đầu đến cuối

### Bước 1 — Phát hiện triệu chứng

Bạn đang test app và nhận ra rằng mỗi lần push rồi pop `ProfileViewController`, bộ nhớ tăng lên một chút và không giảm lại. Bạn thêm print trong deinit để kiểm tra:

```swift
class ProfileViewController: UIViewController {
    var viewModel: ProfileViewModel?
    
    deinit { print("ProfileVC deallocated") }  // Không bao giờ thấy log này
}

class ProfileViewModel {
    var onUpdate: (() -> Void)?
    
    deinit { print("ProfileVM deallocated") }  // Cũng không thấy
}
```

Khi pop ViewController mà không thấy "ProfileVC deallocated" trong console, đó là dấu hiệu rõ ràng của retain cycle.

### Bước 2 — Mở Memory Graph

Thao tác lại: push vào ProfileVC, pop ra, push vào lần nữa, pop ra. Sau đó nhấn nút Memory Graph. Tại panel trái bạn thấy:

```
⚠️ ProfileViewController (2)    ← Lẽ ra phải là 0 sau khi pop
⚠️ ProfileViewModel (2)         ← Tương tự
```

Có 2 instance của mỗi class đang tồn tại dù bạn đã pop cả 2 lần. Đây là leak.

### Bước 3 — Phân tích Graph

Click vào một trong 2 instance của `ProfileViewController`. Panel giữa hiển thị:

```
                    ┌─────────────────────┐
                    │  ProfileViewModel   │
                    │                     │
                    │  onUpdate (closure)─┼────┐
                    └─────────────────────┘    │
                            ▲                  │
                            │ viewModel        │ captures self
                            │ (strong)         │ (strong)
                            │                  ▼
                    ┌─────────────────────┐    ┌──────────┐
                    │ ProfileViewController│◀──│ Closure  │
                    │                     │    └──────────┘
                    └─────────────────────┘
```

Bạn thấy rõ vòng tròn: `ProfileVC → viewModel (strong) → closure → captures self (strong) → ProfileVC`.

### Bước 4 — Xem Backtrace tìm dòng code gây ra vấn đề

Click vào mũi tên từ Closure đến ProfileVC, panel phải hiển thị backtrace:

```
Backtrace (allocation):
  0  MyApp  ProfileViewController.setupBindings() — ProfileVC.swift:34
  1  MyApp  ProfileViewController.viewDidLoad()   — ProfileVC.swift:18
  ...
```

Mở file `ProfileVC.swift` dòng 34:

```swift
func setupBindings() {
    viewModel?.onUpdate = {
        // ← Đây! closure capture self mạnh
        self.tableView.reloadData()
        self.updateHeader()
    }
}
```

### Bước 5 — Fix

```swift
// FIX: Dùng [weak self] trong capture list
func setupBindings() {
    viewModel?.onUpdate = { [weak self] in
        guard let self else { return }
        self.tableView.reloadData()
        self.updateHeader()
    }
}
```

Sau khi fix, graph sẽ trở thành:

```
    ┌─────────────────────┐
    │  ProfileViewModel   │
    │                     │
    │  onUpdate (closure)─┼────┐
    └─────────────────────┘    │
            ▲                  │
            │ viewModel        │ captures self
            │ (strong)         │ (WEAK) ← đường đứt nét
            │                  ▼
    ┌───────────────────────┐  ┌──────────┐
    │ ProfileViewController │◁╌│ Closure  │
    │                       │  └──────────┘
    └───────────────────────┘
           ◁╌ = weak reference (không tính vào ref count)
```

Bây giờ khi pop VC: biến navigation stack không còn giữ VC → ref count VC giảm về 0 → VC bị dealloc → viewModel ref count giảm về 0 → viewModel bị dealloc → closure bị dealloc. Chuỗi giải phóng hoạt động đúng.

---

## Phần 5: Các pattern Retain Cycle thường gặp và cách fix

### Pattern 1 — Closure capture self

```swift
// ❌ BUG: retain cycle
class SearchVC: UIViewController {
    var searchService = SearchService()
    
    func search(query: String) {
        searchService.onResult = { results in
            self.displayResults(results)  // strong capture self
        }
    }
}

// ✅ FIX: weak self
func search(query: String) {
    searchService.onResult = { [weak self] results in
        self?.displayResults(results)
    }
}
```

### Pattern 2 — Timer

```swift
// ❌ BUG: Timer giữ strong ref đến target
class DashboardVC: UIViewController {
    var timer: Timer?
    
    override func viewDidLoad() {
        timer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,       // strong reference
            selector: #selector(refresh),
            userInfo: nil,
            repeats: true       // Timer sống mãi → VC sống mãi
        )
    }
}

// ✅ FIX: Dùng closure-based Timer với weak self
override func viewDidLoad() {
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        self?.refresh()
    }
}

// Và luôn invalidate khi không cần
override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    timer?.invalidate()
    timer = nil
}
```

### Pattern 3 — Delegate quên weak

```swift
// ❌ BUG
protocol NetworkManagerDelegate: AnyObject {
    func didFetchData(_ data: Data)
}

class NetworkManager {
    var delegate: NetworkManagerDelegate?  // strong
}

// ✅ FIX: luôn dùng weak cho delegate
class NetworkManager {
    weak var delegate: NetworkManagerDelegate?
}
```

### Pattern 4 — NotificationCenter (trước iOS 9) và KVO

```swift
// Từ iOS 9+, NotificationCenter tự remove observer khi object dealloc
// Nhưng với closure-based API, vẫn cần cẩn thận:

// ❌ BUG
class ChatVC: UIViewController {
    var observer: Any?
    
    override func viewDidLoad() {
        observer = NotificationCenter.default.addObserver(
            forName: .newMessage,
            object: nil,
            queue: .main
        ) { notification in
            self.handleNewMessage(notification)  // strong capture
        }
    }
}

// ✅ FIX
override func viewDidLoad() {
    observer = NotificationCenter.default.addObserver(
        forName: .newMessage,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        self?.handleNewMessage(notification)
    }
}

deinit {
    if let observer { NotificationCenter.default.removeObserver(observer) }
}
```

### Pattern 5 — Chuỗi object giữ nhau (3+ objects)

```swift
// Retain cycle không chỉ xảy ra giữa 2 object
// A → B → C → A cũng là retain cycle

class ViewControllerA {
    var coordinator: Coordinator?        // A → Coordinator
}

class Coordinator {
    var viewModel: ViewModel?            // Coordinator → ViewModel
}

class ViewModel {
    var onComplete: (() -> Void)?        // ViewModel → closure → A
}

// Khi setup:
// vcA.coordinator = coordinator          A ──strong──▶ Coordinator
// coordinator.viewModel = viewModel      Coordinator ─strong──▶ ViewModel
// viewModel.onComplete = { vcA.doSomething() }  ViewModel ─strong──▶ A
//
// Vòng: A → Coordinator → ViewModel → A
// Fix: weak bất kỳ một mắt xích nào trong vòng
```

---

## Phần 6: Kỹ thuật phát hiện nhanh không cần Memory Graph

Ngoài Memory Graph, bạn nên kết hợp các phương pháp sau trong quá trình phát triển hàng ngày:

**deinit print:** Thêm print vào `deinit` của mọi ViewController và ViewModel. Nếu pop VC mà không thấy log, chắc chắn có leak.

```swift
deinit {
    #if DEBUG
    print("♻️ \(String(describing: type(of: self))) deallocated")
    #endif
}
```

**Xcode Memory Report:** Trong Debug Navigator (⌘6), tab Memory hiển thị biểu đồ bộ nhớ realtime. Nếu bộ nhớ chỉ tăng mà không bao giờ giảm khi pop VC, đó là dấu hiệu leak.

**Instruments — Leaks:** Chạy app qua Instruments với template Leaks, nó sẽ tự động phát hiện và báo leak theo thời gian thực.

---

## Phần 7: Câu hỏi phỏng vấn thường gặp

Interviewer có thể hỏi bạn những câu như:

- "Giải thích sự khác biệt giữa `weak` và `unowned`, khi nào dùng cái nào?"
- "Cho một đoạn code, chỉ ra retain cycle và cách fix."
- "App bạn bị memory tăng dần sau mỗi lần navigate, bạn debug thế nào?"
- "Closure trong `DispatchQueue.main.async { self.doSomething() }` có gây retain cycle không? Tại sao?"

Câu cuối là câu bẫy: `DispatchQueue.main.async` **không gây retain cycle** vì closure chỉ được giữ tạm thời bởi GCD, sau khi thực thi xong closure được giải phóng, phá vỡ reference. Retain cycle chỉ xảy ra khi closure được **lưu trữ lâu dài** dưới dạng property.

---

# Off-main-thread rendering: Decode image trên background thread

# Off-Main-Thread Image Decoding — Giải thích chi tiết

## Tại sao đây là vấn đề?

Trước khi đi vào kỹ thuật, bạn cần hiểu một sự thật mà nhiều iOS developer không biết: **khi bạn gán một UIImage vào UIImageView, hình ảnh chưa thực sự được decode**. iOS "lười" — nó trì hoãn việc decode cho đến thời điểm cuối cùng, tức là ngay trước khi render lên màn hình. Và việc decode đó xảy ra trên **main thread**.

---

## Phần 1: Image Pipeline — Chuyện gì xảy ra từ lúc load đến lúc hiển thị

### Toàn bộ quá trình từ file đến pixel trên màn hình

```
Bước 1          Bước 2           Bước 3          Bước 4
LOAD            DECODE           RENDER          DISPLAY
                
File/Network    Compressed       Bitmap          Pixels
  → Data        → UIImage       → CGContext      → Screen
                
┌──────┐      ┌───────────┐    ┌──────────┐    ┌────────┐
│ JPEG │      │ UIImage   │    │ Bitmap   │    │ Screen │
│ PNG  │ ───▶ │ (vẫn là  │───▶│ (decoded │───▶│ 60fps  │
│ Data │      │ compressed)│    │  pixels) │    │        │
└──────┘      └───────────┘    └──────────┘    └────────┘
                
  Ở đâu:        Ở đâu:          Ở đâu:
  Background     MAIN THREAD     MAIN THREAD
  (bạn kiểm     (iOS tự làm    (Core Animation)
   soát được)    NGẦM, bạn
                 không thấy)
                    ⬆
              VẤN ĐỀ NẰM Ở ĐÂY
```

### Bước 1 — Load: Đọc data từ file hoặc network

```swift
// Từ file
let data = try Data(contentsOf: fileURL)

// Từ network
let (data, _) = try await URLSession.shared.data(from: imageURL)
```

Ở bước này bạn chỉ có raw data — một chuỗi bytes ở định dạng JPEG, PNG, WebP, v.v. Data này đã được **nén** (compressed).

### Bước 2 — Tạo UIImage (vẫn chưa decode!)

```swift
let image = UIImage(data: data)
```

Đây là điều nhiều người hiểu sai. `UIImage(data:)` **không decode** hình ảnh. Nó chỉ tạo một object wrapper quanh compressed data. UIImage ở giai đoạn này rất nhẹ vì chưa giải nén.

### Bước 3 — Decode (bước tốn kém nhất, xảy ra NGẦM trên main thread)

```swift
imageView.image = image
// → Tại frame render tiếp theo, Core Animation cần pixel data
// → iOS phát hiện image chưa decode
// → iOS DECODE trên main thread ngay lúc đó
// → Nếu ảnh lớn, main thread bị block → UI GIẬT
```

Decode là quá trình giải nén compressed data (JPEG, PNG) thành **bitmap** — một mảng pixel RGBA mà GPU có thể hiểu được. Đây là bước tốn CPU và bộ nhớ nhất.

### Tại sao decode tốn kém?

```
Ví dụ: Một ảnh chụp từ iPhone

File JPEG:        ~3 MB (compressed)
Sau khi decode:   ~33 MB (uncompressed bitmap)

Tính toán:
  4032 x 3024 pixels
  × 4 bytes/pixel (RGBA)
  = 48,771,072 bytes
  ≈ 46.5 MB bitmap trong bộ nhớ

Thời gian decode: 20-100ms tùy thiết bị
Main thread budget cho 60fps: chỉ 16.67ms/frame
```

Một ảnh đã có thể vượt quá budget của một frame. Nếu bạn scroll một UITableView/UICollectionView với nhiều ảnh, mỗi cell xuất hiện đều trigger decode → frame bị drop liên tục → **scroll giật**.

---

## Phần 2: Giải pháp — Decode trên Background Thread

Ý tưởng cốt lõi rất đơn giản: thay vì để iOS tự decode ngầm trên main thread, bạn **chủ động decode trước** trên background thread. Khi gán vào UIImageView, image đã sẵn sàng, main thread không phải làm gì thêm.

### Cách 1 — Force decode bằng CGContext (Cách cơ bản nhất)

```swift
func decodedImage(from data: Data) -> UIImage? {
    guard let image = UIImage(data: data),
          let cgImage = image.cgImage else { return nil }
    
    let width = cgImage.width
    let height = cgImage.height
    
    // Tạo một CGContext (bitmap context)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,                           // Để hệ thống cấp phát bộ nhớ
        width: width,
        height: height,
        bitsPerComponent: 8,                 // 8 bit cho mỗi channel (R, G, B, A)
        bytesPerRow: width * 4,              // 4 bytes per pixel (RGBA)
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
    ) else { return nil }
    
    // VẼ image vào context → BẮT BUỘC decode xảy ra ngay tại đây
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    
    // Tạo CGImage mới từ context → image này ĐÃ DECODE, sẵn sàng render
    guard let decodedCGImage = context.makeImage() else { return nil }
    
    return UIImage(cgImage: decodedCGImage)
}
```

**Tại sao `context.draw()` buộc decode xảy ra?** Khi bạn vẽ một CGImage vào CGContext, hệ thống bắt buộc phải đọc từng pixel từ compressed data để vẽ lên bitmap context. Đây chính là quá trình decode. Sau khi vẽ xong, `context.makeImage()` trả về một CGImage mới mà data đã ở dạng uncompressed bitmap — không cần decode lần nữa.

### Cách 2 — Dùng ImageIO (Hiệu quả hơn, recommended bởi Apple)

```swift
import ImageIO

func decodedImage(from data: Data) -> UIImage? {
    let imageSource = CGImageSourceCreateWithData(data as CFData, nil)
    guard let source = imageSource else { return nil }
    
    let options: [CFString: Any] = [
        // Yêu cầu decode ngay, không lazy
        kCGImageSourceShouldCache: true,
        
        // Cho phép tạo thumbnail từ full image nếu cần
        kCGImageSourceShouldAllowFloat: true
    ]
    
    guard let cgImage = CGImageSourceCreateImageAtIndex(
        source, 0, options as CFDictionary
    ) else { return nil }
    
    return UIImage(cgImage: cgImage)
}
```

### Kết hợp với Background Thread

```swift
func loadAndDecodeImage(from url: URL) async -> UIImage? {
    // Bước 1: Download trên background (URLSession tự xử lý)
    guard let (data, _) = try? await URLSession.shared.data(from: url) else {
        return nil
    }
    
    // Bước 2: Decode trên background thread
    let decodedImage = await Task.detached(priority: .userInitiated) {
        return self.decodedImage(from: data)
    }.value
    
    return decodedImage
    // Bước 3: Caller gán vào imageView trên main thread
    // Image đã decode sẵn → main thread không bị block
}

// Sử dụng trong ViewController
func configureCell(with imageURL: URL) {
    Task {
        let image = await loadAndDecodeImage(from: imageURL)
        // Đã quay về main thread (Task trong ViewController context)
        imageView.image = image  // ← Không cần decode nữa, siêu nhanh
    }
}
```

---

## Phần 3: Downsampling — Kỹ thuật quan trọng hơn cả Decode

Decode trên background là tốt, nhưng vẫn chưa đủ nếu ảnh quá lớn. Ví dụ thực tế: hiển thị ảnh 4032×3024 trong một UIImageView kích thước 100×100 point (200×200 pixel trên 2x retina). Bạn đang decode 46MB bitmap chỉ để hiển thị vùng 200×200 pixel.

**Downsampling** giải quyết vấn đề này: decode ảnh ở kích thước nhỏ hơn, chỉ vừa đủ cho kích thước hiển thị thực tế.

```swift
/// Downsample image hiệu quả với ImageIO
/// - Parameters:
///   - data: raw image data (JPEG, PNG...)
///   - pointSize: kích thước hiển thị (theo point, VD: 100x100)
///   - scale: screen scale (thường là UIScreen.main.scale = 2.0 hoặc 3.0)
func downsampledImage(
    from data: Data,
    to pointSize: CGSize,
    scale: CGFloat = UIScreen.main.scale
) -> UIImage? {
    
    let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let imageSource = CGImageSourceCreateWithData(
        data as CFData,
        imageSourceOptions
    ) else { return nil }
    
    // Tính pixel size thực tế cần hiển thị
    let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
    
    let downsampleOptions: [CFString: Any] = [
        // Tạo thumbnail với kích thước tối đa
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels,
        
        // Decode ngay lập tức (không lazy)
        kCGImageSourceShouldCacheImmediately: true,
        
        // Giữ tỷ lệ ảnh
        kCGImageSourceCreateThumbnailWithTransform: true
    ]
    
    guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(
        imageSource, 0, downsampleOptions as CFDictionary
    ) else { return nil }
    
    return UIImage(cgImage: downsampledImage)
}
```

**Hiệu quả của downsampling:**

```
Trường hợp: Ảnh 4032x3024, hiển thị trong cell 100x100pt (@2x)

Không downsample:
  Decode full: 4032 × 3024 × 4 bytes = 46.5 MB
  Thời gian decode: ~50ms
  
Có downsample:
  Decode size: 200 × 150 × 4 bytes = 120 KB
  Thời gian decode: ~1ms
  
  Tiết kiệm: 99.7% bộ nhớ, 98% thời gian CPU
```

### Sử dụng thực tế trong UICollectionView

```swift
class PhotoCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private var currentTask: Task<Void, Never>?
    
    // Được gọi khi cell chuẩn bị hiển thị
    func configure(with imageData: Data) {
        // Hủy task cũ nếu cell được reuse
        // (user scroll nhanh, cell cũ chưa load xong đã bị reuse)
        currentTask?.cancel()
        
        // Reset image tránh hiện ảnh cũ
        imageView.image = nil
        
        let cellSize = imageView.bounds.size
        
        currentTask = Task {
            // Downsample + decode trên background thread
            let image = await Task.detached(priority: .userInitiated) {
                return downsampledImage(
                    from: imageData,
                    to: cellSize
                )
            }.value
            
            // Kiểm tra task chưa bị cancel (cell chưa bị reuse)
            guard !Task.isCancelled else { return }
            
            // Gán image đã decode sẵn lên main thread
            imageView.image = image
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        currentTask?.cancel()
        imageView.image = nil
    }
}
```

---

## Phần 4: Kingfisher & SDWebImage làm gì bên dưới?

Khi bạn viết một dòng đơn giản như:

```swift
imageView.kf.setImage(with: url)
// hoặc
imageView.sd_setImage(with: url)
```

Bên dưới, chúng thực hiện toàn bộ pipeline sau:

```
┌─────────────────────────────────────────────────────────────────┐
│                     IMAGE LOADING PIPELINE                      │
│                                                                 │
│  1. CHECK MEMORY CACHE                                          │
│     ┌──────────────┐                                            │
│     │ NSCache       │── Hit? ──▶ Trả về ngay (< 1ms)           │
│     │ (decoded      │                                           │
│     │  bitmap)      │── Miss? ──▶ Tiếp tục bước 2              │
│     └──────────────┘                                            │
│                                                                 │
│  2. CHECK DISK CACHE                                            │
│     ┌──────────────┐                                            │
│     │ FileManager   │── Hit? ──┐                                │
│     │ (compressed   │          ▼                                │
│     │  data trên    │    Decode trên background                 │
│     │  ổ đĩa)      │    → Cache vào memory                     │
│     │              │    → Trả về                                │
│     │              │                                            │
│     │              │── Miss? ──▶ Tiếp tục bước 3               │
│     └──────────────┘                                            │
│                                                                 │
│  3. DOWNLOAD                                                    │
│     ┌──────────────┐                                            │
│     │ URLSession    │── Download trên background thread          │
│     │ (background)  │                                           │
│     └──────┬───────┘                                            │
│            ▼                                                    │
│  4. DECODE + PROCESS (trên background thread)                   │
│     ┌──────────────┐                                            │
│     │ Decode       │── CGContext / ImageIO                       │
│     │ Downsample   │── Resize cho kích thước thực tế            │
│     │ Transform    │── Round corners, blur, v.v.                │
│     └──────┬───────┘                                            │
│            ▼                                                    │
│  5. CACHE                                                       │
│     ┌──────────────┐                                            │
│     │ Memory cache │── Lưu decoded bitmap                       │
│     │ Disk cache   │── Lưu compressed data                      │
│     └──────┬───────┘                                            │
│            ▼                                                    │
│  6. DISPLAY (trên main thread)                                  │
│     ┌──────────────┐                                            │
│     │ imageView    │── .image = decodedImage                    │
│     │ .image       │── Main thread không phải decode            │
│     └──────────────┘   → SCROLL MƯỢT                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Điểm đáng chú ý trong thiết kế

**Memory cache lưu decoded bitmap, disk cache lưu compressed data.** Lý do: memory cache cần trả về nhanh nhất có thể nên lưu bitmap sẵn sàng render. Disk cache cần tiết kiệm dung lượng nên lưu dạng nén. Khi đọc từ disk cache, vẫn cần decode lại trên background thread.

**Coalescing requests:** Nếu 5 cell cùng request một URL, thư viện chỉ download một lần và trả kết quả cho cả 5.

**Cancellation:** Khi cell bị reuse (user scroll nhanh), request cũ bị cancel để không lãng phí bandwidth và CPU.

---

## Phần 5: iOS 15+ — UIImage mới hỗ trợ decode sẵn

Từ iOS 15, Apple cung cấp API chính thức để chuẩn bị thumbnail hiệu quả:

```swift
// preparingThumbnail — synchronous, dùng trên background thread
Task.detached {
    let thumbnail = await originalImage.byPreparingThumbnail(
        ofSize: CGSize(width: 200, height: 200)
    )
    
    await MainActor.run {
        imageView.image = thumbnail
    }
}

// Hoặc async version
let thumbnail = await originalImage.byPreparingThumbnail(
    ofSize: CGSize(width: 200, height: 200)
)

// prepareForDisplay — decode ở kích thước gốc
await originalImage.byPreparingForDisplay()
```

API này bên dưới sử dụng cùng kỹ thuật ImageIO downsampling nhưng được Apple tối ưu thêm cho từng loại chip.

---

## Phần 6: Cách kiểm chứng vấn đề bằng Instruments

Để thực sự thấy sự khác biệt, bạn dùng Instruments:

**Time Profiler:** Chạy app, scroll UICollectionView có nhiều ảnh. Nếu bạn thấy `CA::Render::copy_image` hoặc `ImageIO_JPEG_decode` chiếm nhiều thời gian trên main thread, đó là dấu hiệu ảnh đang bị decode trên main thread.

**Core Animation instrument** với option **"Color Blended Layers"** và **"Color Misaligned Images"**: vùng màu vàng cho thấy image size không khớp với view size — nghĩa là bạn đang load ảnh quá lớn so với cần thiết, cần downsample.

---

## Phần 7: Câu hỏi phỏng vấn thường gặp

Một số câu interviewer có thể hỏi liên quan đến chủ đề này:

**"UICollectionView hiển thị ảnh bị giật khi scroll, nguyên nhân có thể là gì?"** — Câu trả lời nên bao gồm: decode ảnh trên main thread, ảnh quá lớn so với kích thước hiển thị (cần downsample), không có cache nên decode lại mỗi lần cell xuất hiện, layout tính toán phức tạp trên main thread.

**"Giải thích sự khác biệt giữa UIImage(named:) và UIImage(contentsOfFile:)?"** — `UIImage(named:)` có hệ thống cache nội bộ của Apple, image được cache sau lần dùng đầu tiên và cache theo tên. `UIImage(contentsOfFile:)` không cache, mỗi lần gọi tạo instance mới. Dùng `named:` cho asset nhỏ dùng nhiều lần (icon, button), dùng `contentsOfFile:` cho ảnh lớn dùng một lần (ảnh user upload) để tránh chiếm memory cache.

**"Nếu không dùng thư viện bên thứ 3, bạn sẽ tự xây dựng image loading pipeline thế nào?"** — Đây là câu hỏi kiểm tra hiểu biết sâu. Bạn cần mô tả các bước: check memory cache (NSCache) → check disk cache → download → decode + downsample trên background → cache → display trên main thread, kèm theo xử lý cancellation khi cell reuse.

---

# MetricKit (Apple's framework để thu thập performance metrics)

# MetricKit — Thu thập Performance Metrics từ người dùng thực

## Tại sao cần MetricKit?

Khi bạn phát triển app, bạn dùng Instruments, Time Profiler, Memory Graph để debug trên máy mình. Nhưng đây là môi trường lý tưởng — bạn có iPhone mới nhất, mạng WiFi nhanh, ít dữ liệu. Người dùng thực thì khác: họ dùng iPhone cũ, mạng 3G yếu, bộ nhớ đầy, hàng trăm app chạy nền. Những vấn đề performance chỉ xảy ra trên thiết bị thực mà bạn không bao giờ tái hiện được trên máy dev.

MetricKit giải quyết vấn đề này. Nó thu thập dữ liệu performance **trực tiếp từ thiết bị của người dùng thực**, gom lại và gửi về cho app của bạn để phân tích. Bạn không cần cài SDK bên thứ 3, không cần server riêng — Apple tự thu thập và gửi cho bạn.

---

## Phần 1: Tổng quan kiến trúc

```
┌──────────────────────────────────────────────────────────┐
│                    THIẾT BỊ NGƯỜI DÙNG                   │
│                                                          │
│  ┌─────────┐     ┌──────────────┐     ┌──────────────┐  │
│  │ Your App│     │   iOS System │     │  MetricKit   │  │
│  │         │────▶│   Monitors   │────▶│  Framework   │  │
│  │         │     │              │     │              │  │
│  └─────────┘     │ • CPU usage  │     │ Gom data     │  │
│                  │ • Memory     │     │ mỗi 24h      │  │
│                  │ • Disk I/O   │     │              │  │
│                  │ • Network    │     │ Gửi payload  │  │
│                  │ • Hang time  │     │ cho app      │  │
│                  │ • Battery    │     │              │  │
│                  └──────────────┘     └──────┬───────┘  │
│                                              │          │
└──────────────────────────────────────────────┼──────────┘
                                               │
                                               ▼
                                    ┌──────────────────┐
                                    │ MXMetricManager  │
                                    │ Delegate         │
                                    │                  │
                                    │ Bạn nhận data    │
                                    │ và xử lý        │
                                    └──────────────────┘
```

Điểm quan trọng: iOS **tự động** theo dõi app bạn ở mức hệ thống. Bạn không cần instrument code để đo CPU hay memory. MetricKit chỉ đóng vai trò cầu nối để đưa dữ liệu đó về cho bạn.

---

## Phần 2: Hai loại dữ liệu MetricKit cung cấp

### Loại 1 — MXMetricPayload (Metrics tổng hợp theo ngày)

Đây là dữ liệu performance được iOS gom trong **24 giờ**, sau đó gửi về cho app dưới dạng một payload duy nhất. Bạn nhận được nó vào khoảng thời gian sau khi hết chu kỳ 24h, thường là khi user mở app.

```
┌─────────────────────────────────────────────────────┐
│               MXMetricPayload                       │
│               (gom trong 24h)                       │
│                                                     │
│  ┌─────────────────────────────────────────────┐    │
│  │ CPU Metrics                                 │    │
│  │  • Tổng CPU time                            │    │
│  │  • CPU time theo instruction count          │    │
│  └─────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────┐    │
│  │ Memory Metrics                              │    │
│  │  • Peak memory usage                        │    │
│  │  • Average suspended memory                 │    │
│  └─────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────┐    │
│  │ Display Metrics                             │    │
│  │  • Scroll hitch rate (tỷ lệ frame bị giật) │    │
│  │  • Hitch time ratio                         │    │
│  └─────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────┐    │
│  │ Launch Metrics                              │    │
│  │  • Time to first draw                       │    │
│  │  • Optimized/unoptimized time               │    │
│  │  • Resume time                              │    │
│  └─────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────┐    │
│  │ Disk I/O, Network, Battery, Location,       │    │
│  │ Animation, App Exit Metrics...              │    │
│  └─────────────────────────────────────────────┘    │
│                                                     │
│  timeStampBegin: 2025-03-08T00:00:00Z               │
│  timeStampEnd:   2025-03-09T00:00:00Z               │
└─────────────────────────────────────────────────────┘
```

### Loại 2 — MXDiagnosticPayload (Diagnostic, gửi sớm hơn)

Từ iOS 14, MetricKit bổ sung **diagnostic payload** chứa thông tin về crash, hang, disk write exception, và CPU exception. Khác với metric payload gom 24h, diagnostic payload có thể được gửi **trong vòng 1 giờ** sau khi sự cố xảy ra (từ iOS 16).

```
┌─────────────────────────────────────────────────────┐
│             MXDiagnosticPayload                     │
│                                                     │
│  ┌─────────────────────────────────────────────┐    │
│  │ Crash Diagnostics                           │    │
│  │  • Exception type, code                     │    │
│  │  • Full call stack (đã symbolicate)         │    │
│  │  • Signal info                              │    │
│  └─────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────┐    │
│  │ Hang Diagnostics                            │    │
│  │  • Hang duration                            │    │
│  │  • Call stack tại thời điểm hang            │    │
│  └─────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────┐    │
│  │ CPU Exception Diagnostics                   │    │
│  │  • Total CPU time vượt ngưỡng               │    │
│  │  • Call stack của code tốn CPU              │    │
│  └─────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────┐    │
│  │ Disk Write Exception Diagnostics            │    │
│  │  • Tổng bytes ghi vượt ngưỡng              │    │
│  │  • Call stack của code ghi disk nhiều       │    │
│  └─────────────────────────────────────────────┘    │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## Phần 3: Triển khai MetricKit — Từng bước

### Bước 1 — Tạo Subscriber class

```swift
import MetricKit

class PerformanceMonitor: NSObject {
    
    // Singleton để đảm bảo chỉ có 1 subscriber
    static let shared = PerformanceMonitor()
    
    private override init() {
        super.init()
    }
    
    /// Gọi hàm này trong AppDelegate hoặc App init
    func startMonitoring() {
        // Đăng ký nhận payload từ MetricKit
        MXMetricManager.shared.add(self)
    }
    
    func stopMonitoring() {
        MXMetricManager.shared.remove(self)
    }
}
```

### Bước 2 — Conform MXMetricManagerSubscriber

```swift
extension PerformanceMonitor: MXMetricManagerSubscriber {
    
    // MARK: - Nhận Metric Payload (gom 24h)
    // Được gọi tối đa 1 lần mỗi 24h
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            processMetricPayload(payload)
        }
    }
    
    // MARK: - Nhận Diagnostic Payload (crash, hang...)
    // Có thể được gọi trong vòng 1h sau sự cố (iOS 16+)
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            processDiagnosticPayload(payload)
        }
    }
}
```

### Bước 3 — Đăng ký trong AppDelegate / App

```swift
// UIKit AppDelegate
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        PerformanceMonitor.shared.startMonitoring()
        return true
    }
}

// Hoặc SwiftUI App
@main
struct MyApp: App {
    init() {
        PerformanceMonitor.shared.startMonitoring()
    }
    
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

---

## Phần 4: Xử lý Metric Payload — Đọc từng loại metric

### 4.1 — Launch Metrics (Thời gian khởi động)

```swift
func processMetricPayload(_ payload: MXMetricPayload) {
    
    // ═══════════════════════════════════════
    // LAUNCH METRICS
    // ═══════════════════════════════════════
    if let launchMetrics = payload.applicationLaunchMetrics {
        
        // Histogram: phân bố thời gian khởi động từ tất cả lần mở app
        // trong 24h qua trên thiết bị này
        let histogram = launchMetrics.histogrammedTimeToFirstDraw
        
        // histogram chứa nhiều bucket, mỗi bucket là một khoảng thời gian
        // Ví dụ: 0-200ms: 15 lần, 200-500ms: 3 lần, 500ms-1s: 1 lần
        //
        // Cấu trúc histogram:
        // ┌────────────────┬────────────┐
        // │ Khoảng thời gian│ Số lần xảy ra│
        // ├────────────────┼────────────┤
        // │   0ms - 200ms  │     15     │  ← Tốt
        // │ 200ms - 500ms  │      3     │  ← Chấp nhận được
        // │ 500ms -   1s   │      1     │  ← Cần tối ưu
        // │    1s -   2s   │      0     │
        // └────────────────┴────────────┘
        
        // Apple khuyến nghị: Time to First Draw < 400ms
        
        // Resume time: thời gian từ background về foreground
        let resumeHistogram = launchMetrics.histogrammedResumeTime
        // Apple khuyến nghị: Resume time < 100ms
        
        sendToAnalytics(event: "launch_metrics", data: [
            "timeToFirstDraw": histogram.jsonRepresentation(),
            "resumeTime": resumeHistogram.jsonRepresentation()
        ])
    }
}
```

**Tại sao là histogram chứ không phải một con số?** Vì trong 24h, user có thể mở app nhiều lần. Mỗi lần thời gian khởi động khác nhau (cold launch vs warm launch, thiết bị bận hay rảnh). Histogram cho bạn thấy **phân bố** — bao nhiêu lần nhanh, bao nhiêu lần chậm — thay vì chỉ một giá trị trung bình che giấu vấn đề.

### 4.2 — Hang Metrics (App bị đơ)

```swift
    // ═══════════════════════════════════════
    // HANG METRICS — App không phản hồi
    // ═══════════════════════════════════════
    // "Hang" = main thread bị block > 250ms
    // User cảm nhận: bấm nút không phản hồi, scroll bị đứng
    
    if let hangMetrics = payload.applicationResponsivenessMetrics {
        
        // Phân bố thời gian hang
        let hangHistogram = hangMetrics.histogrammedApplicationHangTime
        
        // Ví dụ histogram:
        // ┌──────────────────┬────────────┐
        // │ Hang duration    │ Số lần     │
        // ├──────────────────┼────────────┤
        // │ 250ms - 500ms   │     12     │  ← Nhẹ, nhưng nhiều
        // │ 500ms -    1s   │      5     │  ← User bắt đầu khó chịu
        // │    1s -    2s   │      2     │  ← Nghiêm trọng
        // │    2s+          │      1     │  ← Rất nghiêm trọng
        // └──────────────────┴────────────┘
        
        // Apple target: Hang rate < 1 hang/giờ sử dụng
        
        sendToAnalytics(event: "hang_metrics", data: [
            "hangTime": hangHistogram.jsonRepresentation()
        ])
    }
```

### 4.3 — Display Metrics (Scroll performance)

```swift
    // ═══════════════════════════════════════
    // DISPLAY METRICS — Hitch rate khi scroll
    // ═══════════════════════════════════════
    // "Hitch" = frame không render kịp deadline
    // 60fps → deadline 16.67ms/frame
    // 120fps (ProMotion) → deadline 8.33ms/frame
    
    if let displayMetrics = payload.displayMetrics {
        
        // scrollHitchTimeRatio = tổng hitch time / tổng scroll time
        // Đơn vị: ms hitch per giây scroll
        if let scrollMetrics = displayMetrics.scrollHitchTimeRatio {
            let ratio = scrollMetrics
            
            // Cách đọc:
            // < 5 ms/s   → Tốt (user hầu như không cảm nhận được)
            // 5-10 ms/s  → Cần cải thiện
            // > 10 ms/s  → Kém, scroll giật rõ ràng
            
            sendToAnalytics(event: "display_metrics", data: [
                "scrollHitchTimeRatio": ratio
            ])
        }
    }
```

### 4.4 — Memory Metrics

```swift
    // ═══════════════════════════════════════
    // MEMORY METRICS
    // ═══════════════════════════════════════
    
    if let memoryMetrics = payload.memoryMetrics {
        
        // Peak memory usage: đỉnh bộ nhớ app sử dụng
        let peakMemory = memoryMetrics.peakMemoryUsage
        // Đơn vị: UnitInformationStorage (bytes)
        // Ví dụ: 450 MB
        
        // Average suspended memory: bộ nhớ khi app ở background
        // Nếu quá cao → iOS sẽ kill app → user mở lại phải cold launch
        let suspendedMemory = memoryMetrics.averageSuspendedMemory
        
        sendToAnalytics(event: "memory_metrics", data: [
            "peakMemoryMB": peakMemory
                .converted(to: .megabytes).value,
            "avgSuspendedMemoryMB": suspendedMemory.averageMeasurement
                .converted(to: .megabytes).value
        ])
    }
```

### 4.5 — Battery & Network Metrics

```swift
    // ═══════════════════════════════════════
    // BATTERY / ENERGY METRICS
    // ═══════════════════════════════════════
    // Quan trọng vì Apple review app tiêu thụ pin nhiều
    
    if let cellCondition = payload.cellularConditionMetrics {
        // Thời gian ở từng mức tín hiệu cellular
        // Bars 1-5: tín hiệu từ yếu đến mạnh
        let histogram = cellCondition.histogrammedCellularConditionTime
        // Giúp bạn hiểu: user hay dùng app ở vùng sóng yếu không?
        // Nếu đa số ở sóng yếu → cần tối ưu network cho low bandwidth
    }
    
    if let networkMetrics = payload.networkTransferMetrics {
        // Tổng data upload/download trong 24h
        let upload = networkMetrics.cumulativeWifiUpload  
        let download = networkMetrics.cumulativeCellularDownload
        // Giúp phát hiện app đang dùng quá nhiều data cellular
    }
    
    // ═══════════════════════════════════════
    // APP EXIT METRICS (iOS 14+)
    // ═══════════════════════════════════════
    // Cho biết app bị tắt vì lý do gì
    
    if let exitMetrics = payload.applicationExitMetrics {
        
        let fg = exitMetrics.foregroundExitData
        let bg = exitMetrics.backgroundExitData
        
        // FOREGROUND exits (app đang hiển thị mà bị tắt)
        //   normalAppExit      → user tự tắt, bình thường
        //   abnormalAppExit    → crash không bắt được exception
        //   memoryResourceLimit→ dùng quá nhiều RAM, iOS kill
        //   watchdogExit       → main thread bị block quá lâu
        //   badAccess          → truy cập bộ nhớ không hợp lệ
        //   illegalInstruction → CPU instruction không hợp lệ
        
        // BACKGROUND exits (app ở background bị tắt)
        //   suspendedWithLockedFile → bị kill vì giữ file lock
        //   memoryPressureExit     → hệ thống cần RAM, kill app
        //   backgroundTaskAssertionTimeoutExit → BGTask quá lâu
        
        let abnormalExits = fg.cumulativeAbnormalExitCount
        let memoryKills = fg.cumulativeMemoryResourceLimitExitCount
        let watchdogKills = fg.cumulativeAppWatchdogExitCount
        
        sendToAnalytics(event: "exit_metrics", data: [
            "abnormalExits": abnormalExits,
            "memoryKills": memoryKills,
            "watchdogKills": watchdogKills
        ])
    }
```

App Exit Metrics đặc biệt giá trị vì nó cho bạn biết những thứ mà crash reporter thông thường không bắt được. Ví dụ watchdog kill (main thread bị block quá lâu, iOS tự kill app) không tạo crash log nhưng MetricKit ghi nhận được.

---

## Phần 5: Xử lý Diagnostic Payload — Crash & Hang chi tiết

```swift
func processDiagnosticPayload(_ payload: MXDiagnosticPayload) {
    
    // ═══════════════════════════════════════
    // CRASH DIAGNOSTICS
    // ═══════════════════════════════════════
    if let crashDiagnostics = payload.crashDiagnostics {
        for crash in crashDiagnostics {
            
            // Call stack TẠI THỜI ĐIỂM CRASH
            let callStack = crash.callStackTree
            
            // callStackTree chứa toàn bộ stack trace
            // ĐÃ SYMBOLICATE (có tên hàm, file, dòng code)
            // Đây là điểm khác biệt lớn: crash log từ App Store
            // thường chưa symbolicate, bạn phải tự làm
            
            let jsonData = callStack.jsonRepresentation()
            // jsonData chứa cấu trúc như:
            // {
            //   "callStacks": [{
            //     "threadAttributed": true,  ← thread gây crash
            //     "callStackRootFrames": [{
            //       "binaryName": "MyApp",
            //       "address": 4521738,
            //       "offsetIntoBinaryTextSegment": 123456,
            //       "sampleCount": 1,
            //       "subFrames": [...]        ← stack trace lồng nhau
            //     }]
            //   }]
            // }
            
            // Metadata bổ sung
            let exceptionType = crash.exceptionType  // EXC_BAD_ACCESS...
            let exceptionCode = crash.exceptionCode  // KERN_INVALID_ADDRESS...
            let signal = crash.signal                 // SIGSEGV, SIGABRT...
            
            sendToServer(event: "crash", data: [
                "callStack": jsonData,
                "exceptionType": exceptionType as Any,
                "exceptionCode": exceptionCode as Any,
                "signal": signal as Any
            ])
        }
    }
    
    // ═══════════════════════════════════════
    // HANG DIAGNOSTICS (chi tiết hơn hang metrics)
    // ═══════════════════════════════════════
    if let hangDiagnostics = payload.hangDiagnostics {
        for hang in hangDiagnostics {
            
            // Call stack tại thời điểm main thread bị block
            let callStack = hang.callStackTree
            // → Cho biết CHÍNH XÁC hàm nào đang block main thread
            
            let duration = hang.hangDuration
            // → Bao lâu main thread bị block
            
            // Ví dụ output:
            // Duration: 3.2 seconds
            // Main thread stack:
            //   frame 0: MyApp.DatabaseManager.fetchAllRecords()
            //   frame 1: MyApp.HomeVC.viewDidLoad()
            //   frame 2: UIKit.UIViewController.loadViewIfNeeded()
            //
            // → Kết luận: đang query database trên main thread
            //   trong viewDidLoad → cần chuyển sang background
            
            sendToServer(event: "hang", data: [
                "callStack": callStack.jsonRepresentation(),
                "durationSeconds": duration
            ])
        }
    }
    
    // ═══════════════════════════════════════
    // CPU EXCEPTION DIAGNOSTICS
    // ═══════════════════════════════════════
    // iOS gửi khi app dùng CPU vượt ngưỡng cho phép
    // (đặc biệt khi ở background)
    
    if let cpuDiagnostics = payload.cpuExceptionDiagnostics {
        for cpuException in cpuDiagnostics {
            let callStack = cpuException.callStackTree
            let totalCPUTime = cpuException.totalCPUTime
            let totalSampledTime = cpuException.totalSampledTime
            
            sendToServer(event: "cpu_exception", data: [
                "callStack": callStack.jsonRepresentation(),
                "totalCPUTime": totalCPUTime,
                "sampledTime": totalSampledTime
            ])
        }
    }
    
    // ═══════════════════════════════════════
    // DISK WRITE EXCEPTION DIAGNOSTICS
    // ═══════════════════════════════════════
    // iOS gửi khi app ghi disk vượt ngưỡng (thường 1GB/ngày)
    // Ghi disk nhiều → giảm tuổi thọ SSD → Apple rất quan tâm
    
    if let diskDiagnostics = payload.diskWriteExceptionDiagnostics {
        for diskException in diskDiagnostics {
            let callStack = diskException.callStackTree
            let totalWrites = diskException.totalWritesCaused
            
            sendToServer(event: "disk_exception", data: [
                "callStack": callStack.jsonRepresentation(),
                "totalWritesBytes": totalWrites
            ])
        }
    }
}
```

---

## Phần 6: Custom Metrics với mxSignpost

Ngoài các metrics tự động, MetricKit cho phép bạn **đo những thao tác cụ thể** trong app bằng signpost. Đây là cách bạn đo performance của business logic riêng.

```swift
import MetricKit
import os.signpost

// Bước 1: Tạo MXMetricManager log handle
let performanceLog = MXMetricManager.makeLogHandle(category: "Performance")

// Bước 2: Đặt signpost quanh code cần đo
class FeedViewController: UIViewController {
    
    func loadFeed() {
        // Bắt đầu đo
        mxSignpost(.begin, log: performanceLog, name: "FeedLoad")
        
        feedService.fetchFeed { [weak self] result in
            switch result {
            case .success(let posts):
                self?.processPosts(posts)
                
                // Kết thúc đo — thành công
                mxSignpost(.end, log: performanceLog, name: "FeedLoad")
                
            case .failure(let error):
                // Kết thúc đo — thất bại (vẫn cần end để đóng signpost)
                mxSignpost(.end, log: performanceLog, name: "FeedLoad")
            }
        }
    }
    
    func processImage(data: Data) {
        mxSignpost(.begin, log: performanceLog, name: "ImageProcess")
        
        let image = downsampledImage(from: data, to: CGSize(width: 200, height: 200))
        imageView.image = image
        
        mxSignpost(.end, log: performanceLog, name: "ImageProcess")
    }
}
```

Dữ liệu từ custom signpost được gom vào MXMetricPayload dưới dạng histogram, giống các metric khác. Bạn nhận được phân bố thời gian thực thi của "FeedLoad" và "ImageProcess" trên thiết bị người dùng thực.

```swift
// Đọc custom signpost data từ payload
func processMetricPayload(_ payload: MXMetricPayload) {
    if let signpostMetrics = payload.signpostMetrics {
        for metric in signpostMetrics {
            let name = metric.signpostName
            // name = "FeedLoad" hoặc "ImageProcess"
            
            let histogram = metric.signpostIntervalData
                .histogrammedSignpostDuration
            
            // histogram cho biết:
            // FeedLoad: 0-500ms: 45 lần, 500ms-1s: 10 lần, 1-2s: 2 lần
            // → 96.6% load feed < 1 giây, 3.4% > 1 giây → chấp nhận được
            
            sendToAnalytics(event: "custom_metric", data: [
                "name": name,
                "histogram": histogram.jsonRepresentation()
            ])
        }
    }
}
```

---

## Phần 7: Gửi data về server — Xử lý thực tế

```swift
private func sendToServer(event: String, data: [String: Any]) {
    // Cách 1: Gửi JSON trực tiếp lên server của bạn
    guard let url = URL(string: "https://api.yourapp.com/metrics") else { return }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body: [String: Any] = [
        "event": event,
        "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "",
        "osVersion": UIDevice.current.systemVersion,
        "deviceModel": deviceModel(),  // "iPhone14,5" v.v.
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "data": data
    ]
    
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    URLSession.shared.dataTask(with: request).resume()
}

// Cách 2: Dùng jsonRepresentation() cho toàn bộ payload
// Đơn giản hơn, gửi nguyên payload dạng JSON
func didReceive(_ payloads: [MXMetricPayload]) {
    for payload in payloads {
        let json = payload.jsonRepresentation()
        // json là Data, có thể gửi thẳng lên server
        uploadRawPayload(json)
    }
}
```

---

## Phần 8: Debug MetricKit trong quá trình phát triển

Vấn đề lớn nhất khi phát triển với MetricKit: bạn phải **chờ 24 giờ** mới nhận được payload. Để giải quyết, Apple cung cấp cách simulate:

### Dùng Xcode để trigger test payload

```
Xcode → Debug → Simulate MetricKit Payloads
```

Thao tác này gửi một payload giả đến app để bạn test code xử lý. Payload chứa dữ liệu mẫu, không phải dữ liệu thực.

### Debug bằng Xcode Organizer (dữ liệu thực từ App Store)

Sau khi app đã lên App Store và có người dùng, bạn có thể xem dữ liệu tổng hợp mà không cần tự xây server:

```
Xcode → Window → Organizer → chọn app → Metrics tab

┌─────────────────────────────────────────────────┐
│ Organizer — Metrics                             │
│                                                 │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐            │
│ │ Battery │ │ Launch   │ │ Hang    │            │
│ │ Usage   │ │ Time     │ │ Rate    │            │
│ └─────────┘ └─────────┘ └─────────┘            │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐            │
│ │ Memory  │ │ Disk    │ │ Scroll  │            │
│ │ Usage   │ │ Writes  │ │ Hitch   │            │
│ └─────────┘ └─────────┘ └─────────┘            │
│                                                 │
│ Hiển thị biểu đồ theo thời gian, so sánh giữa │
│ các version app, chia theo loại thiết bị        │
└─────────────────────────────────────────────────┘
```

Organizer hiển thị dữ liệu từ **tất cả người dùng** đã cho phép chia sẻ analytics với Apple. Bạn có thể so sánh launch time giữa version 2.0 và 2.1, xem memory usage trên iPhone 12 vs iPhone 15, v.v.

---

## Phần 9: MetricKit so với các giải pháp bên thứ 3

Một câu hỏi tự nhiên là tại sao dùng MetricKit khi đã có Firebase Performance, Datadog, hay New Relic? Đây là điểm khác biệt.

**MetricKit** thu thập ở mức hệ thống nên có quyền truy cập những metric mà SDK bên thứ 3 không thể đo: app exit reasons, watchdog kills, disk write exceptions, chính xác hitch rate từ Core Animation, energy impact thực sự. MetricKit không tốn bandwidth vì iOS gom data sẵn, không cần gửi liên tục. Hạn chế là data chỉ về mỗi 24h (hoặc 1h cho diagnostic), không có real-time dashboard, và bạn phải tự xây pipeline xử lý.

**Firebase/Datadog** cho phép real-time monitoring, custom trace chi tiết hơn, dashboard sẵn, alerting. Nhưng chúng chỉ đo được những gì SDK có thể observe từ trong app — không biết được app bị kill vì memory pressure hay watchdog.

Trong thực tế, senior developer thường **dùng cả hai**: MetricKit cho system-level insights, và Firebase/Datadog cho custom business metrics real-time.

---

## Phần 10: Câu hỏi phỏng vấn thường gặp

Interviewer có thể hỏi bạn:

**"App bạn bị user phàn nàn chậm nhưng bạn không reproduce được trên máy dev, bạn sẽ làm gì?"** — Đây là lúc bạn nhắc đến MetricKit: xem hang diagnostics để tìm call stack gây block main thread, xem launch metrics histogram để biết phân bố thời gian khởi động trên các thiết bị thực, so sánh metrics giữa các version trong Xcode Organizer.

**"Làm sao bạn biết app bị iOS kill vì dùng quá nhiều memory?"** — MetricKit's `applicationExitMetrics` ghi nhận `memoryResourceLimitExitCount` cho foreground và `memoryPressureExitCount` cho background. Crash reporter thông thường không bắt được những trường hợp này vì đây là system-initiated termination, không phải app crash.

**"Bạn đo launch time của app bằng cách nào trong production?"** — MetricKit cung cấp `histogrammedTimeToFirstDraw` cho cold launch và `histogrammedResumeTime` cho warm launch, đo trên thiết bị thực của tất cả user. Kết hợp với custom signpost để đo thêm thời gian từ first draw đến khi content thực sự sẵn sàng (ví dụ feed đầu tiên hiển thị).

---

# Xcode Organizer (xem crash logs, energy reports, disk writes từ user thực)

# Xcode Organizer — Phân tích Performance từ User thực

## Xcode Organizer là gì?

Xcode Organizer là công cụ **tích hợp sẵn trong Xcode** cho phép bạn xem dữ liệu performance và crash được Apple thu thập từ thiết bị của **tất cả người dùng** đã đồng ý chia sẻ analytics. Bạn không cần tích hợp SDK nào, không cần server riêng — Apple tự động thu thập và tổng hợp dữ liệu cho bạn.

Điều kiện duy nhất: app phải được phân phối qua **App Store hoặc TestFlight**, và người dùng phải bật "Share with App Developers" trong Settings → Privacy → Analytics & Improvements.

```
Mở Organizer:
  Xcode → Window → Organizer (⌘ + Shift + Option + O)

Hoặc từ menu:
  Window → Organizer
```

---

## Phần 1: Tổng quan giao diện

Khi mở Organizer, bạn thấy sidebar bên trái với các mục chính:

```
┌──────────────────────────────────────────────────────────────────┐
│ Xcode Organizer                                                  │
│                                                                  │
│ ┌────────────────┐  ┌─────────────────────────────────────────┐  │
│ │   SIDEBAR      │  │          MAIN CONTENT                   │  │
│ │                │  │                                         │  │
│ │ ┌────────────┐ │  │  Hiển thị nội dung tùy theo mục        │  │
│ │ │ Archives   │ │  │  được chọn ở sidebar                   │  │
│ │ ├────────────┤ │  │                                         │  │
│ │ │ Crashes    │ │  │                                         │  │
│ │ ├────────────┤ │  │                                         │  │
│ │ │ Energy     │ │  │                                         │  │
│ │ ├────────────┤ │  │                                         │  │
│ │ │ Launch Time│ │  │                                         │  │
│ │ ├────────────┤ │  │                                         │  │
│ │ │ Hang Rate  │ │  │                                         │  │
│ │ ├────────────┤ │  │                                         │  │
│ │ │ Memory     │ │  │                                         │  │
│ │ ├────────────┤ │  │                                         │  │
│ │ │ Disk Writes│ │  │                                         │  │
│ │ ├────────────┤ │  │                                         │  │
│ │ │ Scrolling  │ │  │                                         │  │
│ │ ├────────────┤ │  │                                         │  │
│ │ │ Terminations│ │  │                                         │  │
│ │ └────────────┘ │  │                                         │  │
│ │                │  │                                         │  │
│ └────────────────┘  └─────────────────────────────────────────┘  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

Mỗi mục cho bạn thấy một khía cạnh khác nhau của app trên thiết bị người dùng thực. Tôi sẽ đi chi tiết từng mục.

---

## Phần 2: Archives — Quản lý bản build

Archives không phải là phần performance, nhưng nó liên quan trực tiếp đến quá trình debug crash log nên cần hiểu trước.

```
┌────────────────────────────────────────────────────────┐
│ Archives                                               │
│                                                        │
│ ┌────────────────────────────────────────────────────┐ │
│ │ MyApp 2.1.0 (build 45)    Mar 8, 2026  ✅ Uploaded│ │
│ │   Archive Path: ~/Library/Developer/Xcode/Archives │ │
│ │   dSYMs: Included                                  │ │
│ │   [Distribute App] [Validate App] [Show in Finder] │ │
│ ├────────────────────────────────────────────────────┤ │
│ │ MyApp 2.0.0 (build 38)    Feb 1, 2026  ✅ Uploaded│ │
│ ├────────────────────────────────────────────────────┤ │
│ │ MyApp 1.9.0 (build 32)    Jan 5, 2026  ✅ Uploaded│ │
│ └────────────────────────────────────────────────────┘ │
│                                                        │
└────────────────────────────────────────────────────────┘
```

**Tại sao Archives quan trọng cho debug?** Mỗi archive chứa **dSYM file** (debug symbol file). Đây là file ánh xạ giữa địa chỉ bộ nhớ và tên hàm, tên file, số dòng trong source code. Khi app crash trên thiết bị người dùng, crash log chỉ chứa địa chỉ bộ nhớ kiểu `0x104a3c1f8`. Để chuyển địa chỉ đó thành `ProfileViewController.swift:34 — loadUser()`, bạn cần dSYM. Quá trình chuyển đổi này gọi là **symbolication**.

```
Crash log CHƯA symbolicate:
  Thread 0:
    0  MyApp    0x104a3c1f8
    1  MyApp    0x104a3b920
    2  UIKit    0x1a8f2c344
    
    → Không biết code nào crash

Crash log ĐÃ symbolicate:
  Thread 0:
    0  MyApp    ProfileViewController.loadUser() + 120  (ProfileVC.swift:34)
    1  MyApp    ProfileViewController.viewDidLoad() + 48 (ProfileVC.swift:18)
    2  UIKit    UIViewController.loadViewIfNeeded()
    
    → Biết chính xác dòng code gây crash
```

Nếu bạn upload app lên App Store Connect có kèm dSYM (Xcode tự làm mặc định), Apple sẽ tự symbolicate crash log cho bạn. Nếu không, bạn phải tự symbolicate bằng command line:

```bash
# Symbolicate thủ công khi cần
xcrun atos -arch arm64 -o MyApp.app.dSYM/Contents/Resources/DWARF/MyApp \
    -l 0x104a00000 \
    0x104a3c1f8

# Output:
# ProfileViewController.loadUser() (in MyApp) (ProfileVC.swift:34)
```

---

## Phần 3: Crashes — Phân tích Crash từ User thực

Đây là mục bạn sẽ dùng nhiều nhất. Nó hiển thị tất cả crash được báo cáo từ thiết bị người dùng.

```
┌──────────────────────────────────────────────────────────────────┐
│ Crashes                                                          │
│                                                                  │
│ ┌──────────────────────────────────┐  Filters:                   │
│ │ App Version: [All ▼]            │  • App Version               │
│ │ Period:      [Last 2 weeks ▼]   │  • Time Period               │
│ │ Device:      [All ▼]            │  • Device Type               │
│ │ OS Version:  [All ▼]            │  • OS Version                │
│ └──────────────────────────────────┘                             │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ CRASH GROUP #1                                    120 reports│ │
│ │                                                              │ │
│ │ EXC_BAD_ACCESS (SIGSEGV)                                    │ │
│ │ MyApp: ProfileViewController.loadUser() + 120                │ │
│ │ ProfileVC.swift:34                                           │ │
│ │                                                              │ │
│ │ Affected versions: 2.0.0, 2.1.0                             │ │
│ │ Devices: iPhone 12 (35%), iPhone 13 (28%), iPhone SE (22%)  │ │
│ │ OS: iOS 17.4 (60%), iOS 16.7 (25%), iOS 17.3 (15%)        │ │
│ ├──────────────────────────────────────────────────────────────┤ │
│ │ CRASH GROUP #2                                     45 reports│ │
│ │                                                              │ │
│ │ EXC_BREAKPOINT (SIGTRAP) — Fatal error: unexpectedly nil    │ │
│ │ MyApp: OrderService.processPayment(_:) + 88                 │ │
│ │ OrderService.swift:156                                       │ │
│ │                                                              │ │
│ │ Affected versions: 2.1.0 only                               │ │
│ │ Devices: All                                                 │ │
│ │ OS: iOS 17.x (100%)                                         │ │
│ ├──────────────────────────────────────────────────────────────┤ │
│ │ CRASH GROUP #3                                     12 reports│ │
│ │ ...                                                          │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Apple tự động nhóm các crash giống nhau

Một điểm rất hay: Apple **tự động nhóm** (group) các crash log có cùng call stack thành một crash group. Nếu 120 user cùng crash tại `ProfileVC.swift:34`, bạn chỉ thấy 1 group với 120 reports — thay vì phải đọc 120 crash log riêng lẻ. Số report cho biết mức độ nghiêm trọng: crash group có 120 reports nghiêm trọng hơn crash group có 12 reports.

### Click vào một Crash Group để xem chi tiết

```
┌──────────────────────────────────────────────────────────────────┐
│ Crash Group #1 — Detail                                          │
│                                                                  │
│ Exception Type:  EXC_BAD_ACCESS (SIGSEGV)                        │
│ Exception Code:  KERN_INVALID_ADDRESS at 0x0000000000000010       │
│ Termination:     Signal 11 (Segmentation fault)                  │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ CRASHED THREAD — Thread 0 (Main Thread)                      │ │
│ │                                                              │ │
│ │ 0  MyApp     ProfileViewController.loadUser() + 120         │ │
│ │              ProfileVC.swift:34                              │ │
│ │                                                              │ │
│ │ 1  MyApp     ProfileViewController.viewDidLoad() + 48       │ │
│ │              ProfileVC.swift:18                              │ │
│ │                                                              │ │
│ │ 2  UIKitCore UIViewController.loadViewIfNeeded() + 172      │ │
│ │                                                              │ │
│ │ 3  UIKitCore UINavigationController                         │ │
│ │              ._pushViewController(_:transition:) + 640      │ │
│ │                                                              │ │
│ │ 4  MyApp     HomeViewController.didTapProfile() + 96        │ │
│ │              HomeVC.swift:67                                 │ │
│ │                                                              │ │
│ │ 5  UIKitCore -[UIApplication sendAction:to:from:] + 100     │ │
│ │ ...                                                         │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ Thread 1 (Background)                                        │ │
│ │ 0  libsystem_kernel.dylib  __workq_kernreturn + 8           │ │
│ │ ...                                                         │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
│ [Open in Project]  ← Click để nhảy thẳng đến dòng code trong   │
│                      Xcode project của bạn                       │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Cách đọc crash log — Từng phần

**Exception Type** cho biết loại lỗi ở mức hệ thống:

```
EXC_BAD_ACCESS (SIGSEGV)
  → Truy cập vùng nhớ không hợp lệ
  → Nguyên nhân phổ biến: force unwrap nil, dangling pointer,
    truy cập object đã bị dealloc

EXC_BAD_ACCESS (SIGBUS)
  → Truy cập vùng nhớ bị misaligned
  → Hiếm gặp hơn SIGSEGV

EXC_BREAKPOINT (SIGTRAP)
  → Code chủ động trigger trap
  → Nguyên nhân phổ biến: Swift fatal error, force unwrap nil,
    precondition failure, fatalError()

EXC_BAD_INSTRUCTION (SIGILL)
  → CPU gặp instruction không hợp lệ
  → Nguyên nhân: implicitly unwrapped optional là nil,
    enum exhaustive switch nhưng rawValue không hợp lệ

EXC_CRASH (SIGABRT)
  → App tự abort
  → Nguyên nhân: NSException không được catch (thường từ ObjC code),
    assert failure, calling abort()

EXC_CRASH (SIGKILL)
  → iOS kill app
  → Nguyên nhân: Watchdog timeout (main thread block quá lâu),
    memory limit exceeded, background task quá hạn
  → KHÔNG CÓ crash log từ app vì app không được thông báo trước
```

**Exception Code** cung cấp thông tin bổ sung:

```
KERN_INVALID_ADDRESS at 0x0000000000000010
  → Địa chỉ gần 0x0 → gần như chắc chắn là nil dereference
  → 0x10 = offset 16 bytes từ null → truy cập property thứ 2
    của một object nil

KERN_INVALID_ADDRESS at 0x7fffffffe000
  → Địa chỉ rất lớn → có thể stack overflow

KERN_PROTECTION_FAILURE
  → Truy cập vùng nhớ bị bảo vệ (read-only, v.v.)
```

**Call stack** đọc từ trên xuống dưới: frame 0 là nơi crash xảy ra, các frame bên dưới là chuỗi hàm đã gọi. Trong ví dụ trên, chuỗi sự kiện là: user tap profile button → `HomeVC.didTapProfile()` → push ProfileVC → `viewDidLoad()` → `loadUser()` → crash tại dòng 34.

### Nút "Open in Project"

Đây là tính năng rất mạnh. Click vào nút này, Xcode sẽ mở đúng file, đúng dòng code gây crash trong project của bạn. Điều kiện: bạn phải đang mở project tương ứng với version app bị crash.

---

## Phần 4: Energy Reports — Phân tích tiêu thụ pin

```
┌──────────────────────────────────────────────────────────────────┐
│ Energy                                                           │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │                                                              │ │
│ │  Energy Impact Over Time                                     │ │
│ │                                                              │ │
│ │  Overhead                                                    │ │
│ │  ████████████░░░░░░░░░░░░░░░░░░  v2.0.0                    │ │
│ │  ██████░░░░░░░░░░░░░░░░░░░░░░░░  v2.1.0  ← Cải thiện!     │ │
│ │                                                              │ │
│ │  ┌──────────────────────────┐                                │ │
│ │  │ Breakdown by Category:  │                                │ │
│ │  │                         │                                │ │
│ │  │ CPU        ████████ 40% │                                │ │
│ │  │ Location   ██████   30% │                                │ │
│ │  │ Networking ████     20% │                                │ │
│ │  │ Display    ██       10% │                                │ │
│ │  └──────────────────────────┘                                │ │
│ │                                                              │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
│ Filters: [Foreground ▼] [Background ▼] [All Devices ▼]          │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ Energy Exception Reports                                     │ │
│ │                                                              │ │
│ │ ⚠️ CPU Wake Overhead              45 reports                │ │
│ │    App waking CPU excessively in background                  │ │
│ │    Stack: BackgroundSyncManager.schedulePush() + 88          │ │
│ │                                                              │ │
│ │ ⚠️ Location Session Active        23 reports                │ │
│ │    Continuous GPS usage detected                             │ │
│ │    Duration: avg 12 minutes per session                      │ │
│ │                                                              │ │
│ │ ⚠️ High Background Audio          8 reports                 │ │
│ │    Audio session active but no audible output                │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Các chỉ số Energy quan trọng

**Foreground Energy** đo năng lượng app tiêu thụ khi đang hiển thị. Thành phần chính gồm CPU (tính toán nặng, decode ảnh, animation phức tạp), GPU (render UI phức tạp, blur effect, shadow), và Networking (request liên tục, download lớn).

**Background Energy** đo năng lượng khi app ở nền. Đây là phần Apple rất quan tâm vì user không biết app đang ngốn pin trong background. Các nguyên nhân phổ biến là location tracking liên tục dù chỉ cần significant change, background fetch quá thường xuyên, audio session không được release đúng cách, và silent push notification trigger xử lý nặng.

**Energy Exception Reports** là những cảnh báo khi app vượt ngưỡng tiêu thụ năng lượng mà Apple cho là bất thường. Mỗi report kèm call stack giúp bạn xác định code nào gây ra vấn đề.

### Ví dụ thực tế: Debug Location Energy Issue

```
Bạn thấy trong Energy report:
  ⚠️ Location Session Active — 23 reports
  avg duration: 12 minutes per session

Phân tích:
  App bạn chỉ cần lấy vị trí user 1 lần để hiện quán cà phê gần đây.
  Nhưng report cho thấy location session active trung bình 12 phút.
  
Nguyên nhân có thể:
  - Quên gọi stopUpdatingLocation() sau khi đã có vị trí
  - Dùng kCLLocationAccuracyBest thay vì kCLLocationAccuracyHundredMeters
  - allowsBackgroundLocationUpdates = true nhưng không cần

Code có vấn đề:
```

```swift
// ❌ Tốn pin: accuracy cao, không stop, cho phép background
class CafeFinderVC: UIViewController, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()
    
    func startFinding() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.startUpdatingLocation()
        // Quên stop → location chạy mãi
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        fetchNearbyCafes(at: location)
        // Vẫn không stop sau khi đã có location!
    }
}
```

```swift
// ✅ Fix: accuracy vừa đủ, stop ngay khi có, không background
class CafeFinderVC: UIViewController, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()
    
    func startFinding() {
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Không cần background location cho tìm quán cafe
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Stop ngay khi đã có vị trí đủ tốt
        locationManager.stopUpdatingLocation()
        
        fetchNearbyCafes(at: location)
    }
}
```

---

## Phần 5: Launch Time — Thời gian khởi động

```
┌──────────────────────────────────────────────────────────────────┐
│ Launch Time                                                      │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │                                                              │ │
│ │  Median Launch Time (ms)                                     │ │
│ │                                                              │ │
│ │  1200 ─┤                                                     │ │
│ │        │  ████                                               │ │
│ │  1000 ─┤  ████                                               │ │
│ │        │  ████  ████                                         │ │
│ │   800 ─┤  ████  ████                                         │ │
│ │        │  ████  ████  ████                                   │ │
│ │   600 ─┤  ████  ████  ████  ████                             │ │
│ │        │  ████  ████  ████  ████  ████                       │ │
│ │   400 ─┤──████──████──████──████──████──── Target ────       │ │
│ │        │  ████  ████  ████  ████  ████                       │ │
│ │   200 ─┤  ████  ████  ████  ████  ████                       │ │
│ │        │  v1.7  v1.8  v1.9  v2.0  v2.1                      │ │
│ │     0 ─┴────────────────────────────────                     │ │
│ │                                                              │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ Breakdown by Device                                          │ │
│ │                                                              │ │
│ │ Device          Median    Typical (P25-P75)    P95           │ │
│ │ ─────────────────────────────────────────────────────        │ │
│ │ iPhone 15 Pro    380ms    320ms - 450ms        620ms        │ │
│ │ iPhone 13        520ms    440ms - 680ms        890ms        │ │
│ │ iPhone SE 3      780ms    650ms - 920ms       1340ms        │ │
│ │ iPhone 11        850ms    710ms - 1050ms      1520ms        │ │
│ │                                                              │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Cách đọc Launch Time report

**Biểu đồ theo version** cho bạn thấy xu hướng: launch time đang cải thiện hay xấu đi qua các version. Trong ví dụ trên, app khởi động chậm dần từ v1.7 đến v1.9 (có thể thêm nhiều framework, init code nặng hơn), rồi cải thiện ở v2.0 và v2.1 (sau khi tối ưu).

**Breakdown by Device** cho thấy sự khác biệt giữa các thiết bị. iPhone 15 Pro khởi động 380ms — tốt. Nhưng iPhone 11 mất 850ms — gần gấp đôi. Nếu bạn chỉ test trên iPhone mới nhất, bạn sẽ không bao giờ thấy vấn đề này. Đây chính là giá trị của Organizer.

**Percentile P95** đặc biệt quan trọng. Nó cho biết 95% user có launch time thấp hơn giá trị này. iPhone 11 có P95 là 1520ms — nghĩa là 5% user trên iPhone 11 phải chờ hơn 1.5 giây. Apple khuyến nghị launch time dưới 400ms.

Report cũng tách riêng hai loại launch. **Cold launch** là khi app không còn trong bộ nhớ, phải load mọi thứ từ đầu. **Warm launch (resume)** là khi app đang bị suspended trong background, user quay lại. Warm launch nên dưới 100ms.

---

## Phần 6: Hang Rate — App bị đơ

```
┌──────────────────────────────────────────────────────────────────┐
│ Hang Rate                                                        │
│                                                                  │
│ Definition: Hangs per hour of app usage                          │
│ A "hang" = main thread unresponsive > 250ms                      │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │                                                              │ │
│ │  Hang Rate (hangs per hour of foreground usage)              │ │
│ │                                                              │ │
│ │  5.0 ─┤  ████                                                │ │
│ │       │  ████                                                │ │
│ │  4.0 ─┤  ████  ████                                          │ │
│ │       │  ████  ████                                          │ │
│ │  3.0 ─┤  ████  ████                                          │ │
│ │       │  ████  ████  ████                                    │ │
│ │  2.0 ─┤  ████  ████  ████                                    │ │
│ │       │  ████  ████  ████  ████                              │ │
│ │  1.0 ─┤──████──████──████──████──████──── Target ─────       │ │
│ │       │  ████  ████  ████  ████  ████                        │ │
│ │    0 ─┤  v1.7  v1.8  v1.9  v2.0  v2.1                       │ │
│ │                                                              │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ Hang Duration Distribution                                   │ │
│ │                                                              │ │
│ │ 250ms - 500ms     ████████████████████████  65%  (nhẹ)      │ │
│ │ 500ms - 1s        ████████████              22%  (vừa)      │ │
│ │ 1s - 2s           ██████                     9%  (nặng)     │ │
│ │ 2s+               ██                         4%  (critical) │ │
│ │                                                              │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Cách đọc Hang Rate

**Hang rate = số lần hang / số giờ sử dụng foreground.** Apple khuyến nghị dưới 1 hang/giờ. Trong ví dụ trên, v1.7 có hang rate 4.8 — tức gần 5 lần bị đơ mỗi giờ sử dụng, trải nghiệm rất kém.

**Hang Duration Distribution** cho biết mức độ nghiêm trọng. Hang 250-500ms user có thể chấp nhận (cảm giác hơi chậm). Hang trên 2 giây user sẽ nghĩ app bị crash. 4% hang trên 2s tương ứng với một user trải nghiệm app đơ cứng khoảng 5-6 lần mỗi ngày nếu dùng 2-3 tiếng.

Organizer không hiển thị call stack gây hang (đó là việc của MetricKit Diagnostic Payload hoặc Instruments). Nhưng nó cho bạn bức tranh toàn cảnh: hang rate đang tăng hay giảm, version nào gây hang nhiều nhất, thiết bị nào bị ảnh hưởng nặng nhất.

---

## Phần 7: Memory — Sử dụng bộ nhớ

```
┌──────────────────────────────────────────────────────────────────┐
│ Memory                                                           │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │                                                              │ │
│ │  Peak Memory Usage (MB) — Median                             │ │
│ │                                                              │ │
│ │  400 ─┤                         ████                         │ │
│ │       │              ████  ████  ████                         │ │
│ │  300 ─┤         ████  ████  ████  ████                       │ │
│ │       │    ████  ████  ████  ████  ████                      │ │
│ │  200 ─┤    ████  ████  ████  ████  ████                      │ │
│ │       │    ████  ████  ████  ████  ████                      │ │
│ │  100 ─┤    ████  ████  ████  ████  ████                      │ │
│ │       │    v1.7  v1.8  v1.9  v2.0  v2.1                     │ │
│ │    0 ─┴──────────────────────────────                        │ │
│ │                                                              │ │
│ │  ⚠️ Peak memory tăng 30% từ v2.0 → v2.1                     │ │
│ │     Cần điều tra: image cache quá lớn? memory leak?          │ │
│ │                                                              │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ Suspended Memory (khi app ở background)                      │ │
│ │                                                              │ │
│ │ Device          Median    P95        Memory Limit (approx)   │ │
│ │ ──────────────────────────────────────────────────────        │ │
│ │ iPhone 15 Pro    120MB    180MB      ~2800MB                 │ │
│ │ iPhone 13         95MB    150MB      ~2600MB                 │ │
│ │ iPhone SE 3       85MB    140MB      ~1800MB                 │ │
│ │ iPhone 8          70MB    130MB      ~1200MB                 │ │
│ │                                                              │ │
│ │ Suspended memory cao → iOS kill app sớm hơn                  │ │
│ │ → User mở lại phải cold launch → trải nghiệm kém            │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Tại sao Suspended Memory quan trọng

Khi user nhấn Home button, app bị suspended nhưng vẫn ở trong RAM. Nếu app bạn chiếm 150MB khi suspended, iOS sẽ ưu tiên kill app bạn khi cần giải phóng RAM cho app khác. Kết quả: user quay lại app phải chờ cold launch thay vì resume tức thì.

Cách giảm suspended memory: implement `applicationDidEnterBackground(_:)` để giải phóng cache, ảnh lớn, data tạm thời. Khi app resume, load lại chúng.

```swift
func applicationDidEnterBackground(_ application: UIApplication) {
    // Giải phóng image cache khi vào background
    ImageCache.shared.clearMemoryCache()
    
    // Giải phóng large data structures
    feedDataSource.clearCachedResponses()
}
```

---

## Phần 8: Disk Writes — Ghi đĩa

```
┌──────────────────────────────────────────────────────────────────┐
│ Disk Writes                                                      │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │                                                              │ │
│ │  Disk Writes per Day (MB) — Median                           │ │
│ │                                                              │ │
│ │  800 ─┤              ████                                    │ │
│ │       │              ████                                    │ │
│ │  600 ─┤         ████  ████                                   │ │
│ │       │         ████  ████                                   │ │
│ │  400 ─┤    ████  ████  ████  ████  ████                      │ │
│ │       │    ████  ████  ████  ████  ████                      │ │
│ │  200 ─┤    ████  ████  ████  ████  ████                      │ │
│ │       │    v1.7  v1.8  v1.9  v2.0  v2.1                     │ │
│ │    0 ─┴──────────────────────────────                        │ │
│ │                                                              │ │
│ │  ⚠️ v1.9 spike lên 700MB/ngày — ghi log quá nhiều?          │ │
│ │                                                              │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ Disk Write Exception Reports                                 │ │
│ │                                                              │ │
│ │ ⚠️ Excessive Disk Writes                     34 reports      │ │
│ │    Total writes: 1.2 GB in 24h                               │ │
│ │    Stack:                                                    │ │
│ │      0  MyApp  LogManager.writeLog(_:) + 44                  │ │
│ │         LogManager.swift:89                                  │ │
│ │      1  MyApp  NetworkService.logResponse(_:) + 112          │ │
│ │         NetworkService.swift:234                              │ │
│ │      2  MyApp  NetworkService.handleResponse(_:) + 88        │ │
│ │         NetworkService.swift:198                              │ │
│ │                                                              │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Tại sao Apple quan tâm đến Disk Writes

SSD trên iPhone có tuổi thọ giới hạn bởi số lần ghi. Nếu app ghi quá nhiều, nó góp phần làm giảm tuổi thọ thiết bị. Apple đặt ngưỡng khoảng **1GB/ngày** — vượt quá sẽ tạo exception report. Ngoài ra, ghi disk là thao tác I/O chậm, ghi nhiều trên main thread sẽ gây hang.

Các nguyên nhân ghi disk nhiều bất thường thường gặp: logging quá verbose trong production (ghi mọi network response vào file log), Core Data hoặc SQLite transaction quá thường xuyên (save sau mỗi thay đổi nhỏ thay vì batch), cache ảnh ghi disk không giới hạn, analytics SDK ghi event quá thường xuyên.

```swift
// ❌ Ghi disk sau MỖI network response
func handleResponse(_ response: HTTPURLResponse, data: Data) {
    let logEntry = "[\(Date())] \(response.url!) - \(response.statusCode)\n"
    
    // Ghi file MỖI LẦN → hàng nghìn lần/ngày
    try? logEntry.append(to: logFileURL)
    
    processData(data)
}

// ✅ Fix: Buffer log trong memory, flush định kỳ
class LogManager {
    private var buffer: [String] = []
    private let flushThreshold = 100  // Gom 100 entry rồi mới ghi
    
    func log(_ entry: String) {
        buffer.append(entry)
        
        if buffer.count >= flushThreshold {
            flush()
        }
    }
    
    private func flush() {
        let batch = buffer.joined(separator: "\n")
        buffer.removeAll()
        
        // Ghi 1 lần thay vì 100 lần
        DispatchQueue.global().async {
            try? batch.append(to: self.logFileURL)
        }
    }
}
```

---

## Phần 9: Scrolling — Scroll Hitch Rate

```
┌──────────────────────────────────────────────────────────────────┐
│ Scrolling                                                        │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │                                                              │ │
│ │  Scroll Hitch Rate (ms delay per second of scrolling)        │ │
│ │                                                              │ │
│ │  15 ─┤  ████                                                 │ │
│ │      │  ████                                                 │ │
│ │  10 ─┤  ████  ████                                           │ │
│ │      │  ████  ████                                           │ │
│ │   5 ─┤──████──████──████──████──████──── Target ──────       │ │
│ │      │  ████  ████  ████  ████  ████                         │ │
│ │   0 ─┤  v1.7  v1.8  v1.9  v2.0  v2.1                        │ │
│ │                                                              │ │
│ │  Hitch Rate Interpretation:                                  │ │
│ │    < 5 ms/s    Tốt — scroll mượt                             │ │
│ │    5-10 ms/s   Cần cải thiện — user bắt đầu cảm nhận        │ │
│ │    > 10 ms/s   Kém — giật rõ ràng                            │ │
│ │                                                              │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ Breakdown by Device                                          │ │
│ │                                                              │ │
│ │ iPhone 15 Pro     2.1 ms/s   ✅ Tốt                         │ │
│ │ iPhone 13         4.8 ms/s   ✅ Tốt                         │ │
│ │ iPhone SE 3       8.2 ms/s   ⚠️ Cần cải thiện              │ │
│ │ iPhone 11        12.5 ms/s   ❌ Kém                         │ │
│ │                                                              │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Cách đọc Scroll Hitch Rate

**Hitch** là khi một frame không được render kịp deadline. Trên màn 60Hz, mỗi frame có 16.67ms. Nếu frame mất 20ms để render, có 3.33ms hitch — user thấy scroll bị "nhảy" một chút.

**Hitch rate** = tổng thời gian hitch / tổng thời gian scroll. Ví dụ 8.2 ms/s nghĩa là trong mỗi giây scroll, có 8.2ms bị "giật". Con số này nghe nhỏ nhưng mắt người rất nhạy với chuyển động không mượt.

Từ bảng breakdown, bạn thấy iPhone 15 Pro tốt (2.1) nhưng iPhone 11 kém (12.5). Điều này gợi ý rằng code của bạn đang quá nặng cho chip cũ, cần tối ưu: có thể là decode ảnh trên main thread, cell layout phức tạp, hoặc shadow/corner radius không được rasterize.

---

## Phần 10: Terminations — Lý do app bị tắt

```
┌──────────────────────────────────────────────────────────────────┐
│ Terminations                                                     │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ Foreground Terminations (app đang hiển thị)                  │ │
│ │                                                              │ │
│ │ Type                        Count    Trend                   │ │
│ │ ───────────────────────────────────────────                  │ │
│ │ Normal (user tự tắt)         1,230    —                      │ │
│ │ Abnormal (crash)                45    ↑ +20% vs last version │ │
│ │ Memory Limit Exceeded           12    ↑ NEW in this version  │ │
│ │ Watchdog (main thread block)     3    ↓ -50%                 │ │
│ │ Bad Access                       8    → same                 │ │
│ │                                                              │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ Background Terminations (app ở nền)                          │ │
│ │                                                              │ │
│ │ Type                        Count    Trend                   │ │
│ │ ───────────────────────────────────────────                  │ │
│ │ System Pressure (cần RAM)    3,450    → normal               │ │
│ │ Background Task Timeout         23    ↑ +100%                │ │
│ │ Memory Pressure Exit           156    ↑ +40%                 │ │
│ │ Suspended w/ Locked File         2    → rare                 │ │
│ │                                                              │ │
│ └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
│ ⚠️ "Memory Limit Exceeded" xuất hiện lần đầu ở version này      │
│    → Có feature mới dùng quá nhiều RAM?                          │
│                                                                  │
│ ⚠️ "Background Task Timeout" tăng gấp đôi                       │
│    → Background task mới chạy quá lâu?                           │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Tại sao Terminations đặc biệt giá trị

Crash reporter truyền thống (Firebase Crashlytics, Sentry) chỉ bắt được crash do exception hoặc signal. Nhưng rất nhiều trường hợp app bị tắt mà không tạo crash log:

**Watchdog Kill:** Main thread bị block quá lâu (thường > 10-20 giây), iOS tự kill app. Không có crash log. User chỉ thấy app biến mất. Nếu không có Organizer, bạn không bao giờ biết điều này đang xảy ra.

**Memory Limit Exceeded:** App dùng quá nhiều RAM, iOS kill ngay. Cũng không có crash log vì app không được thông báo trước.

**Background Task Timeout:** `beginBackgroundTask` mà không `endBackgroundTask` trong thời gian cho phép (~30 giây), iOS kill app.

Terminations report cho bạn thấy **tất cả** lý do app bị tắt, bao gồm những thứ mà crash reporter truyền thống bỏ sót. Đây là công cụ duy nhất cho bạn bức tranh toàn diện về app stability.

---

## Phần 11: Workflow thực tế — Dùng Organizer sau mỗi lần release

```
┌─────────────────────────────────────────────────────────────┐
│              POST-RELEASE MONITORING WORKFLOW                │
│                                                             │
│  Ngày 1-3 sau release:                                      │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 1. Crashes tab                                        │  │
│  │    → Có crash group mới không?                        │  │
│  │    → Crash nào có nhiều report nhất?                  │  │
│  │    → So sánh crash rate với version trước              │  │
│  │    → Nếu crash rate tăng đột biến → xem xét hotfix   │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  Tuần 1:                                                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 2. Launch Time tab                                    │  │
│  │    → Launch time version mới so với cũ thế nào?       │  │
│  │    → Thiết bị cũ bị ảnh hưởng bao nhiêu?             │  │
│  │                                                       │  │
│  │ 3. Hang Rate tab                                      │  │
│  │    → Hang rate tăng hay giảm?                         │  │
│  │    → Có correlation với feature mới không?            │  │
│  │                                                       │  │
│  │ 4. Terminations tab                                   │  │
│  │    → Có loại termination mới xuất hiện không?         │  │
│  │    → Memory kill có tăng không?                       │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  Tuần 2+:                                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 5. Memory, Disk Writes, Energy, Scrolling             │  │
│  │    → Data đã đủ lớn để có ý nghĩa thống kê           │  │
│  │    → So sánh tất cả metrics với version trước         │  │
│  │    → Lập danh sách issues cần fix cho version tiếp    │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Phần 12: Câu hỏi phỏng vấn thường gặp

**"Sau khi release version mới, bạn monitor app bằng cách nào?"** — Câu trả lời tốt nên bao gồm: kiểm tra Xcode Organizer ngay tuần đầu để so sánh crash rate, launch time, hang rate với version trước; dùng Crashlytics/Sentry cho real-time crash alerting; xem Terminations để phát hiện memory kill hay watchdog kill mà crash reporter không bắt được; theo dõi scroll hitch rate và energy report theo device breakdown để đảm bảo thiết bị cũ không bị ảnh hưởng.

**"Làm sao bạn biết app bị user phàn nàn lag trên iPhone cũ nhưng bạn không reproduce được?"** — Mở Organizer, filter theo device type, xem hang rate và scroll hitch rate riêng cho dòng iPhone đó. Nếu hitch rate trên iPhone 11 là 12ms/s nhưng trên iPhone 15 chỉ 2ms/s, bạn biết vấn đề là code quá nặng cho chip cũ. Kết hợp MetricKit diagnostic payload để lấy call stack cụ thể gây hang trên thiết bị cũ.

**"App crash nhưng Crashlytics không ghi nhận, bạn giải thích thế nào?"** — Rất có thể đó không phải crash thông thường mà là system-initiated termination: watchdog kill (main thread block quá lâu), memory limit exceeded, hoặc background task timeout. Những trường hợp này không tạo crash log mà SDK bên thứ 3 bắt được. Xcode Organizer Terminations tab sẽ hiển thị chúng.

---
