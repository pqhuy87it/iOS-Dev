# StreamVideo iOS — Phân tích Media Pipeline

> Phân tích đường đi của media trong SDK: **capture → encode → truyền qua mạng → nhận → decode → phát**.
> Mọi tham chiếu ở dạng `path:line` đều trỏ vào source thật của repo (branch `develop`, version `1.52.0-SNAPSHOT`).

---

## 0. Kết luận trước — SDK này không tự làm RTP/UDP

Điều quan trọng nhất phải nói ngay: **StreamVideo iOS không tự implement việc đóng gói RTP, mã hóa SRTP, hay mở socket UDP/TCP để đẩy media.** Toàn bộ phần đó nằm trong `StreamWebRTC` — bản libwebrtc do Stream fork và build sẵn thành binary framework:

```swift
// Package.swift:24
.package(url: "https://github.com/GetStream/stream-video-swift-webrtc.git", exact: "145.15.0"),
```

Vai trò của code Swift trong repo này là **lớp điều khiển (control plane)**:

| SDK Swift làm gì | libwebrtc làm gì |
|---|---|
| Mở `AVCaptureSession`, lấy `CMSampleBuffer` | Encode H264/VP8/VP9/AV1 |
| Áp video filter (CoreImage/Metal) | Đóng gói RTP, mã hóa SRTP |
| Chọn codec, bitrate, số layer simulcast | Gửi/nhận qua UDP (hoặc TCP/TLS fallback) |
| Trao đổi SDP + ICE candidate qua HTTP/WebSocket | ICE/STUN/TURN, DTLS handshake |
| Quyết định subscribe track nào, kích thước nào | Decode, jitter buffer, NACK/PLI/FEC |
| Đọc `RTCStatsReport`, gửi telemetry | Render lên Metal, phát ra AudioUnit |

Chỗ duy nhất SDK tự mở socket là **Unix domain socket** để chuyển frame từ Broadcast Extension về app (mục 3.3) — đó là IPC nội máy, không phải network.

---

## 1. Bản đồ toàn tuyến

```
┌─────────────────────── THIẾT BỊ GỬI (publisher) ─────────────────────────┐
│                                                                          │
│  AVCaptureSession ──► StreamVideoCapturer ──► CaptureHandler/Pipeline    │
│  (camera)              (dispatch actions)      (filter + rotation)       │
│                                                     │                    │
│  ReplayKit ──────────────────────────────────────────┤                   │
│  (screenshare)                                       ▼                   │
│                                              RTCVideoSource              │
│                                                      │                   │
│  AVAudioEngine ──► AudioDeviceModule ──► RTCAudioSource                  │
│  (mic)              (APM: AEC/NS/AGC)                │                   │
│                                                      ▼                   │
│                                         RTCVideoTrack / RTCAudioTrack    │
│                                                      │                   │
│                              LocalVideoMediaAdapter.publish()            │
│                                (1 transceiver / publish option)          │
│                                                      ▼                   │
│                                    RTCPeerConnection "publisher"         │
│                                    (sendOnly, encode H264/VP8/VP9/AV1)   │
└──────────────────────────────────────────┬───────────────────────────────┘
                                           │
      ┌────────────────────────────────────┼───────────────────────────────┐
      │  SIGNALING                         │  MEDIA                        │
      │                                    │                               │
      │  HTTPS POST (Twirp/protobuf)       │  UDP + DTLS-SRTP              │
      │   • setPublisher (SDP offer)       │   • RTP packets               │
      │   • sendAnswer                     │   • RTCP (NACK/PLI/REMB/TWCC) │
      │   • iceTrickle                     │  fallback: TCP/TLS qua TURN   │
      │   • updateSubscriptions            │                               │
      │   • sendStats                      │                               │
      │                                    │                               │
      │  WSS (protobuf frames)             │                               │
      │   • JoinRequest/JoinResponse       │                               │
      │   • SubscriberOffer                │                               │
      │   • ChangePublishQuality           │                               │
      │   • participant events, healthcheck│                               │
      └────────────────────────────────────┼───────────────────────────────┘
                                           ▼
                              ╔═══════════════════════════╗
                              ║   SFU (edge server)       ║
                              ║   Selective Forwarding    ║
                              ║   — KHÔNG transcode       ║
                              ╚═══════════════════════════╝
                                           │
┌──────────────────────────────────────────┴───────────────────────────────┐
│                        THIẾT BỊ NHẬN (subscriber)                        │
│                                                                          │
│         RTCPeerConnection "subscriber"  (recvOnly, decode)               │
│                            │                                             │
│         didAdd(rtpReceiver) / didAdd(stream)                             │
│                            ▼                                             │
│         VideoMediaAdapter / RemoteAudioMediaAdapter  ──► TrackEvent      │
│                            ▼                                             │
│         WebRTCStateAdapter.didAddTrack() ──► WebRTCTrackStorage          │
│                            ▼                                             │
│         CallParticipant.track  (gắn track vào participant)               │
│                            ▼                                             │
│    VIDEO: VideoRenderer (MTKView/Metal)   AUDIO: AudioDeviceModule       │
│           ← lấy từ VideoRendererPool             → AVAudioEngine → loa   │
└──────────────────────────────────────────────────────────────────────────┘
```

Kiến trúc là **SFU (Selective Forwarding Unit)**, không phải P2P và không phải MCU. Mỗi client giữ **đúng 2 peer connection**:

```swift
// Sources/StreamVideo/WebRTC/v2/PeerConnection/Models/PeerConnectionType.swift
enum PeerConnectionType { case publisher, subscriber }
```

- **publisher** — `sendOnly`, chỉ đẩy media lên SFU
- **subscriber** — `recvOnly`, chỉ nhận media từ SFU

Tách 2 chiều như vậy cho phép renegotiate một chiều mà không ảnh hưởng chiều kia, và cho phép ICE restart riêng biệt.

---

## 2. Các tầng transport thực tế được dùng

Đây là câu trả lời trực tiếp cho câu hỏi "UDP, TCP, HTTP":

| # | Giao thức | Dùng cho | Code |
|---|---|---|---|
| 1 | **HTTPS/REST (JSON)** | Coordinator API: tạo call, join, quyền, recording, HLS | `HTTPClient/HTTPClient.swift`, `OpenApi/` (253 files) |
| 2 | **WSS (WebSocket + JSON)** | Coordinator events: ai vào/ra, ring, permission change | `WebSockets/Client/`, `EndpointConfig.swift:18` |
| 3 | **HTTPS POST (Twirp + protobuf)** | SFU signaling RPC: SDP, ICE trickle, subscriptions, stats | `protobuf/sfu/signal_rpc/signal.twirp.swift:92` |
| 4 | **WSS (protobuf frames)** | SFU event stream: join, subscriber offer, quality change | `WebRTC/v2/SFU/SFUWebSocket.swift` |
| 5 | **UDP + DTLS-SRTP** | **Media thật** (RTP audio/video) | libwebrtc, cấu hình ở `RTCConfiguration+Default.swift` |
| 6 | **TCP/TLS qua TURN** | Fallback khi UDP bị chặn | libwebrtc, ICE server từ join response |
| 7 | **Unix domain socket** | IPC: Broadcast Extension → app | `Screensharing/BroadcastBufferUploadConnection.swift:19` |

### 2.1 Endpoint

```swift
// Sources/StreamVideo/Utils/EndpointConfig.swift:16-19
static let production = EndpointConfig(
    hostname: "https://video.stream-io-api.com",
    wsEndpoint: "wss://video.stream-io-api.com/video/connect"
)
```

URL của SFU **không hardcode** — nó đến từ join response của coordinator, cho phép Stream route client tới edge gần nhất:

```swift
// Sources/StreamVideo/WebRTC/v2/WebRTCAuthenticator.swift:150,158
.init(string: response.credentials.server.url),        // HTTPS cho Twirp
.init(string: response.credentials.server.wsEndpoint), // WSS cho event stream
```

### 2.2 Signaling qua HTTP POST + protobuf (Twirp)

Đây là điểm khác biệt so với WebRTC "sách giáo khoa" (thường signaling toàn bộ qua WebSocket). Stream chia làm hai: **request/response đi HTTP POST**, **push từ server đi WebSocket**.

```swift
// protobuf/sfu/signal_rpc/signal.twirp.swift:92-102
private func makeRequest(for path: String) throws -> URLRequest {
    let url = hostname + pathPrefix + path + "?api_key=\(apiKey)"
    var request = URLRequest(url: url)
    request.setValue("application/protobuf", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
    request.httpMethod = "POST"
    return request
}
```

10 RPC được sinh ra từ `.proto` (`signal.twirp.swift:22-60`):

```
setPublisher            → gửi SDP offer, nhận SDP answer
sendAnswer              → trả lời SDP offer của subscriber
iceTrickle              → gửi 1 ICE candidate
updateSubscriptions     → khai báo muốn nhận track nào, size nào
updateMuteStates        → mute/unmute
iceRestart              → yêu cầu restart ICE
sendStats               → gửi WebRTC stats + telemetry
startNoiseCancellation  / stopNoiseCancellation
```

Twirp layer có **retry riêng, dựa trên error code từ server** — không retry mù:

```swift
// signal.twirp.swift:70-90
if response.hasError {
    if response.error.shouldRetry && retries < httpConfig.maxRetries {
        let delay = httpConfig.retryStrategy.getDelayAfterTheFailure()
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return try await execute(request: request, path: path, retries: retries + 1)
    }
}
```

`maxRetries = 5` (`HTTPClient/HTTPConfig.swift`), dùng exponential backoff của `DefaultRetryStrategy`.

### 2.3 SFU WebSocket — chi tiết đáng chú ý

```swift
// Sources/StreamVideo/WebRTC/v2/SFU/SFUWebSocket.swift:44-57
webSocket = WebSocketClient(
    ...
    healthCheckBeforeConnected: false,
    requiresAuth: false,
    // Keep SFU health checks below the call state's 15-second timeout.
    pingInterval: 5,
    closeCodeProvider: SFUWebSocketCloseCodeProvider(),
    pingRequestBuilder: { makeSFUHealthCheckPing() }
)
```

