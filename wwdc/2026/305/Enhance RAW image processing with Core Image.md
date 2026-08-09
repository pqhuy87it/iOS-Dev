Video **"Enhance RAW image processing with Core Image" (WWDC26, session 305)**, do David Hayward trình bày. Có transcript đầy đủ. Session giới thiệu **RAW version 9** — bản cập nhật lớn nhất từ trước tới nay của pipeline xử lý ảnh RAW trên nền tảng Apple, dựa trên Core ML chạy trên Apple Neural Engine.

---

## Tóm tắt các mục chính

1. **How Core Image supports RAW (0:52)** — Các bước xử lý RAW: parse, demosaic, denoise, convolution (sharpen), điều chỉnh màu/tone; và cách hệ thống hỗ trợ sẵn.
2. **The evolution of RAW support (2:48)** — Lịch sử pipeline RAW qua 9 phiên bản, nay hỗ trợ 784 model máy ảnh.
3. **RAW 9 overview (3:33)** — Pipeline mới dùng Core ML kết hợp demosaic + denoise, chạy trên Neural Engine.
4. **RAW 9 quality improvements (3:56)** — So sánh RAW 8 vs RAW 9: sắc nét, màu chính xác, khử nhiễu vượt trội.
5. **Enable and edit RAW 9 with CIRAWFilter (5:50)** — Cách opt-in `version9`, kiểm tra máy ảnh hỗ trợ, và 20 thuộc tính chỉnh sửa.
6. **Performance overview + Interactive editing + Exporting (8:33)** — Best practice cho hai use case: chỉnh sửa tương tác và export.
7. **New CIImageProcessor features (11:50)** — Hai API mới: explicit output tile sizes và temporary buffers.

---

## Chi tiết từng mục

### 1. How Core Image supports RAW — Quy trình xử lý RAW
File RAW đến từ nhiều hãng/model máy ảnh khác nhau, và **khác với HEIF/JPEG, chúng cần xử lý đặc biệt trước khi hiển thị**. Các bước:
1. **Parse metadata + unpack sensor values** — mỗi pixel lúc này chỉ có **một** giá trị R, G *hoặc* B, sắp theo mosaic pattern (Bayer).
2. **Demosaic** — nội suy để mỗi pixel có đủ cả ba giá trị R, G, B.
3. **Denoise** — khử photon noise, read noise, thermal noise.
4. **Convolution** — làm sắc nét cạnh (sharpen) và thêm local contrast.
5. **Adjust white balance, exposure, color, tone** — tạo ảnh cuối hài hòa.

Thuật toán cho tất cả các bước này **được tích hợp sẵn** trong iOS/iPadOS/macOS/visionOS. Nhờ đó xem RAW được ngay trong Finder, Preview, Freeform. Bất kỳ app/framework nào dùng **Image IO** đều tự động có hỗ trợ RAW. App muốn có **điều khiển chỉnh sửa nâng cao** thì dùng **CIRAWFilter** (như Photos, Pixelmator Pro, Nitro, Acorn...).

### 2. The evolution of RAW support — Lịch sử phát triển
Từ 2006, hệ thống ban đầu chỉ có calibration thủ công cho **21 model**. Đến nay đã lên **784 model** trải khắp các hãng lớn, gồm cả **Apple ProRAW** cho iPhone. Điểm cốt lõi của RAW: **một tấm ảnh cũ chụp nhiều năm trước có thể được xử lý lại bằng thuật toán mới nhất**. Pipeline đã cập nhật 8 lần (mỗi lần cải thiện demosaic, denoise, color), và **một số phiên bản cũ vẫn được giữ lại** để người dùng chọn nếu muốn.

### 3. RAW 9 overview — Tổng quan RAW 9
Đây là **bản cập nhật lớn nhất**. RAW 9 cải thiện đáng kể việc render RAW, xây dựng trên một **Core ML model dạng tiled (chia ô)** kết hợp **demosaic với denoise** để đạt chất lượng tốt nhất. Model chạy **on-device trên các nhân Apple Neural Engine** để tối ưu hiệu năng.

