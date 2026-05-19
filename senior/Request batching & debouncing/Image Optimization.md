# Image Optimization trong iOS

## 1. Tại sao Image Optimization quan trọng?

### Bài toán thực tế

Một màn hình feed hiển thị 10 ảnh, mỗi ảnh server trả về 4K (3840×2160). Thiết bị hiển thị trong UIImageView 375×200 points (@3x = 1125×600 pixels).

```
Ảnh gốc 4K JPEG:     ~3-5 MB × 10 ảnh = 30-50 MB bandwidth
Decoded in memory:    3840 × 2160 × 4 bytes = ~33 MB mỗi ảnh
                      10 ảnh = ~330 MB RAM ← OOM crash trên
                      iPhone cũ

Ảnh resize về 1125×600:  ~100-200 KB × 10 = 1-2 MB bandwidth  
Decoded in memory:        1125 × 600 × 4 = ~2.7 MB mỗi ảnh
                          10 ảnh = ~27 MB RAM ← hoàn toàn OK
```

**Tại sao decoded size lớn hơn file size nhiều như vậy?**

JPEG/WebP trên disk là dạng **compressed**. Khi hiển thị, GPU cần **uncompressed bitmap** — mỗi pixel cần 4 bytes (RGBA). Đây là điểm nhiều developer bỏ qua: file nhỏ không có nghĩa là memory footprint nhỏ.

---

## 2. Image Formats — Hiểu bản chất

### JPEG chuẩn (Baseline)

```
Cách decode Baseline JPEG:

  Scan 1 (duy nhất): ████████████████████████████████ 100%
                      ↑                                ↑
                   Bắt đầu                     Xong → hiển thị

  User thấy: [        trống        ] → [   ảnh hoàn chỉnh   ]
              Loading...                  Xuất hiện đột ngột
```

Ảnh được encode **từ trên xuống dưới**, scan line by line. Phải download xong toàn bộ mới decode được đầy đủ. Nếu network chậm, user nhìn thấy ảnh "rơi" từ trên xuống hoặc không thấy gì cho đến khi xong.

### Progressive JPEG

```
Cách decode Progressive JPEG:

  Scan 1:  ░░░░░░░░░░░░░░░░░░  Toàn bộ ảnh, cực mờ (DC coefficients)
  Scan 2:  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  Rõ hơn một chút (low-frequency AC)
  Scan 3:  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  Gần rõ (mid-frequency AC)
  Scan 4:  ████████████████████  Sắc nét hoàn toàn (high-frequency AC)

  User thấy: [ mờ ] → [ rõ hơn ] → [ gần rõ ] → [ sắc nét ]
              ← Perceived loading time ngắn hơn nhiều →
```

**Cơ chế bên trong:** JPEG sử dụng DCT (Discrete Cosine Transform) để chuyển pixel thành frequency coefficients. Progressive JPEG sắp xếp lại thứ tự encode: gửi **low-frequency coefficients trước** (hình dạng tổng thể, màu chủ đạo), rồi dần bổ sung **high-frequency** (chi tiết, edges, texture).

```swift
// Tạo Progressive JPEG từ UIImage
func progressiveJPEGData(from image: UIImage, quality: CGFloat = 0.8) -> Data? {
    guard let cgImage = image.cgImage else { return nil }
    
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data, kUTTypeJPEG, 1, nil
    ) else { return nil }
    
    let properties: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: quality,
        kCGImagePropertyJFIFDictionary: [
            kCGImagePropertyJFIFIsProgressive: true
        ]
    ]
    
    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
    CGImageDestinationFinalize(destination)
    
    return data as Data
}
```

### WebP

```
┌────────────────────────────────────────────────────────────┐
│ So sánh format ở cùng chất lượng visual (SSIM ~0.95)      │
│                                                            │
│ Format          │ File Size │ Decode Speed │ iOS Support   │
│─────────────────┼───────────┼──────────────┼──────────────│
│ JPEG             │ 100 KB    │ Nhanh        │ Mọi version  │
│ Progressive JPEG │ 102 KB    │ Chậm hơn ~5% │ Mọi version  │
│ WebP (lossy)     │ 70 KB     │ Chậm hơn ~10%│ iOS 14+      │
│ WebP (lossless)  │ 85 KB     │ Chậm hơn ~15%│ iOS 14+      │
│ HEIF/HEIC        │ 65 KB     │ Hardware acc. │ iOS 11+      │
│ AVIF             │ 55 KB     │ Chậm         │ iOS 16+      │
└────────────────────────────────────────────────────────────┘
```

**WebP nhỏ hơn JPEG ~25-35%** ở cùng chất lượng vì sử dụng VP8 codec (prediction-based, tương tự video compression), trong khi JPEG dùng DCT thuần. Tuy nhiên decode chậm hơn vì không có hardware acceleration trên hầu hết iPhone (HEIF thì có).

