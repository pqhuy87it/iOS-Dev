# DispatchSemaphore + `receive(on:)` + `subscribe(on:)` — Giải thích chi tiết

## 1. DispatchSemaphore — Cơ chế đợi/báo hiệu giữa các thread

### Bản chất

`DispatchSemaphore` là công cụ đồng bộ hoá **low-level** của GCD. Nó hoạt động như một **bộ đếm (counter)**:

```
signal() → counter + 1    (báo hiệu: "tôi xong rồi")
wait()   → counter - 1    (đợi: "tôi chờ ai đó signal")
           nếu counter < 0 → BLOCK thread cho đến khi counter >= 0
```

```swift
let semaphore = DispatchSemaphore(value: 0)
//                                       ↑ counter khởi tạo = 0
```

`value: 0` nghĩa là: **bất kỳ ai gọi `wait()` đều bị block ngay**, cho đến khi ai đó gọi `signal()`.

### Hình dung

```
Thread A (main):                Thread B (background):
─────────────────               ─────────────────────
                                async work đang chạy...
semaphore.wait()                     │
  │ counter: 0 → -1                  │
  │ -1 < 0 → BLOCK! 🛑               │
  │ (đứng yên tại đây)              │
  │                                  │ work xong!
  │                            semaphore.signal()
  │                              counter: -1 → 0
  │ ← UNBLOCK! ✅                    │
  │ counter >= 0, tiếp tục          │
  ▼                                  ▼
code tiếp theo...
```

---

## 2. Phân tích đoạn code — Phần 1: `receive(on:)`

### Setup

```swift
let firstStepDone = DispatchSemaphore(value: 0)
// counter = 0 → wait() sẽ block ngay

let publisher = PassthroughSubject<String, Never>()
let receivingQueue = DispatchQueue(label: "receiving-queue")
// ↑ Serial queue tuỳ chỉnh — value sẽ được nhận trên queue này
```

### Pipeline

```swift
let subscription = publisher
    .receive(on: receivingQueue)
    // ↑ Mọi value từ đây trở xuống sẽ được deliver trên receivingQueue
    .sink { value in
        print("Received value: \(value) on thread \(Thread.current)")
        if value == "Four" {
            firstStepDone.signal()
            // ↑ Khi nhận "Four" → signal semaphore → unblock main thread
        }
    }
```

### Gửi value từ background threads

```swift
for string in ["One", "Two", "Three", "Four"] {
    DispatchQueue.global().async {
        publisher.send(string)
        // ↑ Gửi từ global queue (concurrent, background)
        // Nhưng sink nhận trên receivingQueue (nhờ receive(on:))
    }
}
```

### Đợi trên main thread

```swift
firstStepDone.wait()
// ↑ Main thread BLOCK tại đây
// Đợi cho đến khi sink nhận "Four" → signal()
// Sau đó main thread tiếp tục → chạy phần 2
```

### Luồng thực thi chi tiết

```
Main Thread                 Global Queue              receivingQueue
───────────                 ────────────              ──────────────
tạo semaphore(0)
tạo publisher
tạo subscription
                           
for loop dispatch:
  async { send("One") }──▶ send("One")
  async { send("Two") }──▶ send("Two")
  async { send("Three") }──▶ send("Three")
  async { send("Four") }──▶ send("Four")
                               │
firstStepDone.wait()           │ receive(on:) chuyển
  │ counter: 0→-1              │ value sang receivingQueue
  │ BLOCK! 🛑                  ▼
  │                         ┌─────────────────────────────┐
  │                         │ sink: "One" on receivingQueue│
  │                         │ sink: "Two" on receivingQueue│
  │                         │ sink: "Three" ...            │
  │                         │ sink: "Four" → signal()! 📣  │
  │                         └─────────────────────────────┘
  │                                │
  │ ← UNBLOCK! ✅                  │ counter: -1→0
  ▼
print phần 2...
```

### Tại sao cần Semaphore ở đây?

Đây là code trong **Playground** hoặc **command-line tool**. Không có RunLoop giữ process sống. Nếu không có `wait()`:

```swift
// ❌ Không có semaphore
for string in ["One", "Two", "Three", "Four"] {
    DispatchQueue.global().async { publisher.send(string) }
}
// Main thread chạy đến đây → Playground kết thúc
// Async work CHƯA KỊP chạy → không thấy output nào!

// ✅ Có semaphore
firstStepDone.wait()
// Main thread ĐỨNG YÊN cho đến khi phần 1 xong
// Đảm bảo tất cả output của phần 1 xuất hiện
// Rồi mới tiếp tục phần 2
```

