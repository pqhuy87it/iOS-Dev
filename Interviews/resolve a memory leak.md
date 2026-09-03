## Câu hỏi này thực sự test cái gì?

Đề bài nhắc rất đúng hai chi tiết mà người trả lời hay bỏ qua: **persistent vs transient**, và **cách chứng minh leak đã hết**. Cái thứ hai mới là điểm phân biệt thật.

Ai cũng biết `[weak self]`. Rất ít người biết **làm sao chứng minh** rằng mình đã sửa xong. Interviewer đang hỏi: bạn có phương pháp *kiểm chứng*, hay bạn thêm `[weak self]` rồi tin là xong?

## Chia đôi bài toán — đây là ý quan trọng nhất

Nếu bạn chỉ nói được một điều trong câu này, hãy nói điều này: **"memory leak" trong iOS thực chất là hai vấn đề khác nhau**, và công cụ cho chúng khác nhau.

| | **Leak thật** | **Abandoned memory** |
|---|---|---|
| Bản chất | Không ai reference được nữa, nhưng ARC không giải phóng | Vẫn còn reference hợp lệ, nhưng logic không bao giờ dùng lại |
| Nguyên nhân điển hình | Retain cycle | Cache không giới hạn, array `append` mãi, singleton giữ mọi thứ |
| Instruments **Leaks** có bắt được? | **Có** | **Không** |
| Cần dùng gì | Memory Graph, Leaks | Allocations + Generation Analysis |

Đây là chỗ hầu hết ứng viên trượt: họ chạy Leaks instrument, thấy sạch, kết luận không có vấn đề — trong khi memory vẫn tăng đều đặn. **Abandoned memory phổ biến hơn và khó tìm hơn leak thật**, vì về mặt kỹ thuật nó hoàn toàn "hợp lệ".

Câu chốt để nói:

> "Leaks instrument chỉ bắt được retain cycle. Nhưng loại tôi gặp nhiều hơn là abandoned memory — object vẫn có owner nên không bị coi là leak, chỉ là owner đó không bao giờ nhả ra. Với loại này tôi phải dùng generation analysis, vì không có tool nào tự phát hiện được."

Và thêm một ý về hậu quả, đặc thù của iOS: **iOS không có swap**. Vượt memory limit không làm app chậm dần — nó bị **Jetsam giết thẳng**. Nên leak không phải bug "hiệu năng", nó là bug "crash có độ trễ". App extension còn khắc nghiệt hơn: Notification Service Extension chỉ có khoảng 24MB, một leak nhỏ cũng đủ chết.

## Quy trình 5 bước

### Bước 1 — `deinit`, trước khi mở bất cứ tool nào

Rẻ nhất, nhanh nhất, và giải quyết phần lớn trường hợp:

```swift
deinit {
    logger.debug("\(String(describing: Self.self)) deinit")
}
```

Push view controller vào, pop ra — `deinit` có in không? Nếu không, bạn đã xác định được leak và cả class nào bị giữ, trong 10 giây, không cần Instruments.

Nói ra được điều này cho thấy bạn thực dụng: **không phải bài toán nào cũng cần dùng vũ khí nặng**.

### Bước 2 — Memory Graph Debugger để *nhìn thấy* cycle

Đây là công cụ hiệu quả nhất và nên là bước tiếp theo. Nút hình ba khối trong Debug bar khi app đang chạy.

Cách dùng đúng:
- Icon **tím dấu `!`** = Xcode tự phát hiện leak.
- Chọn object → panel bên phải hiện **toàn bộ chuỗi reference** dẫn tới nó, và cho biết cạnh nào là `strong`, cạnh nào `weak`. Cycle hiện ra dưới dạng vòng tròn khép kín — rất trực quan.
- **Filter theo tên type của bạn** (đúng như đề bài gợi ý) ở thanh search dưới cùng, để lọc bỏ hàng nghìn object hệ thống.

