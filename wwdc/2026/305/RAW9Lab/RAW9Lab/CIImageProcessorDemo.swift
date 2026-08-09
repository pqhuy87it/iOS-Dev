import CoreImage

// MARK: - CIImageProcessor: explicit output tile sizes + temporary buffers
//
// This standalone file reproduces the two new CIImageProcessor features from
// the session. It's not wired into the editor UI — it's here so you can study
// and experiment with the exact APIs discussed.

/// A trivial processor that copies input → output. In a real processor you'd
/// run a CIKernel or a Core ML model between the buffers.
final class TileCopyProcessor: CIImageProcessorKernel {

    // Region of interest: for a pure copy, output rect == input rect.
    override class func roi(
        forInput input: Int32,
        arguments: [String: Any]?,
        outputRect: CGRect
    ) -> CGRect {
        outputRect
    }

    override class func process(
        with inputs: [CIImageProcessorInput]?,
        arguments: [String: Any]?,
        output: CIImageProcessorOutput
    ) throws {
        guard let input = inputs?.first,
              let srcPixelBuffer = input.pixelBuffer,
              let dstPixelBuffer = output.pixelBuffer else { return }

        _ = input.region      // the input area available this call
        _ = output.region     // the output tile Core Image asked us to fill

        // --- Temporary buffer feature -----------------------------------
        // Core ML wants planar data, but Core Image gives interleaved buffers,
        // so processors often need scratch space. Asking Core Image for a
        // temporary buffer lets it recycle the allocation across tiles instead
        // of us creating/destroying one every call.
        guard let scratch = output.temporaryPixelBuffer(
            identifier: "myScratch",   // required; unique per buffer you request
            format: kCVPixelFormatType_64RGBAHalf,
            width: Int(output.region.width),
            height: Int(output.region.height),
            pixelBufferAttributes: nil
        ) else { return }

        // Step 1: copy input  → scratch
        // Step 2: process pixels in scratch (e.g. run a Core ML model in-place)
        // Step 3: copy scratch → output
        copy(srcPixelBuffer, to: scratch)
        // (transform scratch here)
        copy(scratch, to: dstPixelBuffer)
    }

    // Placeholder byte copy; replace with a real blit/kernel in practice.
    private static func copy(_ src: CVPixelBuffer, to dst: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(src, .readOnly)
        CVPixelBufferLockBaseAddress(dst, [])
        defer {
            CVPixelBufferUnlockBaseAddress(src, .readOnly)
            CVPixelBufferUnlockBaseAddress(dst, [])
        }
        guard let s = CVPixelBufferGetBaseAddress(src),
              let d = CVPixelBufferGetBaseAddress(dst) else { return }
        let bytes = min(CVPixelBufferGetDataSize(src), CVPixelBufferGetDataSize(dst))
        memcpy(d, s, bytes)
    }
}

enum TilingDemo {
    /// Break an image into explicit 512×512 output tiles and run the processor.
    static func run(on inImg: CIImage, tileSize: CGFloat = 512) throws -> CIImage {
        let extent = inImg.extent
        var tiles: [CIVector] = []
        for y in stride(from: extent.minY, to: extent.maxY, by: tileSize) {
            for x in stride(from: extent.minX, to: extent.maxX, by: tileSize) {
                let tile = CGRect(
                    x: x, y: y,
                    width: min(tileSize, extent.maxX - x),
                    height: min(tileSize, extent.maxY - y)
                )
                tiles.append(CIVector(cgRect: tile))
            }
        }
        // The WWDC26 apply(withTiledExtent:) entry point lets you dictate the
        // output regions rather than letting Core Image pick tile sizes.
        return try TileCopyProcessor.apply(
            withTiledExtent: tiles,
            inputs: [inImg],
            arguments: [:]
        )
    }
}