```swift
// iOS 14+ decode WebP natively
let webpData: Data = ... // từ network
let image = UIImage(data: webpData) // Just works

// Kiểm tra format support
import UniformTypeIdentifiers
let webpSupported = CGImageSourceCopyTypeIdentifiers() as? [String] ?? []
print(webpSupported.contains("org.webmproject.webp")) // true trên iOS 14+
```

**Trade-off quan trọng:** WebP tiết kiệm bandwidth (tốt cho user data plan) nhưng tốn CPU hơn khi decode (tốn pin). Cần benchmark trên target device thấp nhất của app.

---

## 3. Resize về đúng kích thước hiển thị

### Vấn đề cốt lõi

```swift
// ❌ Cách phổ biến nhưng rất tốn resource
let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 375, height: 200))
imageView.contentMode = .scaleAspectFill

// Download ảnh 4K (3840×2160), UIImageView tự scale xuống khi render
// Nhưng trong memory, ảnh 4K vẫn chiếm 33MB!
imageView.image = fullResImage
```

UIKit không tự resize ảnh trong memory. `contentMode = .scaleAspectFill` chỉ yêu cầu **GPU scale khi render** — bitmap gốc vẫn nằm nguyên trong RAM.

### Downsampling đúng cách — ImageIO

```swift
enum ImageDownsampler {
    
    /// Downsampling bằng ImageIO — KHÔNG load full image vào memory
    static func downsample(
        data: Data,
        to pointSize: CGSize,
        scale: CGFloat = UIScreen.main.scale
    ) -> UIImage? {
        
        let pixelSize = CGSize(
            width: pointSize.width * scale,
            height: pointSize.height * scale
        )
        
        let options: [CFString: Any] = [
            // Cho phép cache decoded image
            kCGImageSourceShouldCache: false,
            // QUAN TRỌNG: không decode full image trước
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Resize ngay ở tầng codec, TRƯỚC khi load vào memory
            kCGImageSourceThumbnailMaxPixelSize: max(pixelSize.width, pixelSize.height),
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}
```

**Tại sao ImageIO chứ không phải `UIGraphicsImageRenderer`?**

```swift
// ❌ UIGraphicsImageRenderer — phải decode TOÀN BỘ ảnh gốc trước
func resizeBad(image: UIImage, to size: CGSize) -> UIImage {
    // Bước 1: UIImage đã decode full 33MB vào memory
    // Bước 2: Vẽ lại vào canvas mới → peak memory = 33MB + 2.7MB
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: size))
    }
}

// ✅ ImageIO — decode trực tiếp ở kích thước nhỏ
// Peak memory chỉ ~2.7MB, không bao giờ load 33MB
let small = ImageDownsampler.downsample(data: rawData, to: CGSize(width: 375, height: 200))
```

Điểm mấu chốt: `CGImageSourceCreateThumbnailAtIndex` hoạt động ở **tầng codec** — nó đọc JPEG data và decode thẳng ra thumbnail mà không cần giải nén full resolution trước. Đây là cách tiết kiệm memory nhất.

### Server-side resize — Giải pháp tốt nhất

Thay vì client tự resize, yêu cầu server trả ảnh đúng kích thước:

```swift
// Nhiều CDN/image service hỗ trợ resize qua URL params
enum ImageURLBuilder {
    
    static func optimizedURL(
        original: URL,
        pointSize: CGSize,
        scale: CGFloat = UIScreen.main.scale
    ) -> URL {
        let pixelWidth = Int(pointSize.width * scale)
        let pixelHeight = Int(pointSize.height * scale)
        
        // Cloudinary style
        // https://res.cloudinary.com/demo/image/upload/w_1125,h_600,c_fill,q_auto,f_auto/sample.jpg
        var components = URLComponents(url: original, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "w", value: "\(pixelWidth)"),
            URLQueryItem(name: "h", value: "\(pixelHeight)"),
            URLQueryItem(name: "fit", value: "cover"),
            URLQueryItem(name: "format", value: "auto"),  // Server chọn WebP nếu client hỗ trợ
            URLQueryItem(name: "quality", value: "auto")   // Server chọn quality tối ưu
        ]
        return components.url!
    }
}

// Sử dụng
let thumbnailURL = ImageURLBuilder.optimizedURL(
    original: originalURL,
    pointSize: imageView.bounds.size
)
// Download 100KB thay vì 5MB
```

`f_auto` (format auto) là feature quan trọng: server tự detect client support và trả WebP cho iOS 14+, AVIF cho iOS 16+, fallback JPEG cho device cũ. Client không cần xử lý gì thêm.

---

## 4. Cơ chế bên trong Kingfisher/SDWebImage