**Trong app thực tế (iOS app với RunLoop), thường KHÔNG cần semaphore** — RunLoop giữ app sống. Semaphore ở đây phục vụ mục đích **demo/playground**.

---

## 3. `receive(on:)` — Chuyển thread NHẬN value

### Bản chất

`receive(on:)` ảnh hưởng **downstream** — mọi operator và subscriber phía sau sẽ nhận value trên scheduler chỉ định.

```swift
publisher
    .receive(on: receivingQueue)
    .sink { value in
        // ← Closure này chạy trên receivingQueue
        // KHÔNG PHẢI trên thread mà publisher.send() được gọi
    }
```

### Minh hoạ thread chuyển đổi

```
publisher.send("One")          ← chạy trên Global Queue (thread 5)
         │
    receive(on: receivingQueue)
         │ ← CHUYỂN sang receivingQueue
         ▼
    sink { "One" }             ← chạy trên receivingQueue (thread 8)
```

**Không có `receive(on:)`:**

```swift
// Sink chạy trên CÙNG THREAD với publisher.send()
DispatchQueue.global().async {
    publisher.send("One")    // Global Queue thread 5
}
// sink { } ← cũng chạy trên Global Queue thread 5
```

### Ứng dụng phổ biến nhất: chuyển về Main Thread cho UI

```swift
URLSession.shared.dataTaskPublisher(for: url)   // background thread
    .map(\.data)                                 // background thread
    .decode(type: User.self, decoder: JSONDecoder()) // background thread
    .receive(on: DispatchQueue.main)             // ← CHUYỂN sang main
    .sink(receiveValue: { user in
        self.nameLabel.text = user.name          // ✅ Main thread, UI safe
    })
```

---

## 4. Phân tích đoạn code — Phần 2: `subscribe(on:)`

```swift
let subscription2 = [1, 2, 3, 4, 5].publisher
    .subscribe(on: DispatchQueue.global())
    // ↑ Subscription work (upstream) chạy trên global queue
    .handleEvents(receiveOutput: { value in
        print("Value \(value) emitted on thread \(Thread.current)")
        // ← Chạy trên global queue (ảnh hưởng bởi subscribe(on:))
    })
    .receive(on: receivingQueue)
    // ↑ Từ đây trở xuống chuyển sang receivingQueue
    .sink { value in
        print("Received value: \(value) on thread \(Thread.current)")
        // ← Chạy trên receivingQueue
    }
```

### Luồng thread

```
[1,2,3,4,5].publisher
       │
  subscribe(on: global())
       │ ← Upstream work chạy trên Global Queue
       ▼
  handleEvents { print("emitted on \(Thread.current)") }
       │ ← Global Queue (vẫn ảnh hưởng bởi subscribe(on:))
       │
  receive(on: receivingQueue)
       │ ← CHUYỂN sang receivingQueue
       ▼
  sink { print("received on \(Thread.current)") }
       │ ← receivingQueue
```

### Output dự kiến

```
Value 1 emitted on thread <NSThread: ...>{number = 3, name = (null)}   ← global queue
Value 2 emitted on thread <NSThread: ...>{number = 3, name = (null)}   ← global queue
Value 3 emitted on thread <NSThread: ...>{number = 3, name = (null)}   ← global queue
Value 4 emitted on thread <NSThread: ...>{number = 3, name = (null)}   ← global queue
Value 5 emitted on thread <NSThread: ...>{number = 3, name = (null)}   ← global queue
Received value: 1 on thread <NSThread: ...>{number = 4, name = (null)} ← receivingQueue
Received value: 2 on thread <NSThread: ...>{number = 4, name = (null)} ← receivingQueue
Received value: 3 on thread <NSThread: ...>{number = 4, name = (null)} ← receivingQueue
Received value: 4 on thread <NSThread: ...>{number = 4, name = (null)} ← receivingQueue
Received value: 5 on thread <NSThread: ...>{number = 4, name = (null)} ← receivingQueue
```

---

## 5. `subscribe(on:)` vs `receive(on:)` — So sánh chi tiết

```
subscribe(on:):  ảnh hưởng UPSTREAM — nơi publisher thực thi work
receive(on:):    ảnh hưởng DOWNSTREAM — nơi subscriber nhận value

                subscribe(on: global)          receive(on: main)
                       ↓                              ↓
Publisher ──── [emit trên global queue] ──── [deliver trên main queue] ──── Sink
              ← subscribe(on:) ảnh hưởng →  ← receive(on:) ảnh hưởng →
```

