# BinarySearchLab

Hands-on companion to WWDC25 session 308 — *Optimize CPU performance with Instruments*.
Năm phiên bản binary search, đi từ generic `Collection` chậm đến bản Eytzinger, để bạn
tự đo và profile bằng Instruments.

## Yêu cầu
- **Xcode 16.3+** (Processor Trace cần Instruments 16.3+).
- Toolchain **Swift 6.2** (cho `Span`).
- Để dùng **Processor Trace**: Mac/iPad Pro **M4+** hoặc iPhone **A18+**. Các công cụ
  còn lại (CPU Profiler, CPU Counters) chạy trên Apple silicon nói chung.

## Chạy nhanh (terminal, không cần Xcode)
```bash
cd BinarySearchLab
swift run -c release bench
```
In ra bảng ops/s và mức speedup so với bản Collection.

## Chạy test (correctness + benchmark)
```bash
swift test -c release
```

## Workflow profiling bằng Instruments (đúng lộ trình session)

Mở package trong Xcode: `File ▸ Open ▸ Package.swift`.

### Bước 1 — CPU Profiler (Collection vs Span)
1. Test navigator → chuột phải `throughput_1_collection` → **Profile**.
2. Chọn template **CPU Profiler**, Recorder settings → **Deferred**, Record.
3. Trong track **Points of Interest** tìm vùng signpost "Collection", chuột phải →
   **Set Inspection Range**.
4. Click track process → xem **call tree**. Giữ **Option** + click chevron để expand;
   **Focus on Subtree** vào hàm search. Bạn sẽ thấy protocol witness của `Collection`,
   allocation, và check Objective-C của `Array`.
5. Lặp lại với `throughput_2_span` — nhanh ~4x, call tree gọn hơn hẳn.

### Bước 2 — Processor Trace (chỉ M4/A18)
1. Bật tracing: macOS → *Privacy & Security ▸ Developer Tools*; iOS → *Settings ▸ Developer*.
2. Profile `processorTrace_span` (chỉ 10 vòng → trace nhỏ). Template **Processor Trace**.
3. Regions of Interest → chuột phải interval "ProcessorTrace" → **Set Inspection Range and Zoom**.
4. Chuột phải cột **Start Thread** → **Pin Thread in Timeline** để hiện flame graph.
   Màu: nâu = system framework, hồng = Swift runtime/stdlib, xanh = code của bạn.
5. Xem bảng **Function Calls**, sort theo **cycles**: overhead thật là generic
   `Comparable` chưa specialize (không inline được phép so sánh) — không phải bounds check.
6. So sánh với `throughput_3_int` (đã specialize thủ công cho `Int`) — nhanh thêm ~1.7x.

### Bước 3 — CPU Counters / Bottleneck analysis
1. Profile `throughput_3_int`. Template **CPU Counters** → mode **CPU Bottlenecks**.
2. Pin thread, hover lane bottleneck. Thấy **Discarded** cao → làm theo gợi ý
   **Suggested Next Mode** → **Discarded Sampling**.
3. **Instruction Samples** → mở **Source Viewer**: dòng so sánh `needle`/`middleValue`
   bị **branch misprediction** (nhánh gần như ngẫu nhiên).
4. Chạy `throughput_4_branchless` — vòng lặp không rẽ control flow (conditional move,
   `&+`). Quay lại **CPU Bottlenecks**: giờ nghẽn ở **Instruction Processing**.
5. Mode **Instruction Processing** → gợi ý **L1D Cache Miss Sampling**: binary search
   nhảy xa trong bộ nhớ → cache miss liên tục.
6. Chạy `throughput_5_eytzinger`: mảng xếp lại theo breadth-first (các bước đầu cùng
   cache line) → nhanh thêm ~2x. Tổng cộng ~25x so với bản đầu.

## Gợi ý thực hành thêm
- Đổi `sizeInBytes` trong `SearchData` (thử `8 << 20` như session) và quan sát Eytzinger
  cải thiện rõ hơn khi mảng vượt xa dung lượng cache.
- Thử thêm `@inlinable` cho một hàm và tách nó sang target riêng để thấy specialization
  qua module boundary (liên quan đến access control / Swift Package bạn đang tìm hiểu).
- Bỏ `-Ounchecked` và so sánh: bounds check + overflow check ảnh hưởng thế nào.
