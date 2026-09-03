# Icon sync demo — Silent Push + Background URLSession

## 1. Setup project

Tạo project SwiftUI mới, copy 5 file `.swift` vào. Xoá `ContentView.swift` và `<Tên>App.swift` mặc định.

### Signing & Capabilities
- **Push Notifications** — bật.
- **Background Modes** — bật `Remote notifications` và `Background fetch`.

`Background processing` chỉ cần khi bạn thêm `BGProcessingTask` (xem mục 6).

### Info.plist
Nếu test server local qua HTTP (không HTTPS), tạm thêm:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsLocalNetworking</key>
  <true/>
</dict>
```

Dùng `NSAllowsLocalNetworking` chứ đừng dùng `NSAllowsArbitraryLoads` — cái sau sẽ bị App Review hỏi.

## 2. Server giả để test

Tạo một thư mục, đặt `manifest.json` (xem file kèm) và vài file PNG, rồi:

```bash
python3 -m http.server 8000
```

Sửa `SyncConfig.manifestURL` trong `IconSyncService.swift` thành IP máy Mac của bạn:

```bash
ipconfig getifaddr en0
```

Máy iPhone và Mac phải cùng WiFi.

## 3. Payload silent push

```json
{
  "aps": {
    "content-available": 1
  },
  "sync": {
    "scope": "icons",
    "version": 3
  }
}
```

**Không** có `alert`, `sound`, `badge` — có là nó thành alert push và `content-available` bị bỏ qua.

Headers bắt buộc khi gửi qua APNs thật:

```
apns-push-type: background     ← thiếu là iOS 13+ drop thẳng
apns-priority: 5               ← để 10 kèm content-available thì APNs từ chối
apns-topic: <bundle id>
apns-expiration: 0
```

Gửi bằng `curl` (cần auth key `.p8`, team ID, key ID):

```bash
curl -v --http2 \
  -H "apns-push-type: background" \
  -H "apns-priority: 5" \
  -H "apns-topic: com.exchain.IconSyncDemo" \
  -H "authorization: bearer $JWT" \
  -d '{"aps":{"content-available":1},"sync":{"scope":"icons","version":3}}' \
  https://api.sandbox.push.apple.com/3/device/$DEVICE_TOKEN
```

Device token in ra trong log app khi launch.

## 4. Test nhanh trên Simulator

Không cần APNs. Tạo `payload.apns` rồi:

```bash
xcrun simctl push booted com.exchain.IconSyncDemo payload.apns
```

Lưu ý: Simulator **không** mô phỏng đúng việc suspend và discretionary scheduling. Nó chỉ dùng để verify code path của silent push có chạy không.

## 5. Kịch bản thực hành

Chạy trên **máy thật**, và sau khi build **bấm Stop trong Xcode** rồi mở app từ Home Screen. Debugger còn attach thì iOS không suspend app, bạn sẽ thấy kết quả sai.

| # | Làm gì | Kỳ vọng trong log |
|---|---|---|
| 1 | Bấm Sync ở foreground | Tải ngay, `didFinishEvents` không được gọi (app đang active) |
| 2 | Bấm Sync rồi lập tức bấm Home | Transfer tiếp tục, mở lại app thấy đã installed |
| 3 | Reset, gửi silent push khi app ở background | `silent push nhận được` → `newData` → có thể **chờ rất lâu** vì discretionary |
| 4 | Reset, gửi push, **force-quit app**, chờ | `🚫 user force-quit app → iOS huỷ transfer`. Mở lại app: `♻️ task mồ côi → enqueue lại` |
| 5 | Bật Low Data Mode, gửi push | Transfer không chạy (`allowsConstrainedNetworkAccess = false`) |
| 6 | Settings → tắt Background App Refresh, gửi push | Push không tới app |

Kịch bản 3 và 4 là hai bài học quan trọng nhất của demo này.

## 6. Khi dữ liệu lớn hơn icon

Với icon thì `installStaged()` chỉ là move file, làm luôn trong wake window ~30s được. Nếu bạn đổi sang merge database, phần install **không** được làm ở `urlSessionDidFinishEvents` nữa. Thay bằng:

```swift
func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    store.markPendingImport()            // chỉ ghi marker
    scheduleProcessing()                 // submit BGProcessingTask
    DispatchQueue.main.async {
        self.backgroundCompletionHandler?()
        self.backgroundCompletionHandler = nil
    }
}

private func scheduleProcessing() {
    let request = BGProcessingTaskRequest(identifier: "com.exchain.import")
    request.requiresNetworkConnectivity = false   // merge không cần mạng
    request.requiresExternalPower = true          // nặng → chờ sạc
    try? BGTaskScheduler.shared.submit(request)
}
```

Và handler phải merge theo batch có checkpoint, vì `expirationHandler` sẽ bắn:

```swift
BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.exchain.import", using: nil) { task in
    let op = ImportOperation()
    task.expirationHandler = { op.cancel() }
    op.completionBlock = {
        task.setTaskCompleted(success: !op.isCancelled)
        if op.hasRemainingWork { self.scheduleProcessing() }
    }
    queue.addOperation(op)
}
```

Nhớ khai `BGTaskSchedulerPermittedIdentifiers` trong Info.plist và register handler **trước khi** `didFinishLaunching` return.

Test không cần chờ — pause ở breakpoint rồi chạy trong LLDB:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.exchain.import"]
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.exchain.import"]
```

## 7. Bảy chỗ dễ sai, tóm lại

1. `sessionSendsLaunchEvents = true` — thiếu thì app không được relaunch.
2. **Không** dùng `downloadTask(with:completionHandler:)` trên background session — throw exception. Bắt buộc delegate.
3. Một identifier chỉ được **một** `URLSession` instance trong process. Tạo lần hai → crash.
4. `didFinishDownloadingTo` phải move file **synchronously**. Return khỏi hàm là file mất.
5. `didFinishDownloadingTo` **vẫn được gọi cho HTTP 404/500**. Không check status code = install trang HTML lỗi làm icon.
6. `backgroundCompletionHandler` phải gọi trên **main thread**, đúng một lần. Quên → watchdog kill.
7. `isExcludedFromBackup = true` cho thư mục tải về. Bỏ = rác trong iCloud backup của user.