Chi tiết quan trọng mà nhiều người không biết: mặc định bạn thấy được cycle nhưng **không biết object được tạo ra ở đâu**. Phải bật **Malloc Stack Logging**:

> Edit Scheme → Run → Diagnostics → Malloc Stack Logging: **Live Allocations Only**

Bật xong, panel bên phải sẽ hiện luôn backtrace nơi object được allocate. Đây là thứ biến "tôi biết có cycle" thành "tôi biết chính xác dòng code nào tạo ra nó".

Ngoài ra, memgraph có thể export và phân tích bằng command line — hữu ích khi debug từ device của QA hoặc trong CI:

```bash
xcrun leaks MyApp.memgraph      # liệt kê leak + cycle
xcrun heap MyApp.memgraph       # phân bố object theo class
xcrun vmmap MyApp.memgraph      # dirty / clean / compressed
```

### Bước 3 — Instruments: persistent vs transient và generation analysis

Phần này đề bài nhắc trực tiếp nên phải nói kỹ.

**Persistent vs Transient trong Allocations:**

- **Transient** = đã được deallocate. Sinh ra rồi chết — bình thường, healthy.
- **Persistent** = vẫn đang sống.

Cách đọc: **Persistent count của một type tăng đều sau mỗi chu kỳ thao tác giống nhau** → leak hoặc abandoned memory. Transient cao không phải vấn đề (có thể là vấn đề performance do churn, nhưng không phải leak).

Nhớ **filter theo module/prefix của bạn** — không thì bạn sẽ chìm trong `__NSCFString` và `CFData` của hệ thống.

**Generation Analysis — workflow cụ thể** (đây là chỗ nên nói từng bước, vì nó chứng minh bạn làm thật):

1. Chạy Allocations, đưa app về trạng thái ổn định (baseline).
2. Bấm **Mark Generation**.
3. Thực hiện đúng một chu trình: push VC → tương tác → pop.
4. **Mark Generation** lần nữa.
5. Lặp lại 5–10 lần.
6. Đọc cột **Growth** của từng generation.

Nếu mọi thứ đúng, Growth của mỗi generation phải xấp xỉ 0 sau khi pop. Nếu nó giữ một lượng cố định mỗi vòng — bạn có leak, và click vào generation đó sẽ thấy chính xác object nào còn sống kèm backtrace allocation.

**Một chi tiết tinh tế đáng nói**: generation *đầu tiên* thường có growth thật mà không phải bug — lazy initialization, one-time cache, font/asset load lần đầu. Nên **bỏ generation đầu, đọc từ generation thứ hai trở đi**. Nhắc được điều này là tín hiệu rõ ràng rằng bạn từng ngồi đọc Instruments thật chứ không đọc tutorial.

### Bước 4 — Biết trước danh sách nghi phạm

Khi đã khoanh được type, bạn cần biết nhìn vào đâu. Đây là danh sách theo tần suất thực tế:

**Closure capture `self` trong escaping closure** — thủ phạm số một. `self` giữ closure (qua property/cancellable/subscription), closure giữ `self`.

**Delegate không `weak`.** `weak var delegate: SomeDelegate?` — và protocol phải là `AnyObject` mới `weak` được.

**`Timer`** — cực kỳ hay bị. `Timer` giữ **strong** target/closure, và `RunLoop` giữ `Timer`. Nên `self` không bao giờ chết, kể cả khi bạn dùng `[weak self]` trong block — vì Timer vẫn sống. Phải `invalidate()` thật sự, và `invalidate()` phải được gọi trên **cùng run loop** đã schedule nó.

**`CADisplayLink`** — cùng vấn đề, thêm cái tệ là nó đốt pin liên tục (nối được sang câu battery).

**Block-based `NotificationCenter.addObserver`** — trả về token; phải lưu token và `removeObserver`. Bản selector-based từ iOS 9 thì tự dọn, bản block-based thì không.

