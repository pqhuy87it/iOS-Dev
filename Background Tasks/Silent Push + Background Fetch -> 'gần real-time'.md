tôi đang đọc về Silent Push + Background Fetch Khi cần refresh "gần real-time", làm rõ quan điểm này với tư cách là 1 senior ios developer

----

Ngắn gọn trước: **cả hai đều không phải cơ chế near real-time, và không nên được thiết kế như vậy.** Nếu bạn nói trong interview rằng "cần refresh gần real-time thì dùng Silent Push + Background Fetch", interviewer giỏi sẽ đào ngay vào đó. Đây là lý do.

## Silent push thực chất là gì

Nó là một **hint best-effort**, không phải delivery guarantee. Danh sách điều kiện khiến nó *không* đến — và bạn nên thuộc lòng:

- **User force-quit app** (vuốt trong App Switcher) → iOS không wake app nữa cho tới khi user tự mở lại. Alert push vẫn hiện, silent push thì mất.
- **User tắt Background App Refresh** trong Settings → tắt luôn khả năng silent push đánh thức app. Đây là chỗ hay bị bỏ sót: nó ảnh hưởng cả hai cơ chế bạn đang hỏi.
- **Low Power Mode** → dừng hẳn.
- **Budget/throttling.** Hệ thống cấp ngân sách theo mức độ user dùng app, khoảng vài lần/giờ. Gửi 50 cái, có thể chỉ vài cái được xử lý.
- **Device offline** → APNs coalesce, chỉ giữ bản mới nhất, và background push thường bị drop chứ không store.

Cộng thêm các yêu cầu bắt buộc mà nếu sai thì im lặng không đến: header `apns-push-type: background` (bắt buộc từ iOS 13), `apns-priority: 5` (priority 10 kèm `content-available` sẽ bị APNs từ chối), payload không có `alert`/`sound`/`badge`.

Và callback là `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` trên `UIApplicationDelegate` — **không** đi qua `UNUserNotificationCenterDelegate`. Bạn có ~30s, và phải trả về `UIBackgroundFetchResult` **trung thực**, vì hệ thống dùng chính tín hiệu đó để điều chỉnh budget cho lần sau. Cứ trả `.newData` khi thực ra không có gì mới là tự bóp ngân sách của mình.

## Background Fetch thực chất là gì

`BGAppRefreshTask` (thay cho `performFetchWithCompletionHandler` đã deprecated từ iOS 13) là **opportunistic**, không phải scheduled. `earliestBeginDate` là "không sớm hơn lúc này", không phải "vào lúc này". Hệ thống dùng model on-device học thói quen dùng app để quyết định — thực tế thường vài giờ một lần, có app cả ngày không nổ lần nào. Runtime khoảng 30s.

Nói cách khác: nó dùng để **làm ấm cache trước khi user mở app**, không phải để giữ dữ liệu tươi liên tục.

| | Độ trễ thực tế | Đảm bảo | Vai trò đúng |
|---|---|---|---|
| WebSocket/SSE (foreground) | ms – s | Cao | Real-time thật |
| Alert push + NSE | s | Cao | Việc gấp, user cần biết ngay |
| Silent push | s – ∞ | Thấp | Cache invalidation cơ hội |
| BGAppRefresh | phút – giờ | Rất thấp | Warm cache trước khi mở app |

## Vậy "gần real-time" đạt bằng gì

Câu trả lời senior là: **phân tầng theo trạng thái app**, chứ không có một cơ chế duy nhất.

- **Foreground** — đây là nơi real-time thực sự sống. WebSocket / SSE / long-poll. Không có gì thay thế được.
- **Đang chuyển sang background** — `beginBackgroundTask` để đóng nốt sync đang dở (như case chúng ta vừa làm).
- **Background, server chủ động** — silent push cho các invalidation giá trị cao, server phải **coalesce và rate-limit** (dùng `apns-collapse-id`, `apns-expiration`) vì budget hữu hạn.
- **Background, cơ hội** — `BGAppRefreshTask` warm cache. Nhớ `submit` request mới ngay đầu handler, và luôn set `expirationHandler`.
- **Thông tin gấp, user phải biết** — **alert push có `mutable-content: 1` + Notification Service Extension**. Đây là điểm quan trọng: NSE chạy trong process riêng do hệ thống launch, nên nó **vẫn chạy kể cả khi app đã bị force-quit**. Về độ tin cậy nó vượt xa silent push. Đổi lại: ~24MB memory, 30s, có thể bị skip khi máy yếu → nội dung push phải dùng được ngay cả khi NSE không chạy, và phải xử lý `serviceExtensionTimeWillExpire`.
- **Transfer lớn** — background `URLSession`.

## Mental model đúng

> Thiết kế sao cho **kiến trúc vẫn đúng nếu 100% silent push bị drop.**

Cụ thể: server giữ **sync token / cursor**, client làm **delta sync** mỗi khi có cơ hội — app open, silent push, BGAppRefresh, pull-to-refresh. Silent push chỉ *dịch thời điểm "tươi" sớm lên*, không phải điều kiện cần.

Hệ quả thực hành: **đừng nhét data vào silent push và coi nó là nguồn sự thật**. Payload chỉ nên là tín hiệu:

```json
{
  "aps": { "content-available": 1 },
  "sync": { "since": "2026-08-13T04:12:00Z", "scope": "orders" }
}
```

Client nhận tín hiệu → tự gọi API delta. Push bị mất một cái cũng không tạo lỗ hổng dữ liệu, vì lần sync sau vẫn kéo từ cursor cũ.

Cái này khớp thẳng với offline-first mà bạn đã dựng: cache là nguồn hiển thị, mọi cơ chế background chỉ là các cơ hội để rút ngắn khoảng cách giữa cache và server.

## Đo lường

Chỗ này thường tạo khác biệt trong interview. Đừng nói "gần real-time" chung chung — định nghĩa **staleness SLO**: *"P95 độ cũ của dữ liệu tại thời điểm user mở app < 60s"*. Rồi instrument nó (log `now - serverUpdatedAt` khi render lần đầu). Có số đo thì mới biết silent push có đáng để duy trì hạ tầng hay không — nhiều team giữ nó vì niềm tin chứ chưa từng đo tỉ lệ delivery thực tế.

## Test

Silent push và BGTask rất khó test, nên biết mấy cái này sẽ ghi điểm:

```bash
xcrun simctl push <device> <bundle-id> payload.apns
```

Với `BGTaskScheduler`, pause ở breakpoint rồi chạy trong LLDB:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.you.refresh"]
```

và `_simulateExpirationForTaskWithIdentifier:` để kiểm tra nhánh hết giờ. Ngoài ra Console.app lọc theo `dasd` sẽ cho thấy hệ thống ra quyết định lập lịch như thế nào — rất hữu ích khi debug "sao task không bao giờ chạy".

---

**Câu chốt nếu bị hỏi thẳng:** "Silent push và Background Fetch là cơ chế *cơ hội*, không có SLA. Tôi dùng chúng để giảm độ cũ dữ liệu, không dùng để đảm bảo độ tươi. Yêu cầu real-time thật thì phải nằm ở foreground bằng WebSocket, còn thông tin gấp mà user cần biết ngay thì phải là alert push — vì nếu nó đủ quan trọng để cần trong vài giây, nó đủ quan trọng để hiện ra cho user thấy."
