# Outbox upload demo — `beginBackgroundTask`

## 1. Thời gian tối đa xin được là bao lâu?

**Apple không công bố con số, và cố tình không công bố.** Đừng hardcode.

Lịch sử thay đổi:

| iOS | Thời gian thực tế |
|---|---|
| iOS 6 và trước | 600s (10 phút) |
| iOS 7 – 12 | ~180s (3 phút) |
| iOS 13+ | thường ~30s |

Trên iOS gần đây, ~30 giây là con số hay gặp nhất, nhưng nó phụ thuộc:

- **Low Power Mode** — giảm mạnh, có thể bị từ chối hẳn (`beginBackgroundTask` trả `.invalid`)
- **Thermal state** — máy nóng thì cắt sớm
- **Mức độ user dùng app** — app dùng thường xuyên được ưu ái hơn
- **Áp lực bộ nhớ** trên máy

App này ghi lại grant thực tế mỗi lần bạn chạy, tích lũy qua nhiều lần, hiện ở card "Lịch sử background time đo được". Sau 5–10 lần thử ở các điều kiện khác nhau bạn sẽ có dữ liệu của chính mình — đáng giá hơn bất kỳ con số đọc được ở đâu.

### Cách nói đúng trong interview

> "Apple không cam kết con số. iOS 6 là 10 phút, iOS 7–12 khoảng 3 phút, iOS 13+ thực tế thường ~30 giây, nhưng nó thay đổi theo Low Power Mode, nhiệt độ và mức độ user dùng app. Em đọc `backgroundTimeRemaining` và thiết kế để có thể bị cắt bất cứ lúc nào, chứ không dựa vào một ngưỡng cố định."

### Ba điều về `backgroundTimeRemaining`

1. Ở **foreground** nó trả về `.greatestFiniteMagnitude` (một số khổng lồ), không phải giá trị thật. Chỉ có ý nghĩa khi app đang ở background.
2. Phải đọc trên **main thread**.
3. Giá trị iOS báo lúc đầu **không phải cam kết** — app này ghi cả "iOS báo Xs" và "thực tế được Ys" để bạn tự thấy chúng lệch nhau.

### Ngân sách KHÔNG gia hạn được

Đây là chỗ nhiều người tưởng có thể lách:

```swift
// ❌ KHÔNG hoạt động. Ngân sách là PER-APP, không phải per-task.
UIApplication.shared.endBackgroundTask(oldID)
let newID = UIApplication.shared.beginBackgroundTask { }   // remaining KHÔNG reset
```

Gọi `beginBackgroundTask` nhiều lần cũng không nhân thời gian lên. Ngân sách chỉ reset khi app **quay về foreground rồi xuống background lần nữa**.

Tự kiểm chứng: thêm nút này vào `ContentView` và xem log — `backgroundTimeRemaining` vẫn tiếp tục đếm xuống.

```swift
Button("Thử gia hạn") {
    let id = UIApplication.shared.beginBackgroundTask { }
    Logger.shared.log("task mới id=\(id.rawValue), còn \(readRemainingText())")
}
```

## 2. Setup

Tạo project SwiftUI mới, copy 5 file `.swift` vào, xoá `ContentView.swift` và `<Tên>App.swift` mặc định.

**Không cần** capability nào. `beginBackgroundTask` không đòi background mode — đây là điểm khác biệt so với `BGTaskScheduler` và silent push.

Nếu muốn test với server thật:

```bash
python3 mock_server.py --delay 1.5
ipconfig getifaddr en0        # lấy IP máy Mac
```

Sửa `serverURL` trong `SyncEngine.swift`, bật `useRealServer = true`, và thêm vào Info.plist:

```xml
<key>NSAppTransportSecurity</key>
<dict><key>NSAllowsLocalNetworking</key><true/></dict>
```

Không có server thì `MockUploader` chạy sẵn, đủ để đo background time.

## 3. ⚠️ Bắt buộc: tắt debugger

Build & Run → **bấm Stop trong Xcode** → mở app từ Home Screen.

Khi debugger còn attach, **iOS không suspend app**, `backgroundTimeRemaining` báo số vô nghĩa, và bạn sẽ kết luận sai hoàn toàn. Log được ghi ra file (`Documents/outbox.log`) chính là để bạn đọc lại mà không cần console.

## 4. Kịch bản thực hành

Menu ⋯ → **Seed 5000 record** trước.