**Combine** — cycle kinh điển:
```swift
// SAI: self giữ cancellables, sink closure giữ self
publisher.sink { self.update($0) }.store(in: &cancellables)
// ĐÚNG:
publisher.sink { [weak self] in self?.update($0) }.store(in: &cancellables)
```

**`URLSession` với delegate** — ít người biết: `URLSession` giữ **strong** reference tới delegate cho tới khi bạn gọi `finishTasksAndInvalidate()` hoặc `invalidateAndCancel()`. Không gọi = leak chắc chắn. Nhắc được cái này rất ấn tượng.

**Swift Concurrency** — `Task { }` giữ `self` cho tới khi task hoàn thành. Task không bao giờ kết thúc (ví dụ `for await` trên một stream vô hạn) = giữ `self` vĩnh viễn. Phải giữ handle và `cancel()`, hoặc dùng `.task {}` modifier trong SwiftUI (tự cancel theo view lifecycle).

**SwiftUI** — `@StateObject` vs `@ObservedObject` dùng sai gây tạo lại object liên tục (churn, không hẳn leak); ViewModel giữ closure có capture view context; `@EnvironmentObject` giữ lâu hơn dự kiến.

**Core Graphics / C API** — `CGImage`, `CGContext`, `CFRetain` cần `CFRelease` thủ công. Không nằm trong ARC.

**Một điểm phân biệt cần nói rõ** (nối được với câu về crash): `unowned` trỏ vào object đã chết **không gây leak — nó gây crash** `EXC_BAD_ACCESS`. Hai loại bug ngược nhau: `weak` sai → có thể leak nếu bạn dùng `strong` thay vì `weak`; `unowned` sai → crash. Người hiểu điều này không bao giờ nhầm hai nhóm bug.

### Bước 5 — Chứng minh đã fix (phần đề bài nhấn mạnh nhất)

Đề bài gợi ý rất đúng: **push/pop cùng một view controller 10 lần, memory có giữ nguyên không?** Nhưng cần nói chính xác hơn, vì trả lời "memory phải về đúng mức ban đầu" là **sai**.

Thang kiểm chứng từ yếu tới mạnh:

**Mức 1 — `deinit` được gọi.** Điều kiện cần, không đủ. `deinit` chạy nghĩa là object đó chết, nhưng object khác vẫn có thể còn sống.

**Mức 2 — Memory Graph: filter theo type, instance count = 0** sau khi pop. Đây là bằng chứng trực tiếp và mạnh.

**Mức 3 — Generation analysis: Growth về ~0** ở các generation từ thứ 2 trở đi.

**Mức 4 — Unit test tự động.** Đây là câu trả lời mà rất ít người đưa ra, và nó gắn được với kinh nghiệm CI/CD của bạn:

```swift
func testViewModelDoesNotLeak() {
    weak var weakRef: MyViewModel?
    autoreleasepool {
        let sut = MyViewModel(service: MockService())
        weakRef = sut
        sut.load()          // kích hoạt các closure/subscription
    }
    XCTAssertNil(weakRef, "MyViewModel bị giữ lại — có retain cycle")
}
```

Pattern này chạy trong CI, chặn regression, và **rẻ hơn nhiều so với việc mở Instruments mỗi sprint**. Kèm `XCTMemoryMetric` trong `measure(metrics:)` để đặt baseline cho footprint.

**Và đây là điểm tinh tế then chốt về cách đọc số:**

> "Memory không quay về đúng con số ban đầu là chuyện bình thường — image cache, `URLCache`, font cache, autorelease pool chưa drain. Điều tôi tìm không phải sự bằng nhau tuyệt đối, mà là **tăng trưởng đơn điệu tuyến tính theo số vòng lặp**. Nếu 10 vòng tăng 10 đơn vị và 20 vòng tăng 20 đơn vị — đó là leak. Nếu nó tăng rồi phẳng ra — đó là cache đang làm việc của nó."

Câu này một mình đã tách bạn ra khỏi phần lớn ứng viên.

