import Foundation
import CoreImage

/// Exports RAW files at full resolution, following the session's exporting
/// best practices:
///  - a CIContext with cacheIntermediates = false (each file rendered once)
///  - a raised memoryLimit (iOS default 256 MB is conservative; 512/1024 helps)
///  - Core Image's own heifRepresentation / jpegRepresentation to save memory
enum RAWExporter {

    enum Format { case heif, jpeg }

    /// A context tuned for one-shot, full-resolution exports. Reuse it across
    /// many files in a batch, but keep it separate from the editing context.
    static func makeExportContext(memoryLimitMB: Int = 512) -> CIContext {
        CIContext(options: [
            .cacheIntermediates: false,
            .memoryLimit: memoryLimitMB * 1024 * 1024,
            .name: "ExportContext"
        ])
    }

    static func export(
        image: CIImage,
        to url: URL,
        format: Format,
        quality: Double = 0.9,
        context: CIContext
    ) throws {
        // Wide-gamut working/output space; adjust to your pipeline as needed.
        let colorSpace = CGColorSpace(name: CGColorSpace.displayP3)
            ?? CGColorSpaceCreateDeviceRGB()

        let data: Data?
        switch format {
        case .heif:
            data = context.heifRepresentation(
                of: image,
                format: .RGBA8,
                colorSpace: colorSpace,
                options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality]
            )
        case .jpeg:
            data = context.jpegRepresentation(
                of: image,
                colorSpace: colorSpace,
                options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality]
            )
        }

        guard let data else {
            throw NSError(domain: "RAWExporter", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
        }
        try data.write(to: url)
    }

    /// Batch export: one context reused, each image rendered once.
    static func exportBatch(
        documents: [RAWDocument],
        toDirectory dir: URL,
        format: Format
    ) throws -> [URL] {
        let context = makeExportContext(memoryLimitMB: 1024)
        var written: [URL] = []
        for doc in documents {
            guard let image = doc.makeFullResolutionImage() else { continue }
            let ext = format == .heif ? "heic" : "jpg"
            let out = dir.appendingPathComponent(
                doc.url.deletingPathExtension().lastPathComponent + "." + ext)
            try export(image: image, to: out, format: format, context: context)
            written.append(out)
        }
        return written
    }
}
