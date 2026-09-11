WebRTC in Swift: https://medium.com/@ivanfomenko/webrtc-in-swift-in-simple-words-about-the-complex-d9bfe37d4126

---

Dưới đây là bản dịch tiếng Việt của bài viết **"WebRTC in Swift. In simple words about the complex"** (WebRTC trong Swift. Nói một cách đơn giản về những điều phức tạp) của tác giả Ivan Fomenko:

---

Xin chào các đồng nghiệp. Trong bài viết này, chúng ta sẽ nói về công nghệ WebRTC và những vấn đề mà nó giải quyết.

### Hãy cùng định hình một bài toán trừu tượng:

Cần triển khai kết nối video có đầy đủ chức năng giữa hai thiết bị di động, ở các vùng khác nhau trên thế giới, nhằm đảm bảo truyền tải video ổn định và khá rẻ mà không gây tổn hại (chi phí/tài nguyên) cho người dùng.

### Chi tiết hóa bài toán:

* Kết nối hai hoặc nhiều thiết bị để trao đổi các luồng (stream) video;
* Đảm bảo chất lượng luồng video, việc trao đổi được thực hiện với khả năng khôi phục luồng trong trường hợp chất lượng kết nối Internet bị biến động;
* Bảo mật và mã hóa các luồng video;
* Máy chủ video cho việc phát sóng và truyền luồng video;
* Độ ổn định của kênh trao đổi luồng video và âm thanh;
* Giải quyết các vấn đề về giao tiếp khi sử dụng các loại mạng khác nhau (2-5G, 6G).

Việc tự xây dựng một giải pháp riêng là không hề đơn giản và đòi hỏi một lượng lớn kiến thức chuyên môn cũng như tài nguyên. Thông thường, team của bạn sẽ không có đủ những điều kiện trên — vì vậy bạn sẽ tìm đến các giải pháp có sẵn.
Một trong những giải pháp đó là — **WebRTC**. Một giải pháp tương đối dễ sử dụng và hiệu quả từ Google. Phần tiếp theo của bài viết sẽ cung cấp thông tin cơ bản về công nghệ này và các đặc thù của nó.

### Các điểm chính về WebRTC

WebRTC — công nghệ cung cấp khả năng kết nối hai hoặc nhiều client để truyền dữ liệu video/âm thanh trực tiếp (live).
Trong số các đặc điểm chính, có thể kể đến:

* WebRTC được hỗ trợ bởi các trình duyệt native lớn và bản thân các nền tảng iOS, Android. Nghĩa là, trong bài toán duy trì tính tương thích đa nền tảng, bạn không cần phải sử dụng các công nghệ render của bên thứ ba (như Adobe Flash đã bị khai tử);
* Để truyền dữ liệu giữa các người dùng, bạn không cần kết nối thêm các máy chủ trung chuyển (repeater servers), tất cả dữ liệu được truyền ngang hàng (peer-to-peer) giữa những người dùng;
* Không gặp vấn đề với các kết nối NAT giữa người dùng.

Công nghệ này cũng có một vài tính năng "hay ho":

* Kết nối của bạn không phụ thuộc trực tiếp vào tính ổn định của máy chủ. Nghĩa là cuộc gọi sẽ không bị ngắt khi máy chủ của bạn ngừng hoạt động;
* Chất lượng hình ảnh phụ thuộc trực tiếp vào chất lượng kênh truyền dữ liệu của người dùng. Tức là chất lượng hình ảnh không được điều chỉnh bởi sức mạnh máy chủ của bạn, mà bởi chất lượng kết nối của người dùng;
* WebRTC hỗ trợ mã hóa đầu cuối (end-to-end encryption).

Nhưng mọi thứ không hoàn toàn hoàn hảo, công nghệ này có một vài điểm khó khăn, bao gồm:

* Việc duy trì kết nối lâu dài giữa hai hay nhiều người dùng với nhau;
* Hoạt động nhiều bước để khởi tạo kết nối peer-to-peer này;
* Tính đặc thù của giao thức NAT và việc đồng bộ hóa nó trong các loại mạng khác nhau.

Nhưng tất cả đều đáng để thử. Vậy hãy tiếp tục.

### Mạng ngang hàng (Peer-to-peer)