### Minh hoạ rõ hơn

```swift
somePublisher
    // ── Vùng UPSTREAM (ảnh hưởng bởi subscribe(on:)) ──
    .subscribe(on: DispatchQueue.global())
    .map { heavyTransform($0) }        // ← chạy trên global queue
    .filter { validate($0) }            // ← chạy trên global queue
    .handleEvents(receiveOutput: { _ in
        print(Thread.current)            // ← global queue
    })
    
    // ── Ranh giới ──
    .receive(on: DispatchQueue.main)
    
    // ── Vùng DOWNSTREAM (ảnh hưởng bởi receive(on:)) ──
    .map { formatForUI($0) }            // ← chạy trên main queue
    .sink { value in
        self.label.text = value          // ← main queue ✅
    }
```

### Bảng so sánh

```
                  subscribe(on:)                receive(on:)
                  ──────────────                ────────────
Ảnh hưởng         Upstream (publisher,          Downstream (sink,
                  operators phía trên)          operators phía dưới)

Đặt ở đâu?       Gần đầu pipeline              Gần cuối, trước sink
                  (ảnh hưởng toàn upstream)     (chuyển thread trước delivery)

Dùng khi?         Heavy work cần chạy           UI update cần main thread
                  trên background

Có thể nhiều?     Chỉ cái ĐẦU TIÊN có hiệu lực  Mỗi receive(on:) tạo
                  (downstream subscribe(on:)      ranh giới thread mới
                   bị override)

Phổ biến?         Ít dùng hơn                    RẤT phổ biến
                  (publisher thường tự chọn      (.receive(on: .main)
                   thread rồi)                    gần như mọi pipeline)
```

### Vị trí đặt trong pipeline

```swift
// ✅ Pattern chuẩn trong production
heavyPublisher
    .subscribe(on: DispatchQueue.global(qos: .userInitiated))
    // ↑ ĐẦU pipeline: work nặng trên background
    .map { transform($0) }
    .filter { validate($0) }
    .receive(on: DispatchQueue.main)
    // ↑ CUỐI pipeline: UI trên main
    .sink { value in updateUI(value) }
    .store(in: &cancellables)
```

---

## 6. DispatchSemaphore — Giải thích sâu

### Giá trị khởi tạo

```swift
// value: 0 → "cổng ĐÓNG"
// wait() ngay lập tức → block
// Cần signal() từ thread khác để mở
let gate = DispatchSemaphore(value: 0)

// value: 1 → "cổng MỞ cho 1 người"
// wait() đầu tiên → đi qua (counter 1→0)
// wait() thứ hai → block (counter 0→-1)
// Dùng như mutex/lock
let mutex = DispatchSemaphore(value: 1)

// value: 3 → "cổng cho tối đa 3 người đồng thời"
// 3 wait() đầu → đi qua
// wait() thứ 4 → block
// Dùng để giới hạn concurrent access
let pool = DispatchSemaphore(value: 3)
```

### Các pattern phổ biến

**Pattern 1: Đợi async work (đoạn code demo)**

```swift
let done = DispatchSemaphore(value: 0)

DispatchQueue.global().async {
    // async work...
    done.signal()    // báo xong
}

done.wait()    // main thread đợi
// ← tiếp tục sau khi work xong
```

**Pattern 2: Mutex (mutual exclusion)**

```swift
let mutex = DispatchSemaphore(value: 1)
var sharedResource = 0

// Thread A
mutex.wait()           // lock (counter: 1→0)
sharedResource += 1    // an toàn
mutex.signal()         // unlock (counter: 0→1)

// Thread B
mutex.wait()           // nếu A đang giữ → block cho đến khi A signal
sharedResource += 1
mutex.signal()
```

**Pattern 3: Giới hạn concurrent operations**

```swift
let maxConcurrent = DispatchSemaphore(value: 3)

for url in urls {
    DispatchQueue.global().async {
        maxConcurrent.wait()      // chờ slot trống (tối đa 3)
        downloadFile(url)
        maxConcurrent.signal()    // trả slot
    }
}
```

### ⚠️ Cảnh báo: KHÔNG BAO GIỜ wait() trên Main Thread trong app thực

