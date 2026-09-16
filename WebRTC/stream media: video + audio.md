# Cơ chế stream media: Video + Audio

## 1. Bức tranh tổng thể

Media streaming là một chuỗi 7 stage. Hiểu rõ ranh giới giữa các stage là điều kiện để debug được, vì mỗi stage có failure mode riêng.

```
SENDER                                          RECEIVER
┌─────────────┐                          ┌──────────────────┐
│ 1. CAPTURE  │  AVCaptureSession        │ 5. DEPACKETIZE   │
│  raw frames │  CMSampleBuffer          │  reassemble NAL  │
└──────┬──────┘                          └────────┬─────────┘
       │ CVPixelBuffer / AudioBufferList          │
       ▼                                          ▼
┌─────────────┐                          ┌──────────────────┐
│ 2. ENCODE   │  VideoToolbox            │ 6. JITTER BUFFER │
│  compress   │  AAC/Opus encoder        │  reorder + sync  │
└──────┬──────┘                          └────────┬─────────┘
       │ H.264 NALU / Opus packet                 │
       ▼                                          ▼
┌─────────────┐                          ┌──────────────────┐
│3. PACKETIZE │  RTP / FLV / fMP4        │ 7. DECODE+RENDER │
│  + timestamp│  MPEG-TS                 │  VT decode       │
└──────┬──────┘                          │  AVSampleBuffer* │
       │                                 └──────────────────┘
       ▼                                          ▲
┌───────────────────── 4. TRANSPORT ───────────────┘
   SRTP/UDP · TCP · QUIC · HTTP
```

Điểm quan trọng nhất, và cũng là phần khó nhất: **video và audio là hai stream độc lập với đặc tính hoàn toàn khác nhau**, nhưng phải được đồng bộ lại chính xác ở đầu nhận.

## 2. Tại sao video và audio phải xử lý khác nhau

Đây là câu hỏi nền tảng. Nếu nắm được bảng này thì mọi quyết định thiết kế phía sau đều suy ra được.

| Đặc tính | Audio | Video |
|---|---|---|
| Bitrate | 32–128 kbps | 500 kbps – 8 Mbps |
| Kích thước 1 packet | ~100–200 bytes | Keyframe 50–200 KB (phải fragment) |
| Tần số packet | 50/s (frame 20ms) | 30/s nhưng burst rất lớn |
| Dependency | Mỗi frame độc lập (Opus) | GOP: P/B-frame phụ thuộc I-frame |
| Khi mất packet | Nghe thấy ngay (click, gap) | Có thể che được, hoặc freeze 1 GOP |
| Độ nhạy của người dùng | **Rất cao** | Trung bình |
| Chi phí retransmit | Rẻ (packet nhỏ) | Đắt (keyframe lớn) |

Ba hệ quả trực tiếp trong production:

1. **Audio luôn được ưu tiên bandwidth**. Khi mạng yếu, hạ video xuống 200kbps nhưng giữ audio ở 32kbps. User chấp nhận video mờ, không chấp nhận mất tiếng. Trong WebRTC, congestion controller phân bổ audio trước, video nhận phần còn lại.
2. **Audio dùng FEC, video dùng NACK/PLI**. Opus có in-band FEC (LBRR: gửi kèm bản nén thấp của frame trước trong frame hiện tại) vì retransmit gói audio nhỏ vẫn quá muộn. Video thì retransmit hiệu quả hơn nếu RTT còn trong ngân sách.
3. **Audio là master clock**. Tai người nghe được gián đoạn audio ở mức vài ms. Mắt không phát hiện được việc drop hoặc duplicate 1 video frame. Nên khi mất sync, ta điều chỉnh video theo audio, không bao giờ ngược lại.

## 3. Stage 1: Capture và vấn đề clock

### 3.1 Nguồn của timestamp

`CMSampleBuffer` mang theo `presentationTimeStamp` (PTS). PTS này lấy từ một `CMClock`. Sai lầm hay gặp: dùng `CACurrentMediaTime()` hoặc `Date()` để tự gán timestamp. Kết quả là jitter và mất sync, vì audio hardware và video hardware có **clock domain khác nhau**.

Giải pháp: bắt cả hai từ cùng một `AVCaptureSession`, session sẽ tự chuẩn hoá PTS về một clock chung.