Close code được chọn có chủ đích, vì **nó quyết định SFU có xóa participant state ngay hay giữ lại để chờ reconnect**:

```swift
// SFUWebSocket.swift:86-120
4001 → connectionUnhealthy   // health-check timeout; SFU coi là abnormal close
                             // → giữ participant state trong grace period
4002 → reconfiguration       // Swift thay socket; cũng chọn nhánh abnormal
1000 → normalClosure         // user chủ động rời → SFU teardown ngay
```

Đây là loại chi tiết chỉ xuất hiện sau khi đã gặp bug thật: dùng sai close code thì mọi reconnect sẽ mất participant và phải join lại từ đầu.

### 2.4 Cấu hình ICE / transport

```swift
// Sources/StreamVideo/WebRTC/RTCConfiguration+Default.swift:11-29
static func makeConfiguration(with iceServersConfig: [ICEServer]) -> RTCConfiguration {
    let configuration = RTCConfiguration()
    var iceServers = [RTCIceServer]()
    for iceServerConfig in iceServersConfig {
        iceServers.append(RTCIceServer(
            urlStrings: iceServerConfig.urls,     // stun: và turn: URL
            username: iceServerConfig.username,
            credential: iceServerConfig.password
        ))
    }
    configuration.iceServers = iceServers
    configuration.sdpSemantics = .unifiedPlan
    configuration.bundlePolicy = .maxBundle       // dồn mọi media vào 1 transport
    return configuration
}
```

Ba quyết định quan trọng:

- **`iceServers` lấy từ server**, không hardcode → Stream tự chọn STUN/TURN relay theo vùng. Client chỉ chuyển tiếp nguyên `urls`/`username`/`password` vào `RTCIceServer`, nên **việc có relay TCP/TLS hay không hoàn toàn do backend cấp** — trong repo này không có chỗ nào client tự thêm hay ép transport.
- **`.unifiedPlan`** — bắt buộc cho multi-track/simulcast hiện đại.
- **`.maxBundle`** — mọi audio/video/screenshare đi qua **một cặp port UDP duy nhất**. Giảm số ICE candidate phải gather, tăng tỉ lệ NAT traversal thành công, và cực quan trọng trên mobile khi đổi mạng.

Đáng chú ý: SDK **không set** `iceTransportPolicy` hay `tcpCandidatePolicy` — để mặc định `.all`, tức là cho libwebrtc tự chọn giữa host / srflx / relay và giữa UDP / TCP theo kết quả ICE connectivity check. Không có code nào ép relay-only hay ép UDP-only.

### 2.5 Trickle ICE

`ICEAdapter` là `actor`, bind vào một cặp (peer connection, SFU adapter). Nó giải quyết vấn đề kinh điển: candidate sinh ra **trước khi** WebSocket sẵn sàng.

```swift
// Sources/StreamVideo/WebRTC/v2/PeerConnection/Adapters/ICEAdapter.swift:59-66
func trickle(_ candidate: RTCIceCandidate) {
    guard case .connected = sfuAdapter.connectionState else {
        pendingLocalCandidates.append(candidate)   // buffer lại
        return
    }
    trickleTask(for: candidate)
}
```

Hai buffer đối xứng nhau, drain khi kết nối sẵn sàng:

- `pendingLocalCandidates` — candidate của mình, chờ WS connected mới gửi
- `pendingSFUCandidates` — candidate của SFU đến trước khi có remote description, chờ rồi mới `addIceCandidate`

Candidate được serialize sang JSON rồi nhồi vào field protobuf:

```swift
// ICEAdapter.swift:107-108
let iceCandidate = ICECandidate(from: candidate)
let json = try encoder.encode(iceCandidate)
```

```swift
// PeerConnection/Models/ICECandidate.swift
struct ICECandidate: Codable {
    var candidate: String      // "candidate:842163049 1 udp 1677729535 ..."
    var sdpMid: String?
    var sdpMLineIndex: Int32
}
```

---

## 3. CAPTURE — Video

### 3.1 Kiến trúc: capturer + action handlers

`StreamVideoCapturer` không phải một class to. Nó là **dispatcher**: nhận `Action` rồi forward tuần tự cho từng handler.

```swift
// WebRTC/v2/VideoCapturing/StreamVideoCapturer.swift:34-51
protocol StreamVideoCapturerActionHandler: Sendable {
    func handle(_ action: StreamVideoCapturer.Action) async throws
    /// Rollback hook: gọi cho MỌI handler khi bất kỳ handler nào throw,
    /// trước khi rethrow error gốc.
    func handleFailure(for action: StreamVideoCapturer.Action) async
}
```

`handleFailure` là chi tiết thiết kế tốt: handler nào đã stage state trước khi handler sau chạy thì có chỗ để rollback. Pipeline capture do đó có tính transaction.

Với camera, thứ tự handler được chọn có lý do rõ ràng:

```swift
// StreamVideoCapturer.swift:69, 104-119
// The interruptions handler is placed before the capture handler so it
// updates its state and observers before the capture session is started
// or stopped. This keeps an intentional `stopCapture` from being misread
// as an unexpected stop, and ensures the stop observer is installed
// before capture begins.
let interruptionsHandler = CameraInterruptionsHandler()
var actionHandlers: [StreamVideoCapturerActionHandler] = [
    interruptionsHandler,                 // AVCaptureSession bị ngắt (call đến, app khác chiếm camera)
    CameraBackgroundAccessHandler(),      // quyền dùng camera khi background
    CameraCaptureHandler(),               // start/stop/đổi camera/đổi resolution
    CameraFocusHandler(),                 // tap-to-focus
    CameraCapturePhotoHandler(),          // chụp ảnh giữa call
    CameraVideoOutputHandler(),           // gắn thêm AVCaptureVideoDataOutput
    CameraZoomHandler()                   // pinch-to-zoom
]

let systemPressureHandler = CameraSystemPressureHandler()
if usesNewCapturingPipeline {
    actionHandlers.append(systemPressureHandler)              // nóng máy → giảm chất lượng
    actionHandlers.append(CameraCaptureSessionConfigurationHandler())
}
```

`CameraSystemPressureHandler` + `CaptureQualityUpdateReason` giải quyết một vấn đề thật: khi máy nóng, SDK tự giảm resolution, nhưng phải phân biệt "giảm vì nóng" với "giảm vì user/server yêu cầu" để **không tạo feedback loop**:

```swift
// StreamVideoCapturer.swift:14-17
enum CaptureQualityUpdateReason {
    case external
    case systemPressure
}
```

Cấu hình capture thực tế:

```swift
// ActionHandlers/Camera/CameraCaptureHandler.swift:13-20
private struct Configuration: Equatable, Sendable {
    var position: AVCaptureDevice.Position   // .front / .back
    var dimensions: CGSize                   // resolution mong muốn
    var frameRate: Int                       // fps
}
```

Handler này `Equatable` và **so sánh trước khi hành động** — tránh reconfigure `AVCaptureSession` vô ích (một tác vụ tốn kém, gây flicker):

```swift
// CameraCaptureHandler.swift:101-107
guard configuration != activeConfiguration else {
    log.debug("... performed no action as configuration wasn't changed.")
    return
}
let hasPermission = try await permissions.requestCameraPermission()
guard hasPermission else { throw ClientError("Camera access permission request failed.") }
```

### 3.2 Từ CMSampleBuffer đến RTCVideoSource

Frame do `RTCCameraVideoCapturer` bắt được **không đi trực tiếp** vào `RTCVideoSource`. Nó đi qua một delegate trung gian để áp filter và sửa rotation.

Có hai đường, chọn bằng flag `usesProcessingPipeline`:

```swift
// StreamVideoCapturer.swift:75-80
let videoCapturerDelegate: RTCVideoCapturerDelegate = usesProcessingPipeline
    ? StreamVideoProcessPipeline(source: videoSource, nodes: [
        StreamVideoProcessPipeline.FilterNode()
      ])
    : StreamVideoCaptureHandler(source: videoSource)
```

**Đường mới** — pipeline node kiểu functional, dễ mở rộng:

```swift
// VideoCapturing/StreamVideoProcessPipeline/StreamVideoProcessPipeline.swift:41-51
func capturer(_ capturer: RTCVideoCapturer, didCapture frame: RTCVideoFrame) {
    if nodes.isEmpty {
        source.capturer(capturer, didCapture: frame)
    } else {
        source.capturer(
            capturer,
            didCapture: nodes.reduce(frame) { $1.didCapture($0) }   // fold qua các node
        )
    }
}
```

**Đường cũ** — `StreamVideoCaptureHandler`, vẫn là đường mặc định. Đây là nơi filter thực sự chạy:

```swift
// WebRTC/VideoCapturing/StreamVideoCaptureHandler.swift:46-62
func capturer(_ capturer: RTCVideoCapturer, didCapture frame: RTCVideoFrame) {
    guard
        let selectedFilter,
        let buffer = frame.buffer as? RTCCVPixelBuffer
    else {
        return process(capturer: capturer, frame: frame, buffer: nil)  // fast path, không copy
    }
    apply(filter: selectedFilter, with: buffer, from: frame, capturer: capturer)
}
```

Filter chạy trên `CIContext` với GPU (`useSoftwareRenderer: false`) và **render in-place vào chính pixel buffer gốc** — tránh allocate buffer mới mỗi frame:

```swift
// StreamVideoCaptureHandler.swift:19, 38-40, 64-97
private lazy var processingQueue = OperationQueue(maxConcurrentOperationCount: 1)
context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])

processingQueue.addTaskOperation { [weak self] in
    let imageBuffer = buffer.pixelBuffer
    CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
    let inputImage = CIImage(cvPixelBuffer: imageBuffer, options: [.colorSpace: self.colorSpace])
    let outputImage = await filter.filter(VideoFilter.Input(
        originalImage: inputImage,
        originalPixelBuffer: imageBuffer,
        originalImageOrientation: sceneOrientation.cgOrientation
    ))
    CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
    context.render(outputImage, to: imageBuffer, bounds: outputImage.extent, colorSpace: self.colorSpace)
    process(capturer: capturer, frame: frame, buffer: buffer)
}
```

