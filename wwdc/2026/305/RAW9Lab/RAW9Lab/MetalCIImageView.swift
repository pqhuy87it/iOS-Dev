import SwiftUI
import MetalKit
import CoreImage

#if canImport(UIKit)
import UIKit
typealias PlatformViewRepresentable = UIViewRepresentable
#else
import AppKit
typealias PlatformViewRepresentable = NSViewRepresentable
#endif

/// A SwiftUI wrapper around an MTKView that renders a CIImage.
///
/// Session best practices for interactive editing baked in here:
///  - render directly to a Metal-backed view (Metal can start the next frame
///    before the previous one finishes)
///  - one CIContext per view, with cacheIntermediates = true, so the heavy
///    Core ML work is skipped while sliders move.
struct MetalCIImageView: PlatformViewRepresentable {
    var image: CIImage?

    // One CIContext per view, caching intermediates between renders.
    final class Coordinator {
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        let ciContext: CIContext
        var image: CIImage?
        // Retained strongly here because MTKView.delegate is weak.
        var delegate: MTKViewDelegate?

        init() {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let queue = device.makeCommandQueue() else {
                fatalError("Metal is not available on this device/simulator.")
            }
            self.device = device
            self.commandQueue = queue
            self.ciContext = CIContext(mtlDevice: device, options: [
                .cacheIntermediates: true,     // <-- key for responsive editing
                .name: "InteractiveEditingContext"
            ])
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    #if canImport(UIKit)
    func makeUIView(context: Context) -> MTKView { makeMTKView(context) }
    func updateUIView(_ view: MTKView, context: Context) { update(view, context) }
    #else
    func makeNSView(context: Context) -> MTKView { makeMTKView(context) }
    func updateNSView(_ view: MTKView, context: Context) { update(view, context) }
    #endif

    private func makeMTKView(_ context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        let delegate = context.coordinator.makeDelegate()
        context.coordinator.delegate = delegate   // retain it
        view.delegate = delegate
        view.framebufferOnly = false          // CIContext needs to write to it
        view.enableSetNeedsDisplay = true      // redraw on demand, not 60fps loop
        view.isPaused = true
        view.colorPixelFormat = .rgba16Float   // wide-gamut / EDR friendly
        return view
    }

    private func update(_ view: MTKView, context: Context) {
        context.coordinator.image = image
        view.setNeedsDisplay(view.bounds)
    }
}

// The MTKViewDelegate lives on the Coordinator so it can reach the CIContext.
extension MetalCIImageView.Coordinator {
    func makeDelegate() -> MTKViewDelegate { Delegate(owner: self) }

    final class Delegate: NSObject, MTKViewDelegate {
        unowned let owner: MetalCIImageView.Coordinator
        init(owner: MetalCIImageView.Coordinator) { self.owner = owner }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let image = owner.image,
                  let drawable = view.currentDrawable,
                  let commandBuffer = owner.commandQueue.makeCommandBuffer()
            else { return }

            let dstSize = view.drawableSize

            // Aspect-fit the CIImage into the drawable.
            let scale = min(dstSize.width / image.extent.width,
                            dstSize.height / image.extent.height)
            let scaled = image.transformed(by: .init(scaleX: scale, y: scale))
            let tx = (dstSize.width - scaled.extent.width) / 2 - scaled.extent.origin.x
            let ty = (dstSize.height - scaled.extent.height) / 2 - scaled.extent.origin.y
            let centered = scaled.transformed(by: .init(translationX: tx, y: ty))

            let destination = CIRenderDestination(
                width: Int(dstSize.width),
                height: Int(dstSize.height),
                pixelFormat: view.colorPixelFormat,
                commandBuffer: commandBuffer,
                mtlTextureProvider: { drawable.texture }
            )

            _ = try? owner.ciContext.startTask(toRender: centered, to: destination)
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