```swift
import AVFoundation

/// Capture video + audio với timestamp trên cùng một clock domain.
final class MediaCaptureSession: NSObject {

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()

    // Queue riêng cho từng output. KHÔNG dùng chung một queue:
    // audio đến 50 lần/s, nếu bị block bởi video processing sẽ drop.
    private let videoQueue = DispatchQueue(label: "capture.video", qos: .userInitiated)
    private let audioQueue = DispatchQueue(label: "capture.audio", qos: .userInitiated)

    /// Clock mà mọi PTS đều tham chiếu tới. Dùng nó khi cần
    /// convert PTS sang wallclock hoặc so sánh với nguồn khác.
    private(set) var syncClock: CMClock?

    var onVideoFrame: ((CMSampleBuffer) -> Void)?
    var onAudioFrame: ((CMSampleBuffer) -> Void)?

    func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .hd1280x720

        // --- Video input ---
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .front
        ) else { throw CaptureError.noCamera }

        let videoInput = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(videoInput) else { throw CaptureError.cannotAddInput }
        session.addInput(videoInput)

        // --- Audio input ---
        guard let mic = AVCaptureDevice.default(for: .audio) else {
            throw CaptureError.noMicrophone
        }
        let audioInput = try AVCaptureDeviceInput(device: mic)
        guard session.canAddInput(audioInput) else { throw CaptureError.cannotAddInput }
        session.addInput(audioInput)

        // --- Video output ---
        // NV12 (420YpCbCr8BiPlanarVideoRange) là native format của
        // VideoToolbox encoder trên iOS. Chọn format khác sẽ tốn
        // một lần pixel conversion trên CPU.
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
        // Drop frame khi encoder không kịp, thay vì để queue phình ra
        // gây tăng latency vô hạn.
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(videoOutput) else { throw CaptureError.cannotAddOutput }
        session.addOutput(videoOutput)

        // --- Audio output ---
        audioOutput.setSampleBufferDelegate(self, queue: audioQueue)
        guard session.canAddOutput(audioOutput) else { throw CaptureError.cannotAddOutput }
        session.addOutput(audioOutput)
    }

    func start() {
        session.startRunning()

        // synchronizationClock thay thế masterClock từ iOS 15.4.
        // Đây là clock mà tất cả PTS của session tham chiếu tới.
        if #available(iOS 15.4, *) {
            syncClock = session.synchronizationClock
        } else {
            syncClock = session.masterClock
        }
    }

    enum CaptureError: Error {
        case noCamera, noMicrophone, cannotAddInput, cannotAddOutput
    }
}

extension MediaCaptureSession: AVCaptureVideoDataOutputSampleBufferDelegate,
                               AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        if output === videoOutput {
            onVideoFrame?(sampleBuffer)
        } else {
            onAudioFrame?(sampleBuffer)
        }
    }
}
```

### 3.2 Kiểm chứng

```swift
// PTS của audio và video phải nằm trên cùng timeline.
// Chênh lệch giữa PTS audio mới nhất và PTS video mới nhất
// phải nhỏ (thường < 50ms, do audio buffer 20ms + video 33ms).
let delta = CMTimeSubtract(audioPTS, videoPTS)
print("A/V capture delta: \(CMTimeGetSeconds(delta) * 1000) ms")
```

Nếu con số này lớn hoặc trôi dần theo thời gian, timestamp đang lấy từ hai clock khác nhau.

## 4. Stage 2: Encode

### 4.1 Video: VideoToolbox và cấu trúc GOP

Video nén dựa trên **temporal redundancy**: khung liên tiếp giống nhau ~95%.

```
GOP (Group of Pictures), keyframe interval = 2s @ 30fps
│
├─ I-frame  (Intra)      ~100 KB  tự giải mã được, không phụ thuộc frame khác
├─ P-frame  (Predicted)  ~5 KB    tham chiếu frame TRƯỚC
├─ P-frame               ~5 KB
├─ B-frame  (Bi-dir)     ~2 KB    tham chiếu cả TRƯỚC và SAU
└─ ... (60 frames) rồi lặp lại I-frame
```

Hai quyết định có ảnh hưởng lớn đến latency:

**Tắt B-frame.** B-frame tham chiếu frame tương lai, nên encoder phải buffer thêm frame trước khi output. Điều này tạo ra `DTS != PTS` và cộng thêm latency bằng số B-frame × frame duration. Với real-time streaming, luôn `AllowFrameReordering = false`.

**Keyframe interval.** Keyframe càng dày thì recovery sau mất packet càng nhanh, nhưng bitrate càng cao (I-frame lớn gấp 20 lần P-frame). WebRTC dùng keyframe on-demand (chỉ gửi khi receiver gửi PLI). HLS bắt buộc keyframe ở đầu mỗi segment.