`maxConcurrentOperationCount: 1` đảm bảo **frame không bị đảo thứ tự** — quan trọng vì decoder phía nhận cần đúng trình tự timestamp.

Xử lý rotation là một bảng tra thủ công theo (hướng máy, camera trước/sau):

```swift
// StreamVideoCaptureHandler.swift:105-140
var rotation = RTCVideoRotation._90
switch sceneOrientation {
case let .portrait(isUpsideDown):
    rotation = isUpsideDown ? ._270 : ._90
case let .landscape(isLeft):
    switch (isLeft, currentCameraPosition == .front) {
    case (true, true):   rotation = ._0
    case (true, false):  rotation = ._180
    case (false, true):  rotation = ._180
    case (false, false): rotation = ._0
    }
}
```

Rotation được ghi vào **metadata của `RTCVideoFrame`**, không phải rotate pixel:

```swift
// StreamVideoCaptureHandler.swift:135
return RTCVideoFrame(buffer: _buffer, rotation: rotation, timeStampNs: frame.timeStampNs)
```

Đây là cách làm đúng: rotation đi kèm RTP như metadata (`urn:3gpp:video-orientation`), phía nhận rotate lúc render. Không tốn CPU rotate và không mất chất lượng.

### 3.3 Screensharing — hai chế độ, hai đường truyền

```swift
// StreamVideoCapturer.swift:173, 193
static func screenShareCapturer(...)   // in-app, ReplayKit RPScreenRecorder
static func broadcastCapturer(...)     // system-wide, Broadcast Extension
```

**Chế độ in-app** — `ScreenShareCaptureHandler` dùng `RPScreenRecorder.shared()`, frame đi thẳng vào cùng pipeline như camera. Có thể kèm audio của app:

```swift
// ActionHandlers/ScreenShare/ScreenShareCaptureHandler.swift:20-27
private let includeAudio: Bool
private let audioProcessingQueue = DispatchQueue(
    label: "io.getstream.screenshare.audio.processing", qos: .userInitiated
)
```

Audio app phải resample về format của WebRTC, có helper riêng cho việc đó:

```
ActionHandlers/ScreenShare/Extensions/AudioConverter.swift
ActionHandlers/ScreenShare/Extensions/AVAudioConverter+Convert.swift
ActionHandlers/ScreenShare/Extensions/AVAudioPCMBuffer+FromCMSampleBuffer.swift
ActionHandlers/ScreenShare/Extensions/AVAudioFormat+Equality.swift
```

Rồi inject vào ADM:

```swift
// Utils/AudioSession/AudioDeviceModule/AudioDeviceModule.swift:490
func enqueue(_ sampleBuffer: CMSampleBuffer)
```

**Chế độ broadcast** — chia sẻ cả hệ thống, kể cả khi app ở background. Extension là process riêng nên phải IPC. Đây là **chỗ duy nhất SDK tự mở socket**:

```swift
// WebRTC/Screensharing/BroadcastBufferUploadConnection.swift:16-24  (phía extension)
socketHandle = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)

// WebRTC/Screensharing/BroadcastBufferReaderConnection.swift:20     (phía app)
socketHandle = socket(AF_UNIX, SOCK_STREAM, 0)
```

Socket file nằm trong App Group container dùng chung:

```swift
// WebRTC/Screensharing/BroadcastConstants.swift
static let bufferMaxLength = 10240
static let contentLength = "Content-Length"
static let bufferWidth = "Buffer-Width"
static let bufferHeight = "Buffer-Height"
static let bufferOrientation = "Buffer-Orientation"
static let broadcastStartedNotification = "io.getstream.broadcastStarted"
static let broadcastStoppedNotification = "io.getstream.broadcastStopped"
static let broadcastSharePath = "broadcast_share"
static let broadcastAppGroupIdentifier = "BroadcastAppGroupIdentifier"
```

Giao thức IPC tự định nghĩa, kiểu HTTP-like: mỗi frame gửi header `Content-Length` + `Buffer-Width/Height/Orientation`, rồi payload. Luồng đầy đủ:

```
ReplayKit Extension                          App chính
─────────────────────                        ─────────────────
BroadcastSampleHandler
   │ CMSampleBuffer
   ▼
BroadcastBufferUploader
   │
   ▼
BroadcastBufferUploadConnection ──AF_UNIX──► BroadcastBufferReaderConnection
   (socket client)                                    │
                                                      ▼
                                            BroadcastBufferReader
                                                      │
                                                      ▼
                                            BroadcastCaptureHandler
                                                      │
                                                      ▼
                                            RTCVideoSource → publisher PC
```

`BroadcastObserver` dùng `CFNotificationCenterGetDarwinNotifyCenter` (qua 2 notification name ở trên) để app biết extension đã start/stop.

---

## 4. CAPTURE — Audio

### 4.1 AudioDeviceModule

Audio không đi qua Swift từng buffer như video. libwebrtc quản lý `AVAudioEngine` trực tiếp; Swift chỉ điều khiển. `AudioDeviceModule` (761 dòng) là wrapper quanh `RTCAudioDeviceModule`:

```swift
// Utils/AudioSession/AudioDeviceModule/AudioDeviceModule.swift
var isPlaying: Bool                     // playout đang chạy?
var isRecording: Bool                   // capture đang chạy?
var isMicrophoneMuted: Bool
var isStereoPlayoutEnabled: Bool
var isVoiceProcessingBypassed: Bool     // bypass AEC/NS của iOS
var isVoiceProcessingEnabled: Bool
var isVoiceProcessingAGCEnabled: Bool   // auto gain control
var isMutedSpeechDetectionEnabled: Bool // "bạn đang nói khi đang mute"
var audioLevel: Float                   // để vẽ audio meter
```

Mọi property đều có `Publisher` tương ứng → UI reactive không cần polling.

Điểm đáng chú ý về mute: SDK phân biệt **mute ở tầng ADM** với **disable track**. Mute ADM giữ recording chạy nên vẫn phát hiện được "đang nói khi mute" (`isMutedSpeechDetectionEnabled` → `source.isRecordingAlwaysPreparedMode`), và `Call.state.isSpeakingWhileMuted` hiển thị cảnh báo cho user.

### 4.2 Audio processing chain

```swift
// WebRTC/PeerConnectionFactory.swift:38-46
private(set) lazy var factory: RTCPeerConnectionFactory = {
    let encoderFactory = RTCVideoEncoderFactorySimulcast(
        primary: Self.defaultEncoder,
        fallback: Self.defaultEncoder
    )
    return RTCPeerConnectionFactory(
        audioDeviceModuleType: .audioEngine,     // AVAudioEngine, không phải VPIO cũ
        bypassVoiceProcessing: false,            // giữ AEC/NS của iOS
        encoderFactory: encoderFactory,
        decoderFactory: Self.defaultDecoder,
        audioProcessingModule: audioProcessingModule
    )
}()
```

`audioProcessingModule` là điểm cắm cho custom audio filter (noise cancellation của Krisp, v.v.):

```
Utils/AudioSession/AudioProcessing/        — APM wrapper + components
WebRTC/AudioFilter/Filters/                — audio filter implementations
```

Có một comment giải thích lỗi memory rất cụ thể:

```swift
// PeerConnectionFactory.swift:99-104
deinit {
    /// `RTCAudioDeviceModule` keeps a raw pointer to WebRTC's worker
    /// thread. Releasing it while `factory` is still alive prevents
    /// dangling-pointer dereferences during module deallocation.
    audioDeviceModuleStorage = nil
}
```

### 4.3 Audio session — phần phức tạp nhất

Đây là mảng lớn nhất của `Utils/`, tổ chức theo kiến trúc **Redux-like** (store + reducer):

```
Utils/AudioSession/
├── RTCAudioStore/
│   ├── Namespace/Reducers/RTCAudioStore+AVAudioSessionReducer.swift
│   └── Components/
├── AudioDeviceModule/    (ADM + components + extensions)
├── AudioProcessing/      (APM)
├── AudioRecorder/        (ghi âm local)
├── Policies/             (AudioSessionPolicy — chiến lược category/mode)
├── Protocols/
└── Extensions/
```

Reducer đặt `AVAudioSession` category/mode/options qua `RTCAudioSessionConfiguration`:

```swift
// RTCAudioStore/Namespace/Reducers/RTCAudioStore+AVAudioSessionReducer.swift:199-222
let webRTCConfiguration = RTCAudioSessionConfiguration.webRTC()
webRTCConfiguration.category = category.rawValue
webRTCConfiguration.mode = mode.rawValue
webRTCConfiguration.categoryOptions = categoryOptions
...
RTCAudioSessionConfiguration.setWebRTC(webRTCConfiguration)
```

Dùng store + reducer cho audio session là lựa chọn đúng: `AVAudioSession` là global mutable state bị nhiều bên tranh chấp (CallKit, ReplayKit, WebRTC, app), và mọi bug audio đều là bug thứ tự thao tác. Reducer làm thứ tự đó thành tuần tự và log được.

Ngoài ra `WebRTCAudioSessionWatchdog` (`WebRTC/v2/StateMachine/Components/`) giám sát audio session trong stage `.joined` và chỉnh lại khi bị bên khác thay đổi.

---

## 5. ENCODE

### 5.1 Encoder / decoder factory

```swift
// WebRTC/PeerConnectionFactory.swift:35-38, 49-53
let encoderFactory = RTCVideoEncoderFactorySimulcast(
    primary: Self.defaultEncoder,
    fallback: Self.defaultEncoder
)
private nonisolated(unsafe) static let defaultEncoder = RTCDefaultVideoEncoderFactory()
private nonisolated(unsafe) static let defaultDecoder = RTCDefaultVideoDecoderFactory()
```

