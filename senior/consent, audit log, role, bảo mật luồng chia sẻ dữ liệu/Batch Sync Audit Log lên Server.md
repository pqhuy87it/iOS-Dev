# Batch Sync Audit Log lên Server — Không ảnh hưởng UX

Đây là bài toán kinh điển: app cần gửi **lượng lớn dữ liệu nhỏ** (audit events) lên server liên tục, nhưng **tuyệt đối không được** làm giật UI, tốn pin, hay phình memory.

---

## 1. Tại sao không gửi từng event ngay lập tức?

Nếu mỗi audit event tạo 1 HTTP request:

```
User tap → audit log → HTTP request    ← 1 request
User scroll → audit log → HTTP request ← 1 request  
User view → audit log → HTTP request   ← 1 request
// Trong 10 giây có thể phát sinh 20-50 events
```

Hậu quả:

- **Network overhead**: Mỗi request có HTTP header ~200-500 bytes, TLS handshake, TCP overhead. Gửi 50 event nhỏ = 50 lần overhead đó — cực kỳ lãng phí.
- **Battery drain**: Radio cellular mỗi lần bật lên tốn năng lượng đáng kể. iOS có cơ chế giữ radio active ~10-30s sau mỗi request (radio tail energy). 50 request liên tục = radio không bao giờ được nghỉ.
- **Thread contention**: Nhiều request đồng thời tranh chấp thread pool của URLSession, có thể delay các API call quan trọng (fetch data, load image…).
- **Server load**: Backend nhận hàng triệu user × 50 request/10s = DDoS chính mình.

→ Giải pháp: **gom lại (batch), xếp hàng (queue), gửi đợt (sync)**.

---

## 2. Kiến trúc tổng thể

```
┌─────────────────────────────────────────────────────────┐
│                    APP RUNTIME                           │
│                                                         │
│  User Action ──▶ AuditLogger.log()                      │
│                       │                                  │
│                       ▼                                  │
│              ┌─────────────────┐                         │
│              │  Serial Queue   │  ← DispatchQueue        │
│              │  (background)   │    .utility QoS          │
│              └────────┬────────┘                         │
│                       │                                  │
│                       ▼                                  │
│              ┌─────────────────┐                         │
│              │  Local Buffer   │  ← Encrypted file/DB    │
│              │  (persist)      │    Survive app kill      │
│              └────────┬────────┘                         │
│                       │                                  │
│              ┌────────┴────────┐                         │
│              │  Flush Trigger  │                          │
│              │  • Timer 30s    │                          │
│              │  • Buffer ≥ 50  │                          │
│              │  • App → BG     │                          │
│              └────────┬────────┘                         │
│                       │                                  │
│                       ▼                                  │
│              ┌─────────────────┐                         │
│              │  Batch Upload   │  ← 1 HTTP request       │
│              │  (URLSession    │    cho 50 events         │
│              │   background)   │                          │
│              └─────────────────┘                         │
└─────────────────────────────────────────────────────────┘
```

---

## 3. Triển khai chi tiết

### 3.1. Serial Queue — Cổng vào duy nhất

```swift
final class AuditSyncEngine {
    // MARK: - Serial queue đảm bảo thread-safe, không blocking main
    private let queue = DispatchQueue(
        label: "com.app.audit.sync",
        qos: .utility   // ← Ưu tiên thấp hơn .userInitiated
    )

    private var buffer: [AuditEvent] = []
    private let maxBufferSize = 50
    private let flushInterval: TimeInterval = 30
    private var flushTimer: DispatchSourceTimer?

    // MARK: - Entry point — gọi từ bất kỳ thread nào
    func enqueue(_ event: AuditEvent) {
        queue.async { [weak self] in
            guard let self else { return }
            self.buffer.append(event)
            self.persistBuffer()  // Lưu disk phòng app crash

            if self.buffer.count >= self.maxBufferSize {
                self.flush()      // Buffer đầy → gửi ngay
            }
        }
    }
}
```

**Tại sao Serial Queue + `.utility` QoS?**

- **Serial**: Mọi write vào buffer đều tuần tự → không cần lock, không race condition. Đây là pattern an toàn nhất cho shared mutable state.
- **`.utility` QoS**: iOS scheduler hiểu rằng công việc này "quan trọng nhưng không gấp". Khi main thread đang bận render animation, hệ thống sẽ tự động **giảm CPU time** cho queue này. Khi main thread rảnh, queue này mới được chạy nhiều hơn.

QoS hierarchy để hiểu rõ:

```
.userInteractive  ← UI animation, touch handling    (KHÔNG dùng cho audit)
.userInitiated    ← User đang chờ kết quả           (KHÔNG dùng cho audit)
.default          ← Mặc định
.utility          ← Long-running, user biết nhưng không chờ  ✅ AUDIT LOG
.background       ← User không biết, làm khi nào cũng được
```

