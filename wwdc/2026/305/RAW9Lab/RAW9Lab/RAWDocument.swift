import SwiftUI
import CoreImage
import CoreImage.CIRAWFilter

/// Editable RAW adjustments, mirroring the four key CIRAWFilter properties the
/// session highlights: exposure, luminance noise reduction, sharpness, contrast.
struct RAWEdits: Equatable {
    var exposure: Float = 0.0                    // stops, typically -2...2
    var luminanceNoiseReductionAmount: Float = 0.5 // 0...1
    var sharpnessAmount: Float = 0.5             // 0...1
    var contrastAmount: Float = 0.5              // 0...1
}

/// Wraps a CIRAWFilter for one RAW file, opts in to RAW 9 when available, and
/// applies edits. This is the piece that maps 1-to-1 onto the session content.
@Observable
final class RAWDocument {
    let url: URL
    private(set) var usingRAW9 = false
    private(set) var cameraModel: String?
    private(set) var loadError: String?

    // Recreated when the source changes; edits are applied on demand.
    private var filter: CIRAWFilter?

    var edits = RAWEdits()

    init(url: URL) {
        self.url = url
        configure()
    }

    private func configure() {
        guard let filter = CIRAWFilter(imageURL: url) else {
            loadError = "Could not create CIRAWFilter for \(url.lastPathComponent)"
            return
        }

        // --- RAW 9 opt-in (NOT enabled by default) -----------------------
        // CIRAWDecoderVersion is a typed string enum (NS_TYPED_ENUM), so we
        // compare against the `.version9` constant directly.
        let supported = filter.supportedDecoderVersions
        if supported.contains(.version9) {
            filter.decoderVersion = .version9
            usingRAW9 = true
        } else if let newest = supported.last {
            // supportedDecoderVersions is ordered oldest→newest, so `.last`
            // is the newest available for this file.
            filter.decoderVersion = newest
            usingRAW9 = false
        }

        self.filter = filter
    }

    /// Which camera models support a given decoder version (WWDC26 class method).
    static func supportedCameraModels(for version: CIRAWDecoderVersion) -> [String] {
        CIRAWFilter.supportedCameraModels(for: version)
    }

    /// Produce a CIImage for display, applying the current edits.
    /// - Parameter scaleFactor: use < 1.0 when showing below full resolution to
    ///   cut work on images with more megapixels than the display (session tip).
    func makeImage(scaleFactor: Float = 1.0) -> CIImage? {
        guard let filter else { return nil }

        // scaleFactor must be set before reading outputImage.
        filter.scaleFactor = scaleFactor

        // Apply the four key adjustments, but only if this instance supports
        // them — RAW 9 drops colorNoiseReduction / detail / moire, so we check.
        filter.exposure = edits.exposure
        if filter.isLuminanceNoiseReductionSupported {
            filter.luminanceNoiseReductionAmount = edits.luminanceNoiseReductionAmount
        }
        if filter.isSharpnessSupported {
            filter.sharpnessAmount = edits.sharpnessAmount
        }
        if filter.isContrastSupported {
            filter.contrastAmount = edits.contrastAmount
        }

        return filter.outputImage
    }

    /// Full-resolution image for export (scaleFactor 1.0).
    func makeFullResolutionImage() -> CIImage? {
        makeImage(scaleFactor: 1.0)
    }
}
