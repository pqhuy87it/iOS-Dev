# Automated Testing & Debugging Tools cho Senior iOS Developer

Đây là một competency cốt lõi mà một Senior iOS Developer cần nắm vững. Mình sẽ phân tích chi tiết theo từng khía cạnh.

---

## 1. Automated Testing

### Unit Testing (XCTest & XCTestCase)

Đây là nền tảng. Ở level senior, bạn không chỉ viết test mà còn phải thiết kế code sao cho **testable**. Điều này đòi hỏi hiểu sâu về Dependency Injection, Protocol-Oriented Programming, và cách tách biệt các layer (MVVM, Clean Architecture...) để mock được dependencies.

Một số điểm cần nắm chắc:

**Test Doubles** — bạn cần phân biệt và sử dụng thành thạo Mock, Stub, Spy, Fake. Ví dụ khi test một ViewModel gọi API, bạn sẽ inject một `MockNetworkService` conform protocol thay vì gọi network thật.

**Code Coverage** — senior developer hiểu rằng 100% coverage không phải mục tiêu. Quan trọng là test đúng business logic, edge cases, và các điểm dễ regression. Bạn cần biết cách đọc coverage report trong Xcode và quyết định đâu là vùng cần ưu tiên.

**Asynchronous Testing** — iOS đầy rẫy async code (Combine, async/await, completion handlers). XCTest cung cấp `XCTestExpectation` và từ Swift Concurrency có thể test trực tiếp các hàm `async`. Senior cần master cả hai cách tiếp cận.

### UI Testing (XCUITest)

UI test mô phỏng interaction thực của user. Ở level senior, bạn cần biết cách thiết kế **Page Object Pattern** để UI test không trở thành một đống code brittle, khó maintain. Bạn cũng cần hiểu trade-off: UI test chạy chậm, nên chỉ cover các critical user flows (login, checkout, onboarding...) thay vì mọi thứ.

Accessibility identifiers là chìa khóa — senior dev sẽ đảm bảo team đặt identifier hợp lý từ đầu, phục vụ cả testing lẫn accessibility.

### Snapshot Testing

Các library như **iOSSnapshotTestCase** (từ Uber) hay **swift-snapshot-testing** (Point-Free) cho phép so sánh UI pixel-by-pixel. Senior dev dùng cái này để detect unintended visual regression mà UI test thông thường không bắt được — ví dụ font bị lệch, spacing sai, dark mode bị hỏng.

### Testing Frameworks bổ trợ

**Quick/Nimble** — cung cấp BDD-style syntax (`describe`, `it`, `expect(...).to(equal(...))`) giúp test đọc dễ hơn. Senior cần biết khi nào dùng framework này thay vì XCTest thuần, và trade-off về build time.

### CI/CD Integration

Đây là điểm phân biệt senior với junior rõ nhất. Senior dev phải biết cách:
- Cấu hình **xcodebuild test** hoặc **fastlane scan** trong CI pipeline (GitHub Actions, Bitrise, Jenkins...)
- Chạy test song song để giảm thời gian
- Tích hợp test report, code coverage vào PR review process
- Thiết lập policy: PR không merge được nếu test fail hoặc coverage giảm

---

## 2. Debugging Tools

### Xcode Debugger (LLDB)

Vượt xa việc đặt breakpoint cơ bản. Senior dev cần thành thạo:

- **`po`, `p`, `v`** — hiểu sự khác nhau (v nhanh nhất, po gọi `debugDescription`, p dùng compiler evaluate)
- **Conditional breakpoints** — chỉ dừng khi điều kiện thoả, ví dụ `index == 99` trong một vòng lặp 1000 phần tử
- **Symbolic breakpoints** — đặt breakpoint trên method name mà không cần mở file, ví dụ break mọi lần `viewDidLoad` được gọi trong app
- **Watchpoints** — theo dõi khi một biến thay đổi giá trị, rất hữu ích khi debug state bị mutate không rõ từ đâu
- **LLDB scripting** — viết custom command, tự động hoá debug workflow

### Instruments

Đây là bộ công cụ profiling mạnh nhất của Apple. Senior cần biết dùng ít nhất:

- **Time Profiler** — tìm bottleneck CPU, hiểu call tree, phát hiện hàm nào tốn thời gian
- **Allocations & Leaks** — phát hiện memory leak, retain cycle. Kết hợp với Memory Graph Debugger trong Xcode để visualize object graph
- **Network (URLSession Instrument)** — phân tích API call timing, payload size
- **Core Animation / Animation Hitches** — debug scroll jank, đảm bảo 60fps (hoặc 120fps trên ProMotion)
- **Energy Log** — tối ưu battery consumption

### Memory Graph Debugger

Tích hợp sẵn trong Xcode, cho phép capture toàn bộ object graph tại một thời điểm. Senior dev dùng cái này để tìm **retain cycles** — đặc biệt với closures và delegate patterns. Bạn có thể thấy rõ object A giữ strong reference đến B và ngược lại.

### Xcode Organizer & MetricKit

Sau khi app lên production, bạn cần theo dõi crash reports và performance metrics từ real users. **MetricKit** cho phép thu thập dữ liệu về hang rate, disk writes, battery usage... Senior dev kết hợp với third-party tools như **Firebase Crashlytics** hoặc **Sentry** để có full picture.

### Network Debugging

**Charles Proxy** hoặc **Proxyman** — senior dev dùng để inspect API traffic, mock response, simulate slow network, test error handling. Đây là công cụ không thể thiếu khi debug các vấn đề liên quan đến backend integration.

### Sanitizers

- **Address Sanitizer (ASan)** — phát hiện buffer overflow, use-after-free
- **Thread Sanitizer (TSan)** — phát hiện data race trong concurrent code
- **Undefined Behavior Sanitizer (UBSan)** — bắt undefined behavior

Senior dev bật các sanitizer này trong CI và trong debug scheme. Đặc biệt TSan cực kỳ quan trọng khi app dùng nhiều concurrency (GCD, Swift Concurrency).

---

## 3. Tư duy của Senior Dev về Testing & Debugging

Điều thực sự tách biệt senior khỏi mid-level không phải là biết tool nào, mà là **chiến lược**:

**Testing Pyramid** — senior hiểu rằng nên có nhiều unit test (nhanh, rẻ), ít integration test hơn, và ít UI test nhất (chậm, brittle). Phân bổ sai tỷ lệ này dẫn đến CI chậm và test suite khó maintain.

**Shift-left mindset** — phát hiện bug càng sớm càng rẻ. Senior dev push cho static analysis (SwiftLint, custom rules), code review kỹ, và test coverage ngay từ PR level thay vì chờ QA phát hiện.

**Debug systematically** — không đoán mò. Senior dev reproduce issue trước, thu hẹp phạm vi bằng binary search (comment code, isolate module), dùng đúng tool cho đúng loại bug, và document root cause để team học.

Tóm lại, ở level senior, bạn không chỉ **dùng** các tool này mà còn phải **xây dựng culture** xung quanh testing và debugging cho cả team — chọn strategy phù hợp, setup infrastructure, mentor junior, và liên tục cải thiện development workflow.
