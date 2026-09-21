# Phân tích LiveKit Swift SDK — Cách xử lý WebRTC

> Phân tích source code `client-sdk-swift` (branch `main`, commit `c9af3af`), tập trung vào lớp
> tích hợp WebRTC: kiến trúc, mô hình luồng (threading), vòng đời kết nối, thương lượng SDP/ICE,
> đường đi publish/subscribe media, data channel, E2EE và reconnect.

---

## 1. Tổng quan

SDK không dùng `libwebrtc` gốc mà dùng **`LiveKitWebRTC`** — một XCFramework libwebrtc được
LiveKit build lại với toàn bộ symbol prefix `LK` (`LKRTCPeerConnection`, `LKRTCRtpSender`, …) để
tránh xung đột symbol khi app đồng thời link thư viện WebRTC khác.

```swift
// Package.swift
.package(url: "https://github.com/livekit/webrtc-xcframework.git", exact: "150.7871.02")
```

Điểm kiến trúc quan trọng nhất: **WebRTC là chi tiết triển khai, không phải public API**. Mọi file
đụng tới WebRTC đều import bằng:

```swift
internal import LiveKitWebRTC   // Swift 6 access-level import
```

Nhờ vậy không một type `LKRTC*` nào lọt ra `.swiftinterface` của module `LiveKit`. Consumer chỉ
thấy `Room`, `Participant`, `Track`, `VideoView` — không thấy `RTCPeerConnection`.

### Phân lớp

```
Consumer app
    │  Room / Participant / Track / VideoView / RoomDelegate      ← public, Obj-C compatible
    ▼
Room (điều phối)  ──────────────┬──────────────────────────────┐
    │ signaling                 │ media                        │ data
    ▼                           ▼                              ▼
SignalClient (actor)        Transport (@RTC)              DataChannelPair
  WebSocket + nanopb        LKRTCPeerConnection            3× DataChannelDrain
    │                           │                              │
    └────────────── protobuf (nanopb, Sources/CLiveKitProto) ───┘
                                │
                    ┌───────────┴────────────┐
                    │  RTC global actor      │  ← hàng rào isolation duy nhất
                    │  LKRTCPeerConnFactory  │
                    └────────────────────────┘
                                │
                         LiveKitWebRTC.xcframework
```

Có hai "kênh" song song tới server:

| Kênh | Thành phần | Nội dung |
|---|---|---|
| Signaling | `SignalClient` (actor) trên WebSocket | JOIN, offer/answer, trickle ICE, AddTrack, mute, subscription, leave |
| Media/Data | `Transport` → `LKRTCPeerConnection` | RTP audio/video, SCTP data channel |

---

## 2. Trái tim của thiết kế: global actor `@RTC`

Đây là phần đáng chú ý nhất của codebase và là điều khác biệt lớn nhất so với các SDK WebRTC
Swift thông thường. File: `Sources/LiveKit/Core/RTC.swift`.

### 2.1. Vấn đề

Mọi object API của libwebrtc là **proxy object**. Mỗi lời gọi method — và cả việc **release
reference cuối cùng** — là một `BlockingCall` chặn luồng gọi để chờ signaling/worker/network
thread của WebRTC.

Trong khi đó, cooperative thread pool của Swift Concurrency có **số luồng cố định** (≈ số core) và
**không tự nở ra** khi một luồng bị block. Gọi WebRTC trực tiếp từ `async` code ⇒ nguy cơ
**deadlock toàn bộ pool**.

### 2.2. Giải pháp

Một `@globalActor` có executor riêng là một `DispatchQueue` — nơi *được phép* block:

```swift
@globalActor
actor RTC {
    static let shared = RTC()
    fileprivate static let queue = DispatchQueue(label: "LiveKitSDK.webRTC", qos: .default)
    private static let executor = DispatchQueueExecutor(queue: queue)
    nonisolated var unownedExecutor: UnownedSerialExecutor { Self.executor.asUnownedSerialExecutor() }
}
```

Ba nguyên thủy để vào/ra domain này:

| API | Dùng khi | Hành vi |
|---|---|---|
| `RTC.run { }` | async code | `await`, caller **suspend** (không block luồng pool) |
| `RTC.blocking { }` | public sync API | `queue.sync`, caller **bị block** (theo hợp đồng đã ghi trong docstring) |
| `RTC.park(_:)` | `deinit`, teardown | fire-and-forget lên **concurrent queue** riêng |

`RTC.run` nhận `sending @RTC () throws -> T` chứ không phải `@Sendable`: closure's captures được
*chuyển vùng* (region transfer) vào executor, nên có thể đưa object WebRTC không-`Sendable` vào hop
mà không cần khai `Sendable` ở bất cứ đâu. Kết quả trả về vẫn phải `Sendable` — chính điều này ngăn
raw proxy "rò" ngược ra ngoài.

### 2.3. Queue giải phóng riêng (`releaseQueue`)

Đây là chi tiết dễ bỏ sót nhưng rất quan trọng:

```swift
fileprivate static let releaseQueue = DispatchQueue(label: "LiveKitSDK.webRTC.release",
                                                    attributes: .concurrent)
```

Release proxy cuối cùng = destructor blocking. Khi teardown một room, hàng chục track + data
channel `deinit` gần như đồng thời ⇒ nếu đẩy hết qua executor **serial** `@RTC` thì head-of-line
blocking sẽ làm nghẽn mọi công việc RTC khác (comment trong code ghi rõ chuyện này từng làm CI treo
dưới sanitizer). Vì vậy release đi qua queue **concurrent**, để libdispatch tự nở worker khi chúng
block.

### 2.4. Facade pattern: `RTCBox` + các handle

`Sources/LiveKit/Core/RTCBox.swift` và các `RTCSender` / `RTCReceiver` / `RTCMediaTrack`.

```swift
final class RTCBox<Raw: AnyObject>: @unchecked Sendable {
    private let raw: Raw
    @RTC var value: Raw { raw }                 // chỉ truy cập được trên RTC executor
    func blocking<T>(_ body: (Raw) throws -> T) rethrows -> T { try RTC.blocking { try body(raw) } }
    func park(_ teardown: @escaping @Sendable (Raw) -> Void) { … }
    deinit { RTC.park(raw) }                    // release blocking đi đúng chỗ, tự động
}
```

Mỗi facade giữ box `private` và chỉ mở ra `@RTC var raw`:

```swift
struct RTCSender: Sendable {
    let senderId: String                     // cache: id() là BYPASS proxy member, thread-safe
    private let box: RTCBox<LKRTCRtpSender>
    @RTC var raw: LKRTCRtpSender { box.value }
}
```

Ý nghĩa: **không thể viết được** một lời gọi WebRTC ngoài RTC executor — sai isolation là **lỗi
compile**, không phải luồng bị treo lúc runtime. Đây là kiểu "làm cho trạng thái sai không biểu
diễn được" áp dụng cho threading.