`.utility` là sweet spot: đủ ưu tiên để không bị đói (starved) quá lâu, nhưng đủ thấp để nhường CPU cho UI.

---

### 3.2. Local Buffer — Persist để chống mất dữ liệu

```swift
extension AuditSyncEngine {
    private let fileURL: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("audit_buffer.enc")
    }()

    /// Lưu buffer xuống disk — phòng trường hợp app bị kill
    private func persistBuffer() {
        // Chỉ persist khi buffer thay đổi đáng kể (mỗi 10 events)
        // để giảm disk I/O
        guard buffer.count % 10 == 0 else { return }

        do {
            let data = try JSONEncoder().encode(buffer)
            let encrypted = try CryptoKit.seal(data)
            try encrypted.write(to: fileURL, options: .atomic)
            // .atomic: ghi vào temp file trước, rename sau
            // → không bao giờ có file corrupt nửa chừng
        } catch {
            // Disk full? → Giữ in-memory, retry sau
            os_log(.error, "Audit persist failed: %{public}@", error.localizedDescription)
        }
    }

    /// Khi app launch, khôi phục buffer chưa gửi
    func recoverUnsentEvents() {
        queue.async { [weak self] in
            guard let self,
                  let encrypted = try? Data(contentsOf: self.fileURL),
                  let data = try? CryptoKit.open(encrypted),
                  let events = try? JSONDecoder().decode([AuditEvent].self, from: data)
            else { return }

            self.buffer.insert(contentsOf: events, at: 0)
            self.flush()  // Gửi ngay những event từ session trước
        }
    }
}
```

**Tại sao cần persist?**

- User force-quit app, iOS kill app vì low memory, crash → buffer trong RAM mất hết.
- Audit log là **bằng chứng pháp lý** — mất event = mất compliance.
- Khi app launch lại → `recoverUnsentEvents()` khôi phục và gửi tiếp.

---

### 3.3. Flush Triggers — Khi nào thì gửi?

```swift
extension AuditSyncEngine {

    func startFlushTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + flushInterval,
                       repeating: flushInterval,
                       leeway: .seconds(5))   // ← Cho phép iOS gộp timer
        timer.setEventHandler { [weak self] in
            self?.flush()
        }
        timer.resume()
        self.flushTimer = timer
    }

    /// Gọi khi app sắp vào background
    func flushBeforeBackground() {
        queue.async { [weak self] in
            self?.flush()
        }
    }
}
```

Ba trigger chính:

| Trigger | Điều kiện | Lý do |
|---|---|---|
| **Buffer đầy** | `count >= 50` | Không để buffer phình vô hạn trong RAM |
| **Timer** | Mỗi 30 giây | Đảm bảo event không "ngồi" quá lâu |
| **App → Background** | `sceneDidEnterBackground` | Cơ hội cuối trước khi app bị suspend/kill |

**Chi tiết quan trọng — `leeway`:**

```swift
timer.schedule(..., leeway: .seconds(5))
```

`leeway` cho phép iOS **gộp (coalesce) timer** của app mình với timer của app khác. Thay vì mỗi app đánh thức CPU riêng, iOS đánh thức 1 lần cho nhiều app → **tiết kiệm pin đáng kể**. Với audit log — chậm 5 giây hoàn toàn chấp nhận được.

---

### 3.4. Batch Upload — Gộp nhiều event thành 1 request

```swift
extension AuditSyncEngine {

    private func flush() {
        // Đã trên serial queue rồi, không cần sync thêm
        guard !buffer.isEmpty else { return }

        let batch = Array(buffer.prefix(maxBufferSize))
        let batchID = UUID().uuidString

        // Tạo compressed payload
        let payload = AuditBatchPayload(
            batchID: batchID,
            events: batch,
            deviceID: DeviceInfo.id,
            appVersion: Bundle.main.appVersion,
            timestamp: Date()
        )

        guard let jsonData = try? JSONEncoder().encode(payload),
              let compressed = try? jsonData.compressed(using: .zlib)
        else { return }

        // Upload qua background URLSession
        uploadInBackground(compressed, batchID: batchID)

        // Xoá batch khỏi buffer (optimistic)
        buffer.removeFirst(min(batch.count, buffer.count))
        persistBuffer()
    }
}
```

**Tại sao compress?**

Audit events là JSON, rất repetitive (cùng field names, cùng userID…). `zlib` compress thường đạt **60-80% reduction**. 50 events × ~500 bytes = 25KB → sau compress ~5-8KB. Giảm bandwidth = giảm thời gian radio active = giảm pin.

---

### 3.5. Background URLSession — Gửi ngay cả khi app bị suspend

