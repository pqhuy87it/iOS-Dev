# VistaFinderMx — Kiến trúc Streaming Video/Audio

> Tài liệu phân tích luồng truyền video/audio qua socket trong project `Mx-T`.
> Base path của toàn bộ đường dẫn bên dưới: `VistaFinderMx/VistaFinderMx/Classes/`

---

## 0. Kết luận nhanh

Project **không dùng WebSocket**. Toàn bộ truyền tải là **BSD socket thuần** (`socket()` / `bind()` / `connect()` / `sendto()` / `recvfrom()`), chia làm hai kênh:

| Kênh | Protocol | Nội dung |
|---|---|---|
| **Media** | UDP + **RTP tự implement** | Video H.264, Audio AAC (đã mã hóa KCipher2) |
| **Control** | TCP + giao thức nhị phân riêng | Feedback bitrate, lệnh capture, AR pose, chia sẻ ảnh… |

Đây là một live-streaming stack **tự viết tay hoàn toàn** — không WebRTC, không HLS/DASH, không FFmpeg, không thư viện RTP bên thứ ba. Thiết kế khoảng 2013, phục vụ truyền hình ảnh thực địa từ điện thoại lên trung tâm điều hành qua mạng di động.

---

## 1. Sơ đồ luồng dữ liệu

```
 ┌─────────────────────────────────────────────────────────────────────┐
 │ Camera (AVFoundation) ──→ EncoderEngine ──→ RtpSink                 │
 │ Mic                        H.264 / AAC       RTP packetize + KCipher2│
 └──────────────────────────────────────────────┬──────────────────────┘
                                                │ UDP tới 127.0.0.1
                                                │ (loopback, port local)
                    ┌───────────────────────────▼──────────────────────┐
                    │ VideoSwitcher / AudioSwitcher                    │
                    │  recvfrom() → queue → rate control → sendto()    │
                    │  (đo throughput, delay, drop, retry)             │
                    └───────────────────────────┬──────────────────────┘
                                                │ UDP/RTP ra Internet
                                                ▼
                                          ┌──────────┐
                                          │  SERVER  │
                                          └────┬─────┘
                                               │
        ControlConnection (TCP) ←── feedback ──┘
               │
               └──→ RateControl ──→ điều chỉnh bitrate/fps của EncoderEngine
```

### Vì sao có chặng loopback?

Encoder **không** gửi trực tiếp ra Internet. `RtpSink` hard-code địa chỉ đích là `127.0.0.1` (`rtp/RtpSink.mm:254` — hàm `initConfigure:port:srv_addr:` bỏ qua tham số `host` một cách vô điều kiện). Các `Switcher` bắt lại packet trên localhost rồi mới forward lên server.

Chặng trung gian này là nơi chèn:
- **Rate control** (bỏ packet, hạ chất lượng khi mạng yếu)
- **Đo lường chính xác** (timestamp nanosecond trước/sau mỗi `sendto`)
- **Handover** (đổi Wi-Fi ↔ 4G mà không phải restart encoder)
- **Packet queue + retry**

---

## 2. Bản đồ code

### 2.1. Chiều GỬI — `rtp/RtpSink.mm` (lõi quan trọng nhất)

| Chức năng | Vị trí |
|---|---|
| Tạo socket UDP + bind port ephemeral | `rtp/RtpSink.mm:127` `initSocket` |
| Khởi tạo RTP header (video + audio riêng) | `rtp/RtpSink.mm:347` `initializeHeader:type:` |
| Cập nhật seq/pts/marker mỗi packet | `rtp/RtpSink.mm:378` `updateHeader:pts:marker:` |
| Resolve địa chỉ đích (`getaddrinfo`) | `rtp/RtpSink.mm:239` `initConfigure:port:srv_addr:` |
| Gom SPS/PPS thành STAP-A | `rtp/RtpSink.mm:406` `setParameterSet:size:` |
| Gửi parameter set (trước keyframe) | `rtp/RtpSink.mm:439` `sendParameterSet:` |
| **Gửi video H.264** | `rtp/RtpSink.mm:465` `sendVideo:size:pts:marker:sendParameterSet:` |
| **Gửi audio AAC** | `rtp/RtpSink.mm:641` `sendAudio:size:pts:` |
| Mã hóa KCipher2 lên payload | `rtp/RtpSink.mm:196` `transCrypto:packet:length:seq:` |
| **`sendto()` thực tế** | `rtp/RtpSink.mm:211` `sendTo:rtpBuff:packetsize:` |

**Nguồn dữ liệu:** `encoder/EncoderEngine.mm`
- Giữ tham chiếu `RtpSinkIF* rtpSink_` — `encoder/EncoderEngine.mm:55`
- Inject qua `initWithRtpUnit:Sink:` — `encoder/EncoderEngine.mm:337`
- Callback H.264 gọi `sendVideo` — `encoder/EncoderEngine.mm:1286`
- Callback AAC gọi `sendAudio` — `encoder/EncoderEngine.mm:2198`

**Nơi khởi tạo cả cụm:** `controller/PlayerController.mm:1227` (`setupEncoderPlayerMgr`) — tạo `RtpSink` + `RtpSource`, truyền vào encoder/decoder.