### 4. RAW 9 quality improvements — Cải thiện chất lượng
Ba ví dụ so sánh trực tiếp:
- **Ảnh ít nhiễu** (Sony Alpha 7 II, mặt đồng hồ đo): RAW 8 vốn đã đẹp, nhưng RAW 9 **sắc nét hơn, chữ nhỏ dễ đọc hơn**.
- **Ảnh nhiễu cao** (Canon 5D Mark III, ISO 51.200, crop 10x hộp bút chì màu): RAW data gốc nhiễu luma/chroma đến mức không phân biệt được màu; RAW 8 khôi phục màu ở mức chấp nhận được, còn RAW 9 **màu chính xác, rõ nét, thấy được cả highlight bóng loáng**.
- **Sensor phi truyền thống** (Fujifilm X-T5, ISO 12.800, chỉ sợi thêu): RAW 8 có color artifact và mất chi tiết; RAW 9 **chữ dễ đọc hơn, texture rõ hơn** (sensor Fuji X-Trans khó demosaic).

### 5. Enable and edit RAW 9 with CIRAWFilter — Bật và chỉnh sửa

**Opt-in (quan trọng: RAW 9 KHÔNG bật mặc định)**
```swift
// Kiểm tra hỗ trợ rồi mới chọn version9
if filter.supportedDecoderVersions.contains(.version9) {
    filter.decoderVersion = .version9
}
```

**Kiểm tra máy ảnh hỗ trợ** — có class method mới `supportedCameraModels` trả về mảng model được hỗ trợ cho một version. Bản phát hành iOS/iPadOS/macOS/visionOS 27 có **hàng trăm model** dùng được RAW 9, và danh sách này **mở rộng qua cập nhật OTA**. Máy quay **DNG native** (như iPhone) tự động được hỗ trợ.

**20 thuộc tính chỉnh sửa** — Bốn cái quan trọng nhất:
- `exposure` — làm sáng/tối ảnh.
- `luminanceNoiseReductionAmount` — mức khử nhiễu hạt luma.
- `sharpnessAmount` — mức làm sắc nét cạnh.
- `contrastAmount` — mức local contrast quanh cạnh.

Tất cả đều hoạt động **tốt hơn** trong RAW 9 so với trước.

**Thuộc tính không còn dùng trong RAW 9** (vì model Core ML tự lo):
- `colorNoiseReductionAmount` — **không còn tác dụng** (model tự khử color noise).
- `detailAmount` và `moireReductionAmount` — **không còn cần và không được hỗ trợ**.

Dùng các property `is...Supported` để kiểm tra thuộc tính nào còn hiệu lực với instance filter.

### 6. Performance — Hiệu năng và best practice
RAW 9 **tốn tài nguyên hơn** các version trước (model Core ML chạy hàng trăm lần mỗi ảnh). Nhưng khi app chỉnh property, các lần render sau **nhanh và mượt** nhờ Core Image **cache kết quả trung gian**. Hai use case chính:

**a) Interactive editing (9:19)** — một file RAW render nhiều lần ở độ phân giải màn hình (khi chỉnh exposure/sharpness...):
- Dùng `scaleFactor` của CIRAWFilter khi hiển thị thu nhỏ → giảm việc render với ảnh nhiều megapixel hơn màn hình.
- Dùng **một `CIContext` cho mỗi view**, đặt `cacheIntermediates = true` → bỏ qua được phần Core ML nặng khi đang chỉnh.
- Thêm **Extended Virtual Addressing entitlement** để Core Image dùng nhiều bộ nhớ hơn cho cache giữa các lần render.
- **Render thẳng vào Metal-backed view (`MTKView`)** → Metal bắt đầu frame kế trước khi frame trước xong.

**b) Exporting (10:52)** — nhiều file RAW, mỗi file render **một lần** ở full resolution sang HEIF/JPEG:
```swift
let exportCtx = CIContext(options: [
  .cacheIntermediate: false,   // export chỉ render 1 lần → tắt cache
  .memoryLimit: 512            // MB; mặc định iOS là 256, tăng lên 512/1024 nhanh hơn
])
```
- Tắt `cacheIntermediates` (không tái sử dụng nên cache vô ích).
- Tăng `memoryLimit` (256 MB mặc định trên iOS khá dè dặt; 512 hoặc 1024 MB cải thiện rõ).
- Dùng `heifRepresentation` / `jpegRepresentation` của context thay vì gọi Image IO trực tiếp → **tiết kiệm bộ nhớ** hơn.