`RTCDefaultVideoEncoderFactory` dùng **VideoToolbox** trên iOS → H.264 encode/decode bằng **hardware**. VP8/VP9/AV1 là software (libvpx/libaom). Đây là lý do `isHardwareAccelerationAvailable` được expose ở API công khai (`StreamVideo.swift:74`) và là lý do H.264 thường là lựa chọn mặc định trên iOS.

`RTCVideoEncoderFactorySimulcast` bọc encoder gốc để **chạy nhiều encoder song song**, mỗi encoder một layer resolution.

Codec được hỗ trợ:

```swift
// Models/VideoCodec.swift:15-25
public enum VideoCodec: String, Sendable, Hashable, CustomStringConvertible {
    case unknown, h264, vp8, vp9, av1
}

// Models/VideoCodec.swift:35-44
var isSVC: Bool {
    switch self {
    case .vp9, .av1:   return true    // SVC native
    case .h264, .vp8:  return false   // phải dùng simulcast
    default:           return false
    }
}
```

```swift
// Models/AudioCodec.swift:10-14
public enum AudioCodec: String, CustomStringConvertible, Sendable {
    case opus
    case red      // RFC 2198 redundant audio — chống mất gói
    case unknown
}
```

### 5.2 Simulcast vs SVC — SDK xử lý cả hai

Đây là phần kỹ thuật sắc nhất của pipeline.

**Simulcast (H264/VP8)** — encode 3 stream độc lập, gửi cả 3 lên SFU, SFU chọn stream nào forward cho từng người nhận.

```swift
// Models/VideoLayer.swift:16-20, 36-64
enum Quality: String {
    case full = "f"       // rid trong SDP
    case half = "h"
    case quarter = "q"
}

static let full = VideoLayer(
    dimensions: .full, quality: .full,
    maxBitrate: .maxBitrate, sfuQuality: .high
)
static let half = VideoLayer(
    dimensions: .half, quality: .half,
    maxBitrate: 500_000,
    scaleDownFactor: CMVideoDimensions.full.area / CMVideoDimensions.half.area,
    sfuQuality: .mid
)
static let quarter = VideoLayer(
    dimensions: .quarter, quality: .quarter,
    maxBitrate: 300_000,
    scaleDownFactor: CMVideoDimensions.full.area / CMVideoDimensions.quarter.area,
    sfuQuality: .lowUnspecified
)
```

Layer được sinh động từ publish option server trả về, không hardcode:

```swift
// WebRTC/v2/Extensions/Protobuf/Stream_Video_Sfu_Models_PublishOption+VideoLayers.swift:35-75
func videoLayers(spatialLayersRequired: Int) -> [VideoLayer] {
    var scaleDownFactor: Int = 1
    let qualities: [VideoLayer.Quality] = [.full, .half, .quarter]
    var videoLayers: [VideoLayer] = []
    for quality in qualities {
        let width   = publishOptionWidth  / scaleDownFactor
        let height  = publishOptionHeight / scaleDownFactor
        let bitrate = publishOptionBitrate / Int(scaleDownFactor)
        videoLayers.append(VideoLayer(
            dimensions: CMVideoDimensions(width: Int32(width), height: Int32(height)),
            quality: quality, maxBitrate: bitrate, sfuQuality: .init(quality)
        ))
        scaleDownFactor *= 2      // mỗi bậc: /2 chiều, /2 bitrate
    }
    if spatialLayersRequired < 3 {
        videoLayers = videoLayers.dropLast(videoLayers.count - spatialLayersRequired)
    }
    return videoLayers
}
```

**SVC (VP9/AV1)** — một stream duy nhất chứa nhiều layer lồng nhau. Scalability mode được encode thành string chuẩn WebRTC:

```swift
// Models/PublishOptions.swift:70-100
struct CapturingLayers: Sendable, Hashable, CustomStringConvertible {
    var spatialLayers: Int
    var temporalLayers: Int

    var scalabilityMode: String {
        var components = ["L", "\(spatialLayers)", "T", "\(temporalLayers)"]
        if spatialLayers > 1 { components.append("_KEY") }
        return components.joined()      // ví dụ "L3T3_KEY"
    }
}
```

### 5.3 Publish options — server điều khiển encode

`PublishOptions` gần như hoàn toàn do SFU quyết định, client chỉ thực thi:

```swift
// Models/PublishOptions.swift:31-36 (audio), 101-115 (video)
init(_ publishOption: Stream_Video_Sfu_Models_PublishOption) {
    id = Int(publishOption.id)
    codec = .init(publishOption.codec)
    bitrate = Int(publishOption.bitrate)
}

// video:
var id: Int
var codec: VideoCodec
var capturingLayers: CapturingLayers
var bitrate: Int
var frameRate: Int
var dimensions: CGSize
var fmtp: String                      // format parameters (profile-level-id...)
```

`fmtp` được tra từ chính WebRTC, không tự đoán:

```swift
// WebRTC/v2/WebRTCCoordinator.swift:452-466
func updatePublishOptions(preferredVideoCodec: VideoCodec, maxBitrate: Int) async {
    // For the request videoCodec, we query WebRTC to get the best fmtp to use.
    let fmtp = stateAdapter
        .peerConnectionFactory
        .codecCapabilities(for: preferredVideoCodec)?.fmtp ?? ""
    if fmtp.isEmpty {
        log.warning("Unable to detect fmtp for video codec:\(preferredVideoCodec).")
    }
    ...
}
```

`AudioPublishOptions`/`VideoPublishOptions` có `Hashable`/`Equatable` **chỉ theo `(id, codec)`**, bỏ qua bitrate:

```swift
// Models/PublishOptions.swift:56-67
func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    hasher.combine(codec)
}
static func == (lhs: AudioPublishOptions, rhs: AudioPublishOptions) -> Bool {
    lhs.id == rhs.id && lhs.codec == rhs.codec
}
```

Đây là quyết định có chủ đích: **đổi bitrate không được tạo transceiver mới**, chỉ update encoding parameters của transceiver hiện có. Nếu equality tính cả bitrate thì mỗi lần server điều chỉnh bitrate sẽ sinh transceiver mới và buộc renegotiate — cực đắt.

### 5.4 Publish: một transceiver cho mỗi publish option

```swift
// PeerConnection/MediaAdapters/LocalMediaAdapters/LocalVideoMediaAdapter.swift:227-260
func publish() async throws {
    guard !primaryTrack.isEnabled else { return }
    try await startVideoCapturingSession()
    primaryTrack.isEnabled = true

    publishOptions.forEach {
        self.addTransceiverIfRequired(
            for: $0,
            with: self.primaryTrack.clone(from: self.peerConnectionFactory)  // clone track!
        )
    }

    let activePublishOptions = Set(self.publishOptions)
    transceiverStorage.forEach {
        if activePublishOptions.contains($0.key) {
            $0.value.track.isEnabled = true
            $0.value.transceiver.sender.track = $0.value.track
        } else {
            $0.value.track.isEnabled = false
            $0.value.transceiver.sender.track = nil    // giữ transceiver, bỏ track
        }
    }
}
```

Ba điểm quan trọng:

1. **`primaryTrack.clone(...)`** — mỗi publish option (mỗi codec) cần track riêng, nhưng dùng chung một `RTCVideoSource`. Nên một lần capture có thể feed cho nhiều encoder cùng lúc (ví dụ publish đồng thời H264 cho iOS cũ và VP9 cho client mới).
2. **Không xóa transceiver khi unpublish**, chỉ `sender.track = nil`. Xóa transceiver buộc renegotiate SDP; giữ lại thì bật/tắt camera trở thành thao tác cực rẻ.
3. Transceiver tạo `sendOnly` + gán `streamIds` để SFU map track ↔ participant:

```swift
// LocalVideoMediaAdapter.swift:783-812
guard let transceiver = peerConnection.addTransceiver(
    trackType: .video,
    with: track,
    init: .init(
        trackType: .video,
        direction: .sendOnly,
        streamIds: streamIds,
        videoOptions: options      // → encodings (rid, scaleResolutionDownBy, maxBitrate...)
    )
) else { ... }

let params = transceiver.sender.parameters
if params.setDegradationPreference(options.degradationPreference) {
    transceiver.sender.parameters = params
}
```

`degradationPreference` là lựa chọn "khi thiếu bandwidth thì hy sinh gì": giảm resolution (`maintainFramerate`) hay giảm fps (`maintainResolution`). Screenshare nên giữ resolution, video call nên giữ framerate.

---

## 6. NEGOTIATION — SDP đi đâu

### 6.1 Chiều publisher: offer từ client

```swift
// PeerConnection/RTCPeerConnectionCoordinator.swift:785-846
private func negotiate(constraints: RTCMediaConstraints = .defaultConstraints) async {
    let offer = try await createOffer(constraints: constraints)
    try await setLocalDescription(offer)
    try await ensureSetUpHasBeenCompleted()

    let tracksInfo = WebRTCJoinRequestFactory(capabilities: clientCapabilities.map(\.rawValue))
        .buildAnnouncedTracks(self, collectionType: .allAvailable)

    // debug-only validation
    validateTracksAndTransceivers(.video, tracksInfo: tracksInfo)
    validateTracksAndTransceivers(.screenshare, tracksInfo: tracksInfo)

    let sessionDescription = try await sfuAdapter.setPublisher(
        sessionDescription: offer.sdp,
        tracks: tracksInfo,          // ← metadata NGOÀI SDP
        for: sessionId
    )
    try await setRemoteDescription(.init(type: .answer, sdp: sessionDescription.sdp))
}
```

Điểm thiết kế đáng lưu ý: **track metadata gửi song song với SDP**, không nhét hết vào SDP. SFU nhận được `tracks: [Stream_Video_Sfu_Models_TrackInfo]` mô tả rõ mỗi track là loại gì, layer nào, thay vì phải parse SDP để suy ra.

Đi qua HTTP POST:

```swift
// WebRTC/v2/SFU/SFUAdapter.swift:427-453
func setPublisher(
    sessionDescription: String,
    tracks: [Stream_Video_Sfu_Models_TrackInfo],
    for sessionId: String
) async throws -> Stream_Video_Sfu_Signal_SetPublisherResponse {
    var request = Stream_Video_Sfu_Signal_SetPublisherRequest()
    request.sdp = sessionDescription
    request.sessionID = sessionId
    request.tracks = tracks

    let response = try await executeTask(retryPolicy: .fastCheckValue { true }) { [weak self] in
        try Task.checkCancellation()
        guard let self, isConnected == true else { throw ClientError("Not connected.") }
        return try await signalService.setPublisher(setPublisherRequest: request)
    }
    if response.error.code != .unspecified && !response.error.message.isEmpty {
        throw response.error
    }
    return response
}
```

### 6.2 Chiều subscriber: offer từ SFU

Ngược lại — SFU chủ động offer khi có người mới publish:

```swift
// RTCPeerConnectionCoordinator.swift:853+
private func handleSubscriberOffer(_ event: Stream_Video_Sfu_Event_SubscriberOffer) async {
    let offerSdp = event.sdp
    try await setRemoteDescription(.init(type: .offer, sdp: offerSdp))
    // → createAnswer → setLocalDescription → sfuAdapter.sendAnswer(...)
}
```

Event đến qua **WebSocket** (`SubscriberOffer`), answer đi ra qua **HTTP POST** (`sendAnswer`). Bất đối xứng nhưng hợp lý: push cần WS, request/response cần HTTP.

```swift
// SFUAdapter.swift:506-528
func sendAnswer(
    sessionDescription: String,
    peerType: Stream_Video_Sfu_Models_PeerType,
    for sessionId: String
) async throws {
    var request = Stream_Video_Sfu_Signal_SendAnswerRequest()
    request.sessionID = sessionId
    request.peerType = peerType
    request.sdp = sessionDescription
    ...
}
```

### 6.3 Join — SDP đi qua WebSocket

Lúc join lần đầu thì khác: SDP của **cả hai** peer connection được gói trong một `JoinRequest` gửi qua WebSocket.

```swift
// WebRTC/v2/WebRTCJoinRequestFactory.swift:42-80
func buildRequest(
    with connectionType: ConnectionType,
    coordinator: WebRTCCoordinator,
    publisherSdp: String,
    subscriberSdp: String,
    reconnectAttempt: UInt32,
    publisher: RTCPeerConnectionCoordinator?,
    ...
) async -> Stream_Video_Sfu_Event_JoinRequest {
    var result = Stream_Video_Sfu_Event_JoinRequest()
    result.clientDetails = SystemEnvironment.clientDetails
    result.sessionID = await coordinator.stateAdapter.sessionID
    result.publisherSdp = publisherSdp
    result.subscriberSdp = subscriberSdp
    result.fastReconnect = connectionType.isFastReconnect
    result.token = await coordinator.stateAdapter.token
    result.preferredPublishOptions = await buildPreferredPublishOptions(
        coordinator: coordinator, publisherSdp: publisherSdp
    )
    result.capabilities = capabilities
    result.unifiedSessionID = coordinator.stateAdapter.unifiedSessionId
    ...
}
```

`subscriberSdp` lúc join là một SDP "giả" — tạo từ `RTCTemporaryPeerConnection` chỉ để **khai báo khả năng decode** của thiết bị:

```swift
// StateMachine/Stages/WebRTCCoordinator+Joining.swift:324-336
private func buildSessionDescription(...) async throws -> String {
    try await RTCTemporaryPeerConnection(...)
    ...
}
```

SFU đọc SDP này để biết client decode được codec nào, rồi mới quyết định forward layer/codec nào — trước khi peer connection thật tồn tại.

### 6.4 SDP Parser tự viết

SDK tự parse SDP thay vì chỉ dựa vào WebRTC API:

```
WebRTC/v2/SDP Parsing/
├── Parser/SDPParser.swift
├── Parser/Visitors/SDPLineVisitor.swift
├── Parser/Visitors/RTPMapVisitor.swift        — map codec name → payload type
├── Parser/Visitors/StereoEnableVisitor.swift  — bật stereo bằng cách sửa fmtp
└── Models/SupportedPrefix.swift, MidStereoInformation.swift
```

Kiến trúc visitor, prefix khai báo bằng enum:

```swift
// SDP Parsing/Models/SupportedPrefix.swift:25
case fmtp = "a=fmtp:"
```

Dùng để làm gì:

**(a) Lấy payload type để gửi cho SFU** — SDP do WebRTC sinh nên payload type là động, phải parse ra:

```swift
// WebRTCJoinRequestFactory.swift (buildPreferredPublishOptions)
let sdpParser = SDPParser()
let rtmapVisitor = RTPMapVisitor()
sdpParser.registerVisitor(rtmapVisitor)
await sdpParser.parse(sdp: publisherSdp)

return await coordinator.stateAdapter.publishOptions.source.map {
    var publishOption = $0
    publishOption.codec.payloadType = UInt32(rtmapVisitor.payloadType(for: $0.codec.name) ?? 0)
    return publishOption
}
```

**(b) Bật stereo** — `StereoEnableVisitor` sửa fmtp line (`fmtpLineReplacements`), vì WebRTC không có API bật `stereo=1` cho Opus.

---

## 7. NHẬN & DECODE

### 7.1 Track đến như thế nào

Video và audio đi **hai đường khác nhau** trong WebRTC iOS API — SDK phải xử lý riêng.

**Video** — qua `RTCMediaStream`:

```swift
// PeerConnection/MediaAdapters/VideoMediaAdapter.swift:259-277
private func add(_ stream: RTCMediaStream) { ... }
private func remove(_ stream: RTCMediaStream) { ... }
```

**Audio** — không có stream, chỉ có receiver callback:

```swift
// PeerConnection/MediaAdapters/LocalMediaAdapters/RemoteAudioMediaAdapter.swift:9-13
/// Observes remote audio receivers on a subscriber peer connection.
///
/// WebRTC exposes remote audio through receiver callbacks rather than local
/// media streams. This adapter converts those callbacks into `TrackEvent`
/// values so shared track storage can attach and detach `RTCAudioTrack`
/// instances from `CallParticipant`.
```

Adapter này chuẩn hóa cả hai về cùng một `TrackEvent`:

```swift
// RemoteAudioMediaAdapter.swift:57-72
peerConnection
    .publisher(eventType: StreamRTCPeerConnection.AddedReceiverEvent.self)
    .compactMap(AudioTrack.init)
    .receive(on: processingQueue)              // OperationQueue(maxConcurrentOperationCount: 1)
    .sink { [weak self] in self?.processAddedTrack($0) }
    .store(in: disposableBag)

peerConnection
    .publisher(eventType: StreamRTCPeerConnection.RemovedReceiverEvent.self)
    .receive(on: processingQueue)
    .compactMap { [weak self] in self?.audioReceivers[$0.receiver.receiverId] }
    .sink { [weak self] in self?.processRemovedTrack($0) }
    .store(in: disposableBag)
```

Delegate của `RTCPeerConnection` được bọc thành Combine publisher (`StreamRTCPeerConnection+DelegatePublisher.swift`) — cho phép nhiều adapter cùng observe một peer connection mà không tranh delegate.

### 7.2 Lưu và gắn track vào participant

```swift
// WebRTC/v2/WebRTCStateAdapter.swift:589-599
func didAddTrack(_ track: RTCMediaStreamTrack, type: TrackType, for id: String) async {
    trackStorage.addTrack(track, type: type, for: id)
    if id != sessionID {
        await mediaFrameReporter.add(track, type: type)   // theo dõi có frame về không
    }
    enqueue { $0 }        // trigger participant recompute
}
```

`WebRTCTrackStorage` là storage thread-safe, tách 3 loại track:

```swift
// WebRTC/v2/WebRTCTrackStorage.swift:16-26
final class WebRTCTrackStorage: @unchecked Sendable {
    private let accessingQueue = UnfairQueue()
    private var audioTracks: [String: RTCAudioTrack] = [:]
    private var videoTracks: [String: RTCVideoTrack] = [:]
    private var screenShareTracks: [String: RTCVideoTrack] = [:]
}
```

Lookup có **fallback hai tầng** — vì SFU dùng `trackLookupPrefix` chứ không phải `sessionId`:

```swift
// WebRTCStateAdapter.swift:620-634
func track(for participant: CallParticipant, of trackType: TrackType) -> RTCMediaStreamTrack? {
    if let trackLookupPrefix = participant.trackLookupPrefix {
        return trackStorage.track(for: trackLookupPrefix, of: trackType)
            ?? trackStorage.track(for: participant.sessionId, of: trackType)
    } else {
        return trackStorage.track(for: participant.sessionId, of: trackType)
    }
}
```

`MediaFrameReporter` là một chi tiết hay: nó theo dõi track đã thực sự có frame về chưa. Phân biệt được "đã subscribe nhưng chưa có media" (vấn đề mạng) với "chưa subscribe" (vấn đề logic) — hai lỗi trông giống nhau trên UI nhưng nguyên nhân hoàn toàn khác.

### 7.3 Client điều khiển mình nhận gì

Đây là cơ chế bandwidth quan trọng nhất phía nhận. Client **chủ động khai báo** muốn nhận track nào ở kích thước nào:

```swift
// WebRTC/v2/Extensions/CallParticipant+Convenience.swift:18-70
func trackSubscriptionDetails(incomingVideoQualitySettings: IncomingVideoQualitySettings)
    -> [Stream_Video_Sfu_Signal_TrackSubscriptionDetails] {
    var result = [Stream_Video_Sfu_Signal_TrackSubscriptionDetails]()

    if hasVideo, !incomingVideoQualitySettings.isVideoDisabled(for: sessionId) {
        result.append(.init(
            for: userId, sessionId: sessionId,
            /// If the session is covered by the incoming video quality setting, use the
            /// target size. Otherwise, use the track's size.
            size: incomingVideoQualitySettings.contains(sessionId) == true
                ? incomingVideoQualitySettings.targetSize
                : trackSize,               // ← kích thước view THẬT trên màn hình
            type: .video
        ))
    }
    if hasAudio {
        result.append(.init(for: userId, sessionId: sessionId, type: .audio))
    }
    if isScreensharing {
        result.append(.init(for: userId, sessionId: sessionId, type: .screenShare))
        /// We subscribe to screenShareAudio anytime a user is screenSharing. In the future
        /// that should be driven by events to know if the user is actually publishing audio.
        result.append(.init(for: userId, sessionId: sessionId, type: .screenShareAudio))
    }
    return result
}
```

