tôi có thể dùng Silent Push + Background URLSession để đồng bộ dữ liệu data lớn từ server xuống ví dụ như: database, image, video không

----

Được — và đây chính xác là cặp được Apple thiết kế để đi cùng nhau. Silent push làm **tín hiệu**, background `URLSession` làm **đường ống**. Silent push handler chỉ cần tạo task rồi return `.newData` ngay; transfer sống trong daemon nên bạn không cần dùng đến 30 giây đó.

Nhưng có bốn thứ sẽ làm bạn đau nếu không biết trước.

## Bẫy lớn nhất: task tạo ở background luôn là discretionary

Đây là chỗ then chốt và nó đánh đúng vào chính combo bạn đang hỏi.

Task tạo khi app **đang ở background** — mà silent push thì app luôn ở background — được iOS coi là **discretionary bất kể bạn set `isDiscretionary = false`**. Hệ thống sẽ chờ WiFi + đang sạc + máy rảnh. Trì hoãn **hàng giờ** là bình thường.

Nên kỳ vọng đúng là: *"silent push khởi động một transfer sẽ hoàn thành lúc nào đó trong vài giờ tới"*, không phải *"push xong là có data"*.

Cộng thêm ngân sách silent push (vài lần/giờ, tuỳ mức user dùng app) và force-quit thì mất cả push lẫn transfer — bạn có một cơ chế **cơ hội chồng cơ hội**.

## Tách theo loại dữ liệu, vì câu trả lời khác nhau

**Database / structured data** — fit tốt, nhưng nhớ background session giao **file**, không giao `Data`. Nên server cần một endpoint trả về file delta (NDJSON, protobuf, sqlite patch) chứ không phải JSON response thường.

Vấn đề thật nằm ở bước **apply**, không phải download. Khi app được wake, bạn có ~30 giây. Merge 100MB records vào Core Data trong đó là không thực tế. Cách đúng: download xong thì chỉ **move file + ghi một marker "có pending delta"**, rồi merge ở lần foreground tiếp theo hoặc trong `BGProcessingTask`. Đừng cố làm hết trong wake window.

**Images** — thường là hướng sai nếu chỉ để "app nhanh hơn". Prefetch toàn bộ ảnh tốn dung lượng và data của user để đổi lấy chút latency. Dùng on-demand + `URLCache`/Nuke/Kingfisher là đủ. Chỉ prefetch khi app **buộc phải chạy offline** — mà app hướng dẫn thảm hoạ của bạn đúng là ca đó, nên với bạn thì hợp lý.

Nếu prefetch: **đừng tạo 500 download task.** Daemon xử lý được, nhưng discretionary scheduling với 500 task nhỏ thì tệ hơn hẳn một task lớn. Bảo server đóng thành một archive, tải một lần, giải nén sau.

**Video** — được, nhưng **đừng dùng background `URLSession` thô nếu là HLS.** Dùng `AVAssetDownloadURLSession` (và `AVAggregateAssetDownloadTask` cho nhiều variant). Nó *được xây trên* background session nhưng thêm: xử lý master/media playlist, FairPlay persistent key, và quan trọng là tích hợp với storage management của hệ thống — user thấy và xoá được trong Settings, iOS biết đây là purgeable-with-consent. Tải mp4 thẳng thì background session thường là ổn.

## Storage — chỗ dễ bị App Review đánh

Ba quyết định phải làm rõ ngay từ đầu:

- **Caches có thể bị iOS xoá bất cứ lúc nào** khi thiếu dung lượng. Nội dung sync mà app cần để chạy offline thì **không** để ở Caches.
- Để ở Documents hoặc Application Support, và **bắt buộc** set `isExcludedFromBackup = true`. Không set → nội dung tải về bị đẩy lên iCloud backup của user. Vài GB rác trong backup là lý do bị review hỏi và bị user 1 sao.

```swift
var url = destinationURL
var values = URLResourceValues()
values.isExcludedFromBackup = true
try url.setResourceValues(values)
```

- **Xử lý hết dung lượng.** `NSFileWriteOutOfSpaceError` là lỗi thật, không phải edge case, đặc biệt với video.

## Network policy — không được bỏ

```swift
config.allowsCellularAccess = userPrefersCellular
config.allowsExpensiveNetworkAccess = false      // 4G/5G, hotspot
config.allowsConstrainedNetworkAccess = false    // Low Data Mode
```

`allowsConstrainedNetworkAccess = false` là **tôn trọng Low Data Mode** của user. Bỏ qua nó là cách nhanh nhất để bị uninstall. Với video, cho user một toggle "Chỉ tải qua WiFi" và mặc định là bật.

## Kiến trúc mình sẽ dùng

Điểm cốt lõi: **silent push không phải trigger duy nhất.** Nó chỉ là một trong bốn cửa vào cùng một hàm sync.

```swift
enum SyncTrigger { case appForeground, silentPush, bgProcessing, manual }

func requestSync(_ trigger: SyncTrigger) async {
    let cursor = store.lastSyncCursor
    let manifest = try await api.fetchManifest(since: cursor)   // nhẹ, JSON
    for item in manifest.items where !store.hasLocal(item.id) {
        transferManager.enqueue(item)                            // background session
    }
}
```

Push payload chỉ là tín hiệu, không phải dữ liệu:

```json
{ "aps": { "content-available": 1 }, "scope": "guidance", "since": 148203 }
```

Lý do: payload APNs giới hạn 4KB, push có thể bị coalesce hoặc drop. Nếu push mất, lần foreground sau vẫn kéo từ `cursor` cũ — không có lỗ hổng.

Và với dữ liệu lớn, thiết kế **partial availability**: mỗi item tải xong là dùng được ngay, đừng gate cả app vào việc sync hoàn tất. UI hiện "đã tải 34/120 chủ đề" thay vì spinner vô hạn.

## Chỗ mình sẽ phản biện, riêng cho app của bạn

App hướng dẫn thảm hoạ có một yêu cầu mà silent push **không phục vụ được**: nội dung phải *có sẵn khi cần*, mà lúc cần thì thường là lúc mất mạng, mất điện, pin yếu.

Dựa vào silent push + discretionary download nghĩa là: content có thể vẫn chưa tải xong sau nhiều giờ, và bạn không biết. Với app này mình sẽ làm ngược lại:

**Foreground, có consent tường minh.** Một màn hình "Tải gói dùng offline — 240MB" với progress bar rõ ràng, task tạo lúc app đang mở nên `isDiscretionary = false` thực sự có hiệu lực, tải ngay. Silent push chỉ dùng cho **cập nhật nội dung nhỏ** sau đó.

Nói chung: **silent push để giữ dữ liệu tươi, không để đảm bảo dữ liệu tồn tại.** Nếu thiếu dữ liệu là app vô dụng, dữ liệu đó phải được tải bằng đường mà bạn kiểm soát được.

## Câu chốt nếu bị hỏi trong interview

> "Được, và đó là cặp đúng — silent push làm tín hiệu, background `URLSession` làm transport, vì transfer chạy trong `nsurlsessiond` nên không bị giới hạn 30 giây. Nhưng em không thiết kế nó như đường sync duy nhất: task tạo ở background luôn là discretionary nên có thể trì hoãn hàng giờ, cộng với ngân sách silent push và việc force-quit hủy cả hai. Em coi silent push là một trong nhiều trigger vào cùng một cursor-based delta sync, và với dữ liệu mà thiếu là app không dùng được thì em tải ở foreground với consent tường minh của user."

Muốn mình viết `TransferManager` hoàn chỉnh dạng manifest-based, có resume qua relaunch và deferred merge để bạn dựng thử không?
