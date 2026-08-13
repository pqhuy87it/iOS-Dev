## What steps do you take to identify and resolve battery life issues?

### Suggested approach: This is something so many developers don’t ever think about, so use this as your chance to shine: talk about optimizing drawing, batching network requests, and minimizing work when the user isn’t interacting with the app.
Keep in mind that the battery settings app on iOS automatically shows which apps use the most battery life for a user, so having poor battery performance is very visible.

---

## Câu hỏi này thực sự test cái gì?

Đề bài đã nói thẳng một nửa: **hầu hết dev không bao giờ nghĩ tới battery**. Nên câu này không phải để loại người, mà để **tìm người hiếm**. Nếu bạn trả lời có hệ thống, khoảng cách giữa bạn và ứng viên trung bình sẽ rất rõ.

Nửa còn lại — cái mà đề bài gợi ý ở đoạn cuối — quan trọng hơn: **battery là loại bug duy nhất mà user thấy được tên app của bạn viết ra trắng đen**. Settings → Battery liệt kê từng app kèm % và tách rõ "Screen On" / "Background". Không có crash log, không có stack trace, không có gì để bạn debug — chỉ có một dòng chữ trong Settings và một review 1 sao viết "app này ngốn pin kinh khủng". Đây là bug **không tự báo cáo nhưng lại rất công khai**.

Interviewer muốn thấy bạn hiểu điều đó, và có quy trình đo → quy trách nhiệm → sửa → kiểm chứng.

## Mô hình tư duy — nói cái này trước mọi thứ khác

Đây là phần khiến câu trả lời của bạn khác hẳn số đông. Đa số người nghĩ "tốn pin = tốn CPU". Sai, hoặc ít nhất là không đủ.

**Năng lượng = diện tích dưới đường cong công suất theo thời gian.** Và điều quyết định diện tích đó không phải bạn dùng bao nhiêu CPU, mà là **bạn đánh thức các subsystem phần cứng bao nhiêu lần và giữ chúng tỉnh bao lâu**.

Hai hệ quả cực kỳ quan trọng:

**1. Tail energy (năng lượng đuôi).** Khi radio cellular truyền xong một request, nó **không tắt ngay** — nó ở lại trạng thái công suất cao thêm vài giây (RRC connected state) phòng khi có gói tiếp theo. Nghĩa là:

> 10 request nhỏ rải rác trong 1 phút tốn pin **gấp nhiều lần** 10 request gộp lại gửi cùng lúc — dù tổng số byte y hệt nhau.

Đây là lý do "batching network requests" trong gợi ý của đề bài lại quan trọng đến vậy. Nó không phải để tiết kiệm băng thông, mà để tránh trả phí đánh thức radio 10 lần.

**2. "Race to sleep".** Làm việc thật nhanh rồi để CPU ngủ sâu tiết kiệm hơn là làm chậm rãi liên tục. Chia nhỏ công việc thành 100 mẩu rải đều khiến CPU không bao giờ vào được deep idle state — tệ hơn nhiều so với chạy hết trong một burst rồi im lặng.

Câu chốt để nói ra:

> "Tôi không tối ưu pin bằng cách làm ít việc đi, mà bằng cách làm ít lần đánh thức phần cứng hơn. Chi phí lớn nhất thường nằm ở overhead của việc bật radio, GPS hay CPU lên — không phải ở bản thân công việc."

## Quy trình 4 bước để trình bày

### Bước 1 — Đo, và đo cho đúng điều kiện

Nói ngay điều kiện đo, vì đây là chỗ 90% người làm sai:

- **Không đo trên Simulator.** Simulator không có energy model, chạy trên CPU của Mac. Số liệu vô nghĩa.
- **Không đo khi cắm dây.** Máy đang sạc thì hành vi thermal, radio, và scheduler đều khác. Dùng **wireless debugging** hoặc chạy Instruments rồi ngắt kết nối, thu data sau.
- **Không đo Debug build.** Không optimization, có assertion, có logging — sai lệch nặng.