Việc thiết lập kết nối peer-to-peer (gọi tắt là p2p) diễn ra thông qua địa chỉ IP public (công cộng) của thiết bị. Nhiệm vụ này khá phức tạp, vì trong hầu hết các trường hợp, thiết bị không có địa chỉ IP public riêng, do chúng được bảo vệ bởi công nghệ NAT.

**Network Address Translation (NAT)** — là phương pháp ánh xạ một không gian địa chỉ IP sang một không gian khác bằng cách thay đổi thông tin địa chỉ mạng trong header IP của các gói tin khi chúng đi qua một thiết bị định tuyến lưu lượng (router). Kỹ thuật này ban đầu được dùng để tránh việc phải gán một địa chỉ mới cho từng host khi di chuyển mạng hoặc đổi nhà cung cấp dịch vụ Internet, nhưng không thể định tuyến không gian địa chỉ mạng. Nó đã trở thành một công cụ phổ biến và quan trọng để bảo tồn không gian địa chỉ toàn cầu trước sự cạn kiệt của IPv4. Một IP NAT gateway có thể định tuyến Internet có thể được sử dụng cho toàn bộ một mạng nội bộ (private network).

Tức là tất cả điện thoại, máy tính bảng hoặc laptop kết nối vào mạng Wi-Fi tại nhà của bạn đều có chung một địa chỉ trên mạng toàn cầu, điều này khiến việc định danh một thiết bị riêng biệt trở nên bất khả thi.
Nói một cách tóm gọn, tình huống tương tự cũng xảy ra với kết nối 3/4/5G. Trong những trường hợp này, các "router" che giấu bạn chính là các trạm phát sóng di động.

Để hiểu rõ hơn về tình hình, tôi đề xuất xem xét một vài trường hợp:

**Trường hợp 1:** Cả hai thiết bị ở trong cùng một mạng.
Trong trường hợp này, việc nhận dạng và kết nối giữa các thiết bị sẽ không có vấn đề gì. Các thiết bị được nhận diện bằng các địa chỉ IP nội mạng (intranet), vì vậy rất dễ dàng để chúng thiết lập kết nối p2p trực tiếp.

**Trường hợp 2:** Các thiết bị ở các mạng khác nhau.
Thiết bị đầu tiên nằm trong mạng nội bộ, thiết bị kia nằm ở mạng công cộng (ví dụ một mạng Wi-Fi mở tại quán cà phê).
Trong trường hợp này, chúng ta đang làm việc với 2 địa chỉ IP cho mỗi thiết bị. Địa chỉ đầu tiên - là địa chỉ bên ngoài - đại diện bởi địa chỉ IP của router; địa chỉ thứ hai - là địa chỉ nội bộ, dùng để giao tiếp bên trong mạng. Nhưng với mạng công cộng, có thể có tới hàng trăm thiết bị ẩn đằng sau một địa chỉ công cộng. Làm sao để xác định được chính xác thiết bị chúng ta cần?

Chúng ta dùng WebRTC cho tác vụ này. Cụ thể, giao thức ICE kết hợp cùng các máy chủ STUN và TURN, giúp chúng ta tìm và kết nối tới thiết bị của mình. Tiếp theo, hãy xem xét kỹ hơn về ICE, STUN và các thực thể chính khác trong WebRTC.

### WebRTC: Các thành phần chính (Main entities)

#### Mediastream (Luồng phương tiện)

Mediastream có thể được gọi là một trong những thành phần then chốt trong WebRTC để trao đổi dữ liệu video và âm thanh. Thực tế, đây chính là đối tượng được trao đổi, vì stream bao gồm video và âm thanh nhận từ các đầu vào của thiết bị (micro và camera).

Có hai loại stream:

* **Local** — stream được tạo ra từ thiết bị của bạn.
* **Remote** — stream được tạo trên thiết bị khác và bạn nhận được trong quá trình trao đổi với người đối thoại.

Mỗi thiết bị phải lưu trữ cả hai loại để hoạt động đầy đủ. Local để truyền đi, remote để hiển thị. Giống hệt như pattern Input/Output tiêu chuẩn.
Bản thân thực thể Stream bao gồm ít nhất một thực thể Track. Track là một lớp bọc (wrapper) thân thiện với WebRTC bao bọc luồng dữ liệu từ micro, camera hoặc bất kỳ công cụ nhập dữ liệu ngoại vi nào được kết nối với thiết bị.