**Mức 5 — Kiểm chứng ngoài production**: `MXMemoryMetric` (peak memory footprint) từ MetricKit, và Xcode Organizer → Metrics → Memory theo từng app version. Cộng với việc theo dõi Jetsam/OOM termination rate.

## Cách gói lại thành một câu chuyện

Khung 4 nhịp — triệu chứng → manh mối → nguyên nhân → phòng ngừa:

> "Bọn tôi thấy OOM termination tăng ở một luồng có nhiều lần vào/ra chi tiết sản phẩm. Leaks instrument sạch, nên tôi biết không phải retain cycle. Chuyển sang Allocations + generation analysis, mark generation quanh mỗi lần vào/ra: từ generation thứ hai trở đi, mỗi vòng giữ lại một lượng cố định — toàn bộ là `UIImage` và một array trong một singleton. Nguyên nhân là image cache tự viết không có giới hạn, cứ append. Fix là chuyển sang `NSCache` (tự nhả khi hệ thống áp lực) và set `countLimit`. Sau đó tôi thêm một test dùng `weak` reference cho ViewModel của màn đó và một `XCTMemoryMetric` baseline trong CI, để nếu ai vô tình giữ lại thứ gì thì build đỏ ngay chứ không phải đợi user report."

## Bẫy cần tránh

- **Đừng nói "em chạy Leaks, không thấy gì nên không có leak".** Đây là sai lầm khái niệm rõ nhất — Leaks không bắt abandoned memory.
- **Đừng rắc `[weak self]` khắp nơi như phản xạ.** Non-escaping closure không cần. Closure chạy một lần rồi giải phóng cũng thường không cần. Và `[weak self]` trong `Task` có thể khiến công việc bị bỏ giữa đường một cách âm thầm — đôi khi bạn *muốn* giữ `self` sống tới khi task xong. Nói được sự phân biệt này cho thấy bạn hiểu ARC, không chỉ nhớ mẹo.
- **Đừng nhầm memory growth với leak.** Cache tăng rồi phẳng là healthy.
- **Đừng bỏ qua `deinit`.** Nếu bạn mở Instruments trước khi thử `deinit` log, interviewer sẽ nghĩ bạn thiếu thực dụng.
- **Đừng quên bật Malloc Stack Logging.** Không có nó, Memory Graph cho bạn "cái gì" nhưng không cho "từ đâu".
- **Đừng bỏ qua bước chống regression.** Câu hỏi này có chữ "resolve", và resolve đúng nghĩa gồm cả việc đảm bảo nó không quay lại.

## Câu hỏi đào sâu có thể theo sau

1. **"`weak` và `unowned` khác nhau thế nào, khi nào dùng cái nào?"** → `weak` là optional, tự về `nil`, có overhead (side table). `unowned` không optional, nhanh hơn, nhưng dangling → crash. Dùng `unowned` chỉ khi bạn chắc chắn dependency sống lâu hơn hoặc bằng closure — điển hình là closure capture một object mà `self` sở hữu.
2. **"`NSCache` khác `Dictionary` ở đâu?"** → `NSCache` tự nhả object khi hệ thống áp lực memory, thread-safe, có `countLimit`/`totalCostLimit`. Đây gần như luôn là câu trả lời đúng cho cache trong app iOS.
3. **"Retain cycle có luôn là leak không?"** → Có, cycle nghĩa là không bao giờ giải phóng. Nhưng ngược lại không đúng: leak không nhất thiết là cycle.
4. **"iOS xử lý app hết memory thế nào?"** → Jetsam giết, không có swap. `didReceiveMemoryWarning` / `.didReceiveMemoryWarningNotification` là cơ hội cuối để nhả cache, nhưng đừng trông cậy vào nó.
5. **"Value type có leak được không?"** → `struct`/`enum` bản thân không, nhưng nếu chúng chứa reference type hoặc closure capture thì có. Và `struct` chứa closure capture `self` của một class là một cycle rất khó thấy.