Bộ công cụ, từ nhẹ tới nặng:

| Công cụ | Dùng khi nào |
|---|---|
| **Energy Impact gauge** (Debug Navigator) | Nhìn nhanh khi đang dev — tách CPU / Network / Location / GPU / Background / **Overhead** |
| **Instruments — Energy Log** | Đo trên device thật, untethered |
| **Instruments — Time Profiler / Network / Location Energy Model** | Đào sâu từng subsystem |
| **Core Animation / Animation Hitches / Metal System Trace** | Vấn đề vẽ và GPU |
| **MetricKit** | Data từ **user thật ngoài production** |
| **Xcode Organizer → Metrics** | Xu hướng theo từng app version — phát hiện regression |
| **Settings → Battery trên device** | Nhìn đúng thứ user nhìn thấy |

Chi tiết đáng ghi điểm: trong Energy gauge, mục **"Overhead"** chính là chi phí đánh thức phần cứng. Nếu Overhead cao mà CPU thấp — đó là dấu hiệu kinh điển của tail energy, tức bạn đang gọi network/location quá vụn.

**MetricKit là con bài mạnh nhất ở câu này**, vì rất ít ứng viên nhắc tới. Nói cụ thể vài metric:

- `MXCPUMetric` — thời gian CPU tích luỹ, gồm cả background
- `MXLocationActivityMetric` — bao nhiêu thời gian ở mỗi mức accuracy
- `MXNetworkTransferMetric` — tách cellular/WiFi, upload/download
- `MXDisplayMetric` — average pixel luminance
- `MXCellularConditionMetric` — user ở vùng sóng yếu bao nhiêu (sóng yếu = radio phải phát mạnh hơn = tốn pin hơn nhiều)
- `MXAnimationMetric` — scroll hitch rate

Lý do phải nhấn mạnh field data: **vấn đề pin gần như không reproduce được trên bàn làm việc**. Bạn ngồi trong văn phòng WiFi mạnh, máy cắm sạc, dùng app 3 phút. User thì đi ngoài đường sóng yếu, app chạy background 8 tiếng. Hai thế giới khác nhau hoàn toàn.

### Bước 2 — Quy trách nhiệm về đúng subsystem

Đây là phần kỹ thuật chính. Bốn nguồn ngốn pin, xếp theo mức độ thường gặp:

**A. Network — thủ phạm số một**

| Vấn đề | Cách sửa |
|---|---|
| Polling định kỳ | Thay bằng **silent push notification** làm trigger |
| Request vụn rải rác | **Coalesce/batch**, gộp analytics event thành lô |
| Retry bằng timer | `waitsForConnectivity = true` để hệ thống đánh thức khi có mạng |
| Tải thứ không gấp | `isDiscretionary = true` + background `URLSessionConfiguration` → hệ thống tự chọn lúc sạc + WiFi |
| Tải lại data đã có | HTTP caching, `ETag`, `URLCache` |
| Không phân biệt mạng | `allowsExpensiveNetworkAccess`, `allowsConstrainedNetworkAccess` (Low Data Mode), `NWPathMonitor` |

Điểm tinh tế: `isDiscretionary` là công cụ mạnh nhất mà ít người dùng. Bạn giao quyền quyết định *khi nào* cho hệ thống — nó biết lúc nào máy đang sạc, đang trên WiFi, đang mát. Không có cách nào bạn tự đoán tốt hơn iOS.

**B. Location — thủ phạm số hai, nhưng khi sai thì sai thảm nhất**

GPS chip là một trong những thứ tốn điện nhất trên máy. Các lỗi kinh điển:

- **Không bao giờ gọi `stopUpdatingLocation()`.** Đây là bug phổ biến nhất trong toàn bộ chủ đề này. App lấy vị trí một lần lúc mở, rồi để GPS chạy mãi mãi.
- **`desiredAccuracy = kCLLocationAccuracyBest`** cho mọi thứ. Nếu bạn chỉ cần biết user ở thành phố nào, `kCLLocationAccuracyThreeKilometers` là đủ và rẻ hơn hàng chục lần — vì nó dùng cell tower/WiFi thay vì bật GPS.
- Không set `distanceFilter`.
- Bật `allowsBackgroundLocationUpdates` khi không thực sự cần.

Các API rẻ hơn nên biết tên: **significant location change monitoring**, **region monitoring (geofencing)**, **visit monitoring**, và `requestLocation()` cho nhu cầu một lần. Tất cả đều dựa trên hạ tầng cell/WiFi, rẻ hơn GPS liên tục rất nhiều. Kèm `pausesLocationUpdatesAutomatically = true`.

**C. CPU / background work**

- Timer chạy tiếp khi app đã background hoặc view đã biến mất — quan sát `scenePhase` và **dừng** mọi thứ.
- **Timer coalescing**: set `tolerance` cho `Timer`, `leeway` cho `DispatchSourceTimer`. Cho phép hệ thống gom nhiều wake-up của nhiều app vào cùng một thời điểm thay vì đánh thức CPU liên tục. Rẻ, dễ, hiệu quả — và gần như không ai làm.
- **QoS đúng**: gán `.background`/`.utility` cho việc không gấp để scheduler đưa xuống efficiency core và gom lại. Gán `.userInitiated` cho mọi thứ là vô hiệu hoá toàn bộ cơ chế này.
- **`BGTaskScheduler`**: `BGProcessingTask` với `requiresExternalPower = true` và `requiresNetworkConnectivity` — bạn khai báo *điều kiện*, hệ thống chọn *thời điểm*. Đây là mô hình đúng cho mọi việc nặng không gấp.
- Không làm việc nặng trong `didFinishLaunching` (vừa tốn pin vừa dính watchdog).

**D. Graphics / display**

- **`CADisplayLink` không `invalidate()`** — ép redraw 60/120fps vĩnh viễn. Sát thủ thầm lặng.
- Animation vẫn chạy khi view off-screen hoặc app ở background.
- **Overdraw và offscreen rendering** — bật Debug → Color Blended Layers / Color Offscreen-Rendered. Dùng `shadowPath` thay vì để hệ thống tự tính shadow (tránh hẳn một offscreen pass).
- **ProMotion**: `CADisplayLink.preferredFrameRateRange` — đừng đòi 120Hz cho animation mà 30 là đủ. Adaptive refresh tiết kiệm thật.
- Với SwiftUI: `body` bị re-evaluate quá nhiều do identity không ổn định hoặc `@Published` bắn thừa. Dùng `Self._printChanges()` và Instruments SwiftUI template để soi.

**E. Đừng quên: third-party SDK**

Rất nhiều vụ ngốn pin thực ra đến từ SDK analytics/ads/attribution — chúng poll, chúng xin location, chúng gửi event lẻ liên tục. Nói được ý "tôi audit cả SDK bên thứ ba, không chỉ code của mình" cho thấy bạn từng xử lý vấn đề này thật.

### Bước 3 — Tôn trọng trạng thái nguồn của máy

Đây là phần rất ít người nhắc, và nó thể hiện tư duy sản phẩm chứ không chỉ kỹ thuật:

```swift
// Low Power Mode
ProcessInfo.processInfo.isLowPowerModeEnabled
// + observe .NSProcessInfoPowerStateDidChange

// Thermal state
ProcessInfo.processInfo.thermalState  // .nominal / .fair / .serious / .critical
```

Khi Low Power Mode bật hoặc máy nóng lên, app tử tế sẽ tự giảm tải: tắt auto-play video, ngừng prefetch, hạ frame rate animation, giãn chu kỳ refresh, dừng background sync.