Đối với một cuộc gọi video thông thường, bạn sẽ cần 2 track (một cho micro, một cho video). Trong cuộc gọi, bạn có thể dừng hoặc tắt bất kỳ track nào từ stream local hoặc remote, ví dụ như khi người dùng muốn tắt camera hoặc micro.

#### SDP (Session Description Protocol)

SDP là một "bộ mô tả phiên" (session descriptor). Nó là các tệp chứa thông tin kỹ thuật cơ bản về thiết bị của bạn, cấu hình, phiên bản hệ điều hành và các thông tin chi tiết khác để đồng bộ hóa giao tiếp chính xác. Có thể gọi đây là "hộ chiếu kỹ thuật" cá nhân của bạn dành cho WebRTC, dựa trên đó WebRTC xác định cách kết nối và cấu hình việc trao đổi dữ liệu.
SDP là dữ liệu đầu tiên bạn gửi hoặc nhận từ người đối thoại. Do đó, nó cũng giống như một "lời mời" (invitation).

SDP có thể được hình thành theo hai cách:

1. **Không sử dụng remote_offer**: Phù hợp nếu bạn là người khởi xướng (initiator) cuộc gọi. Bạn tạo `local_offer` của chính mình và gửi cho người dùng khác.
2. **Có sử dụng remote_offer**: Phù hợp nếu bạn không phải là người khởi xướng. Trong trường hợp này, bạn phải dùng cả `local_offer` của bạn và `remote_offer` nhận được để khởi tạo thực thể.

#### Máy chủ STUN và TURN

Để WebRTC hoạt động ổn định, cần phải sử dụng các máy chủ STUN và TURN (đôi khi được gọi chung là ICE servers). Nếu không sử dụng chúng, các node (nút) chỉ có thể kết nối trong cùng một mạng không có NAT.

**STUN server**
STUN server là một máy chủ bên ngoài trên Internet, dùng để trả về địa chỉ gốc (địa chỉ của node gửi). Node nằm sau router sẽ liên hệ với STUN server để vượt qua NAT. Gói tin đi tới STUN server chứa địa chỉ nguồn — chính là địa chỉ bên ngoài của router (địa chỉ của node chúng ta cần). STUN server gửi ngược địa chỉ này lại. Bằng cách này, node biết được IP bên ngoài và cổng (port) của nó có thể truy cập được từ bên ngoài.
Địa chỉ này sau đó được WebRTC sử dụng để tạo một **ICE candidate**. Sau quá trình này, một bản ghi được tạo trong bảng NAT của router cho phép các gói tin gửi qua port đã định được định tuyến đúng đến node của chúng ta.

*Tóm lại:* STUN server giúp node tìm ra địa chỉ bên ngoài của nó, từ đó tạo ra lỗ hổng trên NAT (NAT hole punching) để nhận gói tin.

**TURN server**
TURN server là một phiên bản nâng cao của STUN server. TURN có thể hoạt động như một STUN server để thay thế nó, nhưng có điểm khác biệt quan trọng: khả năng hoạt động ở chế độ trung chuyển (relay mode).
Chức năng này hữu ích khi giao tiếp p2p trực tiếp giữa các node là không thể (ví dụ kết nối giữa các thiết bị di động qua mạng 3/4/5G). Lúc này, TURN server đóng vai trò làm trung gian nhận và chuyển tiếp dữ liệu giữa các node. Mặc dù về mặt mạng lưới đây không phải là p2p thực sự, nhưng bên trong cơ chế của ICE, các node vẫn "tin" rằng chúng đang giao tiếp trực tiếp với nhau.

*Tóm lại:* TURN server đóng vai trò dự phòng (relay) khi kết nối p2p thất bại. Nếu ứng dụng của bạn sẽ được dùng trên mạng 3/4/5G, bạn bắt buộc phải dùng TURN server.