```swift
extension AuditSyncEngine {

    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.app.audit.upload"
        )
        config.isDiscretionary = false       // Gửi ngay, không đợi WiFi
        config.sessionSendsLaunchEvents = true  // Đánh thức app khi xong
        config.shouldUseExtendedBackgroundIdleMode = true
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private func uploadInBackground(_ data: Data, batchID: String) {
        // Background session yêu cầu upload từ FILE, không từ Data
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit_\(batchID).bin")

        do {
            try data.write(to: tempURL)
        } catch { return }

        var request = URLRequest(url: APIEndpoints.auditBatch)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(batchID, forHTTPHeaderField: "X-Batch-ID")

        let task = backgroundSession.uploadTask(with: request, fromFile: tempURL)
        task.taskDescription = batchID   // Để mapping lại khi callback
        task.resume()
    }
}
```

**Tại sao `URLSessionConfiguration.background`?**

Đây là điểm **then chốt** mà nhiều dev bỏ qua:

- **Regular URLSession**: App vào background → iOS suspend app sau ~5-10s → request bị cancel.
- **Background URLSession**: iOS **tách request ra khỏi process của app**. Upload được thực hiện bởi hệ thống (nsd daemon). Ngay cả khi app bị kill, upload vẫn tiếp tục. Khi xong, iOS đánh thức app qua `application(_:handleEventsForBackgroundURLSession:completionHandler:)`.

```swift
// AppDelegate
func application(_ application: UIApplication,
                 handleEventsForBackgroundURLSession identifier: String,
                 completionHandler: @escaping () -> Void) {
    AuditSyncEngine.shared.backgroundCompletionHandler = completionHandler
}

// URLSessionDelegate
extension AuditSyncEngine: URLSessionDelegate {
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
```

---

### 3.6. Retry với Exponential Backoff

```swift
extension AuditSyncEngine: URLSessionTaskDelegate {

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {

        guard let batchID = task.taskDescription else { return }

        if let error = error {
            let retryCount = retryTracker[batchID, default: 0]
            guard retryCount < 5 else {
                // Đã retry 5 lần → lưu vào dead letter queue
                moveToDeadLetterQueue(batchID: batchID)
                return
            }

            // Exponential backoff: 2s, 4s, 8s, 16s, 32s
            let delay = pow(2.0, Double(retryCount))
            // Thêm jitter để tránh thundering herd
            let jitter = Double.random(in: 0...1)

            queue.asyncAfter(deadline: .now() + delay + jitter) { [weak self] in
                self?.retryTracker[batchID] = retryCount + 1
                self?.retryBatch(batchID: batchID)
            }
        } else {
            // Thành công → cleanup
            retryTracker.removeValue(forKey: batchID)
            cleanupTempFile(batchID: batchID)
        }
    }
}
```

**Tại sao exponential backoff + jitter?**

- Nếu server down, hàng triệu device retry cùng lúc → **thundering herd** → server càng chết.
- Exponential backoff: mỗi lần retry cách xa hơn → giảm load.
- Jitter (random thêm 0-1s): phân tán thời điểm retry giữa các device → tránh đồng loạt.

---

## 4. Đo lường & Giám sát

Một senior cần biết hệ thống audit sync **có đang hoạt động tốt không**:

```swift
extension AuditSyncEngine {
    struct Metrics {
        var totalEnqueued: Int = 0
        var totalSynced: Int = 0
        var totalFailed: Int = 0
        var averageFlushSize: Double = 0
        var averageUploadLatency: TimeInterval = 0
        var currentBufferSize: Int = 0
        var oldestUnsentEvent: Date?

        var dropRate: Double {
            guard totalEnqueued > 0 else { return 0 }
            return Double(totalFailed) / Double(totalEnqueued)
        }
    }

    // Gửi metrics này về analytics dashboard
    // Alert nếu: dropRate > 5%, oldestUnsentEvent > 1 giờ,
    // currentBufferSize liên tục tăng
}
```

---

## 5. Tóm tắt — Checklist Senior

| Yếu tố | Giải pháp | Lý do |
|---|---|---|
| **Thread safety** | Serial DispatchQueue | Không lock, không race condition |
| **Không block UI** | `.utility` QoS | iOS tự nhường CPU cho main thread |
| **Giảm network** | Batch 50 events/request + zlib compress | Ít request = ít radio = ít pin |
| **Chống mất data** | Persist buffer encrypted trên disk | App crash/kill → khôi phục được |
| **Gửi khi background** | Background URLSession | OS-level upload, sống sót qua app suspend |
| **Timer hiệu quả** | DispatchSourceTimer + leeway | Cho iOS gộp timer, tiết kiệm pin |
| **Retry thông minh** | Exponential backoff + jitter | Tránh thundering herd khi server recover |
| **Observability** | Metrics + drop rate alert | Biết hệ thống có healthy không |

Tư duy cốt lõi: audit log là **critical nhưng không urgent** — user không bao giờ "chờ" audit log gửi xong. Nên toàn bộ thiết kế xoay quanh nguyên tắc **"làm đúng, làm đủ, nhưng đừng bao giờ làm phiền user"**.
