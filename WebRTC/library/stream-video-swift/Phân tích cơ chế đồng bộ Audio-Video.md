# StreamVideo iOS — Phân tích cơ chế đồng bộ Audio/Video

> Tài liệu bổ trợ cho [`MEDIA_PIPELINE_ANALYSIS.md`](./MEDIA_PIPELINE_ANALYSIS.md).
> Câu hỏi cần trả lời: **SDK có cơ chế sync audio packets với video packets không?**
> Phạm vi: `Sources/` của repo này (branch `develop`, `1.52.0-SNAPSHOT`).

---

## Kết luận

**Không có cơ chế A/V sync nào được implement ở tầng Swift.**

Không phải "có nhưng đơn giản" — mà là **hoàn toàn không có code nào phục vụ việc này**. Không có logic ghép audio với video, không có bù trễ, không có phát hiện lệch, không có điều chỉnh playout.

Đồng bộ (ở mức nào đó) là **hệ quả mặc định của libwebrtc** — một binary dependency mà repo này không có source.

Tuy nhiên trong quá trình tra, tôi tìm ra một chi tiết cấu trúc đáng chú ý hơn cả câu trả lời "không": **audio và video được đặt vào hai `MediaStream` khác nhau**, cả ở chiều gửi lẫn chiều nhận. Chi tiết ở [mục 3](#3-phát-hiện-chính-audio-và-video-nằm-ở-hai-mediastream-khác-nhau).

---

## 1. Bằng chứng: những gì KHÔNG tồn tại

### 1.1 Không có từ khóa sync nào liên quan media timing

Grep toàn bộ `Sources/` (863 file Swift):

```bash
grep -rniE "lipsync|lip.sync|a/v sync|avsync|audio.video.sync|synchroniz|\
jitterBuffer|playoutDelay|playout_delay|estimatedPlayout|rtpTimestamp|\
ntpTimestamp|senderReport" Sources --include='*.swift'
```

Toàn bộ hit của `synchroniz*` đều là **thread-safety**, không phải media timing:

| File | Nội dung hit |
|---|---|
| `WebRTCTrackStorage.swift:12,16` | "reads are synchronized on a dedicated queue" — `UnfairQueue` |
| `MediaTransceiverStorage.swift:10,22` | "A serial queue used to synchronize access" |
| `AudioMediaAdapter.swift:27` | "A queue for synchronizing access to shared resources" |
| `VideoMediaAdapter.swift:27` | idem |
| `ScreenShareMediaAdapter.swift:27` | idem |
| `CallCache.swift:9` | "A queue for synchronizing access to the cache" |
| `Store.swift:45` | "its own synchronization through a serial operation queue" |
| `VideoRenderer.swift:26,142` | "DispatchQueue for synchronizing access to the video track" |
| `StreamCallAudioRecorder.swift:18,40,95` | sync với **call state**, không phải media clock |
| `CallStatsReport.swift:66` | SSRC = "**S**ynchronization **S**ource" — chỉ là tên field RTP |

Không một hit nào là cơ chế đồng bộ A/V.

### 1.2 Không có knob nào của WebRTC được chạm tới

| Knob | Trạng thái trong repo |
|---|---|
| `receiver.parameters` | **Không có** một lần xuất hiện nào |
| `jitterBufferTarget` | Không có |
| `playoutDelay` / playout delay hint | Không có |
| `syncGroup` / `sync_group` | Không có |
| `setStreamIds` (đổi msid sau khi tạo) | Không có |
| `audioJitterBufferMaxPackets` | Chỉ xuất hiện trong `Encodable+Retroactive.swift:248,293,332` — **để log**, không set |
| `audioJitterBufferFastAccelerate` | idem, chỉ log |
| `preferredIOBufferDuration` | Không set — để mặc định WebRTC |

Về `audioJitterBuffer*`: file `Utils/Swift6Migration/Encodable+Retroactive.swift` cho `RTCConfiguration` conform `Encodable` để **dump config vào log/telemetry**. Nó *đọc* hai property này, không *ghi*. Ở chỗ thực sự tạo config:

```swift
// WebRTC/RTCConfiguration+Default.swift:11-29 — TOÀN BỘ file
static func makeConfiguration(with iceServersConfig: [ICEServer]) -> RTCConfiguration {
    let configuration = RTCConfiguration()
    var iceServers = [RTCIceServer]()
    for iceServerConfig in iceServersConfig { ... }
    configuration.iceServers = iceServers
    configuration.sdpSemantics = .unifiedPlan
    configuration.bundlePolicy = .maxBundle
    return configuration
}
```

Chỉ 3 property được set. Không có gì về jitter buffer hay timing.

### 1.3 Stats không được dùng để feedback timing

Metric duy nhất liên quan timing mà SDK expose:

```swift
// Models/CallStatsReport.swift:58-59, 78
/// The jitter in the participant's video stream.
public let jitter: Double
/// The average jitter across all participants in milliseconds.
```

Nó chỉ đi một chiều: đọc từ `RTCStatsReport` → đóng gói → gửi lên SFU qua `sendStats`. **Không có nhánh nào đọc `jitter` rồi điều chỉnh playout hay bù trễ.**

Đặc biệt, `estimatedPlayoutTimestamp` — metric chuẩn của WebRTC để **đo độ lệch A/V thực tế** — không hề được đọc. Nếu SDK có ý định quản lý sync thì đây là field đầu tiên phải chạm.

### 1.4 Protocol SFU cũng không có khái niệm sync

`TrackInfo` — struct mô tả track gửi kèm SDP lên SFU:

```swift
// protobuf/sfu/models/models.pb.swift:1321-1334
var trackType: Stream_Video_Sfu_Models_TrackType = .unspecified
var layers: [Stream_Video_Sfu_Models_VideoLayer] = []
var mid: String = String()
var dtx: Bool = false
var stereo: Bool = false
var red: Bool = false
var muted: Bool = false
```

Không có field nào về timing, clock offset, hay sync group.

Quét toàn bộ protobuf (`models.pb.swift` + `events.pb.swift`, ~9.3k dòng) cho mọi field chứa `sync`/`timestamp`/`clock`/`rtp*`, chỉ có **hai** kết quả:

- `clockRate` — thuộc `Codec`, là sample rate của codec (48000 cho Opus, 90000 cho video). Dùng để khớp codec capability, không phải để sync.
- `timestampMs` — dùng cho event/telemetry, không phải RTP timestamp.

Ở phía Swift, `clockRate` chỉ xuất hiện ở hai chỗ, cả hai đều không liên quan timing:

```swift
// WebRTC/v2/Extensions/Protobuf/Stream_Video_Sfu_Models_Codec+Convenience.swift:37
clockRate = source.clockRate?.uint32Value ?? 0          // map codec capability

// WebRTC/v2/Stats/Components/WebRTCStatsItemTransformer.swift:87
item.codec.clockRate = codecStatistics.value(for: .clockRate, fallback: 0)   // báo cáo stats
```

---

## 2. Vậy ai lo việc đồng bộ?

Toàn bộ nằm trong `StreamWebRTC`:

```swift
// Package.swift:24
.package(url: "https://github.com/GetStream/stream-video-swift-webrtc.git", exact: "145.15.0"),
```

Đây là binary framework (libwebrtc fork) — **không có source trong repo này**. Trong libwebrtc, các thành phần liên quan là:

```
RtpStreamsSynchronizer      — ghép audio stream + video stream cùng sync group
StreamSynchronization       — tính toán offset tương đối giữa hai stream
RemoteNtpTimeEstimator      — map RTP timestamp → NTP wall clock (từ RTCP Sender Report)
NetEq                       — jitter buffer audio, có thể accelerate/decelerate để bám target
FrameBuffer / VideoStreamBufferController — chọn thời điểm render frame video
```

Cơ chế chuẩn: mỗi stream gửi kèm **RTCP Sender Report** chứa cặp `(RTP timestamp, NTP timestamp)`. Phía nhận dùng cặp này để đưa cả hai stream về **cùng một trục thời gian tuyệt đối**, rồi delay stream nào đến sớm hơn.

**Điều kiện tiên quyết**: hai stream phải được libwebrtc coi là **thuộc cùng một cặp cần đồng bộ**. Đây chính là chỗ phát hiện ở mục 3 trở nên quan trọng.

---

## 3. Phát hiện chính: audio và video nằm ở hai MediaStream khác nhau

### 3.1 Chiều gửi (publisher)

Ba adapter, ba `streamIds` hoàn toàn khác nhau:

```swift
// PeerConnection/MediaAdapters/LocalMediaAdapters/LocalAudioMediaAdapter.swift:83
streamIds = ["\(sessionID):audio"]

// PeerConnection/MediaAdapters/LocalMediaAdapters/LocalVideoMediaAdapter.swift:125
streamIds = ["\(sessionID):video"]

// PeerConnection/MediaAdapters/LocalMediaAdapters/LocalScreenShareMediaAdapter.swift:471
streamIds: ["\(sessionID)-screenshare-\(screenSharingType)"]
```

Và được truyền vào transceiver:

```swift
// LocalVideoMediaAdapter.swift:790-800
let transceiver = peerConnection.addTransceiver(
    trackType: .video,
    with: track,
    init: .init(
        trackType: .video,
        direction: .sendOnly,
        streamIds: streamIds,       // ["<sessionID>:video"]
        videoOptions: options
    )
)

// LocalAudioMediaAdapter.swift:355-362 — tương tự với ["<sessionID>:audio"]
```

`streamIds` chính là **msid** trong SDP (`a=msid:<stream-id> <track-id>`). Hai msid khác nhau ⇒ hai `MediaStream` khác nhau.

### 3.2 Chiều nhận (subscriber)

SFU không dùng lại msid của client — nó sinh msid theo convention riêng, và SDK có code để parse:

```swift
// PeerConnection/Extensions/RTCMediaStream+Convenience.swift — toàn bộ phần logic
private let screenShareTrackType = "TRACK_TYPE_SCREEN_SHARE"
private let videoTrackType       = "TRACK_TYPE_VIDEO"
private let audioTrackType       = "TRACK_TYPE_AUDIO"

extension RTCMediaStream {
    /// Determines the type of track based on the stream's identifier.
    var trackType: TrackType {
        let components = streamId.components(separatedBy: ":")
        guard components.endIndex > 1 else { return .unknown }
        let component = components[1]
        switch component {
        case screenShareTrackType: return .screenshare
        case videoTrackType:       return .video
        case audioTrackType:       return .audio
        default:                   return .unknown
        }
    }

    /// Extracts the track identifier from the stream's identifier.
    var trackId: String {
        streamId.components(separatedBy: ":").first ?? streamId
    }
}
```

Suy ra được format msid mà SFU gửi xuống:

```
<trackLookupPrefix>:TRACK_TYPE_AUDIO
<trackLookupPrefix>:TRACK_TYPE_VIDEO
<trackLookupPrefix>:TRACK_TYPE_SCREEN_SHARE
```

**Cùng prefix** (cùng participant) nhưng **msid khác nhau** — vẫn là ba `MediaStream` riêng biệt, không phải một stream chứa nhiều track.

Đây là lý do `trackId` được lấy bằng cách cắt phần trước dấu `:` — nó chính là `trackLookupPrefix`, dùng để tra participant:

```swift
// WebRTC/v2/WebRTCStateAdapter.swift:620-627
func track(for participant: CallParticipant, of trackType: TrackType) -> RTCMediaStreamTrack? {
    if let trackLookupPrefix = participant.trackLookupPrefix {
        return trackStorage.track(for: trackLookupPrefix, of: trackType)
            ?? trackStorage.track(for: participant.sessionId, of: trackType)
    } else {
        return trackStorage.track(for: participant.sessionId, of: trackType)
    }
}
```

Tức là **việc ghép audio + video của cùng một người được làm ở tầng application** (`WebRTCTrackStorage` + `CallParticipant`), **không phải ở tầng WebRTC MediaStream**. Storage tách hẳn ba dictionary:

```swift
// WebRTC/v2/WebRTCTrackStorage.swift:19-25
private var audioTracks: [String: RTCAudioTrack] = [:]
private var videoTracks: [String: RTCVideoTrack] = [:]
private var screenShareTracks: [String: RTCVideoTrack] = [:]
```

Ghép lại chỉ để **hiển thị đúng người**, không phải để **phát đúng thời điểm**.

### 3.3 Ý nghĩa — và ranh giới của kết luận

Trong libwebrtc, `RtpStreamsSynchronizer` chỉ ghép một audio stream với một video stream **thuộc cùng `sync_group`**, và `sync_group` được suy ra từ msid của receiver (`stream_ids()` của `RTCRtpReceiver`). Hai msid khác nhau ⇒ khác `sync_group` ⇒ **không được ghép để đồng bộ playout**; mỗi stream render theo timeline riêng của nó.

**Cần phân định rõ mức độ chắc chắn:**

| Điều gì | Mức độ |
|---|---|
| Audio và video có msid khác nhau (cả hai chiều) | **Đã kiểm chứng** từ source trong repo này |
| Không có code Swift nào can thiệp sync | **Đã kiểm chứng** — grep toàn bộ `Sources/` |
| Protocol SFU không có field timing/sync | **Đã kiểm chứng** từ protobuf generated |
| `sync_group` lấy từ msid ⇒ khác msid thì không sync | **Suy luận từ kiến thức libwebrtc** — không kiểm chứng được vì libwebrtc là binary dependency, không có source trong repo |

Tôi **không** khẳng định chắc chắn là lip-sync bị tắt. Tôi khẳng định: repo này không làm gì về sync, và cấu trúc msid của nó không tạo điều kiện cho cơ chế sync mặc định của libwebrtc hoạt động theo cách thông thường.

### 3.4 Cách kiểm chứng thực tế

Nếu cần câu trả lời dứt khoát, đo thay vì đọc code:

**Cách 1 — so `estimatedPlayoutTimestamp`.** Lấy `RTCStatsReport` và so field này giữa `inbound-rtp` của audio và của video cùng participant. Lệch lớn và **trôi dần** ⇒ không có sync. Lệch nhỏ và ổn định ⇒ có sync.

```swift
// điểm truy cập có sẵn:
// WebRTC/v2/PeerConnection/RTCPeerConnectionCoordinator.swift:638
func statsReport() async throws -> StreamRTCStatisticsReport
```

**Cách 2 — dump SDP của subscriber.** Kiểm tra dòng `a=msid:` của m-line audio và video. Nếu khác nhau thì xác nhận điều mục 3.2 suy ra. SDK đã log SDP ở subsystem `.webRTC`.

**Cách 3 — test clap.** Vỗ tay trước camera, quay lại màn hình người nhận, so frame vỗ tay với waveform tiếng. Thô nhưng dứt khoát.

### 3.5 Tại sao thiết kế này có thể là chủ đích

Không nên coi đây là bug ngay. Có lý do hợp lý để SFU tách msid:

1. **Ưu tiên độ trễ audio.** Trong hội thoại, tiếng quan trọng hơn hình. Ghép sync buộc audio phải chờ video — tăng độ trễ hội thoại. Nhiều SFU cố tình không sync để audio đi nhanh nhất có thể.
2. **Subscribe độc lập từng loại track.** SDK gửi `TrackSubscriptionDetails` **riêng cho từng track type**:
   ```swift
   // WebRTC/v2/Extensions/CallParticipant+Convenience.swift:18-70
   if hasVideo, !incomingVideoQualitySettings.isVideoDisabled(for: sessionId) { result.append(... type: .video) }
   if hasAudio { result.append(... type: .audio) }
   if isScreensharing { result.append(... type: .screenShare); result.append(... type: .screenShareAudio) }
   ```
   Client có thể bỏ video mà giữ audio (audio-only mode) cho từng participant. Gói chung một MediaStream sẽ làm mô hình này rối.
3. **Simulcast + nhiều publish option.** Mỗi codec một transceiver, mỗi transceiver có track clone riêng. Nhóm theo msid trở nên nhập nhằng khi một nguồn video sinh ra nhiều track.
4. **Ngưỡng cảm nhận của người.** Lệch trong khoảng ~±100ms hầu như không nhận ra. Với video call điều kiện mạng thông thường, phần lớn thời gian sẽ nằm trong ngưỡng này kể cả không sync chủ động.

Đổi lại: **không có gì đảm bảo** khi mạng xấu một chiều, khi jitter audio và video lệch nhau, hoặc khi video filter tự thêm trễ (mục 5).

### 3.6 Ghi chú: msid phía gửi thực chất không được SFU dùng

Một điểm bổ trợ. Format msid của screenshare phía gửi dùng **dấu gạch ngang**:

```swift
// LocalScreenShareMediaAdapter.swift:471
streamIds: ["\(sessionID)-screenshare-\(screenSharingType)"]
```

trong khi parser phía nhận yêu cầu **dấu hai chấm** và literal `TRACK_TYPE_SCREEN_SHARE`. Hai format không khớp nhau — nhưng **đây không phải bug**, vì SFU không đọc msid của client. Nó map track qua `mid` được gửi tường minh trong protobuf:

```swift
// LocalVideoMediaAdapter.swift:381
trackInfo.mid = transceiver.mid
// LocalAudioMediaAdapter.swift:317
trackInfo.mid = transceiver.mid
// LocalScreenShareMediaAdapter.swift:369
trackInfo.mid = transceiver.mid
```

`mid` cũng là field chính thức trong `TrackInfo` (`models.pb.swift:1325`). Điều này khẳng định: **msid phía gửi gần như là trang trí**; SFU sinh msid riêng cho subscriber. Nên muốn thay đổi hành vi sync thì phải sửa ở SFU, không sửa được từ client.

---

## 4. Những gì code làm ĐÚNG để không phá sync

Đây là phần tích cực. Có nhiều cách để một SDK **tự phá** khả năng sync, và repo này tránh được hết.

### 4.1 Giữ nguyên capture timestamp khi rebuild frame

Khi sửa rotation, SDK phải tạo `RTCVideoFrame` mới. Nó truyền lại timestamp gốc:

```swift
// WebRTC/VideoCapturing/StreamVideoCaptureHandler.swift:130-137
if rotation != frame.rotation, let _buffer = buffer ?? frame.buffer as? RTCCVPixelBuffer {
    return RTCVideoFrame(buffer: _buffer, rotation: rotation, timeStampNs: frame.timeStampNs)
}
```

Nếu ở đây stamp bằng thời gian hiện tại (lỗi rất dễ mắc), timeline nguồn sẽ bị phá và **mọi nỗ lực sync phía nhận trở nên vô nghĩa** — vì RTP timestamp không còn phản ánh thời điểm capture thật.

Screenshare cũng lấy đúng presentation timestamp thay vì thời gian hệ thống:

```swift
// WebRTC/v2/VideoCapturing/ActionHandlers/ScreenShare/ScreenShareCaptureHandler.swift:218-225
let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
let timeStampNs = Int64(CMTimeGetSeconds(timeStamp) * Double(NSEC_PER_SEC))
...
timeStampNs: timeStampNs
```

Và Picture-in-Picture cũng propagate đúng:

```swift
// StreamVideoSwiftUI/Utils/PictureInPicture/PictureInPictureBufferTransformer.swift:40
timeStampNs: frame.timeStampNs
```

### 4.2 Rotation qua metadata, không rotate pixel

```swift
// StreamVideoCaptureHandler.swift:105-140 — chọn rotation theo hướng máy + camera
```

Rotation đi kèm RTP như metadata (`urn:3gpp:video-orientation`), phía nhận rotate lúc render. Rotate pixel thủ công sẽ thêm độ trễ vào đường video và làm lệch với audio.

### 4.3 `maxBundle` — cùng một transport

```swift
// WebRTC/RTCConfiguration+Default.swift:27
configuration.bundlePolicy = .maxBundle
```

Audio và video đi qua **một cặp port UDP duy nhất**, cùng NAT binding, cùng đường mạng. Độ trễ mạng của hai loại gần như bằng nhau, nên độ lệch tự nhiên nhỏ.

Đây là **hệ quả phụ có lợi**, không phải cơ chế sync. Nó làm giảm nguồn gây lệch, không phát hiện hay sửa lệch.

### 4.4 Giữ thứ tự frame

```swift
// StreamVideoCaptureHandler.swift:19
private lazy var processingQueue = OperationQueue(maxConcurrentOperationCount: 1)
```

`maxConcurrentOperationCount: 1` đảm bảo frame ra khỏi filter **đúng thứ tự vào**. Frame đảo thứ tự sẽ làm decoder phía nhận phải reorder hoặc drop.

### 4.5 Không chạm vào clock của WebRTC

Nghe như hiển nhiên nhưng đáng ghi nhận: không có chỗ nào SDK cố "giúp" WebRTC bằng cách chèn delay thủ công, buffer thêm frame, hay điều chỉnh timestamp. Can thiệp nửa vời vào timing thường tệ hơn không can thiệp.

---

## 5. Rủi ro thực tế: video filter tạo trễ một phía

Đây là điểm đáng lo nhất tôi tìm thấy liên quan A/V sync.

Filter chạy **đồng bộ trong đường frame**, giữa capturer và `RTCVideoSource`:

```swift
// WebRTC/VideoCapturing/StreamVideoCaptureHandler.swift:64-97
private func apply(filter: VideoFilter, with buffer: RTCCVPixelBuffer,
                   from frame: RTCVideoFrame, capturer: RTCVideoCapturer) {
    processingQueue.addTaskOperation { [weak self] in
        let imageBuffer = buffer.pixelBuffer
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        let inputImage = CIImage(cvPixelBuffer: imageBuffer, options: [.colorSpace: self.colorSpace])
        let outputImage = await filter.filter(VideoFilter.Input(...))   // ← độ trễ ở đây
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        context.render(outputImage, to: imageBuffer, bounds: outputImage.extent, colorSpace: self.colorSpace)
        process(capturer: capturer, frame: frame, buffer: buffer)
    }
}
```

Vấn đề:

1. **Trễ chỉ cộng vào video.** Audio đi đường hoàn toàn khác (ADM → APM → encoder), không qua queue này. Filter chậm ⇒ video muộn hơn audio.
2. **Timestamp giữ nguyên gốc.** Đúng về mặt bảo toàn timeline (mục 4.1), nhưng nghĩa là **không có tín hiệu nào cho phía nhận biết video đã bị trễ thêm bao nhiêu**. Frame mang timestamp cũ nhưng đến encoder muộn.
3. **Không drop frame khi dồn.** `OperationQueue` xếp hàng vô hạn. Nếu filter chậm hơn frame interval (16.7ms ở 60fps, 33ms ở 30fps), queue dồn và **độ trễ tích lũy** thay vì bị chặn.
4. **Không có cơ chế phát hiện.** Không đo thời gian filter, không log cảnh báo, không tự tắt filter khi quá chậm.

Ai chịu ảnh hưởng: filter nặng (`BlurBackgroundFilter`, `ImageBackgroundFilter` trong `WebRTC/VideoFilters/Filters/`) trên máy cũ. Tổ hợp "máy yếu + blur background + 30fps" là ca thực tế đáng kiểm tra.

Cần lưu ý là đường mới (`StreamVideoProcessPipeline`) **đồng bộ hoàn toàn** — `nodes.reduce(frame)` chạy ngay trên thread gọi:

```swift
// WebRTC/v2/VideoCapturing/StreamVideoProcessPipeline/StreamVideoProcessPipeline.swift:41-51
func capturer(_ capturer: RTCVideoCapturer, didCapture frame: RTCVideoFrame) {
    if nodes.isEmpty {
        source.capturer(capturer, didCapture: frame)
    } else {
        source.capturer(capturer, didCapture: nodes.reduce(frame) { $1.didCapture($0) })
    }
}
```

Không dồn queue (tốt hơn về tích lũy trễ) nhưng **block capture thread** — có thể làm capturer drop frame ở nguồn. Đánh đổi khác, chưa rõ cái nào tốt hơn cho sync; cần đo.

---

## 6. Bảng tổng hợp

| Thành phần | Có trong repo? | Ghi chú |
|---|---|---|
| Logic ghép audio↔video để đồng bộ playout | ❌ | Không có dòng code nào |
| Bù trễ / delay compensation | ❌ | — |
| Phát hiện lệch A/V | ❌ | `estimatedPlayoutTimestamp` không được đọc |
| Điều chỉnh jitter buffer | ❌ | `audioJitterBuffer*` chỉ để log |
| Playout delay hint | ❌ | — |
| Thao tác `receiver.parameters` | ❌ | Không xuất hiện lần nào |
| Field timing/sync trong protocol SFU | ❌ | `TrackInfo` chỉ có mid/dtx/stereo/red/muted/layers |
| Audio & video cùng MediaStream | ❌ | msid khác nhau — [mục 3](#3-phát-hiện-chính-audio-và-video-nằm-ở-hai-mediastream-khác-nhau) |
| Bảo toàn capture timestamp | ✅ | `StreamVideoCaptureHandler.swift:137` |
| Rotation qua metadata | ✅ | Không rotate pixel |
| Cùng transport UDP (`maxBundle`) | ✅ | `RTCConfiguration+Default.swift:27` |
| Giữ thứ tự frame | ✅ | `maxConcurrentOperationCount: 1` |
| Ghép audio+video theo participant | ✅ | Nhưng chỉ để **hiển thị**, không để **timing** |
| Trễ một phía do video filter | ⚠️ | Không đo, không bù, không drop frame |

---

## 7. Nếu cần cải thiện

Xếp theo thứ tự chi phí tăng dần:

**1. Đo trước khi sửa.** Log `estimatedPlayoutTimestamp` của audio và video cùng participant từ `statsReport()` (`RTCPeerConnectionCoordinator.swift:638`), theo dõi độ lệch và xem nó có trôi không. Không có số liệu thì mọi thay đổi là đoán.

**2. Instrument video filter.** Đo thời gian `filter.filter(...)`, log khi vượt frame interval. Rẻ, và trả lời ngay được câu hỏi filter có phải nguồn lệch hay không.

**3. Bỏ frame khi queue dồn.** Thêm giới hạn độ sâu cho `processingQueue`: quá ngưỡng thì bỏ frame cũ nhất thay vì xếp tiếp. Trong real-time, frame muộn vô dụng — bỏ tốt hơn giữ.

**4. Đặt vấn đề msid với Stream.** Nếu đo được lệch A/V thật và trôi dần, đây là **vấn đề phía SFU**, không sửa được từ client (mục 3.6 — SFU sinh msid riêng, client chỉ nhận). Cần báo kèm số liệu.

---

## Phụ lục: các file đã kiểm tra

| Mối quan tâm | File |
|---|---|
| msid phía gửi (audio) | `WebRTC/v2/PeerConnection/MediaAdapters/LocalMediaAdapters/LocalAudioMediaAdapter.swift:83` |
| msid phía gửi (video) | `.../LocalVideoMediaAdapter.swift:125` |
| msid phía gửi (screenshare) | `.../LocalScreenShareMediaAdapter.swift:471` |
| msid phía nhận + parser | `WebRTC/v2/PeerConnection/Extensions/RTCMediaStream+Convenience.swift` |
| Transceiver init tạm | `WebRTC/v2/PeerConnection/Extensions/RTCRtpTransceiverInit+Convenience.swift:72-100` |
| Ghép track↔participant | `WebRTC/v2/WebRTCStateAdapter.swift:620-634`, `WebRTC/v2/WebRTCTrackStorage.swift:19-25` |
| Subscribe từng loại track | `WebRTC/v2/Extensions/CallParticipant+Convenience.swift:18-70` |
| Bảo toàn timestamp | `WebRTC/VideoCapturing/StreamVideoCaptureHandler.swift:130-137` |
| Timestamp screenshare | `WebRTC/v2/VideoCapturing/ActionHandlers/ScreenShare/ScreenShareCaptureHandler.swift:218-225` |
| Cấu hình peer connection | `WebRTC/RTCConfiguration+Default.swift` |
| Config dump (log-only) | `Utils/Swift6Migration/Encodable+Retroactive.swift:248,293,332` |
| Stats model | `Models/CallStatsReport.swift:58-78` |
| Truy cập stats | `WebRTC/v2/PeerConnection/RTCPeerConnectionCoordinator.swift:638` |
| `TrackInfo` protobuf | `protobuf/sfu/models/models.pb.swift:1321-1334` |
| `mid` gửi lên SFU | `LocalVideoMediaAdapter.swift:381`, `LocalAudioMediaAdapter.swift:317`, `LocalScreenShareMediaAdapter.swift:369` |
| Filter pipeline (cũ) | `WebRTC/VideoCapturing/StreamVideoCaptureHandler.swift:64-97` |
| Filter pipeline (mới) | `WebRTC/v2/VideoCapturing/StreamVideoProcessPipeline/StreamVideoProcessPipeline.swift:41-51` |
| Dependency WebRTC | `Package.swift:24` |