```swift
// ❌ NGUY HIỂM trong iOS app
// Main thread bị block → UI đóng băng → watchdog kill app
DispatchQueue.main.async {
    semaphore.wait()    // 💀 App freeze
}

// ✅ Trong Playground/test → OK (không có UI)
// ✅ Trong app → dùng async/await hoặc completion handler thay thế
```

---

## 7. Tổng hợp — Luồng hoàn chỉnh của đoạn code

```
╔══════════════════════════════════════════════════════════════════╗
║ PHẦN 1: receive(on:)                                            ║
║                                                                  ║
║ Main         Global Queue          receivingQueue                ║
║ ─────        ────────────          ──────────────                ║
║ tạo pub                                                          ║
║ tạo sub      send("One")──────▶   sink("One") ✅                ║
║              send("Two")──────▶   sink("Two") ✅                ║
║              send("Three")────▶   sink("Three") ✅              ║
║              send("Four")─────▶   sink("Four") → signal()! 📣   ║
║ wait()🛑                                  │                      ║
║    │ ←──────── unblock ──────────────────┘                      ║
║    ▼                                                             ║
║                                                                  ║
║ PHẦN 2: subscribe(on:)                                          ║
║                                                                  ║
║ Main         Global Queue          receivingQueue                ║
║ ─────        ────────────          ──────────────                ║
║              [1,2,3,4,5].publisher                               ║
║              subscribe work ▲                                    ║
║              handleEvents:                                       ║
║              "emitted on global"                                 ║
║                    │                                             ║
║                    │ receive(on:)                                ║
║                    ▼                                             ║
║                                    sink: "received on receiving" ║
╚══════════════════════════════════════════════════════════════════╝

Vai trò DispatchSemaphore:
┌─────────────────────────────────────────────────────────┐
│ Đảm bảo PHẦN 1 hoàn thành trước khi PHẦN 2 bắt đầu    │
│ Playground không có RunLoop → cần semaphore giữ process │
│ Trong iOS app → KHÔNG cần, RunLoop giữ app sống         │
└─────────────────────────────────────────────────────────┘
```

---

## 8. Tóm tắt

| Concept | Vai trò trong đoạn code |
|---|---|
| `DispatchSemaphore(value: 0)` | Cổng đóng — `wait()` block main thread, `signal()` mở cổng khi nhận "Four" |
| `wait()` | Main thread đứng yên, đợi phần 1 xong rồi mới chạy phần 2 |
| `signal()` | Sink nhận "Four" → báo hiệu phần 1 xong → unblock main |
| `receive(on:)` | Chuyển **delivery** sang receivingQueue (downstream) |
| `subscribe(on:)` | Chuyển **subscription work** sang global queue (upstream) |
| Kết hợp | `subscribe(on:)` ở đầu pipeline (work nặng trên background) + `receive(on:)` ở cuối (deliver đúng thread) |

----

Đoạn code này demo hai concept: scheduling trong Combine + đồng bộ hoá bằng semaphore, Huy. Ba điểm cốt lõi:

**`DispatchSemaphore(value: 0)`** hoạt động như cánh cổng: `wait()` block main thread (counter 0 → -1 < 0 → block), `signal()` mở cổng (counter -1 → 0 → unblock). Trong đoạn code, mục đích là **đảm bảo phần 1 chạy xong trước khi phần 2 bắt đầu**. Vì đây là Playground — không có RunLoop giữ process sống, nếu không `wait()` thì main thread chạy hết → Playground kết thúc → async work chưa kịp chạy. **Trong iOS app thực tế, KHÔNG dùng pattern này** vì block main thread = UI đóng băng.

**`receive(on:)`** ảnh hưởng **downstream** — mọi thứ phía dưới nhận value trên queue chỉ định. Dù `publisher.send()` được gọi trên Global Queue, sink vẫn chạy trên `receivingQueue`. Pattern cực kỳ phổ biến: `.receive(on: DispatchQueue.main)` trước sink để UI update an toàn.

**`subscribe(on:)`** ảnh hưởng **upstream** — nơi publisher thực thi work. `[1,2,3,4,5].publisher` phát value trên Global Queue (nhờ `subscribe(on:)`), `handleEvents` cũng chạy trên Global Queue. Nhưng sau `receive(on: receivingQueue)`, sink nhận value trên receivingQueue. Hai operator bổ trợ nhau: `subscribe(on:)` đặt đầu pipeline cho heavy work trên background, `receive(on:)` đặt cuối pipeline chuyển về đúng thread cần thiết.