**Tại sao cần cả hai?**
Mỗi loại máy chủ bao quát các tình huống khác nhau. STUN không phù hợp cho mạng di động di động (cellular) hay các hệ thống NAT đối xứng (Symmetric NAT), nơi router bảo vệ quá chặt chẽ (đòi hỏi IP và port đích phải khớp hoàn toàn với bản ghi đã gửi đi). Khi STUN bó tay do giới hạn bảo mật mạng, TURN server (trung chuyển) sẽ là giải pháp cứu cánh. Tuy nhiên, lưu lượng dùng qua TURN sẽ ít hơn STUN do chi phí duy trì chuyển tiếp dữ liệu (relay) cao hơn.

#### ICE candidate

ICE candidate là một thực thể chứa mô tả chuỗi về bạn dưới dạng một đối tượng trên mạng bên ngoài. Về cơ bản, đó là các "địa chỉ khả thi" của bạn mà bạn cần đồng bộ với người đối thoại để xây dựng kết nối p2p.
ICE candidate được tạo ra bất đồng bộ bởi từng thiết bị và phải được trao đổi liên tục. Theo tác giả, WebSockets là công cụ tiện lợi nhất để phân phối ICE candidates, nhưng bạn cũng có thể dùng Firebase hay các công cụ nhắn tin khác.

Khác với SDP (chỉ cần một bộ cho mỗi phiên), ICE candidates không giới hạn số lượng và được tạo ra liên tục cho đến khi kết nối ổn định được thiết lập, bởi vị trí mạng của bạn có thể được xác định bởi nhiều địa chỉ khác nhau (IP nội bộ, IP router ngoài, thông qua STUN/TURN, v.v.).

### Quá trình thiết lập kết nối trong WebRTC

Quá trình thiết lập liên lạc giữa hai thiết bị qua giao thức WebRTC (RTC trên mobile) có thể được chia thành 2 giai đoạn:

1. Thiết lập kết nối (Connection settings)
2. Trao đổi dữ liệu video/audio (Video and audio data exchange)

**Thiết lập kết nối (Connection establish)**
Các tác nhân chính:

* **Caller** (Người gọi)
* **Callee / Receiver** (Người nhận)
* **Signaler / Signal tool** (Công cụ truyền tín hiệu)

WebRTC rất mạnh trong việc tạo kết nối, nhưng không tự có công cụ trao đổi dữ liệu để "bắt tay" (handshake) ban đầu. Bạn phải dùng một hệ thống Signaler bên ngoài (WebSockets, Firebase, v.v.).

Các bước cơ bản đối với cuộc gọi thông thường:

**Dành cho Caller (Người gọi):**

1. Tạo một local media stream;
2. Bắt đầu render local media stream lên màn hình (nếu cần);
3. Tạo một `offer` (lời đề nghị kết nối);
4. Hình thành SDP dựa trên `offer` vừa tạo;
5. Gửi SDP qua dịch vụ Signaller;
6. Bắt đầu tạo các ICE candidates và đồng thời ở trạng thái sẵn sàng nhận/cài đặt ICE candidates từ phía người nhận;
7. Gửi ICE candidates qua Signaller khi chúng sẵn sàng;
8. Nhận SDP (answer) từ người đối thoại qua Signaller;
9. Cài đặt SDP của người đối thoại;
10. Thiết lập kết nối p2p thành công;
11. Render remote media stream (luồng video/âm thanh của người nhận).

**Dành cho Callee (Người nhận):**

1. Nhận SDP (offer) từ Caller qua Signaller;
2. Tạo local media stream;
3. Render local media stream lên màn hình (nếu cần);
4. Tạo một `answer` (câu trả lời);
5. Hình thành SDP dựa trên `answer` vừa tạo và `offer` đã nhận;
6. Gửi SDP trả lại qua Signaller;
7. Bắt đầu tạo các ICE candidates và chuẩn bị nhận ICE candidates của Caller;
8. Gửi ICE candidates qua Signaller khi chúng sẵn sàng;
9. Thiết lập kết nối p2p thành công;
10. Render remote media stream (luồng video/âm thanh của người gọi).

### Phần kết

