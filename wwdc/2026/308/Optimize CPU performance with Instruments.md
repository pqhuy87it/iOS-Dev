Video **"Optimize CPU performance with Instruments" (WWDC25, session 308)**. Lần này có transcript đầy đủ nên chi tiết sẽ chính xác hơn. Đây là session về tối ưu hiệu năng CPU cho Apple silicon bằng hai công cụ mới trong Instruments (Processor Trace và CPU Counters), minh họa qua việc tối ưu một hàm binary search — cuối cùng nhanh hơn **~25 lần**.

---

## Tóm tắt các mục chính

1. **Introduction & Agenda (0:00)** — Vì sao khó dự đoán hiệu năng: nhiều lớp trừu tượng giữa Swift và máy, và CPU thực thi out-of-order + cache. Giới thiệu lộ trình tối ưu.
2. **Performance mindset (2:28)** — Tư duy đúng khi điều tra hiệu năng: giữ tâm trí mở, đo trước khi đoán, ưu tiên tránh việc thay vì micro-optimize.
3. **Profilers (8:50)** — So sánh Time Profiler vs CPU Profiler; vì sao CPU Profiler chính xác hơn (tránh aliasing).
4. **Span (13:20)** — Chuyển từ `Collection` sang `Span` (Swift 6.2) → nhanh gấp 4 lần mà không đổi thuật toán.
5. **Processor Trace (14:05)** — Công cụ mới ghi lại **mọi instruction** (không lấy mẫu), phát hiện overhead của generic chưa specialize.
6. **Bottleneck analysis (19:51)** — Dùng CPU Counters phân tích nghẽn: branch misprediction (→ branchless) và cache miss (→ Eytzinger layout).
7. **Recap (31:33)** — Đúc kết thứ tự tối ưu: xử lý overhead phần mềm trước, rồi mới tới nghẽn CPU.
8. **Next steps (32:13)** — Tài nguyên và bước tiếp theo.

---

## Chi tiết từng mục

### 1. Introduction & Agenda
Hiệu năng khó dự đoán vì hai lý do:
- **Lớp trừu tượng:** Swift source được biên dịch thành machine instructions, nhưng code không chạy đơn độc — còn có support code do compiler sinh ra, Swift runtime, system frameworks, và system calls vào kernel. Khó biết chi phí thật của các abstraction.
- **Cách CPU thực thi:** các functional unit chạy song song, instructions thực thi **out-of-order** (chỉ *trông* như tuần tự), và có nhiều tầng **cache**. Những đặc điểm này tăng tốc các pattern phổ biến (quét tuyến tính, early exit), nhưng một số cấu trúc dữ liệu/thuật toán lại "khó nhằn" với CPU.

Lộ trình: (1) tư duy đúng → (2) profiling truyền thống tìm CPU usage cao → (3) Processor Trace ghi mọi instruction, đo chi phí abstraction → (4) CPU Counters phân tích bottleneck để micro-optimize.

### 2. Performance mindset
**Giữ tâm trí mở, thu thập dữ liệu để kiểm chứng giả định.** Nguồn gây chậm có thể bất ngờ. Cây quyết định:
- Thread có thể **bị block** (chờ file, chờ shared mutable state) chứ không chỉ do CPU đơn luồng → dùng **System Trace**, hoặc xem session "Visualize and optimize Swift concurrency".
- Có thể do **dùng sai API** (sai QoS, tạo quá nhiều thread ngầm) → đọc doc "Tuning your code's performance".
- Nếu đúng là vấn đề hiệu quả (efficiency) → phải đổi **thuật toán/cấu trúc dữ liệu** hoặc **cách triển khai**.

Công cụ định hướng: **CPU Gauge** (built-in Xcode) để phát hiện CPU bận; **System Trace** cho hành vi block; **Hangs instrument** cho vấn đề UI/main thread.