```swift
import VideoToolbox

/// H.264 encoder cấu hình cho low-latency streaming.
final class H264Encoder {

    private var session: VTCompressionSession?
    private let width: Int32
    private let height: Int32

    /// Output: (NAL units dạng AVCC, PTS, isKeyframe)
    var onEncodedFrame: ((Data, CMTime, Bool) -> Void)?

    /// SPS/PPS. Phải gửi trước frame đầu tiên và mỗi lần gửi keyframe
    /// (với protocol không có out-of-band signaling), nếu không decoder
    /// phía nhận không khởi tạo được.
    private(set) var parameterSets: (sps: Data, pps: Data)?

    init(width: Int32, height: Int32, bitrate: Int32, fps: Int32) throws {
        self.width = width
        self.height = height

        var maybeSession: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: [
                kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder: true
            ] as CFDictionary,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: Self.outputCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &maybeSession
        )
        guard status == noErr, let session = maybeSession else {
            throw EncoderError.creationFailed(status)
        }
        self.session = session

        try configure(session: session, bitrate: bitrate, fps: fps)
        VTCompressionSessionPrepareToEncodeFrames(session)
    }

    private func configure(session: VTCompressionSession,
                           bitrate: Int32, fps: Int32) throws {
        func set(_ key: CFString, _ value: CFTypeRef) throws {
            let s = VTSessionSetProperty(session, key: key, value: value)
            guard s == noErr else { throw EncoderError.propertyFailed(key as String, s) }
        }

        // RealTime: encoder không được block chờ frame sau.
        try set(kVTCompressionPropertyKey_RealTime, kCFBooleanTrue)

        // Tắt frame reordering => không có B-frame => DTS == PTS.
        try set(kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse)

        try set(kVTCompressionPropertyKey_ProfileLevel,
                kVTProfileLevel_H264_High_AutoLevel)

        // Keyframe mỗi 2 giây. Dùng cả hai key: interval theo số frame
        // là cận trên, duration theo thời gian là ràng buộc thực sự khi
        // fps thực tế dao động (điều kiện ánh sáng yếu làm fps giảm).
        try set(kVTCompressionPropertyKey_MaxKeyFrameInterval,
                NSNumber(value: fps * 2))
        try set(kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration,
                NSNumber(value: 2.0))

        try set(kVTCompressionPropertyKey_ExpectedFrameRate,
                NSNumber(value: fps))
        try set(kVTCompressionPropertyKey_AverageBitRate,
                NSNumber(value: bitrate))

        // DataRateLimits là hard cap trong cửa sổ trượt: [bytes, seconds].
        // AverageBitRate chỉ là mục tiêu dài hạn, encoder vẫn có thể
        // burst khi có keyframe. Cap này chống burst làm nghẽn link.
        let maxBytesPerSecond = NSNumber(value: Double(bitrate) / 8.0 * 1.5)
        try set(kVTCompressionPropertyKey_DataRateLimits,
                [maxBytesPerSecond, NSNumber(value: 1.0)] as CFArray)
    }

    func encode(pixelBuffer: CVPixelBuffer, pts: CMTime,
                duration: CMTime, forceKeyframe: Bool = false) {
        guard let session else { return }

        let props: CFDictionary? = forceKeyframe
            ? [kVTEncodeFrameOptionKey_ForceKeyFrame: kCFBooleanTrue!] as CFDictionary
            : nil

        VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: pts,
            duration: duration,
            frameProperties: props,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )
    }

    /// Thay đổi bitrate runtime, không cần tạo lại session.
    /// Gọi khi congestion controller báo bandwidth mới.
    func updateBitrate(_ bitrate: Int32) {
        guard let session else { return }
        VTSessionSetProperty(session,
                             key: kVTCompressionPropertyKey_AverageBitRate,
                             value: NSNumber(value: bitrate))
    }

    func invalidate() {
        guard let session else { return }
        VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
        VTCompressionSessionInvalidate(session)
        self.session = nil
    }

    // MARK: - Output callback (chạy trên encoder thread nội bộ của VT)

    private static let outputCallback: VTCompressionOutputCallback = {
        outputCallbackRefCon, _, status, _, sampleBuffer in

        guard status == noErr,
              let refcon = outputCallbackRefCon,
              let sampleBuffer,
              CMSampleBufferDataIsReady(sampleBuffer) else { return }

        let encoder = Unmanaged<H264Encoder>
            .fromOpaque(refcon).takeUnretainedValue()
        encoder.handleEncoded(sampleBuffer)
    }

    private func handleEncoded(_ sampleBuffer: CMSampleBuffer) {
        let isKeyframe = Self.detectKeyframe(sampleBuffer)

        // Trích SPS/PPS từ format description mỗi lần có keyframe.
        // Format description có thể thay đổi khi bitrate/resolution đổi.
        if isKeyframe,
           let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
            parameterSets = Self.extractParameterSets(from: formatDesc)
        }

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        var totalLength = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(
            blockBuffer, atOffset: 0, lengthAtOffsetOut: nil,
            totalLengthOut: &totalLength, dataPointerOut: &dataPointer
        ) == noErr, let dataPointer else { return }

        let data = Data(bytes: dataPointer, count: totalLength)
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        onEncodedFrame?(data, pts, isKeyframe)
    }

    private static func detectKeyframe(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer, createIfNecessary: false
        ) as? [[CFString: Any]], let first = attachments.first else {
            return false
        }
        // Không có NotSync => là sync sample => keyframe.
        return (first[kCMSampleAttachmentKey_NotSync] as? Bool) != true
    }

    private static func extractParameterSets(
        from formatDesc: CMFormatDescription
    ) -> (sps: Data, pps: Data)? {
        var spsSize = 0, spsCount = 0
        var spsPointer: UnsafePointer<UInt8>?
        guard CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDesc, parameterSetIndex: 0,
            parameterSetPointerOut: &spsPointer,
            parameterSetSizeOut: &spsSize,
            parameterSetCountOut: &spsCount,
            nalUnitHeaderLengthOut: nil
        ) == noErr, let spsPointer else { return nil }

        var ppsSize = 0
        var ppsPointer: UnsafePointer<UInt8>?
        guard CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDesc, parameterSetIndex: 1,
            parameterSetPointerOut: &ppsPointer,
            parameterSetSizeOut: &ppsSize,
            parameterSetCountOut: nil,
            nalUnitHeaderLengthOut: nil
        ) == noErr, let ppsPointer else { return nil }

        return (Data(bytes: spsPointer, count: spsSize),
                Data(bytes: ppsPointer, count: ppsSize))
    }

    enum EncoderError: Error {
        case creationFailed(OSStatus)
        case propertyFailed(String, OSStatus)
    }
}
```