Chúng ta đã nói về WebRTC và các tính năng chính của nó, xem xét chức năng, thông số cụ thể và cách sử dụng các thực thể.
Chúng ta cũng đã tìm hiểu thuật toán để xây dựng quy trình một cuộc gọi video tiêu chuẩn cho hai người tham gia, và nguyên lý của một service-controller xử lý cuộc gọi dựa trên công nghệ WebRTC.
Hy vọng bạn đã nắm bắt được ý tưởng cơ bản và các thành phần cấu trúc của công nghệ WebRTC cũng như các phương pháp triển khai nó.

---

Mình không dịch nguyên văn toàn bộ bài viết được (đó là nội dung có bản quyền của tác giả Ivan Fomenko), nhưng mình tóm tắt nội dung chính và viết lại một bản giải thích WebRTC trong Swift bằng tiếng Việt theo cách hiểu của mình — bao phủ đủ các khái niệm bài đó đề cập, kèm code thực tế hơn.

**Tóm tắt bài gốc:** Tác giả đặt vấn đề xây dựng video call giữa hai thiết bị ở hai đầu thế giới sao cho rẻ và ổn định, rồi giới thiệu WebRTC như giải pháp. Bài đi qua các entity chính (MediaStream, SDP, STUN/TURN, ICE candidate), giải thích tại sao NAT làm cho p2p khó, và mô tả trình tự thiết lập kết nối cho phía caller và callee, kèm một class controller viết bằng Swift.

---

## 1. Vấn đề cốt lõi: NAT

Hai máy muốn nói chuyện trực tiếp thì phải biết địa chỉ của nhau. Nhưng gần như mọi thiết bị đều nằm sau **NAT** (router Wi-Fi, hoặc CGNAT của nhà mạng 4G/5G), nên chúng chỉ có private IP. Từ bên ngoài nhìn vào, cả nhà bạn chỉ có một public IP duy nhất.

Ba tình huống:

| Tình huống | Cách kết nối |
|---|---|
| Cùng một LAN | Dùng private IP, p2p trực tiếp, không cần gì thêm |
| Khác mạng, NAT thường | STUN đủ để "chọc thủng" NAT (hole punching) |
| Symmetric NAT / mạng di động | STUN thất bại → phải relay qua TURN |

Đây là lý do bạn cần **cả hai** loại server. STUN rẻ (chỉ trả về địa chỉ), TURN tốn băng thông vì toàn bộ media đi xuyên qua nó.

## 2. Các entity chính

**MediaStream / MediaStreamTrack** — Stream là bó dữ liệu audio/video. Mỗi stream chứa ít nhất một track (1 audio track từ mic + 1 video track từ camera cho video call thường). Bạn luôn có hai loại: `local` (từ thiết bị mình, để gửi đi) và `remote` (nhận từ đầu kia, để render). Tắt mic/camera thực chất là set `track.isEnabled = false`.

**SDP (Session Description Protocol)** — "bản mô tả phiên": codec hỗ trợ, độ phân giải, thông tin mã hóa DTLS, media direction. Hai bên trao đổi SDP theo mô hình **offer/answer**: caller tạo `offer`, callee nhận và trả `answer`. Mỗi session chỉ có một cặp offer/answer tại một thời điểm (trừ khi renegotiate).

**ICE candidate** — mỗi ứng viên là một đường đi khả dĩ tới bạn: địa chỉ `host` (private IP), `srflx` (public IP do STUN phát hiện), hoặc `relay` (qua TURN). Khác với SDP, số lượng candidate **không giới hạn** — chúng được sinh bất đồng bộ và gửi dần. ICE sẽ thử ghép từng cặp candidate của hai bên và chọn đường tốt nhất.

**Signaling** — WebRTC **không** định nghĩa cách trao đổi SDP và ICE candidate. Bạn tự lo. WebSocket là lựa chọn phổ biến nhất; Firebase, MQTT, hay thậm chí push notification đều được.

## 3. Luồng thiết lập kết nối

```
Caller                    Signaling Server                    Callee
  │                              │                              │
  ├─ createLocalStream           │                              │
  ├─ createOffer                 │                              │
  ├─ setLocalDescription         │                              │
  ├──────── offer SDP ──────────►│──────── offer SDP ──────────►│
  │                              │              createLocalStream ┤
  │                              │         setRemoteDescription ┤
  │                              │                  createAnswer ┤
  │                              │          setLocalDescription ┤
  │◄─────── answer SDP ──────────│◄─────── answer SDP ──────────┤
  ├─ setRemoteDescription        │                              │
  │                              │                              │
  ├◄══════ ICE candidates (hai chiều, liên tục) ════════════════►│
  │                              │                              │
  └═══════════ DTLS handshake → SRTP media flow ════════════════┘
```