**Cảnh báo về micro-optimization:** nó làm code khó mở rộng/khó hiểu và thường dựa vào tối ưu compiler mong manh (auto-vectorization, reference count elision). Trước khi micro-optimize, hãy tìm cách **tránh việc** hẳn:
- Xóa code không cần (kiểm tra lại xem kết quả có thực sự quan trọng không).
- Làm việc **muộn hơn**, ngoài critical path, hoặc chỉ khi kết quả sẽ được nhìn thấy.
- **Precompute** (thậm chí bake giá trị lúc build) — nhưng có thể tốn điện hoặc tăng kích thước app.
- **Caching** — nhưng kèm bài toán khó (invalidation, tăng bộ nhớ).

Ưu tiên tối ưu code trên **critical path** (nơi người dùng cảm nhận được) hoặc tác vụ chạy lâu tốn điện. Trong session, ví dụ là **binary search** trên mảng số nguyên đã sort.

### 3. Profilers
Hai profiler tập trung CPU:
- **Time Profiler:** lấy mẫu định kỳ theo timer, chụp call stack của mỗi thread. Vấn đề: **aliasing** — nếu có việc chạy đúng nhịp với timer lấy mẫu, nó bị over-represent một cách bất công.
- **CPU Profiler (nên dùng):** lấy mẫu **độc lập theo tần số clock của từng CPU**. Chính xác hơn, cân bằng hơn. Apple silicon là CPU bất đối xứng (một số core chạy chậm/tiết kiệm điện hơn); CPU nào scale tần số cao sẽ được lấy mẫu nhiều hơn, không bị thiên vị như Time Profiler.

Thao tác thực tế: từ **test navigator** trong Xcode, chuột phải vào test → **Profile**; chọn template CPU Profiler; đặt **deferred mode** (giảm overhead khi test tự động chạy cùng máy với Instruments). Dùng track **Points of Interest** (từ signpost) để khoanh vùng, chuột phải **Set Inspection Range**, xem **call tree**. Giữ **Option** rồi click chevron để expand cây tới điểm sample bắt đầu phân kỳ; **Focus on Subtree** vào hàm binary search.

**Phát hiện:** rất nhiều sample nằm trong các hàm xử lý kiểu `Collection` — protocol witness chiếm ~1/4 số mẫu, có cả allocation và kiểm tra kiểu Objective-C của `Array`. → Nên đổi sang container khớp dữ liệu hơn: **`Span`**.

### 4. Span
**`Span` (Swift 6.2)** dùng thay `Collection` khi phần tử nằm **liên tục trong bộ nhớ**. Về bản chất nó là **base address + count**, đồng thời ngăn việc "escape"/leak tham chiếu bộ nhớ ra ngoài phạm vi hàm.

Áp dụng chỉ cần đổi kiểu `haystack` và kiểu trả về sang `Span` — **thuật toán không đổi**:
```swift
public func binarySearch<E: Comparable>(needle: E, haystack: Span<E>) -> Span<E>.Index {
    var start = haystack.indices.startIndex
    var length = haystack.count
    while length > 0 {
        let half = length / 2
        let middle = haystack.indices.index(start, offsetBy: half)
        let middleValue = haystack[middle]
        if needle < middleValue { length = half }
        else if needle == middleValue { return middle }
        else { start = haystack.indices.index(after: middle); length -= half + 1 }
    }
    return start
}
```
Thay đổi nhỏ này giúp **nhanh gấp 4 lần** (tránh overhead của `Array` copy-on-write và generics). Nhưng vẫn còn chậm → nghi ngờ bounds checking của Span → dùng Processor Trace để đào sâu.

### 5. Processor Trace
Từ **Instruments 16.3**, Processor Trace ghi lại **toàn bộ instruction** mà process của app thực thi ở user space. Đây là bước ngoặt: **không có sampling bias**, chỉ **~1% overhead**. Yêu cầu phần cứng: **Mac & iPad Pro với M4** trở lên, hoặc **iPhone với A18** trở lên.

**Thiết lập:** bật trong Privacy & Security → Developer Tools (Mac), hoặc mục Developer (iPhone/iPad). Nên **trace chỉ vài giây** — khác với sampling, không cần gom việc, một lần chạy code là đủ.