Các thuộc tính thread-safe của libwebrtc (`id()`, `kind()` — proxy `BYPASS`) được **cache tại thời
điểm khởi tạo** (`trackId`, `kind`, `senderId`) để đọc sau này không cần hop actor.

### 2.5. Ngoại lệ có chủ đích: đường gửi data channel

```swift
// RTC.swift — Value objects
static func createDataBuffer(data: Data) -> LKRTCDataBuffer { LKRTCDataBuffer(data: data, isBinary: true) }
```

`sendData`, `readyState`, khởi tạo `LKRTCDataBuffer` được để **`nonisolated`** vì đây là đường
per-packet, nhạy độ trễ: `sendData` chỉ block trên network thread (`PROXY_SECONDARY_*`),
`readyState` là `BYPASS`, và `LKRTCDataBuffer` chỉ là container byte thuần (không có proxy).

Tương tự, các "value object" không có proxy phía sau (`LKRTCConfiguration`,
`LKRTCMediaConstraints`, `LKRTCRtpEncodingParameters`, `LKRTCRtpTransceiverInit`,
`LKRTCSessionDescription`, `LKRTCIceCandidate`) được tạo thẳng tại chỗ cần dùng — không có gì để
chờ.

### 2.6. Các bẫy đã được xử lý (ghi trong AGENTS.md + comment)

- **Completion handler phải `@Sendable`**: closure không-Sendable viết trong code `@RTC` sẽ *kế
  thừa* isolation `@RTC`, nhưng WebRTC gọi nó trên thread của chính nó ⇒ binary build bằng Swift
  6.1 sẽ trap ở prologue. Toàn bộ callback trong `Transport` đều ghi `{ @Sendable error in … }`.
- **`@RTC` executor không mang priority**: mọi hop chạy ở QoS `.default` của queue.
- **Không bật `NonisolatedNonsendingByDefault` (SE-0461)** khi chưa audit: dưới flag này
  `nonisolated async` chạy trên executor của *caller*, nên các method `Room` mà `@RTC Transport`
  await (negotiation, signal send) sẽ bắt đầu chạy trên WebRTC queue.
- **Statics trong extension `@RTC`, không phải instance member**: compiler coi instance isolation
  của actor là domain *khác* `@RTC` ở cả hai chiều, nên instance member không compose được.
