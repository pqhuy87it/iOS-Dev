## What steps do you take to identify and resolve crashes?

### Suggested approach: Walk through your knowledge of debugging from the basics upwards. Do you use breakpoints? Do you use assert() or precondition()? Do you write to a log? Do you download crash logs from iTunes Connect?
All these things help provide data points we can use to find and fix problems in our code, because once you know where the problem is it's usually(!) fairly straightforward to fix.

----

## Câu hỏi này thực sự test cái gì?

Không phải "bạn biết bao nhiêu tool". Mà là: **bạn có một quy trình không, hay bạn chọc mò cho tới khi hết crash?**

Ứng viên yếu sẽ liệt kê tool rời rạc: "em dùng breakpoint, em dùng Crashlytics". Ứng viên mạnh mô tả một **phễu thu hẹp**: từ "app crash ở đâu đó" → "crash ở dòng này, vì lý do này" → "fix" → "đảm bảo không tái phát". Tool chỉ là thứ bạn gọi tên tại từng bước của phễu đó.

Chi tiết đáng chú ý: đề bài viết "iTunes Connect" — tên đó đã đổi thành **App Store Connect** từ 2018, và nơi thực tế bạn xem crash là **Xcode Organizer → Crashes**. Không cần bắt bẻ interviewer, nhưng dùng đúng tên hiện tại là tín hiệu nhỏ cho thấy bạn đang làm nghề chứ không học thuộc.

## Chia đôi bài toán trước khi trả lời

Đây là điều khiến câu trả lời của bạn khác hẳn số đông. Crash có **hai thế giới hoàn toàn khác nhau**, và tool cho mỗi thế giới không giống nhau:

| | Crash lúc dev/QA | Crash ngoài production |
|---|---|---|
| Vấn đề chính | Tìm nguyên nhân | **Tìm được crash trước đã** |
| Có debugger không | Có | Không |
| Reproduce được không | Thường được | Thường **không** |
| Vũ khí | Breakpoint, Sanitizer, LLDB | Crash log, symbolication, breadcrumb, MetricKit |

Mở đầu bằng cách phân đôi này ngay lập tức nâng chất câu trả lời. Còn nếu bạn muốn ngắn gọn hơn nữa, đây là câu mở:

> "Cách tôi tiếp cận phụ thuộc vào việc tôi có reproduce được hay không. Nếu có, đó là bài toán debug. Nếu không, đó là bài toán thu thập bằng chứng — và phần lớn công sức của tôi thực ra nằm ở việc *chuẩn bị từ trước* để khi crash xảy ra thì tôi có đủ dữ liệu."

## Quy trình 6 bước để trình bày

**1. Triage — quyết định có đáng fix ngay không**

Không phải crash nào cũng ngang nhau. Ở Xcode Organizer bạn sort theo số lượng và **crash-free user rate**; ở Crashlytics/Sentry có thêm số user bị ảnh hưởng. Ba câu hỏi: bao nhiêu % user dính, có tập trung ở một OS/device/app version cụ thể không, có phải regression từ bản vừa release không.

Việc "crash chỉ xảy ra trên iOS 26 beta" hoặc "chỉ trên iPad" tự nó đã là nửa manh mối.

**2. Đọc crash log cho đúng**

Đây là phần kỹ thuật nhất, và cũng là chỗ dễ ghi điểm nhất. Cấu trúc một crash report:

- **Exception Type / Signal** — nói cho bạn *loại* lỗi
- **Termination Reason** — với những vụ bị hệ thống giết
- **Crashed Thread + backtrace** — nói cho bạn *chỗ* lỗi
- **Binary Images** — dùng để match dSYM

Bảng signal cần thuộc:

| Signal | Ý nghĩa thường gặp trong Swift/iOS |
|---|---|
| `EXC_BAD_ACCESS` (SIGSEGV/SIGBUS) | Truy cập bộ nhớ đã giải phóng — `unowned` dangling, ObjC over-release, con trỏ hỏng |
| `EXC_BREAKPOINT` (SIGTRAP) | **Swift runtime trap**: force unwrap `nil`, array index out of range, integer overflow, `try!` fail |
| `SIGABRT` | Uncaught `NSException` (KVO chưa remove, unrecognized selector, Auto Layout không thoả), hoặc `fatalError` |
| `EXC_CRASH` / watchdog | Bị hệ thống giết |

Và các **termination code** — nhớ được vài cái này gây ấn tượng rất mạnh vì nó chứng minh bạn từng đọc crash log thật:

- `0x8badf00d` ("ate bad food") — **watchdog timeout**, app block main thread quá lâu lúc launch/suspend. Đây *không* phải bug logic, mà là performance bug.
- `0xdead10cc` ("dead lock") — giữ file lock hoặc SQLite/Core Data resource khi vào background.
- `0xc00010ff` ("cool off") — bị giết vì nhiệt.
- **Jetsam / memory pressure** — không phải crash log thường mà là JetsamEvent report; app vượt memory limit. Nếu backtrace trông "vô lý" ở chỗ chẳng liên quan, hãy nghi memory.