**Cách hoạt động:** CPU ghi lại mọi quyết định rẽ nhánh (branching) + cycle count + thời gian. Instruments dùng binary của app và framework để **tái dựng đường thực thi chính xác**, chú thích mỗi lời gọi hàm với số cycle và thời lượng. Dữ liệu có thể lên tới nhiều GB/giây với app đa luồng → phải giới hạn thời gian.

**Flame graph theo thời gian:** khác flame graph sampling thông thường (chi phí chỉ ước lượng), đây là **chuỗi call chính xác như CPU đã chạy**. Màu sắc: **nâu** = system framework, **hồng đậm (magenta)** = Swift runtime/stdlib, **xanh dương** = code app/custom framework. Có thể zoom vào một lời gọi chỉ chạy vài trăm nanosecond. Bảng **Function Calls** hiển thị cùng dữ liệu dạng bảng, sort theo cycles.

**Phát hiện (bất ngờ):** giả định "bounds check gây chậm" **sai**. Thủ phạm thật là **overhead của protocol metadata** và việc **không inline được phép so sánh số** — vì tham số generic `Comparable` **chưa được specialize** cho kiểu phần tử thực tế. Do hàm nằm trong framework mà app link tới, compiler không thể sinh bản specialize.

**Giải pháp:** thêm annotation `@inlinable` cho hàm framework để sinh bản specialize trong binary của client. Nhưng inline làm code khó phân tích (trộn với caller), nên ở đây tác giả chọn cách **specialize thủ công cho `Int`** (đổi tên hàm thành `binarySearchInt`). Mất tính tổng quát nhưng **nhanh thêm ~1.7 lần**.

### 6. Bottleneck analysis
Trước tiên cần mô hình về cách CPU chạy. CPU thực thi qua hai phase, được **pipeline hóa**:
- **Instruction Delivery:** fetch instruction, decode thành **micro-operations** (hầu hết 1 instruction → 1 micro-op, một số thành nhiều).
- **Instruction Processing:** map & schedule (định tuyến, dispatch) → gán cho execution unit, hoặc **load-store unit** nếu cần truy cập bộ nhớ.

**Instruction-level parallelism (ILP):** khác với parallelism cấp thread/process (Swift Concurrency, GCD). ILP cho phép **một CPU** tận dụng lúc unit rảnh. Swift source không điều khiển trực tiếp được ILP mà phải giúp compiler sinh chuỗi instruction "dễ song song hóa". Mỗi mũi tên giữa các unit là nơi op có thể **stall** — đó là **bottleneck**.

**CPU Counters instrument** đọc các bộ đếm sự kiện phần cứng để dựng metric bậc cao. Năm nay thêm **preset modes** và phương pháp lặp có hướng dẫn gọi là **bottleneck analysis** (mỗi mode gợi ý "Suggested Next Mode"). CPU Counters dựa trên **sampling** nên phải quay lại test harness đo throughput.

**Bước 1 — CPU Bottlenecks mode:** chia việc CPU thành 4 nhóm lớn (stacked bar chart). Phát hiện phần trăm cao ở **Discarded** bottleneck → gợi ý mode **Discarded Sampling**.

**Bước 2 — Discarded Sampling:** counter được set để trigger sampling, chỉ lấy đúng **instruction sinh ra việc bị hủy** (không phải call stack). Mở **Source Viewer** thấy chính dòng so sánh `needle` với `middleValue` bị **dự đoán nhánh sai (branch misprediction)**.

**Lý do:** CPU thực thi out-of-order và dùng **branch predictor** dự đoán nhánh kế tiếp. Vòng lặp binary search có hai loại nhánh: điều kiện vòng lặp (thường dễ đoán, không xuất hiện trong sample) và **check needle — về cơ bản là nhánh ngẫu nhiên**, nên predictor liên tục đoán sai.

**Giải pháp — branchless:** viết lại thân vòng lặp để chỉ **gán giá trị theo điều kiện** (không rẽ control flow) → compiler sinh **conditional move** thay vì branch. Bỏ early return, dùng **unchecked arithmetic (`&+`)** để tránh nhánh terminate chương trình:
```swift
public func binarySearchBranchless(needle: Int, haystack: Span<Int>) -> Span<Int>.Index {
    var start = haystack.indices.startIndex
    var length = haystack.count
    while length > 0 {
        let remainder = length % 2
        length /= 2
        let middle = start &+ length
        let middleValue = haystack[middle]
        if needle > middleValue { start = middle &+ remainder }
    }
    return start
}
```
→ **nhanh gấp ~2 lần** (nhưng tác giả lưu đây là chỗ micro-optimization dễ vỡ, kém an toàn/khó hiểu).