**`size: trackSize` là chìa khóa của Dynascale.** Client nói "tôi đang render participant này trong ô 120×120", SFU chọn forward layer `q` thay vì `f`. Không cần transcode, không tốn CPU server, chỉ chọn stream nào để forward. Tile nhỏ → nhận layer nhỏ → tiết kiệm băng thông và CPU decode.

Kích thước này chảy về từ UI:

```swift
// StreamVideoSwiftUI/CallView/VideoRenderer/VideoRenderer.swift:143-175
public func handleViewRendering(
    for participant: CallParticipant,
    onTrackSizeUpdate: @escaping @Sendable (CGSize, CallParticipant) -> Void
) {
    if let track = participant.track {
        self.participant = participant
        add(track: track)
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.01) { [weak self] in
            let prev = participant.trackSize
            if let viewSize, prev != viewSize {
                onTrackSizeUpdate(viewSize, participant)     // → Call.updateTrackSize
            }
        }
    }
}
```

Vòng khép kín: `layoutSubviews` → `viewSize` → `updateTrackSize` → `CallParticipant.trackSize` → `updateSubscriptions` → SFU đổi layer.

### 7.4 Adapter chống spam subscription

Participant list thay đổi liên tục (ai đó mute, đổi tile, scroll). Nếu mỗi thay đổi đều gọi `updateSubscriptions` thì sẽ ngập request.

```swift
// WebRTC/v2/UpdateSubscriptions/WebRTCUpdateSubscriptionsAdapter.swift:18-36
final class WebRTCUpdateSubscriptionsAdapter: @unchecked Sendable {
    private let processingQueue = OperationQueue(maxConcurrentOperationCount: 1)
    private let publisher: AnyPublisher<(WebRTCStateAdapter.ParticipantsStorage, IncomingVideoQualitySettings), Never>

    /// Stores the last set of track subscription details sent to the SFU.
    private var lastTrackSubscriptionDetails:
        [Stream_Video_Sfu_Signal_TrackSubscriptionDetails] = []
```

Ba lớp bảo vệ:
1. `CombineLatest(participants, qualitySettings)` — gộp hai nguồn thay đổi thành một
2. `OperationQueue(maxConcurrentOperationCount: 1)` — serialize, không có race
3. `lastTrackSubscriptionDetails` — **diff, chỉ gửi khi thực sự khác**

`updateSubscriptions` dùng retry policy tên rất đặc trưng:

```swift
// SFUAdapter.swift:496-505
/// - Note: This method uses a retry policy named ".neverGonnaGiveYouUp", which will persistently
/// retry until successful.
```

Retry vô hạn là đúng ở đây: nếu subscription update thất bại thì user sẽ **thấy màn hình đen** cho participant đó — trạng thái sai vĩnh viễn cho tới lần update sau. Khác hẳn `sendStats` (fail thì bỏ qua được).

### 7.5 Decode

Decode hoàn toàn nằm trong libwebrtc, cấu hình một dòng:

```swift
// PeerConnectionFactory.swift:43, 52
decoderFactory: Self.defaultDecoder,
private nonisolated(unsafe) static let defaultDecoder = RTCDefaultVideoDecoderFactory()
```

Phía Swift chỉ đọc lại kết quả để báo cáo:

```swift
// SFUAdapter.swift:355-356
statsRequest.encodeStats = encodeStats ?? []
statsRequest.decodeStats = decodeStats ?? []
```

Codec decode được là giao của `supportedVideoCodecDecoding` (`PeerConnectionFactory.swift:70-72`) và những gì SFU có — thương lượng qua `subscriberSdp` lúc join (mục 6.3).

---

## 8. PHÁT LẠI

### 8.1 Video — Metal renderer

```swift
// StreamVideoSwiftUI/CallView/VideoRenderer/VideoRenderer.swift:13
public class VideoRenderer: RTCVideoRenderingView, @unchecked Sendable {
```

Render bằng Metal (`MTKView`), không phải `CALayer`:

```swift
// VideoRenderer.swift:47
private lazy var metalView: MTKView? = { subviews.compactMap { $0 as? MTKView }.first }()
```

Gắn track vào renderer:

```swift
// VideoRenderer.swift:104-113
public func add(track: RTCVideoTrack) {
    queue.sync {
        self.track?.remove(self)     // bỏ track cũ trước
        self.track = nil
        self.track = track
        track.add(self)              // RTCVideoRenderer nhận frame đã decode
    }
}
```

**Điều tiết theo nhiệt độ máy** — giảm fps render khi nóng:

```swift
// VideoRenderer.swift:64-79
cancellable = thermalStateObserver.statePublisher.sink { [weak self] state in
    switch state {
    case .nominal, .fair:
        self.preferredFramesPerSecond = UIScreen.main.maximumFramesPerSecond
    case .serious:
        self.preferredFramesPerSecond = Int(Double(UIScreen.main.maximumFramesPerSecond) * 0.5)
    case .critical:
        self.preferredFramesPerSecond = Int(Double(UIScreen.main.maximumFramesPerSecond) * 0.4)
    @unknown default:
        self.preferredFramesPerSecond = UIScreen.main.maximumFramesPerSecond
    }
}
self.renderingBackend = videoRenderingOptions.backend
self.maxInFlightFrames = videoRenderingOptions.maxInFlightFrames
```

`maxInFlightFrames` giới hạn số frame đang chờ GPU — chống memory spike khi render chậm hơn tốc độ frame về.

Có một comment cảnh báo về main-thread block rất cụ thể:

```swift
// VideoRenderer.swift:135-141
/// - Important: This method can run on the main thread during SwiftUI
///   updates. Reading `RTCVideoTrack.isEnabled` here is unsafe because its
///   proxy may wait for WebRTC's signaling thread and block UI updates.
```

Đây là bug đã từng xảy ra thật (có trong CHANGELOG 1.51.0: *"prevented participant video rendering from blocking the main thread while querying WebRTC track state"*).

Cleanup đúng cách khi rời khỏi view hierarchy:

```swift
// VideoRenderer.swift:122-131
override public func willMove(toSuperview newSuperview: UIView?) {
    _superviewSubject.send(newSuperview)
    super.willMove(toSuperview: newSuperview)
    if newSuperview == nil {
        setSize(.zero)      // giải phóng frame đã render
    }
}

deinit {
    cancellable?.cancel()
    track?.remove(self)     // gỡ khỏi track, tránh leak
}
```

### 8.2 Renderer pool

Tạo/hủy renderer Metal liên tục rất đắt. Số participant thay đổi thường xuyên → phải pool:

```swift
// StreamVideoSwiftUI/Utils/VideoRendererPool/VideoRendererPool.swift:11-49
final class VideoRendererPool: @unchecked Sendable {
    private let pool: ReusePool<VideoRenderer>

    @MainActor
    init(initialCapacity: Int = 0) {
        pool = ReusePool(initialCapacity: initialCapacity) {
            VideoRenderer(frame: CGRect(origin: .zero, size: .zero))
        }
        // Observe call end notifications to release all renderers when a call ends
        callEndedCancellable = NotificationCenter.default
            .publisher(for: Notification.Name(CallNotification.callEnded))
            .sink { [weak self] _ in self?.pool.releaseAll() }
    }

    @MainActor func acquireRenderer(size: CGSize) -> VideoRenderer { ... }
    func releaseRenderer(_ renderer: VideoRenderer) { pool.release(renderer) }
}
```

Cùng nhóm còn có `StreamPixelBufferRepository` (pool `CVPixelBuffer` cho Picture-in-Picture).

### 8.3 Audio

Không có "render audio" trong Swift. `RTCAudioTrack` được gắn vào peer connection, libwebrtc mix mọi remote track rồi phát qua `AVAudioEngine` bên trong ADM. Swift chỉ điều khiển:

```swift
// AudioDeviceModule.swift:315, 344, 264, 450
func setPlayout(_ isActive: Bool) throws
func resetPlayout()
func setStereoPlayoutPreference(_ isPreferred: Bool)
func refreshStereoPlayoutState()
```

Chọn loa/tai nghe/Bluetooth đi qua `RTCAudioStore` reducer (category + mode + options), không set `AVAudioSession` trực tiếp — xem mục 4.3.

---

## 9. Hai vòng điều khiển chất lượng

Đây là phần thông minh nhất của pipeline: có **hai vòng feedback độc lập**, một cho chiều gửi, một cho chiều nhận.

### 9.1 Vòng gửi — SFU điều khiển encoder của client

```
       SFU đo bandwidth/congestion của publisher
                        │
                        ▼
       ChangePublishQuality event (qua WebSocket)
                        │
                        ▼
       LocalVideoMediaAdapter.changePublishQuality(...)
                        │
         ┌──────────────┴──────────────┐
         ▼                             ▼
  sender.parameters              adaptCaptureDimensions
  (bật/tắt layer,                (giảm luôn resolution
   đổi bitrate/fps/               capture nếu layer cao
   scalabilityMode)               đã tắt hết)
```

