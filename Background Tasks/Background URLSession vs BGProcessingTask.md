cho tôi hỏi thêm  Background URLSession và BGProcessingTask cái nào sẽ tốt cho việc lấy data lớn

---

Câu hỏi này giả định hai cái thay thế nhau, nhưng thực ra chúng ở **hai tầng khác nhau** và câu trả lời đúng là dùng cả hai.

- **Background `URLSession`** = tầng **vận chuyển**. Network I/O, chạy trong daemon `nsurlsessiond`, không phải process của bạn.
- **`BGProcessingTask`** = tầng **xử lý**. Code của *bạn* chạy trong process của *bạn*, có nhiều thời gian hơn `BGAppRefreshTask`, nhưng vẫn có giới hạn.

| | Background `URLSession` | `BGProcessingTask` |
|---|---|---|
| Ai chạy | Daemon hệ thống | Process app của bạn |
| Giới hạn thời gian | Không (transfer), 7 ngày resource timeout | Có — vài phút, Apple không công bố số |
| Sống qua app bị terminate | ✅ Có | ❌ Không, app phải được launch |
| Chạy được code tuỳ ý | ❌ Chỉ HTTP transfer | ✅ Bất cứ gì |
| Điều kiện chạy | Discretionary nếu tạo ở background | Máy rảnh, tuỳ chọn yêu cầu đang sạc |

## Vì sao `BGProcessingTask` một mình là sai cho việc tải data lớn

Đây là lập luận cốt lõi.

Nếu bạn download bên trong `BGProcessingTask` bằng `URLSession` thường, thì **transfer bị buộc vào vòng đời của task**. `expirationHandler` bắn → task bị huỷ → download đang ở 80% cũng chết → lần sau tải lại từ đầu. Với file 500MB trên mạng di động, bạn sẽ không bao giờ hoàn thành, chỉ đốt data của user vòng vòng.

Tệ hơn: `BGProcessingTask` **không sống qua việc app bị terminate**. Trong khi background `URLSession` thì daemon vẫn tải tiếp kể cả app bị jetsam do memory pressure.

Nên: **việc gì là network transfer thì đưa cho daemon.** Đó là lý do duy nhất background `URLSession` tồn tại.

Có một điểm dễ nhầm: `BGProcessingTaskRequest` có cờ `requiresNetworkConnectivity = true`. Nó chỉ nói "đừng chạy task nếu không có mạng" — **không** kéo dài thời gian cho transfer. Đừng đọc nó thành "được phép làm việc mạng dài".

## Vậy `BGProcessingTask` để làm gì

Làm chính xác những gì daemon **không** làm được — và với data lớn, phần này thường tốn thời gian hơn cả download:

- Giải nén archive
- Merge/import vào Core Data hoặc SQLite (chỗ này thực sự tốn thời gian)
- Reindex, build full-text search index
- Generate thumbnail, transcode
- Verify checksum, migration schema
- Dọn dẹp file cũ

`BGAppRefreshTask` với ~30 giây không đủ cho mấy việc này. Đó là khoảng trống mà `BGProcessingTask` lấp.

## Pipeline đúng

```
Silent push / foreground / BGAppRefresh
        ↓  fetch manifest (nhẹ, JSON)
Background URLSession (daemon)
        ↓  didFinishDownloadingTo → move file + ghi marker "pending"
        ↓  submit BGProcessingTaskRequest
BGProcessingTask (process của app)
        ↓  giải nén, merge, index — có checkpoint
Dữ liệu dùng được
```

Điểm quan trọng: `handleEventsForBackgroundURLSession` chỉ có ~30 giây, nên **đừng merge ở đó**. Chỉ move file, ghi marker, submit `BGProcessingTask`, rồi gọi `completionHandler`.

```swift
func urlSession(_ session: URLSession,
                downloadTask: URLSessionDownloadTask,
                didFinishDownloadingTo location: URL) {
    let dest = stagingURL(for: downloadTask.taskDescription)
    try? FileManager.default.moveItem(at: location, to: dest)   // synchronous, ngay tại đây
    store.markPendingImport(dest)
    scheduleProcessing()                                        // không merge ở đây
}

private func scheduleProcessing() {
    let request = BGProcessingTaskRequest(identifier: "com.exchain.import")
    request.requiresNetworkConnectivity = false   // merge không cần mạng
    request.requiresExternalPower = true          // merge nặng → chờ sạc
    try? BGTaskScheduler.shared.submit(request)
}
```

Handler bắt buộc phải **resumable**, vì `expirationHandler` sẽ bắn:

```swift
BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.exchain.import",
                                using: nil) { task in
    let op = ImportOperation()   // merge theo batch, ghi checkpoint sau mỗi batch

    task.expirationHandler = {
        op.cancel()              // dừng ở batch hiện tại, checkpoint đã lưu
    }

    op.completionBlock = {
        task.setTaskCompleted(success: !op.isCancelled)
        if op.hasRemainingWork { self.scheduleProcessing() }   // chia nhiều lần
    }

    queue.addOperation(op)
}
```

Nguyên tắc: **merge theo batch có checkpoint**, mỗi batch commit độc lập. Bị cắt giữa đường thì lần sau tiếp tục, không làm lại. Đây cùng một tư duy với `beginBackgroundTask` mà bạn đã làm ở demo đầu.

## Mấy chỗ dễ sai về `BGTaskScheduler`

- **Register handler trước khi `didFinishLaunching` return.** Muộn hơn → crash. Điều này nghĩa là bạn phải register *mọi* identifier ở mọi lần launch, kể cả khi không dùng.
- **Khai `BGTaskSchedulerPermittedIdentifiers` trong Info.plist**, và bật background mode `processing`.
- **Mỗi identifier chỉ có một pending request.** Submit lần hai là thay thế, không phải xếp hàng.
- **`requiresExternalPower = true` làm nó rất khó nổ.** Với data lớn thì đáng, nhưng phải có đường foreground fallback, không thì user không sạc qua đêm là không bao giờ có data.
- **Test bằng LLDB**, đừng chờ: `_simulateLaunchForTaskWithIdentifier:` và `_simulateExpirationForTaskWithIdentifier:`.

## Câu trả lời gọn nếu bị hỏi

> "Hai cái không thay thế nhau. Background `URLSession` là transport — transfer chạy trong `nsurlsessiond` nên không bị giới hạn thời gian và sống qua cả việc app bị hệ thống terminate. `BGProcessingTask` là compute — code của em chạy trong process của em với vài phút, dùng để giải nén, merge vào database, reindex, những thứ mà 30 giây của `BGAppRefreshTask` không đủ.
>
> Nếu download bên trong `BGProcessingTask` thì transfer bị buộc vào vòng đời task, `expirationHandler` bắn là mất luôn phần đã tải. Nên em tách: daemon tải, `handleEventsForBackgroundURLSession` chỉ move file và ghi marker rồi submit processing task, còn merge thì làm theo batch có checkpoint trong `BGProcessingTask` để bị cắt lúc nào cũng resume được."

Và điều kiện cứng vẫn không đổi: **cả hai đều chết trước force-quit.** Nếu thiếu dữ liệu là app vô dụng — như app hướng dẫn thảm hoạ của bạn — thì đường chính vẫn phải là foreground với consent tường minh, còn hai cơ chế này là để *duy trì*, không phải để *đảm bảo*.
