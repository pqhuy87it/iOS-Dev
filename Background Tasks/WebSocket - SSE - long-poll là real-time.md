Điểm cốt lõi không phải là "nhanh hơn". Là **ai đứng giữa**.Với push, mỗi bước trung gian là một chỗ iOS có quyền quyết định thay bạn. Với socket, **kết nối vốn đã mở sẵn** — server không cần xin phép ai để chạm tới app, chỉ cần ghi vào một cái ống đã tồn tại. Đó là lý do gọi là "real-time thật".

Nhưng nói cho chính xác: nó không phải "được đảm bảo". Nó là **failure mode thuộc về bạn, không thuộc về OS**. Socket vẫn chết — mất mạng, server restart, chuyển WiFi sang 4G. Khác biệt là bạn *phát hiện được* và *xử lý được*, trong khi silent push bị drop thì bạn không bao giờ biết.

## Ba cơ chế khác nhau ở đâu

| | Chiều | Kết nối | iOS API |
|---|---|---|---|
| **Long-poll** | Server → client, 1 message/request | HTTP request treo đến khi có data | `URLSession` thường, timeout dài |
| **SSE** | Server → client, một chiều, nhiều message | 1 HTTP response không đóng | `URLSession.bytes(for:)` |
| **WebSocket** | Hai chiều | Upgrade từ HTTP lên TCP frame | `URLSessionWebSocketTask` |

**Long-poll** là bậc thang thấp nhất: client gửi request, server *giữ* không trả lời cho tới khi có dữ liệu (hoặc timeout ~30s), client nhận rồi gọi lại ngay. Chỉ cần HTTP thường, đi qua mọi proxy/firewall. Nhược điểm: mỗi message tốn một round-trip mới, và có khoảng hở giữa lúc response về và lúc request mới được thiết lập.

**SSE** thường bị bỏ qua nhưng rất đáng cân nhắc. Nó chỉ là một HTTP response `text/event-stream` không bao giờ đóng, server ghi từng dòng `data: ...`. Một chiều, nhưng phần lớn use case (order status, price ticker, notification feed) *vốn* một chiều. Điểm cộng lớn: nó có **`Last-Event-ID` sẵn trong spec** — khi reconnect, client gửi lại ID cuối, server resume từ đó. Đúng cái resume token mà với WebSocket bạn phải tự thiết kế.

```swift
var request = URLRequest(url: url)
request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
if let lastID { request.setValue(lastID, forHTTPHeaderField: "Last-Event-ID") }

let (stream, response) = try await session.bytes(for: request)
for try await line in stream.lines {
    if line.hasPrefix("id:")   { lastID = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
    if line.hasPrefix("data:") { handle(String(line.dropFirst(5))) }
}
```

Lưu ý: iOS không có API SSE native, bạn tự parse. Và nhớ set `timeoutIntervalForRequest` đủ lớn, không thì stream bị cắt.

**WebSocket** khi cần hai chiều thật (chat, collaborative editing, gửi ack lên server). Từ iOS 13 có `URLSessionWebSocketTask` native, không cần Starscream nữa:

```swift
private func receiveLoop() async {
    guard let task else { return }
    do {
        while true {
            // Cái bẫy kinh điển: receive() là one-shot,
            // phải gọi lại sau MỖI message. Quên → nhận đúng 1 cái rồi im.
            switch try await task.receive() {
            case .string(let s): handle(s)
            case .data(let d):   handle(d)
            @unknown default:    break
            }
        }
    } catch {
        await scheduleReconnect()
    }
}
```

## Cái bẫy lớn nhất trên iOS

**Socket chỉ sống ở foreground.** Vào background, `URLSessionWebSocketTask` không nằm trong danh sách được `background` configuration hỗ trợ, và dù có sống được vài giây thì app bị suspend là mất. Không có background mode nào cho phép giữ socket (VoIP mode có, nhưng App Store reject nếu app không thực sự là VoIP).

Nên đây chính là chỗ toàn bộ mạch hội thoại nối lại: **socket là tầng foreground, push là tầng background, và bạn cần cả hai.** Vòng đời thực tế:

```swift
.onChange(of: scenePhase) { phase in
    switch phase {
    case .active:     client.connect()        // + delta sync bù khoảng hở
    case .background: client.disconnect()     // chủ động đóng, đừng để nó chết bẩn
    default: break
    }
}
```

Chi tiết dễ bị bỏ qua: **khi reconnect ở foreground, phải delta sync trước rồi mới tin socket.** Khoảng thời gian app ở background là một lỗ hổng dữ liệu. Nếu chỉ mở socket rồi chờ message mới, bạn mất hết những gì xảy ra trong lúc đó.

## Bốn thứ tách senior khỏi mid-level

**1. Heartbeat.** Đây là điểm quan trọng nhất và hay bị bỏ. TCP **không** báo cho bạn biết kết nối đã chết. Qua NAT/carrier proxy, socket có thể ở trạng thái half-open: bạn tưởng đang kết nối, thực tế không gì đi qua nữa. Không có ping chủ động thì app "im lặng chết" — user nhìn màn hình đứng yên và tưởng là không có gì mới.

```swift
task.sendPing { error in ... }   // mỗi 20–30s, kèm timeout riêng cho pong
```

**2. Reconnect có exponential backoff + jitter.** Không jitter thì khi server restart, toàn bộ client reconnect cùng lúc → thundering herd, tự DDoS mình.

**3. `NWPathMonitor`.** WiFi → cellular là đổi IP, socket cũ chết nhưng iOS không lỗi ngay. Chủ động đóng và mở lại khi path thay đổi, nhanh hơn nhiều so với chờ ping timeout.

**4. Sequence number / cursor.** Mỗi message có `seq`, client giữ `lastSeq`. Reconnect thì gửi lên, server replay phần thiếu. Không có cái này thì mọi lần mất mạng là mất dữ liệu. Và nó cho bạn **dedup + idempotency** miễn phí, vì replay có thể gửi trùng.

## Khi nào đừng dùng

Nếu dữ liệu đổi vài phút một lần và user không cần biết ngay, socket là **chi phí thuần**: giữ radio thức tốn pin, thêm hạ tầng stateful phía server (load balancer sticky, scale khó hơn REST rất nhiều), thêm cả một lớp state machine phía client. Pull-to-refresh + polling 30s thường là câu trả lời đúng.

Câu hỏi sàng lọc: **user có nhìn màn hình chờ nó đổi không?** Có (chat, live score, trạng thái đơn hàng đang giao) → socket. Không → polling.