Điểm quan trọng nhiều người làm sai: **ICE candidate có thể đến trước khi `setRemoteDescription` hoàn tất**. Phải buffer lại và apply sau, nếu không sẽ bị lỗi.

## 4. Implementation trong Swift

Cài đặt qua SPM hoặc CocoaPods:

```swift
// Package.swift
.package(url: "https://github.com/stasel/WebRTC.git", from: "120.0.0")
```

### WebRTCClient

```swift
import Foundation
import WebRTC

protocol WebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCClient, didGenerate candidate: RTCIceCandidate)
    func webRTCClient(_ client: WebRTCClient, didChange state: RTCIceConnectionState)
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data)
}

final class WebRTCClient: NSObject {

    // Factory phải là singleton — tạo nhiều instance sẽ leak và crash
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoder = RTCDefaultVideoEncoderFactory()
        let videoDecoder = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(
            encoderFactory: videoEncoder,
            decoderFactory: videoDecoder
        )
    }()

    weak var delegate: WebRTCClientDelegate?

    private let peerConnection: RTCPeerConnection
    private let audioQueue = DispatchQueue(label: "com.reactplus.webrtc.audio")
    private let mediaConstraints = [
        kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
        kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
    ]

    private var videoCapturer: RTCVideoCapturer?
    private var localVideoTrack: RTCVideoTrack?
    private var localAudioTrack: RTCAudioTrack?
    private var remoteVideoTrack: RTCVideoTrack?

    // Buffer cho candidate đến sớm
    private var pendingCandidates: [RTCIceCandidate] = []
    private var hasRemoteDescription = false

    init(iceServers: [RTCIceServer]) {
        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.sdpSemantics = .unifiedPlan        // bắt buộc, planB đã deprecated
        config.continualGatheringPolicy = .gatherContinually
        config.bundlePolicy = .maxBundle
        config.rtcpMuxPolicy = .require

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue]
        )

        guard let pc = WebRTCClient.factory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: nil
        ) else {
            fatalError("Không khởi tạo được RTCPeerConnection")
        }
        self.peerConnection = pc

        super.init()
        createMediaSenders()
        configureAudioSession()
        self.peerConnection.delegate = self
    }

    deinit {
        peerConnection.close()
    }
}
```

### Tạo local media

```swift
private extension WebRTCClient {

    func createMediaSenders() {
        let streamId = "stream-\(UUID().uuidString)"

        // Audio
        let audioConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil, optionalConstraints: nil
        )
        let audioSource = WebRTCClient.factory.audioSource(with: audioConstraints)
        let audioTrack = WebRTCClient.factory.audioTrack(
            with: audioSource, trackId: "audio0"
        )
        self.localAudioTrack = audioTrack
        peerConnection.add(audioTrack, streamIds: [streamId])

        // Video
        let videoSource = WebRTCClient.factory.videoSource()
        #if targetEnvironment(simulator)
        self.videoCapturer = RTCFileVideoCapturer(delegate: videoSource)
        #else
        self.videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        #endif
        let videoTrack = WebRTCClient.factory.videoTrack(
            with: videoSource, trackId: "video0"
        )
        self.localVideoTrack = videoTrack
        peerConnection.add(videoTrack, streamIds: [streamId])

        // Lấy remote video track (Unified Plan)
        self.remoteVideoTrack = peerConnection.transceivers
            .first { $0.mediaType == .video }?
            .receiver.track as? RTCVideoTrack
    }

    func configureAudioSession() {
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        defer { session.unlockForConfiguration() }
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            debugPrint("AudioSession error: \(error)")
        }
    }
}
```

### Bật camera và render