```swift
// LocalVideoMediaAdapter.swift:393-527
func changePublishQuality(with layerSettings: [Stream_Video_Sfu_Event_VideoSender]) {
    processingQueue.addTaskOperation { [weak self] in
        for videoSender in layerSettings {
            let key = PublishOptions.VideoPublishOptions(
                id: Int(videoSender.publishOptionID),
                codec: VideoCodec(videoSender.codec)
            )
            guard let transceiver = transceiverStorage.get(for: key)?.transceiver else { continue }

            var hasChanges = false
            let params = transceiver.sender.parameters

            let isUsingSVCCodec = {
                if let preferredCodec = params.codecs.first {
                    return VideoCodec(preferredCodec).isSVC
                }
                return false
            }()

            for encoding in params.encodings {
                let layerSettings = isUsingSVCCodec
                    // for SVC, we only have one layer (q) and often rid is omitted
                    ? videoSender.layers.first
                    // for non-SVC, we need to find the layer by rid (simulcast)
                    : videoSender.layers.first(where: { $0.name == encoding.rid })

                // flip 'active' flag only when necessary
                if layerSettings?.active != encoding.isActive {
                    encoding.isActive = layerSettings?.active ?? false
                    hasChanges = true
                }
                guard let layerSettings else { updatedEncodings.append(encoding); continue }

                if layerSettings.scaleResolutionDownBy >= 1,
                   layerSettings.scaleResolutionDownBy != Float(truncating: encoding.scaleResolutionDownBy ?? 0) {
                    encoding.scaleResolutionDownBy = .init(value: layerSettings.scaleResolutionDownBy)
                    hasChanges = true
                }
                if layerSettings.maxBitrate > 0,
                   layerSettings.maxBitrate != Int32(truncating: encoding.maxBitrateBps ?? 0) {
                    encoding.maxBitrateBps = .init(value: layerSettings.maxBitrate)
                    hasChanges = true
                }
                if layerSettings.maxFramerate > 0, ... { encoding.maxFramerate = ...; hasChanges = true }
                if !layerSettings.scalabilityMode.isEmpty,
                   layerSettings.scalabilityMode != encoding.scalabilityMode {
                    encoding.scalabilityMode = layerSettings.scalabilityMode
                    hasChanges = true
                }
                updatedEncodings.append(encoding)
            }

            guard hasChanges else {
                log.info("Update publish quality, no change: ...")
                return                        // không ghi lại parameters nếu không đổi
            }
            params.encodings = updatedEncodings
            transceiver.sender.parameters = params
        }
        await adaptCaptureDimensions(for: layerSettings)
    }
}
```

Ba điểm tinh tế:
- **Xử lý SVC và simulcast khác nhau ngay trong cùng vòng lặp**: SVC không có `rid` nên lấy `layers.first`; simulcast phải match theo `rid`.
- **Cờ `hasChanges`**: `transceiver.sender.parameters = params` là setter đắt (đi xuống C++ và có thể trigger reconfigure encoder). Chỉ ghi khi thật sự khác.
- **`adaptCaptureDimensions`**: nếu SFU tắt hết layer cao, không chỉ dừng encode mà **giảm luôn resolution capture** — tiết kiệm cả CPU capture, filter, và encode. Đây là tối ưu mà nhiều SDK bỏ sót.

### 9.2 Vòng nhận — client điều khiển SFU

```
    View layout thay đổi (VideoRenderer.layoutSubviews)
                        │
                        ▼
    onTrackSizeUpdate → Call.updateTrackSize
                        │
                        ▼
    CallParticipant.trackSize
                        │
                        ▼
    WebRTCUpdateSubscriptionsAdapter (CombineLatest + diff)
                        │
                        ▼
    updateSubscriptions (HTTP POST) — kèm size mong muốn
                        │
                        ▼
    SFU chọn layer f/h/q để forward
```

Chồng lên vòng này còn có `IncomingVideoQualitySettings` — app có thể **ép** giới hạn, bỏ qua size thật:

```swift
// Models/IncomingVideoQualitySettings.swift
// dùng ở CallParticipant+Convenience.swift:22-33
incomingVideoQualitySettings.isVideoDisabled(for: sessionId)   // tắt hẳn video 1 người
incomingVideoQualitySettings.contains(sessionId)               // người này bị override?
incomingVideoQualitySettings.targetSize                        // size bị ép
```

API công khai: `Call.setIncomingVideoQualitySettings(...)` (`Call.swift:1442`). Dùng cho audio-only mode, tiết kiệm data, hoặc call rất lớn.

### 9.3 Các vòng phụ

| Nguồn tín hiệu | Tác động | Code |
|---|---|---|
| Thermal state | Giảm fps **render** | `VideoRenderer.swift:64-79` |
| Camera system pressure | Giảm resolution **capture** | `CameraSystemPressureHandler` |
| App vào background | Mute video track | `ApplicationLifecycleVideoMuteAdapter.swift` |
| Battery yếu | Điều chỉnh chất lượng | `Utils/Battery/` |
| Proximity (áp tai) | Đổi audio route, tắt video | `Utils/Proximity/` |
| Participant không hoạt động | Auto leave | `Utils/ParticipantAutoLeavePolicy/` |
| Screen properties | Tính target size | `Utils/ScreenPropertiesAdapter/` |

---

## 10. Stats & telemetry

```
WebRTC/v2/Stats/
├── Collector/WebRTCStatsCollector.swift      — poll RTCStatsReport theo interval
├── Components/WebRTCStatsItemTransformer.swift
├── Components/WebRTCStatsCompressor.swift    — nén trước khi gửi
├── Components/WebRTCItemTransformerProcessingUnit.swift
├── Reporter/WebRTCStatsReporter.swift        — gom & gửi định kỳ
├── Traces/WebRTCTracesAdapter.swift          — trace event lifecycle
└── Models/
```

Stats lấy từ peer connection:

```swift
// RTCPeerConnectionCoordinator.swift:638
func statsReport() async throws -> StreamRTCStatisticsReport
```

Rồi gửi lên SFU qua HTTP POST:

```swift
// SFUAdapter.swift:347-372
func sendStats(
    _ report: CallStatsReport? = nil,
    for sessionId: String,
    unifiedSessionId: String,
    traces: String? = nil,
    thermalState: ProcessInfo.ThermalState? = nil,
    telemetry: Stream_Video_Sfu_Signal_Telemetry? = nil,
    encodeStats: [Stream_Video_Sfu_Models_PerformanceStats]? = nil,
    decodeStats: [Stream_Video_Sfu_Models_PerformanceStats]? = nil
) async throws {
    var statsRequest = Stream_Video_Sfu_Signal_SendStatsRequest()
    statsRequest.sessionID = sessionId
    statsRequest.sdk = "stream-ios"
    statsRequest.sdkVersion = SystemEnvironment.version
    statsRequest.webrtcVersion = SystemEnvironment.webRTCVersion
    statsRequest.publisherStats = report?.publisherRawStats?.jsonString ?? ""
    statsRequest.subscriberStats = report?.subscriberRawStats?.jsonString ?? ""
    statsRequest.deviceState = .init(thermalState)      // ← nhiệt độ máy!
    statsRequest.encodeStats = encodeStats ?? []
    statsRequest.decodeStats = decodeStats ?? []
    statsRequest.rtcStats = traces ?? ""
    statsRequest.telemetry = telemetry ?? .init()
    statsRequest.unifiedSessionID = unifiedSessionId
    ...
}
```

Gửi cả `thermalState` là chi tiết tinh: chất lượng kém vì máy nóng (throttle) khác hoàn toàn với kém vì mạng. Không có tín hiệu này thì backend không phân biệt được, và sẽ điều chỉnh bitrate sai hướng.

`unifiedSessionID` (`WebRTCStateAdapter.swift:38`) tồn tại xuyên qua mọi lần reconnect/migrate — cho phép backend nối các session rời rạc thành một trải nghiệm cuộc gọi để phân tích.

---

## 11. Reconnect ảnh hưởng media thế nào

```swift
// WebRTC/v2/StateMachine/Stages/WebRTCCoordinator+Stage.swift:303-317
enum ReconnectionStrategy: Equatable {
    case unknown, disconnected, fast(disconnectedSince: Date, deadline: TimeInterval),
         rejoin, migrate

    var next: ReconnectionStrategy {
        switch self {
        case .unknown, .disconnected: return .disconnected
        case .fast:                   return .rejoin
        case .rejoin, .migrate:       return self
        }
    }
}
```

| Chiến lược | Việc gì xảy ra với media | Chi phí |
|---|---|---|
| `.fast` | **ICE restart** — giữ peer connection, giữ transceiver, giữ encoder. Chỉ tìm đường mạng mới. | Rẻ nhất, ~vài trăm ms, media gần như không ngắt |
| `.rejoin` | JoinRequest mới, **peer connection mới**, track được announce lại. Session ID mới. | Trung bình, có ngắt hình/tiếng |
| `.migrate` | Đổi hẳn SFU edge. Giữ `previousSessionPublisher/Subscriber` chạy song song trong lúc chuyển. | Đắt nhất |

Migration có cơ chế chống mất media: context giữ peer connection cũ sống trong lúc thiết lập cái mới:

```swift
// WebRTCCoordinator+Stage.swift:57-60
var previousSessionPublisher: RTCPeerConnectionCoordinator?
var previousSessionSubscriber: RTCPeerConnectionCoordinator?
var previousSFUAdapter: SFUAdapter?
```

Giới hạn để tránh loop bệnh lý:

```swift
// WebRTCCoordinator+Stage.swift:63-84
var fastReconnectionMaxAttempts: Int = 3
/// Maximum number of `.rejoin` transitions allowed inside the rolling
/// `rejoinAttemptWindow`.
///
/// This is intentionally a burst guard, not a lifetime cap.
/// - If 10 rejoins happen within 2 minutes, the 11th rejoin inside that
///   same 2-minute window is rejected.
/// - If rejoins are 6 minutes apart, older attempts have already aged out
///   of the rolling window before the next one happens.
var rejoinMaxAttempts: Int = 10
```

Và một fix đáng chú ý trong CHANGELOG hiện tại (`#1231`):

> *Transient peer-connection disconnections no longer trigger an immediate full rejoin, allowing the existing ICE restart flow to recover the session.*

Tức là ưu tiên `.fast` — giữ media chạy — thay vì nhảy thẳng lên `.rejoin`.

---

## 12. Tổng hợp: trace một frame video

**Chiều gửi (mình → người khác):**