### 4.2 Hai định dạng NAL: AVCC vs Annex B

Đây là chỗ gây bug im lặng rất nhiều.

```
AVCC (Apple, MP4 container):
[4-byte big-endian length][NAL payload][4-byte length][NAL payload]...

Annex B (RTP, MPEG-TS, hầu hết non-Apple decoder):
[0x00 0x00 0x00 0x01][NAL payload][0x00 0x00 0x00 0x01][NAL payload]...
```

VideoToolbox **luôn output AVCC**. Nếu bạn gửi thẳng lên RTMP hay MPEG-TS mà không convert, decoder phía nhận sẽ ra màn hình xanh hoặc không decode được gì cả.

```swift
extension Data {
    /// Convert AVCC (length-prefixed) sang Annex B (start-code).
    /// nalLengthSize thường là 4, nhưng phải đọc từ format description
    /// để chắc chắn (có thể là 1, 2 hoặc 4).
    func avccToAnnexB(nalLengthSize: Int = 4) -> Data {
        var output = Data()
        let startCode: [UInt8] = [0x00, 0x00, 0x00, 0x01]
        var offset = 0

        while offset + nalLengthSize <= count {
            var nalLength: UInt32 = 0
            for i in 0..<nalLengthSize {
                nalLength = (nalLength << 8) | UInt32(self[offset + i])
            }
            offset += nalLengthSize

            guard nalLength > 0, offset + Int(nalLength) <= count else { break }

            output.append(contentsOf: startCode)
            output.append(self[offset..<(offset + Int(nalLength))])
            offset += Int(nalLength)
        }
        return output
    }
}
```

### 4.3 Audio: Opus vs AAC

| | Opus | AAC-LC |
|---|---|---|
| Frame size | 2.5–60ms (thường 20ms) | 1024 samples (~21ms @ 48kHz) |
| Algorithmic delay | ~26ms | ~50–100ms |
| Bitrate hữu dụng | 6–510 kbps, tốt từ 24kbps | Cần ≥ 64kbps |
| In-band FEC | Có (LBRR) | Không |
| Hardware encode iOS | Không (nhưng rất nhẹ) | Có |
| Dùng cho | WebRTC (mandatory) | HLS, RTMP, DASH |

Opus thắng rõ rệt về latency và khả năng chống mất packet, nên WebRTC bắt buộc dùng nó. AAC thắng về hệ sinh thái, nên HLS/RTMP dùng nó.