```swift
extension WebRTCClient {

    func startCaptureLocalVideo(renderer: RTCVideoRenderer) {
        guard let capturer = videoCapturer as? RTCCameraVideoCapturer,
              let frontCamera = RTCCameraVideoCapturer.captureDevices()
                  .first(where: { $0.position == .front })
        else { return }

        let formats = RTCCameraVideoCapturer.supportedFormats(for: frontCamera)
        // Chọn format gần 640x480 nhất để cân bằng chất lượng / băng thông
        guard let format = formats.min(by: { lhs, rhs in
            let l = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
            let r = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
            return abs(Int(l.width) - 640) < abs(Int(r.width) - 640)
        }) else { return }

        let fps = format.videoSupportedFrameRateRanges
            .map { $0.maxFrameRate }.max() ?? 30

        capturer.startCapture(with: frontCamera, format: format, fps: Int(fps))
        localVideoTrack?.add(renderer)
    }

    func renderRemoteVideo(to renderer: RTCVideoRenderer) {
        remoteVideoTrack?.add(renderer)
    }

    func setAudioEnabled(_ enabled: Bool) {
        audioQueue.async { [weak self] in
            self?.localAudioTrack?.isEnabled = enabled
        }
    }

    func setVideoEnabled(_ enabled: Bool) {
        localVideoTrack?.isEnabled = enabled
    }
}
```

### Offer / Answer / ICE

```swift
extension WebRTCClient {

    func offer() async throws -> RTCSessionDescription {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: mediaConstraints, optionalConstraints: nil
        )
        let sdp = try await peerConnection.offer(for: constraints)
        try await peerConnection.setLocalDescription(sdp)
        return sdp
    }

    func answer() async throws -> RTCSessionDescription {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: mediaConstraints, optionalConstraints: nil
        )
        let sdp = try await peerConnection.answer(for: constraints)
        try await peerConnection.setLocalDescription(sdp)
        return sdp
    }

    func set(remoteSdp: RTCSessionDescription) async throws {
        try await peerConnection.setRemoteDescription(remoteSdp)
        hasRemoteDescription = true
        // Flush các candidate đã buffer
        for candidate in pendingCandidates {
            try? await peerConnection.add(candidate)
        }
        pendingCandidates.removeAll()
    }

    func add(remoteCandidate: RTCIceCandidate) async {
        guard hasRemoteDescription else {
            pendingCandidates.append(remoteCandidate)
            return
        }
        try? await peerConnection.add(remoteCandidate)
    }
}
```

### Delegate

```swift
extension WebRTCClient: RTCPeerConnectionDelegate {

    func peerConnection(_ pc: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        delegate?.webRTCClient(self, didGenerate: candidate)
    }

    func peerConnection(_ pc: RTCPeerConnection, didChange state: RTCIceConnectionState) {
        delegate?.webRTCClient(self, didChange: state)
        // .disconnected → chờ tự phục hồi; .failed → cần restartIce()
        if state == .failed {
            pc.restartIce()
        }
    }

    func peerConnection(_ pc: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ pc: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ pc: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ pc: RTCPeerConnection) {}
    func peerConnection(_ pc: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ pc: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ pc: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
```

### Cấu hình ICE servers

```swift
let iceServers: [RTCIceServer] = [
    RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
    RTCIceServer(
        urlStrings: ["turn:turn.your-domain.com:3478?transport=udp"],
        username: credentials.username,   // lấy từ backend, TTL ngắn
        credential: credentials.password
    )
]
```

**Lưu ý production:** đừng hardcode TURN credential trong app. Dùng cơ chế time-limited credential của coturn — backend sinh `username = timestamp:userId`, `password = HMAC-SHA1(secret, username)`.

## 5. Checklist khi triển khai thật

- `Info.plist`: `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`
- Background mode `voip` + `audio` nếu cần giữ call khi app xuống nền
- Tích hợp **CallKit** và **PushKit** — iOS bắt buộc report incoming call qua CallKit khi nhận VoIP push, nếu không app sẽ bị kill
- Kiểm thử với symmetric NAT thật (mạng 4G) chứ không chỉ Wi-Fi
- Theo dõi `peerConnection.statistics()` để log bitrate, packet loss, RTT
- Chỉ dùng p2p cho 1-1; từ 3 người trở lên nên chuyển sang **SFU** (LiveKit, mediasoup, Janus) vì p2p mesh tăng băng thông theo O(n²)

Bạn muốn mình đi sâu vào phần nào — signaling server với WebSocket, tích hợp CallKit/PushKit, hay setup coturn?