Điểm chốt đáng nói: *"Điều đầu tiên tôi làm không phải nhìn dòng cuối cùng của stack trace, mà nhìn Exception Type. Nó quyết định tôi sẽ đi tìm cái gì — memory bug, logic bug, hay performance bug là ba hướng điều tra hoàn toàn khác nhau."*

**3. Symbolication — nếu không có bước này thì không có bước nào cả**

Crash log thô chỉ là địa chỉ hex. Cần **dSYM có UUID khớp chính xác** với build đã ship. Nói được ba ý:

- Xcode Organizer symbolicate tự động nếu bạn upload symbols khi submit.
- Nếu dùng bitcode ngày xưa (nay đã deprecated), dSYM phải tải về từ App Store Connect vì Apple recompile lại binary.
- Fallback thủ công: `atos -o MyApp.app.dSYM/Contents/Resources/DWARF/MyApp -l <load_address> <address>`.
- **Phải archive dSYM cho mọi build đã release.** Mất dSYM = crash log vô dụng vĩnh viễn. Team tốt sẽ upload dSYM tự động trong CI/CD pipeline.

Đây là chỗ bạn có thể kéo về kinh nghiệm CI/CD của mình — bước upload dSYM lên Crashlytics là một job trong pipeline, không phải việc làm tay.

**4. Reproduce & localize**

Nếu reproduce được, thứ tự vũ khí:

- **Exception Breakpoint** (`⌘8` → `+` → Exception Breakpoint, All). Cực kỳ quan trọng: nó dừng lại *tại điểm ném exception* thay vì ở `main.swift` với stack trace vô nghĩa. Rất nhiều dev không bật cái này.
- **Symbolic Breakpoint** cho những chỗ bạn không có source (`-[UIViewController viewDidLoad]`, hoặc `UIApplicationMain`).
- **Conditional breakpoint** — chỉ dừng khi `index > 100`, thay vì bấm Continue 100 lần. Kèm action (log message + auto-continue) để biến breakpoint thành một dạng log động không cần recompile.
- **LLDB**: `po`, `p`, `bt`, `frame variable`, `expression` để sửa state ngay tại chỗ và kiểm chứng giả thuyết.

Với các loại crash khó, **Sanitizers là con bài mạnh nhất**:

| Công cụ | Bắt được gì |
|---|---|
| **Address Sanitizer** | Use-after-free, buffer overflow → chính là `EXC_BAD_ACCESS` |
| **Thread Sanitizer** | Data race — loại crash "ngẫu nhiên" khó chịu nhất |
| **Main Thread Checker** | Gọi UIKit ngoài main thread |
| **Zombie Objects** | Over-release trong ObjC / bridged code |
| **Malloc Stack Logging** | Cho biết object bị leak/free được cấp phát ở đâu |
| `-com.apple.CoreData.ConcurrencyDebug 1` | Vi phạm thread confinement của Core Data |

Cộng thêm một ý rất "senior 2026": **Swift 6 strict concurrency đẩy cả một lớp crash từ runtime lên compile time**. Data race từng phải săn bằng TSan giờ compiler chặn thẳng. Đây là câu bạn nên nói vì nó cho thấy bạn theo dõi hướng đi của ngôn ngữ.

**5. Với crash không reproduce được — đây là phần phân biệt senior**

Bạn không debug được, nên bạn phải **dựng sẵn hạ tầng bằng chứng từ trước khi crash xảy ra**:

- **Breadcrumbs**: log lại screen navigation, action chính, network request ID. Khi crash log tới, bạn có "20 sự kiện cuối cùng trước khi chết". Đây gần như luôn là thứ hữu ích nhất.
- **OSLog / `Logger`**: dùng unified logging thay `print()`. Có `privacy: .public/.private`, có subsystem/category để lọc, log được thu thập qua Console.app và `sysdiagnose`, và có `signpost` để đo performance. `print()` không tồn tại trên máy user.
- **MetricKit**: `MXMetricManager` cho `MXCrashDiagnostic` và `MXHangDiagnostic` — data trực tiếp từ Apple, gồm cả **hang report** mà crash reporter thường bỏ sót. Nhắc được MetricKit là một điểm cộng rõ rệt vì rất ít ứng viên nhắc.
- **Third-party**: Crashlytics/Sentry cho grouping, alerting, custom keys (user ID, feature flag state, session length) và non-fatal reporting.

Và một chiêu thực dụng: nếu vẫn không tìm ra, **thu hẹp bằng release**. Đưa fix nghi ngờ ra **phased release**, hoặc bọc code nghi vấn bằng feature flag rồi tắt/bật để xác nhận nhân quả.

**6. Fix xong chưa phải là xong**

Ba việc kết:
- Viết test tái hiện đúng điều kiện gây crash (nếu là logic bug).
- Thêm **guardrail** để nếu tái phát thì nó phát nổ sớm và rõ ràng — chính là chỗ dùng `precondition`.
- **Verify ngoài production**: theo dõi crash-free rate của phiên bản mới, chứ không tự tuyên bố đã fix.

## `assert` vs `precondition` vs `fatalError` — gần như chắc chắn bị hỏi tiếp