```swift
import AVFoundation

/// AAC-LC encoder cho pipeline RTMP/HLS.
final class AACEncoder {

    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat

    /// ADTS header cần thiết cho MPEG-TS. Với FLV/MP4 thì dùng
    /// AudioSpecificConfig (2 bytes) gửi một lần ở đầu stream thay vì
    /// ADTS header trên từng frame.
    var onEncodedFrame: ((Data, CMTime) -> Void)?

    init(sampleRate: Double = 48_000, channels: UInt32 = 1,
         bitrate: Int = 64_000) throws {
        guard let inputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: true
        ) else { throw AudioError.invalidFormat }

        var outDesc = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,   // AAC-LC luôn 1024 samples/frame
            mBytesPerFrame: 0,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 0,
            mReserved: 0
        )
        guard let outFormat = AVAudioFormat(streamDescription: &outDesc),
              let conv = AVAudioConverter(from: inputFormat, to: outFormat) else {
            throw AudioError.converterFailed
        }

        conv.bitRate = bitrate
        self.converter = conv
        self.outputFormat = outFormat
    }

    enum AudioError: Error { case invalidFormat, converterFailed }
}
```

## 5. Stage 3: Packetize và bài toán timestamp

### 5.1 RTP timestamp: hai clock rate khác nhau

Đây là chi tiết mà nhiều người bỏ qua nhưng lại là gốc rễ của mọi vấn đề sync.

```
Video RTP timestamp:  clock rate = 90 000 Hz  (chuẩn cho mọi video codec)
Audio RTP timestamp:  clock rate = sample rate (Opus: 48 000 Hz)
```

Với video 30fps: mỗi frame timestamp tăng `90000 / 30 = 3000`.
Với Opus frame 20ms: mỗi packet timestamp tăng `48000 × 0.02 = 960`.

Quan trọng: **RTP timestamp của hai stream có offset ngẫu nhiên và không so sánh trực tiếp được với nhau**. Chúng chỉ đo được thời gian *trong nội bộ* stream đó.

### 5.2 Cầu nối: RTCP Sender Report

RTCP SR là mảnh ghép cho phép sync hai stream. Mỗi SR chứa một cặp:

```
(NTP timestamp = wallclock 64-bit, RTP timestamp = clock nội bộ stream)
```

Nhận được SR của cả audio stream và video stream, receiver map được cả hai về một timeline chung:

```
wallclock(packet) = NTP_sr + (RTP_packet − RTP_sr) / clockRate
```

```swift
/// Mapping từ RTP timestamp của một stream sang wallclock chung.
/// Cập nhật mỗi khi nhận RTCP Sender Report (thường 1–5 giây/lần).
struct RTPTimeMapper {
    let clockRate: Double        // 90000 cho video, 48000 cho Opus

    private var ntpAnchor: Double?      // giây, từ RTCP SR
    private var rtpAnchor: UInt32?      // RTP ts tương ứng

    mutating func updateFromSenderReport(ntpSeconds: Double, rtpTimestamp: UInt32) {
        self.ntpAnchor = ntpSeconds
        self.rtpAnchor = rtpTimestamp
    }

    /// Trả về wallclock (giây) của một packet. nil khi chưa có SR nào,
    /// lúc đó chưa thể sync cross-stream, chỉ phát theo timeline nội bộ.
    func wallclock(for rtpTimestamp: UInt32) -> Double? {
        guard let ntpAnchor, let rtpAnchor else { return nil }

        // RTP timestamp là UInt32, sẽ wrap sau ~13 giờ với video 90kHz.
        // Dùng phép trừ có dấu trên Int64 để xử lý wrap-around.
        let delta = Int64(Int32(bitPattern: rtpTimestamp &- rtpAnchor))
        return ntpAnchor + Double(delta) / clockRate
    }
}
```

Nếu bỏ qua wrap-around của `UInt32`, ứng dụng sẽ mất sync đột ngột sau nhiều giờ stream. Đây là loại bug chỉ xuất hiện trong long-running session và cực khó reproduce.

### 5.3 Fragmentation cho video

Một keyframe 150KB không thể nhét vào một UDP packet (MTU ~1500 bytes, payload khả dụng ~1200 sau header IP/UDP/RTP/SRTP). RFC 6184 định nghĩa **FU-A** để chia NAL lớn:

```
NAL gốc (150 KB) → ~125 RTP packet FU-A
   packet 1:  [RTP header][FU indicator][FU header S=1][payload]
   packet 2:  [RTP header][FU indicator][FU header      ][payload]
   ...
   packet N:  [RTP header][FU indicator][FU header E=1][payload]
                                          marker bit = 1
```

Hệ quả thực tế: **mất 1 packet trong 125 packet đó là mất cả keyframe**, và mất keyframe là mất cả GOP 2 giây. Đây là lý do video freeze khi mạng yếu, trong khi audio vẫn nghe được bình thường.

`marker bit = 1` đánh dấu packet cuối của một frame. Receiver dựa vào đây để biết khi nào đủ dữ liệu để decode.