| # | Latency | Làm gì | Kỳ vọng |
|---|---|---|---|
| 1 | 1.5s | Bấm Start, để ở foreground | Batch chạy liên tục, "còn ∞ (foreground)" |
| 2 | 1.5s | Start rồi vuốt về Home ngay, đợi 60s, mở lại | Log có `EXPIRATION` sau ~30s, batch dừng, phần chưa upload vẫn `synced = 0` |
| 3 | 8s | Start rồi về Home | Cancel bắn **giữa** một batch → `cancel giữa batch xxx — không commit` |
| 4 | 0.3s | Reset synced, Start rồi về Home | Nhiều batch xong trong background, có thể hết record trước khi hết giờ |
| 5 | 1.5s | Bật Low Power Mode rồi lặp lại #2 | Grant ngắn hơn rõ rệt, hoặc bị từ chối |
| 6 | 1.5s | Start rồi về Home, đợi expiration, **rồi force-quit** | Mở lại: `synced` giữ nguyên, tiếp tục từ đó, không mất và không trùng |

Kịch bản 3 là quan trọng nhất về mặt kiến trúc — xem mục 5.

Với server thật, kịch bản 3 còn cho bạn thấy dòng `DUPLICATE` trong log server: batch đó **đã tới nơi** rồi mới bị cancel, và app gửi lại, server dedup.

## 5. Xử lý cancel — thiết kế quan trọng nhất

Cancel trong Swift Concurrency là **cooperative**: `Task.cancel()` chỉ set một cờ. Không có gì bị giết. Vòng lặp phải tự kiểm tra.

`SyncEngine` kiểm ở hai chỗ:

```swift
while true {
    if Task.isCancelled { return }              // 1. trước khi lấy batch mới

    let batch = store.fetchUnsynced(limit: 100)
    do {
        try await uploader.upload(batch, ...)   // 2. Task.sleep / URLSession tự throw
    } catch is CancellationError {
        return                                   // KHÔNG mark synced
    }
    store.markSynced(ids: ...)                   // không có await ở giữa
}
```

Ba điểm cần hiểu:

**`Task.sleep` phản hồi cancel, `Thread.sleep` thì không.** Nếu bạn thay bằng `Thread.sleep` thì cancel vô tác dụng và app bị watchdog kill. Đây là lý do `MockUploader` dùng `Task.sleep`.

**DB chính là checkpoint.** Không cần lưu "đã tới batch thứ mấy" ở đâu. Record nào `synced = 0` thì lần sau tự động được lấy lại. Bị kill bất ngờ cũng không mất.

**Không được có `await` giữa upload thành công và `markSynced`.** Nếu chèn vào, bạn tạo một cửa sổ mà cancel có thể xảy ra sau khi server đã nhận nhưng trước khi DB được cập nhật → gửi lại vĩnh viễn. Vì cancellation cooperative chỉ xảy ra tại suspension point, không có `await` nghĩa là không có cửa sổ.

**Cancel giữa lúc request đang bay là mơ hồ.** Bạn không biết server đã nhận hay chưa. Lựa chọn ở đây: **không** mark synced → chấp nhận có thể gửi trùng → server dedup bằng `Idempotency-Key`. Tức là chọn *at-least-once + idempotent* thay vì *at-most-once*. Với telemetry/analytics thì gửi trùng vô hại còn mất dữ liệu thì có hại, nên đây là đánh đổi đúng.

## 6. Hai chỗ mình làm theo đúng yêu cầu của bài, nhưng production nên khác

**Thời điểm gọi `beginBackgroundTask`.** Bài yêu cầu gọi lúc app xuống background, nên `SyncEngine.handleDidEnterBackground()` làm đúng vậy. Nhưng production nên gọi **ngay khi công việc bắt đầu**, kể cả đang ở foreground:

```swift
func start() {
    beginBackgroundTask()      // ngay từ đây
    runLoop()
}
```

Lý do: giữa `willResignActive` và `didEnterBackground` có một khoảng ngắn, và trong vài tình huống (cuộc gọi đến, khoá máy) bạn có thể mất cơ hội gọi. Gọi sớm thì không có cửa sổ nào để mất.

**Upload dài thì đừng dùng `beginBackgroundTask`.** Với ~30 giây và 1.5s mỗi batch, bạn upload được khoảng 20 batch = 2000 record. Nếu outbox có 100.000 record thì cơ chế này không phải câu trả lời — dùng background `URLSession` (ghi batch ra file rồi `uploadTask(with:fromFile:)`, vì background session **không** hỗ trợ `uploadTask(with:from: Data)`).

Ranh giới: `beginBackgroundTask` để **đóng nốt việc dở**, không để **làm hết việc**.

## 7. Tóm bốn lỗi hay gặp

1. **Quên `endBackgroundTask`** → iOS terminate app, crash log `0x8badf00d`. Phải gọi trên **mọi** nhánh thoát.
2. **Làm việc async trong `expirationHandler`** → chỉ còn vài giây, `Task { }` có thể chưa kịp chạy. Đây là lý do `SyncEngine` không phải `@MainActor` và dùng `NSLock` — mọi thứ trong expiration handler đều đồng bộ.
3. **Dùng `Thread.sleep` hoặc vòng lặp không check `isCancelled`** → cancel vô nghĩa.
4. **Tin vào con số 30 giây** → thiết kế phải resumable, không phụ thuộc ngưỡng nào.
