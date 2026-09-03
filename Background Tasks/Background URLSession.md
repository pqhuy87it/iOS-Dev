Ý chính đúng, nhưng có ba chỗ nếu nói y nguyên sẽ bị bắt ngay — và đều là những chỗ gây bug thật trong production.

## Sai 1: gộp "suspend/kill" thành một

Đây là chỗ nghiêm trọng nhất. Ba trạng thái, ba kết quả khác nhau:

| Trạng thái | Transfer | App được đánh thức? |
|---|---|---|
| **Suspended** (user bấm Home) | Tiếp tục | Có, resume trong background |
| **Terminated bởi hệ thống** (memory pressure / jetsam) | Tiếp tục | Có, **relaunch** trong background |
| **Force-quit bởi user** (vuốt App Switcher) | ❌ **iOS cancel hết** | ❌ Không relaunch |

Cái thứ ba là điểm mà rất nhiều người nói sai. Apple ghi rõ: nếu user force-quit, hệ thống **cancel toàn bộ background transfer** của session đó và **không** tự launch lại app. Bạn phải tự phát hiện và resume ở lần user mở app tiếp theo.

Nên nói "app bị kill thì hệ thống vẫn download tiếp" là đúng một nửa. Câu chính xác: **hệ thống kill thì tiếp tục, user kill thì không.** Đây cũng chính là cùng một nguyên tắc với silent push mà bạn vừa học — force-quit là tín hiệu "user không muốn app này chạy nữa", iOS tôn trọng nó tuyệt đối.

## Sai 2: "không giới hạn thời gian"

Đúng là **không có timer 30 giây** cho transfer. Nhưng có ba loại giới hạn khác, và mỗi cái đều đủ để làm app hỏng:

**`timeoutIntervalForResource`** — mặc định **7 ngày** cho background session (không phải vô hạn). Hết là task fail.

**Discretionary scheduling.** Task tạo khi app đang ở background thì **tự động là discretionary**, bất kể bạn set gì. Hệ thống sẽ chờ WiFi + đang sạc + máy rảnh mới chạy. Có thể trì hoãn *hàng giờ*. `isDiscretionary = false` chỉ có hiệu lực với task tạo lúc foreground. Đây là nguồn của bug "sao trên máy tôi download ngay mà máy tester để cả buổi không xong".

**Cửa sổ ~30 giây khi app được đánh thức.** Transfer thì không bị giới hạn, nhưng lúc iOS gọi `handleEventsForBackgroundURLSession` thì app **có rất ít thời gian** để xử lý và bắt buộc gọi `completionHandler`. Quên gọi → watchdog kill app. Nên mọi việc nặng (decode, ghi Core Data, transform ảnh) phải làm gọn hoặc lưu lại xử lý sau.

Nói cách khác: **giới hạn không nằm ở transfer, nó dịch sang chỗ khác.**

## Sai 3: "giao data"

Hệ thống không giao `Data`. Nó giao **một file URL tạm**, và bạn có đúng khoảng thời gian bên trong callback để copy nó đi:

```swift
func urlSession(_ session: URLSession,
                downloadTask: URLSessionDownloadTask,
                didFinishDownloadingTo location: URL) {
    // ⚠️ PHẢI move ngay, SYNCHRONOUSLY, trong chính callback này.
    // Return khỏi hàm là file bị xoá. Dispatch async ra queue khác = mất file.
    let dest = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(downloadTask.taskDescription ?? UUID().uuidString)
    try? FileManager.default.removeItem(at: dest)
    try? FileManager.default.moveItem(at: location, to: dest)
}
```

Và một hệ quả quan trọng: **background session không hỗ trợ completion handler block.** `downloadTask(with:completionHandler:)` sẽ throw exception. Bắt buộc dùng delegate — vì khi app bị relaunch thì block không còn tồn tại, chỉ có delegate được tái tạo.

## Flow đúng, đầy đủ

```swift
final class TransferManager: NSObject {
    static let shared = TransferManager()
    static let sessionID = "com.exchain.bg.transfer"

    var backgroundCompletionHandler: (() -> Void)?

    // Lazy + một identifier chỉ được có MỘT session instance.
    // Tạo lần thứ hai với cùng ID → crash.
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionID)
        config.isDiscretionary = false          // chỉ có tác dụng nếu tạo task ở foreground
        config.sessionSendsLaunchEvents = true  // cho phép iOS relaunch app
        config.timeoutIntervalForResource = 60 * 60 * 24  // 1 ngày thay vì 7
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    func download(_ url: URL, id: String) {
        let task = session.downloadTask(with: url)
        task.taskDescription = id   // định danh sống sót qua relaunch
        task.resume()
    }
}
```