## 6. Stage 6: Jitter buffer và A/V sync

Đây là phần quyết định chất lượng cảm nhận, và cũng là phần hay bị hỏi sâu nhất.

### 6.1 Vấn đề jitter

Packet gửi cách nhau đều 20ms, nhưng đến nơi lộn xộn:

```
Gửi:  |--20ms--|--20ms--|--20ms--|--20ms--|
Nhận: |--8ms--|-----45ms-----|-3ms-|--28ms--|
                                ↑ packet #4 đến TRƯỚC #3
```

Jitter buffer giữ packet lại một khoảng, sắp xếp lại theo sequence number, rồi phát ra đều đặn. Trade-off cốt lõi:

- Buffer lớn: chống jitter tốt, nhưng cộng thẳng vào latency
- Buffer nhỏ: latency thấp, nhưng nhiều packet đến muộn bị coi như mất

Buffer phải **adaptive**. Kích thước mục tiêu ước lượng theo jitter đo được:

```swift
/// Ước lượng target delay cho jitter buffer.
/// Công thức tương tự cách WebRTC/NetEQ tính, đơn giản hoá.
struct JitterEstimator {
    private var meanJitter: Double = 0      // ms
    private var maxObserved: Double = 0

    /// Gọi mỗi khi nhận packet. arrivalDelta và rtpDelta cùng đơn vị ms.
    mutating func update(arrivalDelta: Double, rtpDelta: Double) {
        // RFC 3550: D(i-1,i) = (Ri − Ri−1) − (Si − Si−1)
        let d = abs(arrivalDelta - rtpDelta)

        // Exponential moving average, hệ số 1/16 theo RFC 3550
        meanJitter += (d - meanJitter) / 16.0

        // Decay chậm cho max, để buffer co lại được khi mạng tốt trở lại
        maxObserved = max(maxObserved * 0.999, d)
    }

    /// Target delay: bao phủ ~3 sigma của jitter, cộng một sàn tối thiểu.
    var targetDelayMs: Double {
        let computed = meanJitter * 3.0 + 20.0
        return min(max(computed, 40.0), 500.0)   // clamp 40–500ms
    }
}
```

### 6.2 A/V sync: cơ chế lip sync

Hai jitter buffer độc lập (audio và video) sẽ trôi khỏi nhau. Cần một lớp sync ở trên:

```
                    ┌──────────────────┐
  audio packets ───>│ Audio jitter buf │──> audio playout clock
                    └──────────────────┘         │
                                                 │ MASTER
                    ┌──────────────────┐         ▼
  video packets ───>│ Video jitter buf │──> so sánh wallclock
                    └──────────────────┘    → thêm/bớt delay video
```

Thuật toán:

1. Convert PTS của audio packet đang phát sang wallclock qua `RTPTimeMapper`
2. Convert PTS của video frame kế tiếp sang wallclock
3. Tính `drift = wallclock_video − wallclock_audio`
4. Nếu `drift > 0` (video đi trước): giữ frame lại, chờ
5. Nếu `drift < −threshold` (video bị chậm): drop frame, hoặc drop tới keyframe kế tiếp nếu chậm nhiều

```swift
enum VideoSyncAction {
    case render                    // đúng lúc
    case hold(seconds: Double)     // video đi trước, chờ
    case drop                      // video chậm nhẹ, bỏ frame này
    case dropToNextKeyframe        // video chậm nhiều, cần reset
}

struct AVSynchronizer {
    /// Video được phép đi trước audio bao nhiêu trước khi phải hold.
    /// Không cần quá chặt: giữ 1 frame duration là đủ.
    var leadToleranceMs: Double = 30

    /// Video được phép chậm hơn audio bao nhiêu.
    /// Nới rộng hơn phía lead vì tai người quen với việc âm thanh
    /// đến sau hình ảnh (như trong thực tế, tốc độ âm thanh chậm hơn
    /// ánh sáng), nên audio-sau-video khó chịu hơn video-sau-audio.
    var lagToleranceMs: Double = 80

    /// Quá ngưỡng này thì không catch up bằng drop lẻ được nữa.
    var resyncThresholdMs: Double = 400

    func decide(videoWallclock: Double, audioWallclock: Double) -> VideoSyncAction {
        let driftMs = (videoWallclock - audioWallclock) * 1000

        if driftMs > leadToleranceMs {
            return .hold(seconds: (driftMs - leadToleranceMs) / 1000)
        }
        if driftMs < -resyncThresholdMs {
            return .dropToNextKeyframe
        }
        if driftMs < -lagToleranceMs {
            return .drop
        }
        return .render
    }
}
```

