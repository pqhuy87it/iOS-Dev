import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// MARK: - Core: Thumbnail generator dùng CGImageSource

enum ThumbnailGenerator {

    /// Tạo thumbnail nhanh trực tiếp từ dữ liệu ảnh, KHÔNG decode ảnh full-size.
    /// Đây là điểm mấu chốt của bài viết: nhanh hơn ~30-40x so với UIImage(data:).
    static func thumbnail(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            // Luôn tạo thumbnail từ ảnh gốc, tránh log lỗi khi ảnh không có
            // embedded thumbnail (JPEG/HEIC đôi khi không có).
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Tôn trọng EXIF orientation (rất quan trọng với JPEG chụp từ iPhone).
            kCGImageSourceCreateThumbnailWithTransform: true,
            // Cạnh LỚN nhất của thumbnail; ảnh trả về sẽ <= giá trị này.
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgThumb)
    }

    /// Lấy kích thước ảnh gần như tức thì (2-4ms) mà không load ảnh full.
    /// Chỉ đọc phần metadata header. Dùng để set aspect ratio cho placeholder.
    static func pixelSize(from data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int
        else {
            return nil
        }
        return CGSize(width: width, height: height)
    }

    /// Cách "naive" để so sánh — chậm vì decode toàn bộ ảnh rồi mới vẽ lại.
    static func naiveThumbnail(from data: Data, targetSize: CGSize) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

// MARK: - Async loader để dùng trong SwiftUI View

@Observable
final class ThumbnailLoader {
    var thumbnail: UIImage?
    var originalSize: CGSize?
    var elapsedMs: Double?

    /// Bài viết khuyên: lấy size SYNC (rẻ, 2-4ms) để layout, tạo thumbnail ASYNC.
    func load(data: Data, maxPixelSize: CGFloat) {
        // 1. Size lấy đồng bộ, gần như tức thì
        originalSize = ThumbnailGenerator.pixelSize(from: data)

        // 2. Thumbnail chạy nền để không block UI
        Task.detached(priority: .userInitiated) {
            let start = CFAbsoluteTimeGetCurrent()
            let thumb = ThumbnailGenerator.thumbnail(from: data, maxPixelSize: maxPixelSize)
            let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000

            await MainActor.run {
                self.thumbnail = thumb
                self.elapsedMs = ms
            }
        }
    }
}

// MARK: - Demo View

struct ContentView: View {
    @State private var loader = ThumbnailLoader()
    @State private var imageData: Data?
    @State private var thumbMaxSize: CGFloat = 200
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    thumbnailSection
                    infoSection
                    controlSection
                }
                .padding()
            }
            .navigationTitle("CGImageSource Demo")
            .toolbar {
                Button("Chọn ảnh") { showPicker = true }
            }
            // iOS 16+ PhotosPicker; nếu chưa cần thì thay bằng ảnh test trong bundle.
            .sheet(isPresented: $showPicker) {
                ImagePicker { data in
                    self.imageData = data
                    self.loader.load(data: data, maxPixelSize: thumbMaxSize)
                }
            }
        }
    }

    @ViewBuilder
    private var thumbnailSection: some View {
        // Dùng aspect ratio từ originalSize để placeholder không "nhảy" layout
        let aspect = loader.originalSize.map { $0.width / $0.height } ?? 1

        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.gray.opacity(0.15))

            if let thumb = loader.thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if imageData != nil {
                ProgressView()
            } else {
                Text("Chưa có ảnh")
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .frame(maxHeight: 300)
    }

    @ViewBuilder
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let size = loader.originalSize {
                Text("Kích thước gốc: \(Int(size.width)) × \(Int(size.height))")
            }
            if let ms = loader.elapsedMs {
                Text(String(format: "Thời gian tạo thumbnail: %.1f ms", ms))
                    .foregroundStyle(.green)
            }
        }
        .font(.footnote.monospaced())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var controlSection: some View {
        VStack(alignment: .leading) {
            Text("Max pixel size: \(Int(thumbMaxSize))")
            Slider(value: $thumbMaxSize, in: 50...800, step: 10) {
                Text("Size")
            } onEditingChanged: { editing in
                if !editing, let data = imageData {
                    loader.load(data: data, maxPixelSize: thumbMaxSize)
                }
            }
        }
    }
}

// MARK: - PhotosPicker wrapper đơn giản

import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    let onPick: (Data) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (Data) -> Void
        init(onPick: @escaping (Data) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                guard let data else { return }
                DispatchQueue.main.async { self.onPick(data) }
            }
        }
    }
}