```
 1. AVCaptureSession bắt frame                     CameraCaptureHandler.swift:31
 2. RTCCameraVideoCapturer → delegate              StreamVideoCapturer.swift:69
 3. Áp filter (CIContext, GPU, in-place)           StreamVideoCaptureHandler.swift:64
 4. Sửa rotation (metadata, không rotate pixel)    StreamVideoCaptureHandler.swift:113
 5. → RTCVideoSource → RTCVideoTrack               PeerConnectionFactory.swift:110-125
 6. Track clone cho từng publish option            LocalVideoMediaAdapter.swift:227
 7. Transceiver sendOnly + encodings simulcast     LocalVideoMediaAdapter.swift:783
 8. libwebrtc encode (VideoToolbox / libvpx)       RTCVideoEncoderFactorySimulcast
 9. RTP packetize + SRTP encrypt                   libwebrtc
10. Gửi qua UDP (hoặc TCP/TURN)                    ICE-selected candidate pair
11. SFU nhận, chọn layer, forward cho từng peer    (server)
```

**Chiều nhận (người khác → mình):**

```
 1. UDP packet đến, SRTP decrypt, RTP depacketize  libwebrtc
 2. Jitter buffer + NACK/PLI recovery              libwebrtc
 3. Decode (VideoToolbox / libvpx)                 RTCDefaultVideoDecoderFactory
 4. didAdd(stream) / didAdd(rtpReceiver)           StreamRTCPeerConnection+DelegatePublisher
 5. → TrackEvent                                   VideoMediaAdapter.swift:259
                                                   RemoteAudioMediaAdapter.swift:57
 6. didAddTrack → WebRTCTrackStorage               WebRTCStateAdapter.swift:589
 7. Gắn vào CallParticipant.track                  WebRTCStateAdapter.swift:620
 8. VideoRenderer.add(track:)                      VideoRenderer.swift:104
 9. RTCVideoRenderer nhận frame → MTKView          VideoRenderer.swift:47
10. Metal render (fps điều tiết theo nhiệt)        VideoRenderer.swift:64
11. layoutSubviews → viewSize → updateTrackSize    VideoRenderer.swift:143
12. → updateSubscriptions → SFU đổi layer          WebRTCUpdateSubscriptionsAdapter.swift
```

---

## 13. Nhận xét kỹ thuật

### Làm tốt

**1. Phân chia trách nhiệm đúng chỗ.** SDK không cố reimplement WebRTC. Nó làm đúng phần mà một SDK ứng dụng nên làm: capture chỉnh chu, chọn codec/layer, quản lý subscription, xử lý ca biên iOS (nhiệt độ, background, CallKit, ReplayKit). Phần transport để cho libwebrtc.

**2. Adaptive quality hai chiều, thật sự khép kín.** Hầu hết SDK chỉ có một chiều (server đẩy bitrate xuống). Ở đây `trackSize` từ view layout thật chảy ngược lên SFU, và ngược lại `ChangePublishQuality` từ SFU chảy xuống tới cả **capture resolution**. Không có bước nào bị hở.

**3. Simulcast và SVC được xử lý như hai công dân bình đẳng.** `isSVC`, `scalabilityMode`, và nhánh `videoSender.layers.first` vs `first(where: rid)` cho thấy hiểu rõ khác biệt bản chất giữa hai kỹ thuật, không phải patch thêm.

**4. Tối ưu đúng chỗ đắt.** Track clone dùng chung `RTCVideoSource` (một lần capture, nhiều encoder). Filter render in-place. Rotation qua metadata. `VideoRendererPool` và `StreamPixelBufferRepository`. Cờ `hasChanges` trước khi ghi `sender.parameters`. Giữ transceiver khi unpublish. Diff subscription trước khi gửi. Mỗi cái đều nhắm vào một chi phí thật.

**5. Comment giải thích *tại sao*.** Thứ tự action handler, close code 4001/4002, `deinit` của `PeerConnectionFactory`, cảnh báo đọc `RTCVideoTrack.isEnabled` trên main thread — đều là kiến thức mua bằng bug production, và đều được ghi lại tại chỗ.

**6. Retry policy phân tầng theo hậu quả.** `updateSubscriptions` retry vô hạn (fail = màn hình đen vĩnh viễn). `setPublisher` retry có kiểm tra `isConnected`. Twirp retry theo `error.shouldRetry` của server. `sendStats` fail thì bỏ. Không dùng một retry policy cho mọi thứ.

### Cần lưu ý

**1. Hai code path capture song song.** `usesProcessingPipeline` chọn giữa `StreamVideoProcessPipeline` (mới, functional) và `StreamVideoCaptureHandler` (cũ, đang là mặc định). Cộng thêm `usesNewCapturingPipeline` cho action handlers. Hai flag, bốn tổ hợp — đây là nợ migration, cần chốt một đường.

**2. Filter chạy trên `OperationQueue`, không đảm bảo real-time.** `maxConcurrentOperationCount: 1` giữ đúng thứ tự nhưng nếu filter chậm hơn frame interval thì queue dồn → tăng latency mà không có cơ chế drop frame. Filter nặng (blur background) trên máy yếu là rủi ro thực tế.

**3. `subscribe screenShareAudio` vô điều kiện.** Comment đã tự thừa nhận:
> *We subscribe to screenShareAudio anytime a user is screenSharing. In the future that should be driven by events to know if the user is actually publishing audio.*

Tốn một subscription cho track có thể không tồn tại.

**4. Không có audio-only fast path rõ ràng.** Audio-only phải thực hiện qua `IncomingVideoQualitySettings.isVideoDisabled(...)` cho từng session, chứ không có một switch ở tầng transport. Với audio room / large call thì đây là đường vòng.

**5. `@unchecked Sendable` dày đặc trong pipeline.** `StreamVideoCaptureHandler`, `LocalVideoMediaAdapter`, `WebRTCTrackStorage`, `PeerConnectionFactory`, `SFUAdapter` — tất cả đều `@unchecked`. Media pipeline chạy trên nhiều thread (capture queue, WebRTC signaling/worker thread, main thread render, OperationQueue). An toàn hiện dựa vào `UnfairQueue`/`OperationQueue`/`@Atomic` bằng kỷ luật, chưa được compiler kiểm chứng. Đây là mảng rủi ro cao nhất vì bug concurrency ở đây biểu hiện thành crash ngẫu nhiên hoặc frame corruption, rất khó tái tạo.

**6. `LocalVideoMediaAdapter` 828 dòng.** Nó gánh cả capture session lifecycle, transceiver management, publish quality, camera controls (zoom/focus/photo), và capture dimension adaptation. Nhiều trách nhiệm quá cho một file; `changePublishQuality` (135 dòng) và phần camera controls đều tách được.

---

## Phụ lục: bảng tra file

| Mối quan tâm | File |
|---|---|
| Điều phối capture | `WebRTC/v2/VideoCapturing/StreamVideoCapturer.swift` |
| Camera capture | `WebRTC/v2/VideoCapturing/ActionHandlers/Camera/*.swift` (8 handler) |
| Frame delivery + filter | `WebRTC/VideoCapturing/StreamVideoCaptureHandler.swift` |
| Pipeline node (mới) | `WebRTC/v2/VideoCapturing/StreamVideoProcessPipeline/` |
| Screenshare in-app | `WebRTC/v2/VideoCapturing/ActionHandlers/ScreenShare/` |
| Broadcast extension IPC | `WebRTC/Screensharing/` (8 files) |
| Factory codec/encoder | `WebRTC/PeerConnectionFactory.swift` |
| Codec model | `Models/VideoCodec.swift`, `Models/AudioCodec.swift` |
| Simulcast layer | `Models/VideoLayer.swift`, `WebRTC/v2/Extensions/Protobuf/*PublishOption+VideoLayers.swift` |
| Publish options | `Models/PublishOptions.swift` |
| Publish video | `WebRTC/v2/PeerConnection/MediaAdapters/LocalMediaAdapters/LocalVideoMediaAdapter.swift` |
| Publish audio | `.../LocalAudioMediaAdapter.swift` |
| Nhận audio remote | `.../RemoteAudioMediaAdapter.swift` |
| Nhận video remote | `WebRTC/v2/PeerConnection/MediaAdapters/VideoMediaAdapter.swift` |
| Peer connection | `WebRTC/v2/PeerConnection/RTCPeerConnectionCoordinator.swift` |
| ICE config | `WebRTC/RTCConfiguration+Default.swift`, `Models/ConnectOptions.swift` |
| Trickle ICE | `WebRTC/v2/PeerConnection/Adapters/ICEAdapter.swift` |
| ICE state | `WebRTC/v2/PeerConnection/Adapters/ICEConnectionStateAdapter.swift` |
| SFU signaling (HTTP) | `protobuf/sfu/signal_rpc/signal.twirp.swift` |
| SFU adapter | `WebRTC/v2/SFU/SFUAdapter.swift` |
| SFU WebSocket | `WebRTC/v2/SFU/SFUWebSocket.swift` |
| SFU events | `WebRTC/v2/SFU/SFUEventAdapter.swift` |
| Join request | `WebRTC/v2/WebRTCJoinRequestFactory.swift` |
| Auth + ICE servers | `WebRTC/v2/WebRTCAuthenticator.swift` |
| SDP parsing | `WebRTC/v2/SDP Parsing/` |
| Track storage | `WebRTC/v2/WebRTCTrackStorage.swift` |
| State trung tâm | `WebRTC/v2/WebRTCStateAdapter.swift` |
| Subscription | `WebRTC/v2/UpdateSubscriptions/WebRTCUpdateSubscriptionsAdapter.swift` |
| Subscription details | `WebRTC/v2/Extensions/CallParticipant+Convenience.swift` |
| Audio device module | `Utils/AudioSession/AudioDeviceModule/AudioDeviceModule.swift` |
| Audio session store | `Utils/AudioSession/RTCAudioStore/` |
| Audio processing | `Utils/AudioSession/AudioProcessing/` |
| Video render | `StreamVideoSwiftUI/CallView/VideoRenderer/VideoRenderer.swift` |
| Renderer pool | `StreamVideoSwiftUI/Utils/VideoRendererPool/` |
| Stats | `WebRTC/v2/Stats/` |
| HTTP client | `HTTPClient/HTTPClient.swift` |
| Endpoint | `Utils/EndpointConfig.swift` |
