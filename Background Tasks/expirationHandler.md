bạn rõ hơn ý này cho tôi:
Nếu bạn download bên trong `BGProcessingTask` bằng `URLSession` thường, thì transfer bị buộc vào vòng đời của task. `expirationHandler` bắn → task bị huỷ → download đang ở 80% cũng chết → lần sau tải lại từ đầu.

---

Chỗ này đáng làm rõ, vì cơ chế thật hơi khác cách mình diễn đạt lúc trước. Ý cốt lõi đúng, nhưng thứ giết download **không phải** `expirationHandler` — mà là việc app bị suspend ngay sau đó.## Hai đồng hồ độc lập

Đây là gốc rễ của vấn đề. Khi bạn download trong `BGProcessingTask`, có **hai bộ đếm chạy song song và không biết gì về nhau**:

- **Đồng hồ của `URLSession`** — `timeoutIntervalForRequest` (mặc định 60s, và là *idle* timeout, không phải tổng thời gian). Miễn còn byte chảy về thì nó không bao giờ hết.
- **Đồng hồ của `BGProcessingTask`** — Apple **không công bố** con số. Thực tế vài phút, nhưng hệ thống có thể cắt sớm vì nhiệt độ, pin, hoặc user vừa mở app khác.

Download của bạn có thể đang **hoàn toàn khoẻ mạnh**, tốc độ tốt, không lỗi gì — và vẫn bị cắt. Vì đồng hồ thứ hai thắng. Và bạn không thể "đo kích thước file cho vừa cửa sổ", vì cửa sổ không có kích thước xác định.

## Chuỗi sự kiện chính xác

`expirationHandler` không tự tay huỷ `URLSessionDataTask` của bạn. Nó chỉ là **cảnh báo**. Đây là thứ thực sự diễn ra:

1. Hệ thống quyết định thu hồi → gọi `expirationHandler`
2. Bạn có **vài giây** để dọn dẹp và gọi `setTaskCompleted(success:)`
3. Ngay khi `setTaskCompleted` được gọi, **iOS suspend app** — và đây là nhát dao thật: `URLSession` thường chạy trong process của bạn, process đóng băng thì mọi socket đóng băng theo
4. App bị suspend đó sau đó thường bị **terminate** khi hệ thống cần bộ nhớ → process biến mất, connection bị tear down, `URLSessionDownloadTask` object không còn, file tạm mất reference

Nếu bạn **không** gọi `setTaskCompleted`: watchdog kill app ngay ở bước 2, và hệ thống còn ghi nhận app này "cư xử tệ" → giảm ưu tiên lập lịch lần sau. Tệ hơn cả mất download.

## Nguyên tắc cốt lõi: ai giữ file partial

Đây là câu một dòng để nhớ:

> Bytes đã tải nằm ở đâu thì nó sống theo cái đó.

`URLSession` thường: CFNetwork trong **process của bạn** giữ file tạm. Process chết → mất.

Background session: **`nsurlsessiond`** giữ file tạm và cả state của connection. Process của bạn chết → daemon không quan tâm, vẫn tải tiếp. Đến khi xong nó mới đánh thức app lên và giao file.

Đó là lý do duy nhất background session tồn tại. Nó không "nhanh hơn" hay "được ưu tiên hơn" — nó chỉ **đặt tiến trình ra ngoài vòng đời process của bạn**.

## Chỗ mình nói chưa chính xác lúc trước

"Lần sau tải lại từ đầu" — không phải định luật, mà là **kết cục thực tế**. Về lý thuyết bạn có đường thoát:

```swift
task.cancelByProducingResumeData { data in
    // lưu `data` ra đĩa để lần sau dùng downloadTask(withResumeData:)
}
```

Nhưng nó không đáng tin trong ngữ cảnh này, vì ba lý do cộng lại:

- Callback là **async**, mà bạn đang ở trong cửa sổ vài giây và phải gọi `setTaskCompleted` ngay. Bạn đang chạy đua với chính deadline của mình.
- Resume data phải được **ghi ra đĩa** trước khi process chết. Thêm một I/O nữa vào cuộc đua.
- Nó phụ thuộc server hỗ trợ `Range` + `ETag` ổn định. ETag đổi → resume data thành rác.

Nên phát biểu chính xác hơn: *"có cơ chế resume, nhưng bạn phải thắng một cuộc đua vài giây để dùng được nó, và nó còn phụ thuộc server. Không nên xây kiến trúc dựa trên đó."*

Trong khi background session làm resume **miễn phí và mặc định** — daemon giữ partial file, không có cuộc đua nào cả.

## Pattern đúng: trigger, không phải container

`BGProcessingTask` **vẫn dùng được** với download — chỉ là nó phải là *nơi bấm nút*, không phải *nơi chứa*:

```swift
BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.exchain.sync", using: nil) { task in
    Task {
        let manifest = try? await self.fetchManifest()      // nhỏ, vài KB, an toàn
        for entry in manifest?.items ?? [] {
            self.backgroundSession.downloadTask(with: entry.url).resume()
        }
        task.setTaskCompleted(success: true)                 // return ngay
        // Task kết thúc, app suspend — transfer KHÔNG quan tâm, nó ở trong daemon.
    }
}
```

`setTaskCompleted` gọi xong, app suspend, và transfer vẫn chạy. Vì nó chưa bao giờ ở trong process của bạn.

Lưu ý một hệ quả: task enqueue lúc app ở background thì **luôn là discretionary** — hệ thống chờ WiFi + sạc + máy rảnh. Bạn tránh được cái bẫy mất tiến trình, nhưng vẫn không tránh được cái bẫy trì hoãn.

## Khi nào `URLSession` thường trong `BGProcessingTask` lại ổn

Đừng đọc thành "cấm gọi mạng trong `BGProcessingTask`". Nó ổn khi request **nhỏ và nhanh chết cũng không sao**:

- Fetch manifest, config, feature flag — vài KB, xong trong vài trăm ms
- Gọi API report telemetry
- Kiểm tra version

Tiêu chí phân loại: **nếu request này bị cắt giữa đường, có mất tiến trình gì đáng giá không?** Manifest 4KB thì không — lần sau fetch lại mất 200ms. File 500MB đứt ở 80% thì có — bạn vừa đốt 400MB data của user, hai lần.

Đó cũng là lý do trong demo icon sync, mình fetch manifest bằng `URLSession.shared` nhưng tải icon bằng background session. Cùng một hàm, hai loại transport, phân chia theo đúng tiêu chí đó.