Cả hai thư viện đều follow cùng một architecture. Hiểu flow này giúp debug production issues và biết khi nào cần customize.

### Pipeline tổng quan

```
imageView.kf.setImage(with: url)
                │
                ▼
┌─────────────────────────────┐
│  1. Check Memory Cache      │  NSCache<URL, UIImage>
│     (decoded UIImage)       │  → HIT: return ngay, ~0ms
└──────────────┬──────────────┘
           MISS│
               ▼
┌─────────────────────────────┐
│  2. Check Disk Cache        │  File system, keyed by URL hash
│     (encoded Data)          │  → HIT: decode → memory cache → return
└──────────────┬──────────────┘
           MISS│
               ▼
┌─────────────────────────────┐
│  3. Download                │  URLSession data task
│     (raw bytes)             │  Concurrent, có priority queue
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  4. Process                 │  Resize, round corners, blur...
│     (trên background queue) │  Xảy ra TRƯỚC khi cache
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  5. Cache                   │  Lưu vào cả memory + disk
│                             │  Memory: processed UIImage
│                             │  Disk: processed Data (re-encoded)
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  6. Display                 │  Main thread
│     (fade transition)       │  imageView.image = processed
└─────────────────────────────┘
```

### Tự implement để hiểu từng phần

```swift
actor ImagePipeline {
    
    // MARK: - Memory Cache (L1)
    // Lưu decoded UIImage, truy cập ~0ms
    // NSCache tự evict khi memory pressure
    private let memoryCache = NSCache<NSString, UIImage>()
    
    // MARK: - Disk Cache (L2)
    // Lưu encoded data (JPEG/WebP bytes), persist qua app launch
    private let diskCacheDir: URL
    
    // MARK: - Deduplication
    // Tránh download cùng URL nhiều lần đồng thời
    private var inFlightTasks: [URL: Task<UIImage, Error>] = [:]
    
    // MARK: - Main Entry Point
    func image(
        for url: URL,
        targetSize: CGSize? = nil
    ) async throws -> UIImage {
        let cacheKey = cacheKey(url: url, size: targetSize)
        
        // L1: Memory
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            return cached
        }
        
        // L2: Disk
        if let data = diskData(for: cacheKey),
           let image = processData(data, targetSize: targetSize) {
            memoryCache.setObject(image, forKey: cacheKey as NSString)
            return image
        }
        
        // Deduplication: nếu đang download URL này rồi, chờ kết quả
        if let existing = inFlightTasks[url] {
            return try await existing.value
        }
        
        // Download
        let task = Task {
            try await downloadAndProcess(url: url, cacheKey: cacheKey, targetSize: targetSize)
        }
        inFlightTasks[url] = task
        
        defer { inFlightTasks[url] = nil }
        return try await task.value
    }
    
    // MARK: - Download + Process
    private func downloadAndProcess(
        url: URL,
        cacheKey: String,
        targetSize: CGSize?
    ) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Downsample bằng ImageIO (KHÔNG load full res vào memory)
        guard let image = processData(data, targetSize: targetSize) else {
            throw ImageError.decodeFailed
        }
        
        // Cache: disk lưu data gốc, memory lưu processed image
        saveToDisk(data: data, key: cacheKey)
        memoryCache.setObject(image, forKey: cacheKey as NSString)
        
        return image
    }
    
    // MARK: - Processing
    private func processData(_ data: Data, targetSize: CGSize?) -> UIImage? {
        if let size = targetSize {
            return ImageDownsampler.downsample(data: data, to: size)
        }
        return UIImage(data: data)
    }
    
    // MARK: - Cache Key
    // Cùng URL nhưng khác targetSize → khác cache entry
    private func cacheKey(url: URL, size: CGSize?) -> String {
        if let size {
            return "\(url.absoluteString)_\(Int(size.width))x\(Int(size.height))"
        }
        return url.absoluteString
    }
}
```

### Request Deduplication — Chi tiết quan trọng

```
Không có deduplication:
  Cell 1 ──GET avatar.jpg──▶ Server
  Cell 2 ──GET avatar.jpg──▶ Server    (cùng URL!)
  Cell 3 ──GET avatar.jpg──▶ Server    (cùng URL!)
  = 3 request, 3× bandwidth

Có deduplication:
  Cell 1 ──GET avatar.jpg──▶ Server
  Cell 2 ──chờ Cell 1────▶ (reuse response)
  Cell 3 ──chờ Cell 1────▶ (reuse response)
  = 1 request, chia sẻ kết quả
```

Khi user scroll nhanh, cùng một avatar URL có thể bị request bởi nhiều cell gần như đồng thời (do cell reuse). Deduplication đảm bảo chỉ có **1 network request** cho mỗi unique URL tại bất kỳ thời điểm nào.

### Prefetching — Tích hợp UICollectionView