### 7. New CIImageProcessor features — Hai API mới
RAW 9 dùng **CIImageProcessor** vì nó cho phép kết hợp Core ML với các CIKernel khác. Nhân đó, Apple thêm hai tính năng bạn có thể dùng:

**a) Explicit output tile sizes (12:23)**
Bình thường Core Image tự quyết `output.region`: nếu đủ bộ nhớ thì xử lý cả ảnh một lần, thiếu bộ nhớ thì chia ô nhỏ. Giờ bạn **tự kiểm soát kích thước ô output**. Code trong processor giữ nguyên (vẫn implement `roi` và `process`), chỉ cần truyền mảng tile khi apply:
```swift
class MyProcessor: CIImageProcessorKernel {
    override class func roi(forInput input: Int32, arguments: [String:Any]?,
                            outputRect: CGRect) -> CGRect { return outputRect }

    override class func process(with inputs: [CIImageProcessorInput]?,
                                arguments: [String:Any]?,
                                output: CIImageProcessorOutput) throws {
        guard let input = inputs?.first,
              let iBuffer = input.pixelBuffer,
              let oBuffer = output.pixelBuffer else { return }
        let iRegion = input.region
        let oRegion = output.region   // do Core Image kiểm soát
        // MyCopyBuffer(iBuffer, iRegion, oBuffer, oRegion)
    }
}

// Tự dựng mảng tile 512x512 phủ toàn ảnh
let extent = inImg.extent
let tileSize = 512.0
var tiles: [CIVector] = []
for y in stride(from: extent.minY, to: extent.maxY, by: tileSize) {
    for x in stride(from: extent.minX, to: extent.maxX, by: tileSize) {
        let tile = CGRect(x: x, y: y,
                          width: min(tileSize, extent.maxX - x),
                          height: min(tileSize, extent.maxY - y))
        tiles.append(CIVector(cgRect: tile))
    }
}
let result = try MyProcessor.apply(withTiledExtent: tiles, inputs: [inImg], arguments: [:])
```

**b) Temporary buffers (14:24)**
Processor gọi Core ML thường cần **buffer tạm** vì Core Image dùng buffer **interleaved**, còn Core ML cần dữ liệu **planar**. Khi xử lý nhiều tile, việc tạo/hủy buffer tạm lặp đi lặp lại làm chậm. Giờ `CIImageProcessorOutput` có method xin **scratch buffer** mà Core Image tự quản lý vòng đời (giải phóng đúng lúc và **tái sử dụng** cho tile kế):
```swift
guard let scratch = output.temporaryPixelBuffer(
        identifier: "myScratch",   // định danh, thiết yếu khi dùng nhiều buffer tạm
        format: kCVPixelFormatType_64RGBAHalf,
        width: Int(output.region.width),
        height: Int(output.region.height),
        pixelBufferAttributes: nil) else { return }
// Bước 1: copy input → scratch
// Bước 2: xử lý pixel trong scratch (in-place)
// Bước 3: copy scratch → output
```
Cung cấp `identifier` là bắt buộc khi một callback dùng nhiều hơn một buffer tạm.

---

### Điểm rút ra
- **Thử RAW 9** — cải thiện chất lượng lớn, chỉ vài dòng để bật (nhớ opt-in vì không mặc định).
- Theo **best practice hiệu năng**: export nhanh (tắt cache, tăng memoryLimit), editing mượt (scaleFactor, cache, EVA entitlement, MTKView).
- Mở cho người dùng các **thuộc tính chỉnh sửa CIRAWFilter**.
- Trong CIImageProcessor, tận dụng **explicit tiling** và **temporary buffer**.

Video liên quan nên xem: *"Capture and process ProRAW images" (WWDC21)* cho nền tảng CIRAWFilter, và *"Display EDR content with Core Image, Metal, and SwiftUI" (WWDC22)* cho phần render vào MTKView.

Muốn mình dựng một demo app RAW editor hoàn chỉnh (load RAW → bật RAW 9 → slider chỉnh exposure/sharpness/noise → render vào MTKView, kèm nút export HEIF theo đúng best practice) để bạn thực hành không?