Ngưỡng cảm nhận của người dùng, dùng để đặt threshold:

| Lệch A/V | Cảm nhận |
|---|---|
| < 30ms | Không phát hiện được |
| 30–80ms | Hầu hết không nhận ra |
| 80–150ms | Bắt đầu thấy "lệch môi" |
| > 200ms | Rõ ràng, gây khó chịu |

Nguyên tắc: **audio đi sau video dễ chấp nhận hơn audio đi trước video**, nên window bất đối xứng.

### 6.3 Clock drift dài hạn

Vấn đề tinh vi: audio DAC của thiết bị nhận chạy ở 47 998 Hz thay vì đúng 48 000 Hz. Sai số 0.004% nghe như không đáng kể, nhưng sau 1 giờ stream tích luỹ thành ~150ms lệch.

Cách xử lý:
- **Audio**: resample rất nhẹ (NetEQ làm time-stretching/compression bằng WSOLA, thay đổi ±0.5% không nghe ra được)
- **Video**: duplicate hoặc drop 1 frame mỗi vài phút, mắt không thấy

Nếu chỉ dựa vào timestamp nội bộ mà không định kỳ re-anchor bằng RTCP SR, drift này sẽ tích luỹ vô hạn.

## 7. Stage 7: Render trên iOS

Apple cung cấp sẵn lớp sync này qua `AVSampleBufferRenderSynchronizer`. Nó quản lý một `CMTimebase` chung cho cả video layer và audio renderer, tự lo phần đồng bộ.

```swift
import AVFoundation

/// Playback pipeline cho stream đã decode.
/// AVSampleBufferRenderSynchronizer giữ một CMTimebase chung, đảm bảo
/// video layer và audio renderer đọc cùng một timeline.
final class MediaRenderer {

    private let synchronizer = AVSampleBufferRenderSynchronizer()
    private let displayLayer = AVSampleBufferDisplayLayer()
    private let audioRenderer = AVSampleBufferAudioRenderer()

    private let feedQueue = DispatchQueue(label: "renderer.feed")

    var videoLayer: CALayer { displayLayer }

    init() {
        displayLayer.videoGravity = .resizeAspectFill

        synchronizer.addRenderer(displayLayer)
        synchronizer.addRenderer(audioRenderer)
    }

    /// Bắt đầu playback tại một thời điểm trên timeline.
    /// startTime nên là PTS của sample đầu tiên, KHÔNG phải .zero,
    /// nếu stream không bắt đầu từ 0.
    func start(at startTime: CMTime) {
        synchronizer.setRate(1.0, time: startTime)
    }

    func pause() {
        synchronizer.rate = 0
    }

    func enqueue(video sampleBuffer: CMSampleBuffer) {
        guard displayLayer.isReadyForMoreMediaData else {
            // Layer đang đầy. Drop thay vì buffer thêm, để tránh
            // latency phình dần.
            return
        }
        displayLayer.enqueue(sampleBuffer)
    }

    func enqueue(audio sampleBuffer: CMSampleBuffer) {
        guard audioRenderer.isReadyForMoreMediaData else { return }
        audioRenderer.enqueue(sampleBuffer)
    }

    /// Gọi khi decoder bị lỗi hoặc sau khi seek: xoá buffer đang chờ.
    func flush() {
        displayLayer.flushAndRemoveImage()
        audioRenderer.flush()
    }

    /// Điều chỉnh rate rất nhẹ để bù clock drift dài hạn,
    /// thay vì drop/duplicate frame thô.
    func nudgeRate(_ delta: Double) {
        let newRate = Float(1.0 + max(min(delta, 0.005), -0.005))
        synchronizer.setRate(newRate, time: synchronizer.currentTime())
    }

    /// Latency hiện tại: khoảng cách giữa timeline playback
    /// và PTS mới nhất đã nhận.
    func currentLatency(latestReceivedPTS: CMTime) -> Double {
        CMTimeGetSeconds(CMTimeSubtract(latestReceivedPTS, synchronizer.currentTime()))
    }
}
```

Từ iOS 17, nên dùng `displayLayer.sampleBufferRenderer` (`AVSampleBufferVideoRenderer`) để có thêm control về render pacing và diagnostics.

Xử lý khi buffer cạn hoặc lỗi decode:

```swift
// displayLayer có thể vào trạng thái failed khi decoder gặp
// bitstream lỗi. Bắt buộc observe, nếu không màn hình sẽ đứng im
// vĩnh viễn mà không có log gì.
NotificationCenter.default.addObserver(
    forName: .AVSampleBufferDisplayLayerFailedToDecode,
    object: displayLayer, queue: .main
) { [weak self] note in
    let error = note.userInfo?[AVSampleBufferDisplayLayerFailedToDecodeNotificationErrorKey]
    print("Decode failed: \(String(describing: error))")
    // Recovery: flush layer, yêu cầu sender gửi keyframe mới (PLI).
    self?.flush()
    self?.onNeedKeyframe?()
}
```