Đề bài nhắc tới hai cái này nên hãy chuẩn bị kỹ. Khác biệt nằm ở **optimization level**:

| API | `-Onone` (Debug) | `-O` (Release) | `-Ounchecked` |
|---|---|---|---|
| `assert` / `assertionFailure` | Chạy | **Bị loại bỏ** | Bị loại bỏ |
| `precondition` / `preconditionFailure` | Chạy | **Chạy** | Bị loại bỏ |
| `fatalError` | Chạy | Chạy | **Vẫn chạy** |

Cách chọn — nói theo *ý nghĩa* chứ đừng chỉ đọc bảng:

- **`assert`**: kiểm tra giả định nội bộ mà bạn tin là luôn đúng; sai thì là bug của chính bạn. Không tốn chi phí ở release.
- **`precondition`**: kiểm tra input từ bên ngoài mà nếu sai thì chương trình *không thể tiếp tục an toàn*. Ví dụ index ngoài phạm vi trong một collection tự viết. Bạn muốn nó crash cả trên máy user — vì crash rõ ràng còn tốt hơn corrupt data âm thầm.
- **`fatalError`**: đánh dấu đường đi lẽ ra không bao giờ tới — nhánh `default` của một enum đã exhaustive, hoặc `required init?(coder:)` chưa implement.

Triết lý đáng nói thành lời: *"Crash sớm và ồn ào tại nguyên nhân còn dễ sửa hơn nhiều so với việc app đi tiếp với state hỏng rồi crash 5 phút sau ở chỗ chẳng liên quan gì. Assertion không phải để tránh crash, mà để chọn *chỗ* crash."*

## Các nguyên nhân crash phổ biến trong Swift — kể sẵn vài cái

Nếu interviewer hỏi "loại crash nào bạn gặp nhiều nhất", đừng ú ớ:

1. **Force unwrap `nil`** — thường từ `IBOutlet` truy cập trước `viewDidLoad`, hoặc JSON parsing.
2. **Array index out of range** — hay gặp khi data source thay đổi bất đồng bộ mà UI chưa reload; cổ điển với `UITableView`/`UICollectionView` và diffable data source không nhất quán.
3. **`unowned` trỏ vào object đã giải phóng** → `EXC_BAD_ACCESS`. `weak` an toàn hơn, `unowned` nhanh hơn nhưng chỉ dùng khi lifetime được đảm bảo chắc chắn.
4. **UI update ngoài main thread** — Main Thread Checker bắt được, và trong SwiftUI/Swift Concurrency thì `@MainActor` giải quyết ở tầng compiler.
5. **Core Data / SQLite dùng sai thread** — hoặc `NSManagedObject` bị dùng sau khi context chết.
6. **KVO observer chưa remove** → `SIGABRT`.
7. **Watchdog timeout** — làm việc nặng đồng bộ trong `application(_:didFinishLaunchingWithOptions:)`.

## Cách kể thành một câu chuyện (nên chuẩn bị sẵn 1 vụ)

Interviewer sẽ thích nhất nếu bạn kết bằng một case thật, ngắn gọn theo 4 nhịp: **triệu chứng → manh mối quyết định → nguyên nhân gốc → cách phòng ngừa sau đó**.

Ví dụ khung (bạn thay bằng vụ thật của mình):

> "Có lần bọn tôi thấy crash rate tăng vọt chỉ sau một bản release, tất cả đều là `EXC_BREAKPOINT` trong code liên quan tới list. Không reproduce được trên máy dev. Manh mối là breadcrumb cho thấy user đều vừa pull-to-refresh xong. Hoá ra data source được cập nhật trên background thread trong khi table view đang đọc — array index out of range ở giữa. Fix là đưa việc cập nhật snapshot về main actor. Sau đó tôi thêm precondition ở lớp data source và bật Thread Sanitizer trong CI cho suite UI test để không có ai lặp lại."

Nếu bạn có kinh nghiệm CI/CD như đang có, ghép luôn: bước "upload dSYM tự động" và "chạy sanitizer trong pipeline" là những chi tiết cho thấy bạn nghĩ ở tầm hệ thống chứ không chỉ tầm một cái bug.

## Bẫy cần tránh

- **Đừng chỉ nói "em dùng Crashlytics".** Đó là nơi crash *hiện ra*, không phải cách bạn *giải quyết*. Interviewer sẽ hỏi ngay "rồi sau đó thì sao?".
- **Đừng nói `print()`** như là chiến lược logging. Nói `OSLog`/`Logger`.
- **Đừng bỏ qua symbolication.** Nếu bạn nói về crash log production mà không nhắc dSYM, người phỏng vấn sẽ đoán bạn chưa từng thật sự làm.
- **Đừng coi hang/watchdog là ngoài phạm vi.** Với user, app đơ rồi bị giết cũng là "app crash". Nhắc tới nó cho thấy bạn nhìn từ góc user.
- **Đừng để câu trả lời chỉ là danh sách tool.** Mỗi tool phải gắn với một bước trong phễu và một loại bug cụ thể.
