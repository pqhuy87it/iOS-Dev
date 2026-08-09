# RAW9Lab

Demo thực hành cho WWDC26 session 305 — *Enhance RAW image processing with Core Image*.
Một RAW editor tối giản: mở file RAW → **opt-in RAW 9** → chỉnh 4 thuộc tính chính →
xem preview render bằng **Metal** → **export HEIF/JPEG** theo đúng best practice của session.

## Cách chạy
1. Xcode 26+: tạo project **iOS App** (SwiftUI) tên `RAW9Lab`.
2. Thay/kéo các file trong `RAW9Lab/` vào target.
3. Chạy trên **thiết bị thật** có chip Apple Neural Engine để thấy RAW 9 (simulator có thể
   không có RAW 9 và Metal rendering sẽ hạn chế).
4. Nhấn **Open RAW**, chọn một file CR2/CR3, NEF, ARW, RAF hoặc DNG.

Yêu cầu: iOS/iPadOS/macOS/visionOS **27+** để có RAW 9. Trên OS cũ hơn, app tự fallback về
version mới nhất được hỗ trợ (thanh trạng thái sẽ báo "RAW 9 unavailable").

## Bản đồ code ↔ session

| File | Nội dung session |
|---|---|
| `RAWDocument.swift` | Opt-in `decoderVersion = .version9` sau khi kiểm tra `supportedDecoderVersions`; áp 4 property chính; bỏ qua `colorNoiseReduction`/`detail`/`moire` (RAW 9 không cần). Có `supportedCameraModels(for:)`. |
| `MetalCIImageView.swift` | Interactive editing: render thẳng vào `MTKView`, **một `CIContext`/view** với `cacheIntermediates = true`. |
| `RAWExporter.swift` | Exporting: `CIContext` với `cacheIntermediates = false`, `memoryLimit` 512/1024 MB, dùng `heifRepresentation`/`jpegRepresentation`. |
| `CIImageProcessorDemo.swift` | Hai API mới của `CIImageProcessor`: **explicit output tile sizes** (`apply(withTiledExtent:)`) và **temporary buffers** (`output.temporaryPixelBuffer(identifier:...)`). |
| `ContentView.swift` | UI: import file, thanh trạng thái RAW 9, slider Exposure/Luma NR/Sharpness/Contrast, nút Export. Preview dùng `scaleFactor 0.5` cho mượt. |

## 4 thuộc tính chỉnh sửa (session nhấn mạnh)
- **Exposure** — làm sáng/tối (EV).
- **Luminance NR** — khử nhiễu hạt luma.
- **Sharpness** — làm sắc nét cạnh.
- **Contrast** — local contrast quanh cạnh.

RAW 9 tự lo color noise reduction, nên `colorNoiseReductionAmount` không còn tác dụng và
`detailAmount`/`moireReductionAmount` bị loại. Code dùng `isSharpnessSupported`,
`isContrastSupported`, `isLuminanceNoiseReductionSupported` để chỉ áp khi hợp lệ.

## Entitlement bộ nhớ (tùy chọn, cho editing mượt hơn)
Session khuyên thêm **Extended Virtual Addressing** để Core Image cache nhiều hơn giữa các
lần render. Trong Xcode: target ▸ Signing & Capabilities ▸ thêm entitlement
`com.apple.developer.kernel.extended-virtual-addressing` (cần provisioning phù hợp).
Xem tài liệu Apple về entitlement này.

## Thực hành đề xuất
1. **RAW 9 vs cũ**: mở cùng một ảnh nhiễu cao (ví dụ ISO ≥ 12.800). So thanh trạng thái và
   quan sát mức chi tiết/nhiễu khi kéo Luma NR.
2. **scaleFactor**: đổi `refreshPreview()` từ `0.5` sang `1.0` và cảm nhận độ trễ khi kéo slider
   trên ảnh nhiều megapixel — đây là lý do session khuyên dùng scaleFactor khi hiển thị thu nhỏ.
3. **Export memoryLimit**: trong `RAWExporter.makeExportContext`, thử 256 vs 1024 MB và đo thời
   gian export (Instruments ▸ Time Profiler, hoặc bọc bằng `ContinuousClock`).
4. **cacheIntermediates**: bật `true` cho export và quan sát bộ nhớ tăng vô ích (vì mỗi file chỉ
   render một lần) — minh họa vì sao session khuyên tắt.
5. **CIImageProcessor**: gọi `TilingDemo.run(on:)` với một `CIImage` bất kỳ và thử đổi `tileSize`.

## Ghi chú tương thích API
- `CIRAWDecoderVersion` là **typed string enum**. `.version9` chỉ tồn tại trên SDK WWDC26.
  Nếu SDK bạn chưa có, dòng `.version9` sẽ không biên dịch — tạm bỏ nhánh đó hoặc build bằng
  Xcode 26+.
- `supportedCameraModels(for:)` (có tham số version) là API WWDC26; bản không tham số
  (`supportedCameraModels`) đã có từ trước.
- `apply(withTiledExtent:inputs:arguments:)` là entry point tiling mới của WWDC26.
- `temporaryPixelBuffer(identifier:format:width:height:pixelBufferAttributes:)` là API mới trên
  `CIImageProcessorOutput`.
- `MTKView` không chạy tốt trên một số simulator; ưu tiên thiết bị thật.
