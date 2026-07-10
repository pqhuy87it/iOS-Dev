import SwiftUI
import ImageIO
import UIKit

// MARK: - Benchmark engine

struct BenchmarkResult: Identifiable {
    let id = UUID()
    let method: String
    let coldMs: Double      // lần chạy đầu tiên
    let warmMs: Double      // trung bình các lần sau
    let thumbnail: UIImage?
}

enum ThumbnailBenchmark {

    // Ba cách tạo thumbnail để so sánh

    static func naive(_ data: Data, target: CGSize) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    static func preparingThumbnail(_ data: Data, target: CGSize) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        return image.preparingThumbnail(of: target)   // iOS 15+
    }

    static func cgImageSource(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// Đo 1 hàm: lần đầu = cold, trung bình `warmRuns` lần tiếp theo = warm.
    static func measure(warmRuns: Int, _ block: () -> UIImage?) -> (cold: Double, warm: Double, image: UIImage?) {
        // cold
        let s0 = CFAbsoluteTimeGetCurrent()
        let img = block()
        let cold = (CFAbsoluteTimeGetCurrent() - s0) * 1000

        // warm
        var total: Double = 0
        for _ in 0..<warmRuns {
            let s = CFAbsoluteTimeGetCurrent()
            _ = block()
            total += (CFAbsoluteTimeGetCurrent() - s) * 1000
        }
        let warm = warmRuns > 0 ? total / Double(warmRuns) : cold
        return (cold, warm, img)
    }

    /// Chạy toàn bộ benchmark trên nền, trả kết quả về main.
    static func run(data: Data, maxSide: CGFloat, warmRuns: Int = 10) async -> [BenchmarkResult] {
        let target = CGSize(width: maxSide, height: maxSide)

        let naiveR = measure(warmRuns: warmRuns) { naive(data, target: target) }
        let prepR  = measure(warmRuns: warmRuns) { preparingThumbnail(data, target: target) }
        let cgR    = measure(warmRuns: warmRuns) { cgImageSource(data, maxPixelSize: maxSide) }

        return [
            BenchmarkResult(method: "UIImage (naive draw)",
                            coldMs: naiveR.cold, warmMs: naiveR.warm, thumbnail: naiveR.image),
            BenchmarkResult(method: "preparingThumbnail",
                            coldMs: prepR.cold, warmMs: prepR.warm, thumbnail: prepR.image),
            BenchmarkResult(method: "CGImageSource",
                            coldMs: cgR.cold, warmMs: cgR.warm, thumbnail: cgR.image),
        ]
    }
}

// MARK: - Benchmark View

struct BenchmarkView: View {
    @State private var imageData: Data?
    @State private var results: [BenchmarkResult] = []
    @State private var isRunning = false
    @State private var maxSide: CGFloat = 200
    @State private var showPicker = false

    // baseline để tính "nhanh hơn bao nhiêu lần"
    private var baselineWarm: Double? {
        results.first { $0.method.hasPrefix("UIImage") }?.warmMs
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Max side: \(Int(maxSide)) px")
                        .font(.subheadline)
                    Slider(value: $maxSide, in: 50...800, step: 10)

                    Button {
                        runBenchmark()
                    } label: {
                        Label(isRunning ? "Đang chạy..." : "Chạy benchmark",
                              systemImage: "gauge.high")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(imageData == nil || isRunning)

                    if !results.isEmpty {
                        resultsTable
                        thumbnailStrip
                    }
                }
                .padding()
            }
            .navigationTitle("Thumbnail Benchmark")
            .toolbar {
                Button("Chọn ảnh") { showPicker = true }
            }
            .sheet(isPresented: $showPicker) {
                ImagePicker { data in
                    self.imageData = data
                    self.results = []
                }
            }
        }
    }

    @ViewBuilder
    private var resultsTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Method").frame(maxWidth: .infinity, alignment: .leading)
                Text("Cold").frame(width: 70, alignment: .trailing)
                Text("Warm").frame(width: 70, alignment: .trailing)
                Text("Speedup").frame(width: 70, alignment: .trailing)
            }
            .font(.caption.bold())
            .padding(.vertical, 6)

            Divider()

            ForEach(results) { r in
                HStack {
                    Text(r.method)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.0f", r.coldMs))
                        .frame(width: 70, alignment: .trailing)
                    Text(String(format: "%.1f", r.warmMs))
                        .frame(width: 70, alignment: .trailing)
                        .foregroundStyle(colorFor(r.warmMs))
                    Text(speedupText(r.warmMs))
                        .frame(width: 70, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }
                .font(.caption.monospaced())
                .padding(.vertical, 6)
                Divider()
            }
        }
        .padding()
        .background(.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var thumbnailStrip: some View {
        VStack(alignment: .leading) {
            Text("Kết quả ảnh (kiểm tra chất lượng ngang nhau):")
                .font(.caption)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(results) { r in
                        VStack {
                            if let t = r.thumbnail {
                                Image(uiImage: t)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            Text(r.method)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(width: 110)
                    }
                }
            }
        }
    }

    private func runBenchmark() {
        guard let data = imageData else { return }
        isRunning = true
        Task.detached(priority: .userInitiated) {
            let res = await ThumbnailBenchmark.run(data: data, maxSide: maxSide)
            await MainActor.run {
                self.results = res
                self.isRunning = false
            }
        }
    }

    private func speedupText(_ warm: Double) -> String {
        guard let base = baselineWarm, warm > 0 else { return "—" }
        let ratio = base / warm
        return ratio >= 1.05 ? String(format: "%.1fx", ratio) : "1x"
    }

    private func colorFor(_ warm: Double) -> Color {
        guard let base = baselineWarm else { return .primary }
        if warm <= base * 0.3 { return .green }
        if warm <= base * 0.7 { return .orange }
        return .primary
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