```swift
class FeedViewController: UIViewController {
    
    private let pipeline = ImagePipeline()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.prefetchDataSource = self
    }
}

extension FeedViewController: UICollectionViewDataSourcePrefetching {
    
    // Gọi khi cell SẮP scroll vào viewport
    func collectionView(
        _ collectionView: UICollectionView,
        prefetchItemsAt indexPaths: [IndexPath]
    ) {
        for indexPath in indexPaths {
            let item = items[indexPath.item]
            let size = cellImageSize(for: indexPath)
            
            // Bắt đầu download + process TRƯỚC khi cell hiển thị
            Task(priority: .utility) {
                _ = try? await pipeline.image(
                    for: item.imageURL,
                    targetSize: size
                )
            }
        }
    }
    
    // Gọi khi user đổi hướng scroll → cell không cần nữa
    func collectionView(
        _ collectionView: UICollectionView,
        cancelPrefetchingForItemsAt indexPaths: [IndexPath]
    ) {
        // Cancel task cho cell không còn cần
        // Tiết kiệm bandwidth + CPU cho cell thực sự hiển thị
    }
}
```

---

## 5. Memory Footprint — Phân tích chi tiết

### Tính toán thực tế

```swift
enum ImageMemoryCalculator {
    
    /// Tính memory footprint của decoded image
    static func decodedSize(
        width: Int,
        height: Int,
        bytesPerPixel: Int = 4  // RGBA
    ) -> Int {
        width * height * bytesPerPixel
    }
    
    /// Ví dụ thực tế
    static func examples() {
        // Thumbnail 100×100
        // = 100 × 100 × 4 = 40 KB ← không đáng kể
        
        // Feed image 1125×600 (@3x cho 375pt)
        // = 1125 × 600 × 4 = 2.7 MB ← hợp lý
        
        // Ảnh gốc 4K 3840×2160
        // = 3840 × 2160 × 4 = 33.2 MB ← NGUY HIỂM
        
        // Photo gallery 10 ảnh 4K
        // = 33.2 × 10 = 332 MB ← OOM crash
    }
}
```

### Giảm bytes-per-pixel khi không cần full color

```swift
// Ảnh grayscale hoặc ảnh không cần alpha
func downsampleOptimized(data: Data, to size: CGSize) -> UIImage? {
    let options: [CFString: Any] = [
        kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true
    ]
    
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { return nil }
    
    // Dùng UIGraphicsImageRenderer với preferred format
    // .range giảm từ 4 bytes/pixel → 2 bytes (16-bit color)
    // Phù hợp cho thumbnail nhỏ, mắt không phân biệt được
    let renderer = UIGraphicsImageRenderer(
        size: size,
        format: {
            let fmt = UIGraphicsImageRendererFormat()
            fmt.preferredRange = .automatic  // System chọn optimal
            return fmt
        }()
    )
    
    return renderer.image { context in
        UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))
    }
}
```

---

## 6. Tổng kết — Checklist cho Senior

```
┌─ BANDWIDTH ─────────────────────────────────────────────┐
│ □ Server-side resize (CDN params: w, h, format=auto)    │
│ □ WebP/AVIF với fallback JPEG                           │
│ □ Quality parameter tùy context (thumbnail 60%, full 80%)│
│ □ Progressive JPEG cho ảnh lớn, hero image              │
└─────────────────────────────────────────────────────────┘

┌─ MEMORY ────────────────────────────────────────────────┐
│ □ ImageIO downsampling (KHÔNG dùng UIImage init rồi     │
│   resize sau)                                           │
│ □ Cache key bao gồm target size                         │
│ □ NSCache auto-evict khi memory warning                 │
│ □ Monitor decoded size, không chỉ file size             │
└─────────────────────────────────────────────────────────┘

┌─ UX ────────────────────────────────────────────────────┐
│ □ Prefetch trước khi cell visible                       │
│ □ Cancel khi scroll direction thay đổi                  │
│ □ Placeholder / blur-up transition                      │
│ □ Request deduplication tránh duplicate download         │
└─────────────────────────────────────────────────────────┘

┌─ PRODUCTION ────────────────────────────────────────────┐
│ □ Disk cache eviction policy (LRU, max size)            │
│ □ Instrument bằng MetricKit / os_signpost               │
│ □ Benchmark decode time trên device thấp nhất           │
│ □ A/B test format + quality để tìm sweet spot           │
└─────────────────────────────────────────────────────────┘
```

Dùng Kingfisher hay SDWebImage đều tốt cho productivity, nhưng Senior cần hiểu pipeline bên trong để: (1) debug khi cache không hoạt động đúng, (2) custom processor cho use case đặc biệt, (3) tối ưu memory cho device cũ, và (4) phối hợp với backend team để đưa ra image serving strategy đúng đắn ngay từ đầu thay vì fix ở client.