### 2.2. Chiều NHẬN — `rtp/RtpSource.mm`

| Chức năng | Vị trí |
|---|---|
| Tạo socket (có nhánh IPv6) | `rtp/RtpSource.mm:135` / `:144` / `:146` |
| `recvfrom` video | `rtp/RtpSource.mm:529` |
| `recvfrom` audio | `rtp/RtpSource.mm:659` |
| Giải mã & render | `decoder/DecoderEngine.mm:298` `initWithRtpUnit:Source:` |

### 2.3. Live session — relay + rate control (`liveSession/`)

| Thành phần | Vị trí | Vai trò |
|---|---|---|
| `LiveSession.mm` | `:109` `start:` · `:471` `run` | Orchestrator toàn bộ session |
| `ControlConnection.mm` | `:1259` `connectTo()` · `:1265` `socket(SOCK_STREAM)` · `:196` `safe_connect()` | Kênh điều khiển TCP (~3000 dòng) |
| `socket.mm` | toàn file | `TCP_NODELAY`, `SO_NOSIGPIPE`, non-blocking |
| `UDPRedirector.m` | `:68`, `:72` tạo · `:154`, `:162` start | Điều phối 2 switcher |
| `VideoSwitcher.m` | `:390` `_start:` · `:405` socket · `:1043` `recvfrom` · `:798` `_sendData:` · `:828` `sendData:` | Relay + đo lường video |
| `AudioSwitcher.m` | `:358` socket · `:862` `recvfrom` · `:766`, `:799` `sendto` | Relay + đo lường audio |
| `RateControl.m` | `:374` `setFeedback:` · `:462` `getMinimumRate:` | Vòng lặp adaptive bitrate |
| `FeedbackValue.m` | — | Parse chuỗi feedback từ server |
| `JitterAbsorber.mm` | — | Jitter buffer cho audio gửi ngược |
| `HandOver.m`, `SwitcherRetry.m` | — | Xử lý mất/đổi kết nối mạng |
| `ThroughputWork.m`, `Statistics.m`, `PacketInfo.m` | — | Thống kê throughput/delay |
| `UdpMgr.m` | `:62` socket · `:119` `sendto` | Loopback audio cục bộ |
| `WebSpeechManager.m` | `:86` `recvfrom` · `:143` `sendto` | Kênh UDP audio riêng cho web speech |

### 2.4. Chế độ phụ — RTSP client

`RtspMgr/RtspMgr.m` — lấy stream từ camera Wi-Fi ngoài:
- TCP control socket: `:213`, `connect()`: `:239`
- UDP RTP socket: `:858`, `recvfrom`: `:958`, `sendto`: `:1107`
- SDP parse: `liveSession/SDPParser.m` (dùng tại `mgr/ConfigureMgr.mm:485`)

### 2.5. NAT traversal

`mgr/NatClientMgr.m` — SDK NAT của bên thứ ba, 3 chế độ kết nối (CMN / EASY / SOCKET), cấp 1–10 UDP port cho media. Audio send-back: `:1061`.

---

## 3. Chi tiết công nghệ

### 3.1. Codec

| | Công nghệ | Cấu hình |
|---|---|---|
| **Video** | H.264 qua **VideoToolbox** (`VTCompressionSession`) | Baseline AutoLevel (`:865`), `RealTime = true` (`:876`), `AllowFrameReordering = false` → không B-frame (`:874`), `AverageBitRate` (`:896`), `ExpectedFrameRate` (`:918`), `DataRateLimits` (`:927`), `MaxKeyFrameInterval` (`:941`) |
| **Audio** | AAC-LC / AAC-HE qua **AudioConverter** | `kAudioFormatMPEG4AAC` / `kAudioFormatMPEG4AAC_HE` (`:1324-1326`), 1024 samples/frame, có bandpass preprocessing |

*(Số dòng trong bảng này thuộc `encoder/EncoderEngine.mm`)*

### 3.2. RTP — hằng số (định nghĩa tại `rtp/RtpSinkIF.mm`)

```
RTP header             : 12 byte, dựng thủ công (không dùng thư viện)
Payload type video     : 126  (AVC)
Payload type audio     : 111  (AAC)
MAX_PAYLOAD_SIZE       : 1360 byte   (rtp/RtpSink.mm:48)
NAL_UNIT_TYPE_STAPA    : 24
NAL_UNIT_TYPE_FUA      : 28
FU_HEADER_START_BIT    : 0x80
FU_HEADER_END_BIT      : 0x40
KCipher2 block size    : 4096
```

### 3.3. Packetization H.264 (RFC 3984)

Logic tại `rtp/RtpSink.mm:465` `sendVideo:`:

1. **SPS/PPS** → gom thành **STAP-A** (type 24), gửi lại định kỳ trước mỗi keyframe (`:406`, `:421`, `:439`). Có field độ dài 2 byte cho mỗi NAL con.
2. **NAL ≤ 1360 byte** → **Single-NAL packet** (`:490-510`).
3. **NAL > 1360 byte** → cắt thành **FU-A** (type 28) với `FU_INDICATOR` + `FU header`, set START bit ở fragment đầu, END bit ở fragment cuối; marker bit chỉ set ở packet cuối của frame (`:513-555`).