- Bridging Obj-C completion-handler qua overload `async` tự sinh phải bọc
  `withCheckedThrowingContinuation` thủ công (bug thunk-coalescing Swift 5/6,
  swiftlang/swift#81846, fix ở 6.3) — thấy rõ trong mọi call `Transport`.

### 2.7. `PeerConnectionFactory`

Static lazy (global ⇒ lazy sẵn), khởi tạo một lần cho cả process:

```swift
static let peerConnectionFactory: LKRTCPeerConnectionFactory = {
    let (admType, bypassVoiceProcessing) = pcFactoryState.mutate { $0.isInitialized = true; … }
    LKRTCInitializeSSL()
    return LKRTCPeerConnectionFactory(audioDeviceModuleType: admType.toRTCType(),
                                      bypassVoiceProcessing: bypassVoiceProcessing,
                                      encoderFactory: encoderFactory,   // simulcast wrapper
                                      decoderFactory: decoderFactory,
                                      audioProcessingModule: audioProcessingModule)
}()
```

- `encoderFactory` = `LKRTCVideoEncoderFactorySimulcast(primary:fallback:)` bọc factory default ⇒
  simulcast khả dụng cho mọi codec hardware.
- `pcFactoryState` là `StateSync` với cờ `isInitialized`: cấu hình ADM type / bypass voice
  processing chỉ có hiệu lực **trước** lần đọc factory đầu tiên.
- `videoSenderCapabilities` / `audioSenderCapabilities` cũng static lazy — dùng cho codec
  preference.

---

## 3. `Transport` — wrapper của `LKRTCPeerConnection`

`Sources/LiveKit/Core/Transport.swift` (615 dòng), khai báo `@RTC final class Transport: NSObject`.

```swift
private let _pcBox: RTCBox<LKRTCPeerConnection>
@RTC private var _pc: LKRTCPeerConnection { _pcBox.value }   // "forbid direct access"
```

Trạng thái nội bộ (không cần lock vì đã isolated vào `@RTC`):

| Field | Vai trò |
|---|---|
| `_reNegotiate` | có offer đang chờ answer ⇒ xếp hàng renegotiate thay vì offer đè lên |
| `_pendingInitialOffer` | offer bundled theo JOIN, **chưa** `setLocalDescription` |
| `_latestOfferId` | chống answer lạc nhịp (stale answer) |
| `_isRestartingIce` | gate hàng đợi ICE candidate trong lúc ICE restart |
| `_debounce` (20 ms) | gộp nhiều lần `negotiate()` liên tiếp thành một offer |
| `_iceCandidatesQueue` | `QueueActor<IceCandidate>`, xử lý FIFO, có điều kiện |

Cấu hình peer connection (`LKRTCConfiguration.liveKitDefault()`):

```swift
sdpSemantics             = .unifiedPlan
continualGatheringPolicy = .gatherContinually
candidateNetworkPolicy   = .all
tcpCandidatePolicy       = .enabled
// + iceServers từ JOIN response (hoặc override từ ConnectOptions)
// + iceTransportPolicy = .relay nếu server bắt forceRelay
// + enableDscp theo ConnectOptions
```

Constraint duy nhất: `"DtlsSrtpKeyAgreement": true`.

### 3.1. Delegate callbacks — chuyển đổi ngay trên signaling thread

Toàn bộ `LKRTCPeerConnectionDelegate` là `nonisolated` (WebRTC gọi trên thread của nó). Nguyên tắc
áp dụng xuyên suốt: **convert/box ngay tại callback, chỉ cho type an toàn đi tiếp**.

```swift
nonisolated func peerConnection(_: LKRTCPeerConnection, didGenerate candidate: LKRTCIceCandidate) {
    let iceCandidate = candidate.toLKType()   // convert tại đây, raw không vượt isolation
    _delegate.notify { $0.transport(self, didGenerateIceCandidate: iceCandidate) }
}

nonisolated func peerConnection(_: LKRTCPeerConnection, didAdd rtpReceiver: LKRTCRtpReceiver,
                                streams: [LKRTCMediaStream]) {
    let receiver   = RTCReceiver(rtpReceiver)       // boxed
    let mediaTrack = RTCMediaTrack(track)           // boxed
    let streamIds  = streams.map(\.streamId)        // chỉ lấy id: destructor blocking của
                                                    // stream chạy ngay ở đây, không trôi đi đâu khác
    _delegate.notify { $0.transport(self, didAddTrack: mediaTrack, rtpReceiver: receiver,
                                    streamIds: streamIds) }
}
```

### 3.2. `close()` — thứ tự quan trọng

```swift
func close() async {
    await _debounce.cancel()          // chặn negotiate debounced kích hoạt sau khi đã đóng
    _pendingInitialOffer = nil
    _pc.delegate = nil
    // KHÔNG gọi removeTrack trước close()
    _pc.close()
}
```

Comment giải thích: `removeTrack` set null track của sender và đổi direction của transceiver, khiến
`Close()` **bỏ qua** `ClearSend`/`DetachTrack` trong `StopTransceiverProcedure` ⇒ đụng edge case ở
worker-thread teardown (use-after-free ICE, assertion khi dealloc `AVAudioEngine`). `Close()` tự lo
đủ.

---

## 4. Topology: `TransportMode`

`Sources/LiveKit/Core/TransportMode.swift` — mô hình hoá topology bằng enum thay vì optional field:

```swift
enum TransportMode: Equatable {
    case publisherOnly(publisher: Transport)                              // single PC (mới, /rtc/v1)
    case subscriberPrimary(publisher: Transport, subscriber: Transport)    // dual PC, mặc định cũ
    case publisherPrimary(publisher: Transport, subscriber: Transport)     // dual PC
}
```

Các computed property `publisher` / `subscriber` / `dedicatedSubscriber` / `allTransports` /
`transport(for: Livekit_SignalTarget)` đóng gói khác biệt giữa hai chế độ, nên phần còn lại của
`Room` **không phải if-else theo mode**.

| | Single PC (`publisherOnly`) | Dual PC |
|---|---|---|
| Số peer connection | 1 | 2 |
| Ai offer | **client luôn** offer | publisher: client offer; subscriber: **server** offer |
| Nhận media | qua transceiver `recvOnly` trên cùng PC | qua PC subscriber |
| `dedicatedSubscriber` | `nil` | subscriber |
| SDP munging | `mungeInactiveToRecvOnly` + `mungeOpusStereoForAllAudio` trên offer | `mungeOpusStereo`/`mungeOpusNack` trên answer |
| Sync state | `(answer: remoteDesc, offer: localDesc)` của publisher | `(answer: localDesc, offer: remoteDesc)` của subscriber |

Ở single PC mode, server gửi `Livekit_MediaSectionsRequirement` yêu cầu client thêm sẵn m-line
rỗng để nhận media:

```swift
// Room+SignalClientDelegate.swift
let transceiverInit = LKRTCRtpTransceiverInit(); transceiverInit.direction = .recvOnly
try await RTC.run {
    for _ in 0 ..< requirement.numAudios { _ = try publisher.addTransceiver(ofType: .audio, …) }
    for _ in 0 ..< requirement.numVideos { _ = try publisher.addTransceiver(ofType: .video, …) }
}
try await publisherShouldNegotiate()
```

---

## 5. Vòng đời kết nối

### 5.1. Dependency staging

`Sources/LiveKit/Core/RoomDependencies.swift` dùng typestate để loại bỏ optional field:

```swift
enum DependencyStage: Equatable {
    case idle
    case connecting(ConnectionDependencies)   // dataTracks, E2EE manager
    case connected(JoinDependencies)          // + TransportMode
}
```

Invariant: **transport tồn tại ⟺ stage là `.connected`**. `JoinDependencies` chỉ construct được từ
`ConnectionDependencies` (initializer chain) nên thứ tự khởi tạo là tính chất compile-time. Các
transition `begin` / `join` / `retireJoin` / `end` là **con đường duy nhất** để stage payload được
staged hay retired, và vì `DependencyStage` nằm trong `Room.State` (`StateSync`), một transition +
reset data tier là **một mutation atomic dưới cùng một lock**.

Chính sách sống sót:
- **Quick reconnect** (resume): giữ cả `ConnectionDependencies` và `JoinDependencies`.
- **Full reconnect**: `retireJoin()` — bỏ transport, giữ connection (để republish được).
- **Disconnect**: `end()` — bỏ cả hai.

### 5.2. `fullConnectSequence` và tối ưu "offer-with-join"

Đây là một tối ưu đáng chú ý (`EarlyPublisher`, commit #1111):

```
Luồng cũ (dual PC / v0):
  WS connect → JOIN response → tạo PC → createOffer → send offer → nhận answer   [2 RTT]

Luồng mới (single PC / v1):
  tạo PC + 3 data channel + createOffer (chưa apply)
       → WS connect (offer đi kèm trong JOIN request)
       → JOIN response (đã chứa answer) → set config → apply pending offer → setRemoteDescription
                                                                              [1 RTT]
```

Mấu chốt kỹ thuật: **`setLocalDescription` bị hoãn có chủ đích**.

```swift
/// createInitialOffer():
/// `setLocalDescription` is deferred until the answer arrives, because applying it
/// starts ICE gathering — and at this point the peer connection has only the
/// client-side configuration, so it would gather without the server's TURN servers
/// and never produce relay candidates.
```

Vì `makeRTCConfiguration(connectResponse: nil)` chưa có ICE server của server, nếu apply ngay thì
ICE gathering sẽ chạy **không có TURN** ⇒ không bao giờ có relay candidate. Nên:

1. `createOffer()` → munge → lưu `_pendingInitialOffer`, tăng `_latestOfferId`, trả offer ra.
2. Offer đi kèm JOIN request.
3. `JoinDependencies.make` gọi `publisher.set(configuration:)` với ICE server thật.
4. `set(remoteDescription:offerId:)` gọi `applyPendingInitialOffer()` **trước** khi
   `setRemoteDescription` ⇒ lúc này ICE gathering mới bắt đầu, với TURN đầy đủ.

Xử lý lỗi xung quanh khá cẩn thận:

- `createInitialOffer` fail ⇒ `clearPendingInitialOffer()`, offer = `nil`, quay về negotiate thường
  (recoverable, chỉ log `.warning`).
- `applyPendingInitialOffer` là **take-once** (clear *trước* `await`, không restore nếu throw): giữ
  lại sẽ làm `isAwaitingAnswer` mãi `true` ⇒ mọi `createAndSendOffer` sau đó thành no-op.
- Server không có `/rtc/v1` (`.serviceNotFound`) ⇒ đóng early publisher, retry với path legacy;
  không reuse được vì `primary`/`singlePCMode` là `let` immutable trên `Transport`.
- Biến `isAdopted` theo dõi ai sở hữu teardown: chỉ nhánh `.join` trong `configureTransports` mới
  adopt; mọi exit trước đó phải tự `await earlyPublisher?.close()`.
- Nếu offer đã đi kèm JOIN thì set `hasPublished = true` và **không** negotiate lại (tránh offer đè
  lên offer đang chờ answer).
- `signalClient.resumeQueues()` phải gọi **trước** negotiate: offer không queue được, gửi khi
  đang suspend là mất luôn.

Instrumentation: `connectSpan?.record("early_pc_created" / "signal" / "join_recv" / "pc_created" /
"offer_sent" / "answer_sent" / "pc_connected")`.

### 5.3. Ba data channel của publisher

```swift
// PublisherDataChannels.make(on:)
reliable : ordered = true                              // reliable user data
lossy    : ordered = false, maxRetransmits = 0         // lossy user data
dataTrack: ordered = false, maxRetransmits = 0         // DTP tự sequencing
```

Được tạo **trước** khi tạo offer, để m-line `m=application` được thương lượng luôn trong lần
JOIN exchange thay vì tốn thêm một vòng negotiate.

---

## 6. Thương lượng SDP

### 6.1. Publisher (client offer)

```
LocalParticipant.publish / addTransceiver / removeTrack
        │
        ▼
Room.publisherShouldNegotiate(force:)   ──► hasPublished = true
        │
        ▼
Transport.negotiate(force:)
   force == false → _debounce.schedule(20ms)   ← gộp nhiều publish liên tiếp
   force == true  → _debounce.cancel() + gọi thẳng
        │
        ▼
createAndSendOffer(iceRestart:)
   ├─ isAwaitingAnswer? (signalingState == .haveLocalOffer || _pendingInitialOffer != nil)
   │     → _reNegotiate = true; return            ← xếp hàng, không offer đè
   ├─ _latestOfferId += 1
   ├─ createOffer(for: constraints)
   ├─ set(localDescription:munging: …)            ← munge + retry-on-reject
   └─ _onOffer(offer, offerId) → signalClient.send(offer:offerId:)
        │
        ▼ (server)
Room.signalClient(_:didReceiveAnswer:offerId:)
   ├─ parse a=max-message-size → publisherDataChannel.set(maxMessageSize:)
   └─ publisher.set(remoteDescription: answer, offerId:)
         ├─ offerId != _latestOfferId → throw (answer stale)
         ├─ applyPendingInitialOffer()
         ├─ setRemoteDescription
         ├─ _iceCandidatesQueue.resume()          ← flush candidate đã buffer
         └─ if _reNegotiate { createAndSendOffer() }   ← chạy offer đã xếp hàng
```

`offerId` là cơ chế chống race quan trọng. Kiểm tra được đặt **trước** mọi mutation, vì
`applyPendingInitialOffer()` consume offer và đẩy connection sang `.haveLocalOffer` — một answer
sắp bị reject không được phép đi xa đến đó. `offerId == 0` ⇒ server legacy, chỉ log warning và bỏ
qua validate.

### 6.2. Subscriber (server offer, dual PC)

```swift
func signalClient(_ signalClient: SignalClient, didReceiveOffer offer: …, offerId: UInt32) async {
    guard let subscriber = _state.transport?.dedicatedSubscriber else { return }
    try await subscriber.set(remoteDescription: offer)
    var answer = try await subscriber.createAnswer()
    answer = try await subscriber.set(localDescription: answer, munging: [
        { Transport.mungeOpusStereo($0, matchingOffer: offer.sdp) },
        { Transport.mungeOpusNack($0, matchingOffer: offer.sdp) },
    ])
    try await signalClient.send(answer: answer, offerId: offerId)
}
```

### 6.3. SDP munging — 4 loại, kèm chiến lược fallback

SDK có parser SDP riêng (`SDP(parsing:)`, `mediaSections`, `payload(forCodec:)`, `fmtp(forPayload:)`)
thay vì xử lý string thô. Match theo **mid** và resolve payload type **độc lập trong từng document**,
nên peer có reorder hay renumber vẫn munge đúng section.

| Munge | Áp lên | Lý do |
|---|---|---|
| `mungeInactiveToRecvOnlyForMedia` | local offer (single PC) | WebRTC sinh `a=inactive` dù transceiver đã config `recvOnly`; chỉ sửa section RTP, bỏ qua `m=application` |
| `mungeOpusStereoForAllAudio` | local offer (single PC) | RFC 7587 §7.1: `stereo` là preference của **receiver**; thiếu nó libwebrtc tạo decoder mono và downmix. Ở single PC, lúc offer chưa biết publication nào stereo nên khai vô điều kiện |
| `mungeOpusStereo(matchingOffer:)` | answer (dual PC) | như trên, nhưng chỉ cho section mà offer khai `sprop-stereo=1` |
| `mungeOpusNack(matchingOffer:)` | answer (dual PC) | libwebrtc không khai NACK cho audio trong codec capabilities ⇒ answer drop mất `a=rtcp-fb:<pt> nack` mà SFU offer; RFC 4585 §4.2: feedback chỉ active khi **cả hai** đồng ý |

Cơ chế **retry-on-reject** (libwebrtc có `IsSdpMungingAllowed`, có thể reject munge):

```swift
func set(localDescription original: …, munging munges: [(String) -> String]) async throws -> … {
    let mungedSDP = munges.reduce(original.sdp) { $1($0) }
    guard mungedSDP != original.sdp else { try await set(localDescription: original); return original }
    do   { let m = RTC.createSessionDescription(…); try await set(localDescription: m); return m }
    catch {
        // bỏ munge CUỐI rồi thử lại → phải xếp munge "bắt buộc nhất" lên trước
        return try await set(localDescription: original, munging: Array(munges.dropLast()))
    }
}
```

Trả về **description đã thực sự apply** — vì signal một munge bị reject sẽ quảng bá tham số mà peer
connection chưa từng được config. Thứ tự `[inactive→recvonly, opusStereo]` không tuỳ tiện:
direction rewrite là *bắt buộc* để nhận media ở single PC, stereo là *tuỳ chọn* nên phải là cái bị
bỏ trước.

Lưu ý: đường `createInitialOffer()` **không** có retry này (offer đã gửi cho peer rồi, không rút lại
được) — nhưng cả hai munge trên đường đó đều là loại mà mọi offer single PC vốn đã mang.

### 6.4. ICE candidate

**Outbound** (trickle lên server):

```swift
nonisolated func peerConnection(_:didGenerate candidate:) {
    let iceCandidate = candidate.toLKType()
    _delegate.notify { $0.transport(self, didGenerateIceCandidate: iceCandidate) }
}
// → Room: Task { try await signalClient.sendCandidate(candidate:target:) }
```

**Inbound** (từ server) đi qua một `QueueActor` có điều kiện:

```swift
func add(iceCandidate candidate: IceCandidate) async throws {
    await _iceCandidatesQueue.process(candidate, if: remoteDescription != nil && !_isRestartingIce)
}
```

Candidate đến trước `setRemoteDescription`, hoặc trong lúc ICE restart, sẽ được **buffer** và flush
qua `_iceCandidatesQueue.resume()` ở cuối `set(remoteDescription:)`. `_isRestartingIce` cũng được
clear ở đó.

---

## 7. Đường publish media

`Sources/LiveKit/Participant/LocalParticipant.swift` (~`publish(track:options:)`).

```
1. checkPermissions(toPublish:)              → LiveKitError(.insufficientPermissions)
2. track.start()  +  Task.checkCancellation()   (camera start có thể lâu)
3. Video: await track.capturer.dimensionsCompleter.wait()       ← cần dimensions để tính encoding
        Utils.computeVideoEncodings(dimensions:publishOptions:isScreenShare:)
   Audio: RTC.createRtpEncodingParameters(encoding: audioPublishOptions.encoding ?? .presetMusic)
4. LKRTCRtpTransceiverInit { direction = .sendOnly; sendEncodings = encodings }
5. addTrackFunc()  : signalClient.sendAddTrack(cid: track.mediaTrack.trackId, …)
   negotiateFunc() : RTC.run {
                        transceiver = publisher.addTransceiver(with: track.mediaTrack.raw, init:)
                        transceiver.sender.set(degradationPreference:)
                        transceiver.set(preferredVideoCodec:)
                        return RTCSender(transceiver.sender)
                     }
                     track.set(transport: publisher, rtpSender: sender)
                     room.publisherShouldNegotiate()
6. fastPublish ? chạy SONG SONG (async let) : chạy TUẦN TỰ
7. Audio: nếu engineAvailability.isInputAvailable → track.startWaitingForFrames()
8. LocalTrackPublication(info: trackInfo) → add(publication:) → notify delegates
```

Hai điểm đáng chú ý:

**Fast publish** — khi server báo `joinResponse.fastPublish`, request `AddTrack` và
`addTransceiver + negotiate` chạy đồng thời (`async let`), thay vì chờ `trackInfo` rồi mới
negotiate. Tiết kiệm một RTT trên đường publish.

**Rollback** — nếu publish fail *sau khi* sender đã attach:

```swift
private func rollback(sender: RTCSender, publisher: Transport, room: Room) async {
    try await publisher.remove(track: sender)
    try await room.publisherShouldNegotiate()
}
```

Comment giải thích: server chỉ biết track mất đi qua renegotiation, nên fail mà không detach sẽ để
SFU giữ track "sống" trong khi client không còn publication nào để mute/unpublish nó.

### 7.1. Simulcast & SVC

`Sources/LiveKit/Support/Utils+VideoEncodings.swift`:

```swift
if videoCodec.isSVC {                       // VP9 / AV1
    return [RTC.createRtpEncodingParameters(encoding: encoding,
                                            scalabilityMode: isScreenShare ? .L1T3 : .L3T3_KEY)]
} else if !publishOptions.simulcast {
    return [RTC.createRtpEncodingParameters(encoding: encoding)]
}
// simulcast: layer theo chiều lớn hơn của output
//   dimensions.max < 480 → 1 layer
//   [480, 960)           → 2 layer (low + base)
//   >= 960               → 3 layer (low + mid + base)
```

Lower layer bị clamp: `maxFps` luôn ≤ của top layer; `maxBitrate` chỉ clamp khi layer đó
**không** thật sự scale resolution xuống (`scaleDownBy <= 1.0`) — một layer cùng resolution không
được phép tốn băng thông hơn top layer.

### 7.2. Dynacast — server điều khiển layer

Server gửi `Livekit_SubscribedQuality` / `Livekit_SubscribedCodec`; client tắt/mở encoding tương
ứng (`Extensions/LKRTCRtpSender.swift`):

```swift
@RTC func _set(subscribedQualities qualities: [Livekit_SubscribedQuality]) {
    let _parameters = parameters               // phải copy-modify-assign, sửa trực tiếp không có tác dụng
    if ScalabilityMode.fromString(encodings.first?.scalabilityMode) != nil {
        encodings.first.isActive = (qualities.highest != .off)     // SVC: 1 encoding
    } else {
        for e in qualities { encodings.first { $0.rid == e.quality.asRID }?.isActive = e.enabled }
        // stream non-simulcast không có RID → xử lý riêng
    }
    if didUpdate { parameters = _parameters }
}
```

Nếu server yêu cầu codec mà client chưa publish (`missingSubscribedCodecs`), client publish thêm
**backup codec** qua sender riêng — và phải set lại `degradationPreference` cho sender đó, vì đây
là property của *sender* chứ không phải của track.

### 7.3. Codec preference

```swift
@RTC func set(preferredVideoCodec codec: VideoCodec, exceptCodec: VideoCodec? = nil) throws {
    let all = RTC.videoSenderCapabilities.codecs
    let preferred = all.filter { $0.name.lowercased() == codec.name }   // GIỮ TẤT CẢ profile-level-id
    let others    = all.filter { $0.name.lowercased() != codec.name && … }
    try setCodecPreferences(preferred + others, error: ())
}
```

Comment: H.264 expose nhiều entry `profile-level-id`; chỉ offer một entry sẽ **làm hỏng negotiation
phía server**. Codec không nằm trong `codecPreferences` sẽ không được negotiate.

---

## 8. Đường subscribe media

```
LKRTCPeerConnectionDelegate.didAdd(rtpReceiver:streams:)   [signaling thread, nonisolated]
    │  box thành RTCMediaTrack + RTCReceiver, lấy streamIds
    ▼
Room+TransportDelegate.transport(_:didAddTrack:rtpReceiver:streamIds:)
    ├─ guard transport.target == _state.transport?.subscriber.target
    └─ execute(when: connectionState == .connected,
               removeWhen: connectionState == .disconnected) { … }    ← execution gate
    ▼
Room+EngineDelegate.engine(_:didAddTrack:rtpReceiver:streamId:)
    ├─ parse(streamId:) → (participantSid, trackId)      ← LiveKit đóng gói id vào stream id
    ├─ tìm RemoteParticipant theo sid
    └─ Task.retrying(retryDelay: 0.2) { addSubscribedMediaTrack(…) }   ← publication có thể chưa tới
    ▼
RemoteParticipant.addSubscribedMediaTrack(mediaTrack:rtpReceiver:trackSid:)
    ├─ tìm RemoteTrackPublication (không có → notifyDidFailToSubscribe)
    ├─ await RTC.run { RemoteAudioTrack(…) / RemoteVideoTrack(…) }
    │      ← construct trên RTC executor: attach audio sink là BlockingCall signaling thread
    ├─ publication.set(track:) + set(subscriptionAllowed: true)
    ├─ track.set(transport: subscriber, rtpReceiver: receiver)
    ├─ track.start()
    └─ notify didSubscribeTrack (participant + room delegates)
```

Hai chi tiết thiết kế:

- **`execute(when:removeWhen:)`**: track có thể đến trước khi `Room` hoàn tất connect. Block được
  xếp hàng vào `_queuedBlocks` và chạy khi điều kiện thoả, tự bị xoá khi disconnect.
- **`Task.retrying(retryDelay: 0.2)`**: `didAddTrack` (media) và `ParticipantUpdate` (signaling) đến
  qua hai kênh khác nhau ⇒ media có thể tới trước publication. Retry giải quyết race này.

### 8.1. Adaptive stream

`RemoteTrackPublication` theo dõi các `VideoRenderer` đang attach, lấy
`max(adaptiveStreamSize)` của chúng và gửi `sendUpdateTrackSettings(trackSid:settings:)` để server
chọn layer phù hợp. Không renderer nào visible ⇒ disable track (tiết kiệm băng thông).
Chỉ áp dụng cho video: `roomOptions.adaptiveStream && kind == .video`.

---

## 9. Data channel

`Core/DataChannelPair.swift`, `DataChannelDrain.swift`, `DataChannelWrite.swift`,
`DataChannelSendStages.swift`, `BufferedAmountMeter.swift`.

Kiến trúc: **mỗi channel một `DataChannelDrain`**, và drain *chính là*
`LKRTCDataChannelDelegate` của channel đó — nên không có chỗ nào phải dispatch theo label channel.
Mỗi drain có event loop FIFO riêng (single consumer), sở hữu queue + meter + stage.

```
DataChannelPair (publisher)
├── DataChannelDrain<LossyStage>    overflow = .dropOldest   lowWaterMark = 2 MB
└── DataChannelDrain<ReliableStage> overflow = .park         lowWaterMark = 2 MB
DataTracks
└── DataChannelDrain<DataTrackStage>
```

### 9.1. Backpressure: tại sao phải mirror `bufferedAmount`

```
/// `dataChannel(_:didChangeBufferedAmount:)` báo số byte **đã drain** kể từ report trước,
/// KHÔNG phải mức hiện tại (libwebrtc SctpDataChannel::MaybeSendOnBufferedAmountChanged gửi diff,
/// và chỉ khi ≥100 KiB đã drain hoặc buffer rỗng).
/// `LKRTCDataChannel.bufferedAmount` cho mức trực tiếp nhưng là PROXY_SECONDARY_CONSTMETHOD0
/// ⇒ đọc nó BLOCK trên network thread của WebRTC.
```

Nên `BufferedAmountMeter` giữ bản mirror cục bộ:

- `willSend(_:)` cộng **trước** khi hand-off — nếu cộng sau sẽ có cửa sổ mà drain report tới trước,
  trừ số byte khỏi mirror chưa từng thấy chúng, rồi lại được cộng vào ⇒ gate đóng vĩnh viễn với
  không còn gì để drain.
- `didDrain(_:)` trả `false` khi report vượt mirror (đã drift) và **self-heal về 0** thay vì trap —
  mirror chỉ là gate, không phải nguồn chân lý.
- `reset()` khi channel bị swap: mirror còn treo trên mức gate sẽ chặn channel thay thế mà không có
  drain report nào tới để giải phóng.

### 9.2. Reliable: sequence + replay

`ReliableStage` stamp sequence **bên trong** single consumer của drain:

```swift
if sequence == 0 {
    sequence = nextSequence; nextSequence += 1
    // Stamp bằng cách APPEND một packet chỉ chứa field đó: concat = protobuf merge,
    // scalar lấy occurrence cuối ⇒ ghi vài byte thay vì re-encode toàn payload.
    try bytes.append(Livekit_DataPacket.with { $0.sequence = sequence }.serializedData())
}
```

Comment nêu rõ lý do không stamp ở call site: hai sender đồng thời có thể lấy N và N+1 rồi submit
theo thứ tự ngược ⇒ dedup gate của SFU **âm thầm drop** packet có số nhỏ hơn.

`RetryBuffer` giữ các write đã dispatch để replay sau resume; `retry.trim(toAmount:)` gọi từ
`didDrain` để chỉ giữ xấp xỉ tập packet mà peer có thể chưa nhận. `retryReliable(lastSequence:)`
(gọi từ RECONNECT response) replay mọi packet có `sequence > lastSequence`.

`RetainedWrite` **không có field token** — đó là chủ ý: replay gửi lại cùng bytes, nếu còn token thì
sẽ resume continuation của submitter lần thứ hai.

`SendToken` idempotent (first outcome wins) và fail submitter từ `deinit` nếu chưa từng settle —
nên không đường nào trap vì double-resume, cũng không đường nào để submitter treo vĩnh viễn.

### 9.3. `max-message-size`

Parse từ `a=max-message-size` (RFC 8841) trong answer SDP, rồi **clamp xuống default của SDK**:

```swift
let parsed = parseSDPMaxMessageSize(answer.sdp) ?? DataChannelPair.defaultMaxMessageSize
let maxMessageSize = min(parsed, DataChannelPair.defaultMaxMessageSize)   // 64000
```

Comment: libwebrtc quảng bá ~256 KiB nhưng LiveKit/pion không deliver nổi end-to-end (~64 KiB) ⇒
không tin answer quá cái trần compile-in. Giá trị `0` = "no limit" theo RFC, được honor bằng cách
bỏ qua size check. Reset về default mỗi session (negotiate lại từng lần).

### 9.4. Teardown

```swift
func parkChannelRelease(_ target: DrainSendChannel?, closing: Bool = false) {
    guard let channel = target as? LKRTCDataChannel else { return }   // no-op cho fake trong test
    if closing { RTC.park { channel.close() } } else { RTC.park(channel) }
}
```

`close()` block trên signaling thread giống destructor ⇒ cả hai đi cùng một chỗ.

`DrainSendChannel` là seam protocol để queue + overflow policy unit-test được
(`LKRTCDataChannel` không thể construct mà không có peer connection sống). Buffer
`LKRTCDataBuffer` được build **tại thời điểm send**, không phải lúc queue: init memcpy payload vào
`CopyOnWriteBuffer`, và trên channel `dropOldest` thì write đã queue thường bị evict trước khi tới
đó — byte bị evict không nên tốn gì.

---

## 10. E2EE

`Sources/LiveKit/E2EE/E2EEManager.swift` — dùng `LKRTCFrameCryptor` của libwebrtc (frame-level
crypto, tách biệt khỏi SRTP).

```swift
// Sender side (publish)
await RTC.run {
    LKRTCFrameCryptor(factory: RTC.peerConnectionFactory, rtpSender: sender.raw, …)
}
// Receiver side (subscribe)
await RTC.run {
    LKRTCFrameCryptor(factory: RTC.peerConnectionFactory, rtpReceiver: receiver.raw, …)
}
```

Comment: raw sender/receiver là `@RTC`-confined và `LKRTCFrameCryptor` không `Sendable`, nên
cryptor được **build bên trong hop**.

- `frameCryptors: [CryptorKey: LKRTCFrameCryptor]` với key `[participantIdentity: publication.sid]`;
  `trackPublications: [LKRTCFrameCryptor: TrackPublication]` cho ánh xạ ngược khi có state change.
- Data channel dùng `LKRTCDataPacketCryptor(algorithm: .aesGcm, keyProvider:)` riêng.
- `sifTrailer` từ JOIN response được set vào key provider (để nhận diện frame server-injected).
- Trong `DataChannelPair.handle(received:)`, `encryptionType` được **capture trước khi decrypt**, vì
  apply payload đã giải mã sẽ rewrite oneof và clear `encryptedPacket` cùng với type của nó.

---

## 11. Media I/O

### 11.1. Video capture (outbound)

```
CameraCapturer / MacOSScreenCapturer / InAppCapturer / BufferCapturer / ARCameraCapturer
    │  (AVCaptureSession / ReplayKit / ARKit / manual push)
    ▼
VideoCapturer.capture(sampleBuffer:) / capture(pixelBuffer:) / capture(frame:)
    ├─ kiểm tra pixel format ∈ LKRTCCVPixelBuffer.supportedPixelFormats()
    ├─ kiểm tra dimensions hợp lệ → set(dimensions:) → dimensionsCompleter.resume
    ├─ VideoProcessor hook (tuỳ chọn, trên processingQueue riêng)
    ▼
delegate.capturer(capturer, didCapture: rtcFrame)    // LKRTCVideoCapturerDelegate
    ▼
LKRTCVideoSource → LKRTCVideoTrack → transceiver (sendOnly)
```

`dimensionsCompleter` là gate: publish video **phải** chờ dimensions resolve vì encoding layer được
tính từ đó. `startStopCounter` cho phép nhiều `Track` chia sẻ một capturer.

### 11.2. Video render (inbound)

```
LKRTCVideoTrack (remote)
    ▼ add(rtcVideoRenderer:)
VideoRendererAdapter: NSObject, LKRTCVideoRenderer     // Protocols/VideoRenderer.swift
    ▼ renderFrame(_ frame: LKRTCVideoFrame?) → frame.toLKType()
VideoRenderer (public protocol)
    ▼
VideoView → LKRTCMTLVideoView  hoặc  SampleBufferVideoRenderer (AVSampleBufferDisplayLayer)
```

`Track.State.videoRendererAdapters` là `MapTable<VideoRenderer, VideoRendererAdapter>`
(weak key → strong value) để remove trực tiếp và không giữ renderer sống. `VideoView` là thành
phần UI duy nhất chạy `@MainActor`.

### 11.3. Audio

```
AVAudioEngine  ←→  LKRTCAudioDeviceModule  ←→  AudioManager (public API)
                            │
                  AudioDeviceModuleDelegateAdapter (LKRTCAudioDeviceModuleDelegate)
                            │  didCreateEngine / willEnableEngine / willStartEngine /
                            │  didStopEngine / didDisableEngine / willReleaseEngine /
                            │  configureInputFromSource / configureOutputFromSource
                            ▼
                  chain các AudioEngineObserver
                  (AudioSessionEngineObserver, MixerEngineObserver, …)
```

ADM của LiveKit expose hook vòng đời `AVAudioEngine` cho SDK, cho phép:
- inject node vào graph (`MixerEngineObserver` → `SoundPlayer`, `PlayerNodePool`),
- quản lý `AVAudioSession` (`AudioSessionEngineObserver`),
- manual rendering mode, local recording, speech activity event (dùng cho `Agent/`),
- `PreConnectAudioBuffer`: buffer audio **trước khi** connect xong rồi flush sau (giảm độ trễ cảm
  nhận khi nói với agent).

`AudioManager` là public sync API ⇒ dùng `RTC.blocking` và tài liệu hoá rõ là **blocking theo hợp
đồng**.

---

## 12. Reconnect

Trigger:

| Nguồn | Điều kiện |
|---|---|
| `Room+TransportDelegate` | primary transport `.disconnected`/`.failed`, hoặc publisher failed khi `hasPublished` |
| `Room+SignalClientDelegate` | WebSocket disconnect (error ≠ `.cancelled`) |
| `SignalClient` LEAVE | `action == .reconnect` ⇒ ép `nextReconnectMode = .full`; `.resume` ⇒ abort attempt hiện tại |
| `ConnectivityListener` | network switch |
| Debug API | `.debug` |

### 12.1. Quick reconnect (resume) — giữ session

```
signalClient.connect(reconnectMode: .quick, participantSid:)
configureTransports(.reconnect)  → transport.set(configuration:)      ← chỉ đổi config, KHÔNG rebuild PC
                                 → publisherDataChannel.retryReliable(lastSequence:)
signalClient.resumeQueues()
primaryTransportConnectedCompleter.wait(timeout:)
sendSyncState()                  ← PHẢI trước offer
transport.setSubscriberRestartingIce()
if hasPublished { publisher.createAndSendOffer(iceRestart: true) }
                 publisherTransportConnectedCompleter.wait(timeout:)
dataTracks?.handleReconnect(fullReconnect: false)
```

`sendSyncState()` cho server biết client đang ở trạng thái nào:

```swift
let (previousAnswer, previousOffer) = await transport.syncStateDescriptions()  // khác theo mode
// autoSubscribe ON  → gửi danh sách track KHÔNG muốn subscribe (subscribe: false)
// autoSubscribe OFF → gửi danh sách track muốn subscribe      (subscribe: true)
// dùng isDesired (ý định) chứ không phải isSubscribed (trạng thái thực)
//   → tránh race khi quick reconnect: track chưa attach lại xong
// + publishedTracksInfo, publishDataTracks, dataChannels infos, dataChannelReceiveStates
```

ICE restart: `createAndSendOffer(iceRestart: true)` thêm constraint
`kLKRTCMediaConstraintsIceRestart`. Trường hợp đặc biệt được xử lý: nếu đang `.haveLocalOffer` mà
cần ICE restart, SDK `set(remoteDescription: sd)` lại trên remote description cũ để rollback về
`.stable` trước, và clear `_reNegotiate` để không sinh double offer.

### 12.2. Full reconnect — dựng lại từ đầu

```
connectionState = .reconnecting
cleanUp(isFullReconnect: true)        → cleanUpRTC: đóng data channel, transport.close(), retireJoin()
providedUrl.isCloud ? connectWithCloudRegionFailover(regionManager:) : fullConnectSequence(url, token)
dataTracks?.handleReconnect(fullReconnect: true)
    + engine(didMutateState:) phát hiện .reconnecting(.full) → .connected
      ⇒ localParticipant.republishAllTracks()
```

Thứ tự trong `cleanUpRTC` có chủ ý:

```swift
publisherDataChannel.reset(throwing: disconnectError)
subscriberDataChannel.reset(throwing: disconnectError)
await _state.transport?.close()
// Retire join CHỈ SAU KHI transport đã down: các teardown gate (vd. data-track publish gate)
// re-arm dựa trên channel đang đóng, nên cửa sổ "không có transport" mà caller in-flight
// quan sát được không được mở trước chúng.
_ = _state.mutate { $0.hasPublished = false; return $0.stage.retireJoin() }
```

### 12.3. Retry policy

`Task.retrying(totalAttempts: reconnectAttempts, retryDelay:)` với
`TimeInterval.computeReconnectDelay(forAttempt:baseDelay:maxDelay:totalAttempts:addJitter: true)`
— exponential backoff có jitter. Attempt cuối tự động escalate lên `.full`. Reconnect thành công
trên LiveKit Cloud ⇒ `regionManager.resetAttempts()`.

---

## 13. Stats

```swift
extension Transport {
    func statistics(for sender: RTCSender) async -> LKRTCStatisticsReport { … }
    func statistics(for receiver: RTCReceiver) async -> LKRTCStatisticsReport { … }
}
```

`Track` có `_statisticsTimer = AsyncTimer(interval: 1.0)`, bật khi
`roomOptions.reportRemoteTrackStatistics` / `reportStatistics`. Kết quả map sang
`TrackStatistics` public (`Track/Metrics/`), có bản riêng cho từng codec simulcast
(`simulcastStatistics: [VideoCodec: TrackStatistics]`).

---

## 14. Bản đồ file

| File | Vai trò WebRTC |
|---|---|
| `Core/RTC.swift` | global actor `@RTC`, executor, `run`/`blocking`/`park`, peer connection factory, value-object factory |
| `Core/RTCBox.swift` | giam raw proxy vào RTC executor, park release ở `deinit` |
| `Core/RTCSender.swift` / `RTCReceiver.swift` / `RTCMediaTrack.swift` | facade `Sendable` cho sender/receiver/track |
| `Core/Transport.swift` | wrapper `LKRTCPeerConnection`: offer/answer, ICE, SDP munging, transceiver, stats, delegate |
| `Core/TransportMode.swift` | topology single-PC / dual-PC |
| `Core/RoomDependencies.swift` | `EarlyPublisher`, `PublisherDataChannels`, `JoinDependencies`, `DependencyStage` |
| `Core/Room+Engine.swift` | connect sequence, reconnect, `makeRTCConfiguration`, `sendSyncState` |
| `Core/Room+TransportDelegate.swift` | `TransportDelegate` → reconnect trigger, trickle ICE, route track/data channel |
| `Core/Room+SignalClientDelegate.swift` | answer/offer/candidate từ server, dynacast, media-sections requirement |
| `Core/Room+EngineDelegate.swift` | state fan-out ra public delegate, subscribe track |
| `Core/SignalClient.swift` | WebSocket actor, protocol signaling |
| `Core/DataChannel*.swift`, `BufferedAmountMeter.swift` | data channel: drain, backpressure, sequence, replay |
| `Extensions/LKRTCRtpSender.swift` | `degradationPreference`, `_set(subscribedQualities:)` |
| `Extensions/RTCRtpTransceiver.swift` | `set(preferredVideoCodec:)` |
| `Extensions/RTCConfiguration.swift` / `RTCMediaConstraints.swift` | default config/constraints |
| `Extensions/RTCI420Buffer.swift`, `PixelBuffer.swift`, `RTCVideoCapturerDelegate+Buffer.swift` | chuyển đổi frame/buffer |
| `Track/Capturers/*` | nguồn video → `LKRTCVideoCapturerDelegate` |
| `Protocols/VideoRenderer.swift` | `VideoRendererAdapter: LKRTCVideoRenderer` |
| `Views/VideoView.swift`, `SampleBufferVideoRenderer.swift` | render (`LKRTCMTLVideoView` / `AVSampleBufferDisplayLayer`) |
| `Audio/Manager/AudioManager.swift`, `AudioDeviceModuleDelegateAdapter.swift`, `AudioEngineObserver.swift` | ADM ↔ `AVAudioEngine` |
| `E2EE/E2EEManager.swift` | `LKRTCFrameCryptor`, `LKRTCDataPacketCryptor` |
| `Support/Utils+VideoEncodings.swift` | tính encoding simulcast/SVC |

---

## 15. Nhận xét

### Điểm mạnh

1. **Isolation WebRTC bằng type system, không bằng convention.** Đây là điểm nổi bật nhất. Thay vì
   "nhớ dispatch lên queue đúng", SDK làm cho gọi sai trở thành **lỗi compile**: `@RTC` isolation +
   `RTCBox` chỉ mở raw qua accessor isolated + `LKRTC*` types cố ý không `Sendable`. Ba cơ chế cộng
   lại đóng kín được lối rò rỉ.

2. **Tách release path ra concurrent queue** là loại bug rất khó phát hiện (chỉ lộ khi teardown hàng
   loạt dưới sanitizer) và đã được xử lý có ý thức, kèm ghi chú lý do.

3. **Comment giải thích *tại sao*, không phải *cái gì*.** Gần như mọi quyết định khác thường đều có
   ghi chú kèm lý do kỹ thuật, số RFC, tên hàm libwebrtc tương ứng, hoặc reference tới
   client-sdk-js / rust-sdks. Điều này làm codebase đọc được mà không cần archaeology qua git log.

4. **Typestate thay optional.** `TransportMode` (enum thay 2 optional field) và `DependencyStage`
   (invariant "transport tồn tại ⟺ `.connected`") loại bỏ cả một lớp bug "force-unwrap nil
   transport".

5. **Xử lý đối kháng (adversarial) với libwebrtc.** Munge retry-on-reject, mirror `bufferedAmount`
   thay vì đọc getter, clamp `max-message-size` xuống dưới cái server quảng bá, không gọi
   `removeTrack` trước `close()` — đều là chỗ SDK không tin API upstream và có lý do cụ thể.

6. **Đường nóng được miễn trừ có chủ đích.** Data-channel send path để `nonisolated` sau khi phân
   loại chính xác từng member theo proxy semantics (`BYPASS` vs `PROXY_SECONDARY`) — tối ưu dựa trên
   hiểu biết, không phải phỏng đoán.

### Điểm cần lưu ý

1. **`@RTC` là serial executor duy nhất cho mọi peer connection.** Ở dual PC mode, publisher và
   subscriber chia sẻ một queue; một `BlockingCall` chậm trên PC này sẽ head-of-line block PC kia.
   Đánh đổi có ý thức (libwebrtc tự serialize nội bộ, thêm queue không tăng thông lượng), nhưng
   đáng biết khi profiling. `LK_SIGNPOSTS` có sẵn để đo.

2. **`RTCBox` là `@unchecked Sendable`** — an toàn dựa trên bất biến "facade giữ box `private`, chỉ
   forward `@RTC var raw`". Bất biến này **không được compiler kiểm tra**; một facade mới viết sai
   sẽ phá vỡ nó âm thầm. Đây là điểm cần chú ý khi review.

3. **`DataChannelPair` có hai field implicitly-unwrapped** (`lossy!`, `reliable!`) với an toàn dựa
   trên thứ tự: cả hai được set trong `init` trước khi `self` escape sang thread khác. Comment ghi
   rõ "Keep it that way" — fragile theo thiết kế, được bảo vệ bằng tài liệu.

4. **`_reNegotiate` chỉ là cờ boolean**, không phải counter. Nhiều lần `createAndSendOffer` trong lúc
   đang chờ answer sẽ gộp thành **một** offer sau đó. Đúng về mặt ngữ nghĩa (offer luôn phản ánh
   trạng thái *hiện tại* của PC) nhưng không hiển nhiên khi đọc lần đầu.

5. **Nợ kỹ thuật đã được đánh dấu**: nhóm `create*Track` blocking trong `RTC.swift` ghi rõ "Delete
   these together with the deprecated creators"; `DispatchQueue.liveKitWebRTC` đã deprecated;
   `Livekit_DataPacket.kind` có `// TODO: field is deprecated`.

---

*Tài liệu này phân tích cách SDK tích hợp WebRTC. Về lớp protocol (nanopb, `Sources/CLiveKitProto`,
`Sources/LiveKitNanopb`), xem `PROTOCOL.md`. Về quy ước code và build, xem `AGENTS.md`.*