> "Low Power Mode là user đang nói với hệ thống rằng họ cần pin hơn cần tính năng. Nếu app tôi phớt lờ tín hiệu đó, tôi đang tự đặt mình lên đầu danh sách trong Settings → Battery."

### Bước 4 — Chống regression

Sửa xong không phải là xong, vì pin rất dễ hỏng lại ở PR tiếp theo mà không ai biết. Đây là chỗ bạn ghép được nền tảng CI/CD của mình vào:

- **XCTest performance metrics** trong CI: `XCTCPUMetric`, `XCTStorageMetric`, `XCTMemoryMetric`, `XCTOSSignpostMetric` với `measure(metrics:)` — đặt baseline, fail build khi vượt ngưỡng.
- Theo dõi **Xcode Organizer → Metrics** theo từng version sau release để phát hiện regression ngoài thực địa.
- Dùng **signpost** (`OSSignposter`) đánh dấu các đoạn nghi ngờ để đọc được trong Instruments và trong `MXSignpostMetric`.

## Cách gói lại thành một câu chuyện

Nên chuẩn bị sẵn một case thật theo 4 nhịp: **triệu chứng → manh mối → nguyên nhân gốc → phòng ngừa**. Khung ví dụ:

> "Có lần app bọn tôi bị report ngốn pin dù CPU usage rất thấp. Energy gauge cho thấy Overhead cao bất thường trong khi CPU gần như bằng 0 — dấu hiệu của tail energy. Đào ra thì mỗi analytics event được gửi thành một request riêng, có lúc 30-40 request trong vài phút dùng app. Fix là gom event vào buffer, flush theo lô mỗi 30 giây hoặc khi đủ N event, và chuyển sang background session với `isDiscretionary` cho các event không gấp. Sau đó tôi thêm một signpost quanh network layer và một CI check trên số lượng request per session để không ai vô tình phá lại."

## Bẫy cần tránh

- **Đừng chỉ nói về CPU.** Network và location thường mới là thủ phạm chính. Trả lời chỉ xoay quanh "tối ưu thuật toán" là lộ ngay chưa từng đo thật.
- **Đừng nói đo trên Simulator** hoặc đo khi cắm sạc.
- **Đừng quên bước dừng.** Rất nhiều bug pin không phải "làm gì đó tốn", mà là "quên tắt cái gì đó": `stopUpdatingLocation`, `invalidate()` timer/displaylink, huỷ observer, dừng Bluetooth scan, dừng `CMMotionManager`.
- **Đừng tối ưu mù.** Câu đầu tiên luôn phải là "tôi đo trước". Nếu bạn nhảy thẳng vào giải pháp mà không nói đo, interviewer sẽ nghĩ bạn đoán.
- **Đừng bỏ qua góc nhìn user.** Nhắc tới việc Settings → Battery công khai tên app, và việc đó ảnh hưởng tới review và retention — cho thấy bạn hiểu vì sao vấn đề này đáng quan tâm chứ không chỉ biết cách sửa.

## Câu hỏi đào sâu có thể theo sau

1. **"Vì sao gộp request lại tiết kiệm pin, dù tổng byte không đổi?"** → Tail energy của radio. Câu này chính là bài test xem bạn hiểu thật hay học thuộc.
2. **"App của bạn cần theo dõi vị trí user cả ngày, làm sao đỡ tốn pin?"** → Significant location change hoặc region monitoring thay vì continuous GPS; hạ `desiredAccuracy`; `pausesLocationUpdatesAutomatically`; chỉ nâng accuracy lên khi thật sự cần trong khoảng thời gian ngắn.
3. **"Làm sao biết app tốn pin khi bạn không reproduce được?"** → MetricKit + Xcode Organizer Metrics; so sánh theo version để tìm regression.
4. **"Background refresh có tốn pin không?"** → Có, nhưng `BGTaskScheduler` cho hệ thống quyền chọn thời điểm tối ưu. Vấn đề không phải làm việc ở background, mà là *tự quyết định thời điểm* thay vì để hệ thống quyết.