### 3.4. Mã hóa — KCipher2

**KCipher2** là stream cipher của Nhật (ISO/IEC 18033-4), wrap qua `k2wrapper.h` / thư viện `klabpkp`.

Cách áp dụng (`rtp/RtpSink.mm:196`):
- **Chỉ mã hóa payload**, giữ nguyên 12 byte RTP header → server vẫn đọc được sequence number và timestamp mà không cần giải mã.
- Vị trí keystream = `4096 × sequence_number` → mỗi packet dùng đoạn keystream riêng biệt. **Mất packet không làm mất đồng bộ giải mã** — cực quan trọng với UDP.
- Key/IV nhận từ server qua kênh TCP, set bằng `setVideoEncryptSetting:` / `setAudioEncryptSetting:` (dạng hex string → binary).

### 3.5. Adaptive bitrate

Vòng lặp feedback tự viết:

```
Server ──(chuỗi feedback qua TCP)──→ ControlConnection
                                          ↓
                              RateControl.setFeedback:   (RateControl.m:374)
                                          ↓
                              FeedbackValue.setFeedbackInfo:  (parse)
                                          ↓
                       getMinimumRate:height:frameRate:  (RateControl.m:462)
                              → chọn RateInfo (resolution / fps / bitrate)
                                          ↓
                    ┌─────────────────────┴─────────────────────┐
                    ↓                                           ↓
     set lại VTSession bitrate/fps              UDPRedirector.setMaxRate:
     (EncoderEngine)                            (VideoSwitcher/AudioSwitcher)
```

Switcher đo `before_send` / `after_send` bằng nanotime cho **từng packet** (`VideoSwitcher.m:798`), cộng với `getThroughput:end:fps:`, `getSendingDelay`, `getRemainBytes` → cung cấp dữ liệu cho quyết định rate control.

---

## 4. Đánh giá

### Điểm mạnh

- **Toàn quyền kiểm soát đo lường**: delay từng packet, throughput theo cửa sổ thời gian, độ trễ hàng đợi → rate control chính xác hơn so với dùng thư viện đóng.
- **Mã hóa theo sequence number** giữ được khả năng chịu mất gói — phù hợp mạng di động chất lượng kém.
- **Kiến trúc loopback + switcher** rất linh hoạt cho handover mạng: đổi interface mà encoder không hề biết.
- Tách `*IF` / `*OKI` / impl cụ thể (`RtpSinkIF`, `RtpSinkOKI`, `RtpSink`) cho phép thay backend.

### Hạn chế / rủi ro khi bảo trì

| Vấn đề | Chi tiết |
|---|---|
| **Không có RTCP** | Không RR/SR, không FEC, không NACK/retransmit. Mất packet là mất vĩnh viễn. Phản ứng với nghẽn mạng chậm hơn WebRTC vì feedback đi qua TCP. |
| **API lỗi thời** | `EAGLContext` / OpenGL ES đã bị Apple deprecate; manual retain/release (`AH_SUPER_DEALLOC`, `autorelease`) thay vì ARC. |
| **IPv6 chưa bật** | `#define USE_IP_V6` bị comment (`rtp/RtpSink.mm:16`). App Store yêu cầu hỗ trợ IPv6-only network từ 2016 → **cần kiểm tra**. |
| **Hard-code** | `127.0.0.1` tại `rtp/RtpSink.mm:254` — là chủ ý cho kiến trúc loopback, nhưng hàm nhận tham số `host` rồi bỏ qua nên rất dễ gây nhầm khi đọc code. |
| **Code cũ** | Nhiều `#if 0`, comment tiếng Nhật, khối code chết. `ControlConnection.mm` ~3000 dòng, `VideoSwitcher.m` ~1600 dòng. |

### Nếu viết lại hôm nay

**WebRTC** hoặc **SRT** thay thế được gần như toàn bộ tầng vận chuyển này (RTP packetize, mã hóa, congestion control, NAT traversal, FEC/retransmit đều có sẵn và đã được kiểm chứng). Phần đáng giữ lại là logic nghiệp vụ: AR overlay, chia sẻ ảnh, và chính sách chọn resolution/fps theo điều kiện mạng.

---

## 5. Điểm vào để đọc code theo dòng chảy

```
controller/PlayerController.mm:1227     ← khởi tạo RtpSink/RtpSource
        ↓
encoder/EncoderEngine.mm:337            ← encoder nhận sink
        ↓
encoder/EncoderEngine.mm:1286 / :2198   ← callback encode xong, gọi sendVideo/sendAudio
        ↓
rtp/RtpSink.mm:465 / :641               ← RTP packetization
        ↓
rtp/RtpSink.mm:196                       ← mã hóa KCipher2
        ↓
rtp/RtpSink.mm:211                       ← sendto()
        ↓
liveSession/VideoSwitcher.m:1043         ← recvfrom() trên loopback
        ↓
liveSession/VideoSwitcher.m:798          ← sendto() lên server
```