**Bước 3 — chuyển sang memory:** sau branchless, workload gần như hoàn toàn nghẽn ở **Instruction Processing**. Chạy mode **Instruction Processing** → gợi ý **L1D Cache Miss Sampling** → phát hiện việc truy cập bộ nhớ mảng là nguyên nhân.

**Tầng cache:** L1 (trong mỗi CPU, nhanh nhất, nhỏ) → L2 (ngoài CPU, lớn hơn, chậm hơn) → main memory (**chậm gấp ~50 lần**). Cache gom bộ nhớ thành **cache line 64/128 byte** (dù chỉ cần 4 byte cũng kéo về cả line).

**Vì sao binary search tệ với cache:** mảng ban đầu ngoài cache; lần so sánh đầu kéo một cache line vào L1, nhưng lần so sánh kế **nhảy xa** gây cache miss, và các vòng sau liên tục miss cho đến khi thu hẹp về một vùng cỡ cache line. → Binary search là **trường hợp bệnh lý (pathological)** cho memory hierarchy.

**Giải pháp — Eytzinger layout:** sắp xếp lại mảng theo **duyệt theo chiều rộng (breadth-first)** của cây tìm kiếm (đặt tên theo nhà gia phả học người Áo thế kỷ 16). Các phần tử gần gốc cây được xếp **dày đặc**, dễ chia sẻ cùng cache line; tìm 5 thì 3 bước đầu nằm cùng một cache line:
```swift
public func binarySearchEytzinger(needle: Int, haystack: Span<Int>) -> Span<Int>.Index {
    var start = haystack.indices.startIndex.advanced(by: 1)
    let length = haystack.count
    while start < length {
        let value = haystack[start]
        start *= 2
        if value < needle { start += 1 }
    }
    return start >> ((~start).trailingZeroBitCount + 1)
}
```
→ **nhanh thêm ~2 lần** nữa. Đánh đổi: cải thiện tốc độ tìm kiếm nhưng làm **duyệt tuần tự (in-order)** chậm đi (giờ lại miss cache). Vẫn còn kỹ thuật nghẽn ở Instruction Processing vì workload vốn **memory-bound**, nhưng search đã không còn ảnh hưởng critical path → dừng lại, chuyển sang tối ưu chỗ khác.

### 7. Recap
Hành trình tăng tốc: `Collection → Span` (CPU Profiler, ~4x) → phát hiện overhead generic chưa specialize (Processor Trace, thêm ~1.7x) → branchless + Eytzinger (Bottleneck Analysis, thêm ~2x + ~2x). **Tổng cộng ~25 lần nhanh hơn.**

Nguyên tắc thứ tự quan trọng: **xử lý overhead phần mềm trước** (để công cụ CPU không bị nhiễu bởi runtime overhead), **rồi mới** tối ưu bottleneck CPU. Luôn đo để xác nhận giả định và xây dựng trực giác về chi phí abstraction.

### 8. Next steps
- Viết **performance test** để đo lặp lại được với Instruments.
- Xem: "Improve memory usage and performance with Swift" (312), "Explore Swift performance" (WWDC24), "Analyze hangs with Instruments" (WWDC23), "Visualize and optimize Swift concurrency" (WWDC22).
- Đọc **Apple Silicon CPU Optimization Guide** và doc "Analyzing CPU usage with Processor Trace".
- Đặt câu hỏi/góp ý trên Developer Forums.

---

Lần này transcript đầy đủ nên các con số và cơ chế đều lấy trực tiếp từ nội dung session. Muốn mình đào sâu điểm nào — ví dụ cơ chế conditional move, cách tái dựng mảng Eytzinger, hay khi nào nên dùng `@inlinable` vs specialize thủ công — cứ nói nhé.