AppDelegate — **bắt buộc** có, kể cả app SwiftUI (dùng `@UIApplicationDelegateAdaptor`):

```swift
func application(_ application: UIApplication,
                 handleEventsForBackgroundURLSession identifier: String,
                 completionHandler: @escaping () -> Void) {
    // Việc đầu tiên: chỉ giữ handler lại. Chưa gọi.
    TransferManager.shared.backgroundCompletionHandler = completionHandler
    // Việc thứ hai: touch `session` để tái tạo nó → delegate callback mới chảy về.
    TransferManager.shared.warmUp()
}
```

Thứ tự callback khi app được relaunch — đây là chỗ hay hỏi:

```
didFinishDownloadingTo          (từng task, move file ở đây)
   ↓
didCompleteWithError            (từng task, xử lý lỗi)
   ↓
urlSessionDidFinishEvents       (một lần, sau khi HẾT task)
   ↓
gọi completionHandler() trên MAIN THREAD
```

```swift
func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    DispatchQueue.main.async {
        // Bắt buộc main thread. Bắt buộc gọi. Nếu không → watchdog kill.
        self.backgroundCompletionHandler?()
        self.backgroundCompletionHandler = nil
    }
}
```

## Vài constraint nữa dễ bị đào

- **Upload phải từ file.** `uploadTask(with:from: Data)` không hoạt động trên background session — phải `uploadTask(with:fromFile:)`. Body ở trong memory thì không sống sót qua việc app bị terminate.
- **Chỉ HTTP/HTTPS.** Không có custom protocol.
- **Không can thiệp được vào redirect** — daemon tự follow, delegate không được hỏi.
- **Resume data** khi user tự cancel: `cancelByProducingResumeData` rồi `downloadTask(withResumeData:)`. Nhưng nó phụ thuộc server support `ETag` + `Range`; nếu ETag đổi thì resume data vô dụng.
- **Auth challenge sẽ đánh thức app** — nếu server trả 401 giữa transfer, daemon không tự xử lý được, nó phải wake app lên hỏi. Nên token hết hạn giữa một cái download 2GB là tình huống thật cần nghĩ tới.

## Bản viết lại

> **Background `URLSession` khác các cơ chế còn lại ở chỗ transfer không chạy trong process của app** — nó do daemon `nsurlsessiond` thực hiện. Nên khi app bị suspend hoặc bị *hệ thống* terminate, transfer vẫn tiếp tục, và iOS relaunch app trong background qua `handleEventsForBackgroundURLSession` để giao kết quả.
>
> **Hai giới hạn quan trọng.** Thứ nhất, nếu *user* force-quit thì iOS cancel hết transfer và không relaunch — app phải tự resume lần sau. Thứ hai, "không giới hạn thời gian" chỉ đúng với transfer; app lúc được đánh thức vẫn chỉ có ~30 giây và bắt buộc gọi `completionHandler`, không thì bị watchdog kill. Ngoài ra task tạo lúc app ở background luôn là discretionary — hệ thống chờ WiFi và sạc, có thể trì hoãn hàng giờ.
>
> **Về mặt implementation:** phải dùng delegate chứ không dùng completion block, vì block không sống sót qua relaunch. Và `didFinishDownloadingTo` giao một file tạm mà mình phải move đi synchronously ngay trong callback.

## Nối lại toàn bộ mạch

Bốn cơ chế bạn vừa đi qua, đặt cạnh nhau:

| | Ai chạy code | Sống qua force-quit? | Dùng cho |
|---|---|---|---|
| `beginBackgroundTask` | App | — (app đang chạy) | Đóng nốt việc dở, vài chục giây |
| Socket | App | Không (chết cả foreground) | Real-time khi app đang mở |
| Silent push / BGAppRefresh | App (được wake) | ❌ Không | Giảm độ cũ dữ liệu, cơ hội |
| Background `URLSession` | **Daemon** | ❌ Cancel | Transfer lớn, không cần app sống |
| Alert push + NSE | **Extension riêng** | ✅ **Có** | Việc gấp, tin cậy cao nhất |

Điểm xuyên suốt: **càng ít phụ thuộc vào process của app, càng tin cậy.** Và force-quit là ranh giới cứng mà chỉ NSE vượt qua được.