## 8. Sync trong các protocol khác nhau

Cùng một bài toán, ba cách giải khác nhau. Nắm bảng này là đủ trả lời phần lớn câu hỏi so sánh protocol.

| Protocol | Cách carry A/V | Cách sync |
|---|---|---|
| **WebRTC** | 2 RTP stream riêng, khác SSRC | RTCP Sender Report map RTP ts → NTP wallclock |
| **RTMP/FLV** | Interleave trong 1 TCP stream | Timestamp chung đơn vị ms, cùng timebase |
| **HLS/DASH (fMP4)** | Muxed trong cùng segment, hoặc separate track | Cùng `timescale` trong `moov`, sync by construction |
| **MPEG-TS** | Multiplex theo PID | PCR (Program Clock Reference) + PTS/DTS @ 90kHz |
| **SRT** | Thường bọc MPEG-TS | Như MPEG-TS, cộng thêm timestamp-based delivery của SRT |

Nhận xét đáng nêu trong interview: **muxed container (HLS, MPEG-TS) sync dễ hơn nhiều so với separate stream (WebRTC)**, vì timestamp đã nằm trên cùng timebase từ lúc mux. Cái giá phải trả là mất khả năng xử lý độc lập: không thể adapt bitrate video mà không đụng tới audio, không thể drop video layer riêng lẻ, không thể để audio đi tiếp khi video bị nghẽn.

WebRTC chọn separate stream chính vì cần khả năng độc lập đó: ưu tiên audio khi mạng yếu, simulcast video nhiều layer, và bỏ video hoàn toàn mà vẫn giữ cuộc gọi.

## 9. Checklist debug thực chiến

Khi gặp sự cố, đối chiếu bảng này để khoanh vùng stage:

| Hiện tượng | Nguyên nhân thường gặp | Kiểm tra |
|---|---|---|
| Video freeze, audio bình thường | Mất keyframe, mất một FU-A packet | `framesDropped`, `pliCount`, `keyFramesDecoded` |
| Audio ngắt quãng, video ổn | Jitter buffer quá nhỏ, thiếu FEC | `jitter`, `concealedSamples`, `packetsLost` |
| Lệch môi tăng dần theo thời gian | Clock drift, thiếu re-anchor RTCP SR | So `wallclock` audio và video mỗi 30s |
| Lệch môi cố định từ đầu | Timestamp gán từ hai clock domain khác nhau | PTS lúc capture, `synchronizationClock` |
| Latency tăng dần | Queue phình, không drop frame khi trễ | `alwaysDiscardsLateVideoFrames`, độ dài buffer |
| Màn hình xanh / không decode | AVCC gửi thẳng vào RTP, thiếu SPS/PPS | Hexdump 8 byte đầu: `00000001` hay length? |
| Video mờ dù mạng tốt | Encoder software, thermal throttle | `qualityLimitationReason == "cpu"` |
| Mất tiếng sau khi cắm tai nghe | Không handle route change | `AVAudioSession.routeChangeNotification` |

Cách kiểm chứng nhanh nhất mà không cần tool: log mỗi 2 giây bốn con số này ở đầu nhận.

```swift
struct PipelineHealth: CustomStringConvertible {
    let avDriftMs: Double        // video wallclock − audio wallclock
    let audioBufferMs: Double    // độ dài jitter buffer audio
    let videoBufferMs: Double
    let e2eLatencyMs: Double     // capture PTS → render time

    var description: String {
        String(format: "drift=%+.0fms aBuf=%.0f vBuf=%.0f e2e=%.0fms",
               avDriftMs, audioBufferMs, videoBufferMs, e2eLatencyMs)
    }
}
```

`drift` phải dao động quanh 0 và không có xu hướng tăng. Nếu nó trôi một chiều, vấn đề là clock, không phải mạng.

---

Nếu Huy muốn đào tiếp, ba hướng liên quan trực tiếp đến sản phẩm video studio là: **cấu trúc bitstream H.264 ở mức NAL/SPS** (cần khi phải parse, transmux, hoặc chèn SEI metadata), **NetEQ và packet loss concealment** cho audio (phần ít người nắm nhưng hay được hỏi sâu), hoặc **transmux WebRTC sang RTMP/HLS ở server** kèm bài toán re-timestamp khi chuyển giữa hai timebase.
