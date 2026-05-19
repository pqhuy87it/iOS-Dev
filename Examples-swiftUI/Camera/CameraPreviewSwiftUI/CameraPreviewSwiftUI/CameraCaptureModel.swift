
import UIKit
import Combine
import AVFoundation

class CameraCaptureModel: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, ObservableObject {
	///撮影した画像
	@Published var image: UIImage?
    var cameraPreviewRect: CGRect = CGRect.zero
    var photoGuideViewRect: CGRect = CGRect.zero
	var imageSize: CGSize = CGSize.zero
	var boundSize: CGSize = CGSize.zero
	var cropSize: CGSize = CGSize.zero
	///プレビュー用レイヤー
	var previewLayer:CALayer!

	///撮影開始フラグ
	private var _takePhoto:Bool = false
	///セッション
	private let captureSession = AVCaptureSession()
	///撮影デバイス
	private var capturepDevice:AVCaptureDevice!

	override init() {
		super.init()

		prepareCamera()
		beginSession()
	}

	func takePhoto() {
		_takePhoto = true
	}

	func takePhoto(_ boundSize: CGSize, cropSize: CGSize) {
		self.boundSize = boundSize
		self.cropSize = cropSize
		_takePhoto = true
	}

	private func prepareCamera() {
		captureSession.sessionPreset = .high

		if let availableDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
																  mediaType: AVMediaType.video,
																  position: .back).devices.first {
			capturepDevice = availableDevice
		}
	}

	private func beginSession() {
		do {
			let captureDeviceInput = try AVCaptureDeviceInput(device: capturepDevice)

			captureSession.addInput(captureDeviceInput)
		} catch {
			print(error.localizedDescription)
		}

		let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        if ((previewLayer.connection?.isVideoOrientationSupported) != nil) {
            let orientation: AVCaptureVideoOrientation?
            
            switch UIApplication.shared.statusBarOrientation{
                case .landscapeLeft:
                    orientation = .landscapeLeft
                case .landscapeRight:
                    orientation = .landscapeRight
                case .portrait:
                    orientation = .portrait
                case .portraitUpsideDown:
                    orientation = .portraitUpsideDown
                @unknown default:
                    orientation = nil
            }
            
            if let orientation = orientation {
                previewLayer.connection?.videoOrientation = orientation
            }
        }

		previewLayer.videoGravity = .resizeAspect
		self.previewLayer = previewLayer

		let dataOutput = AVCaptureVideoDataOutput()
		dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]

		if captureSession.canAddOutput(dataOutput) {
			captureSession.addOutput(dataOutput)
		}

		captureSession.commitConfiguration()

		let queue = DispatchQueue(label: "github.com.AVFoundationSwiftUI")
		dataOutput.setSampleBufferDelegate(self, queue: queue)
	}

	func startSession() {
		if captureSession.isRunning { return }
		captureSession.startRunning()
	}

	func endSession() {
		if !captureSession.isRunning { return }
		captureSession.stopRunning()
	}
    
    //MARK: - cropping done here
    private func crop(_ image: UIImage) -> UIImage? {
        let imageSize = image.size
        let width = photoGuideViewRect.size.width / cameraPreviewRect.size.height
        let height = photoGuideViewRect.size.height / cameraPreviewRect.size.height
        let x = (photoGuideViewRect.origin.x - cameraPreviewRect.origin.x) / cameraPreviewRect.size.width
        let y = (photoGuideViewRect.origin.y - cameraPreviewRect.origin.y) / cameraPreviewRect.size.height
        
        let cropFrame = CGRect(x: x * imageSize.height,
                               y: y * imageSize.height,
                               width: imageSize.height * width,
                               height: imageSize.height * height)
        if let cropCGImage = image.cgImage?.cropping(to: cropFrame) {
            let cropImage = UIImage(cgImage: cropCGImage, scale: 1, orientation: .up)
            return cropImage
        }
        return nil
    }

	func cropImage(image: UIImage) -> UIImage? {

		let imsize = imageSize
		let scale = max(imageSize.width / boundSize.width, imageSize.height / boundSize.height)

		let currentPositionWidth:CGFloat = 0.0
		let currentPositionHeight:CGFloat = 0.0

		let croppedImsize = CGSize(width: (self.cropSize.width * scale), height: (self.cropSize.height * scale))

		let xOffset = (( imsize.width - croppedImsize.width) / 2.0) - (currentPositionWidth)
		let yOffset = (( imsize.height - croppedImsize.height) / 2.0) - (currentPositionHeight)
		let croppedImrect: CGRect = CGRect(x: xOffset, y: yOffset - 20, width: croppedImsize.width, height: croppedImsize.height)

		//        print("croppedImsize:\(croppedImsize),croppedImrect:\(croppedImrect)")
		if let croppedImage = image.cgImage?.cropping(to: croppedImrect) {
			return UIImage(cgImage: croppedImage)
		}

		return nil
	}

	// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
	func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		var videoOrientation: AVCaptureVideoOrientation = .portrait

        // Rotation should be unlocked to work.
        var orientation = UIImage.Orientation.up
        switch UIDevice.current.orientation {
            case .landscapeLeft:
                orientation = .left
            case .landscapeRight:
                orientation = .right
            case .portraitUpsideDown:
                orientation = .down
            default:
                orientation = .up
        }

		DispatchQueue.main.async(execute: { () -> Void in
			switch UIApplication.shared.statusBarOrientation{
			case .landscapeLeft:
				orientation = .left
				videoOrientation = .landscapeLeft
			case .landscapeRight:
				orientation = .right
				videoOrientation = .landscapeRight
			case .portrait:
				orientation = .up
				videoOrientation = .portrait
			case .portraitUpsideDown:
				orientation = .down
				videoOrientation = .portraitUpsideDown
			@unknown default:
				break
			}

			connection.videoOrientation = videoOrientation
		})
        
		if _takePhoto {
			_takePhoto = false
//			if let image = getImageFromSampleBuffer(buffer: sampleBuffer, orientation: orientation) {
			if let image = imageFromSampleBuffer(sampleBuffer) {
				DispatchQueue.main.async {
					self.imageSize = image.size

					if let croppedImage = self.cropImage(image: image) {
						self.image = croppedImage
					}
				}
			}
		}
	}
    
    // Function to process the buffer and return UIImage to be used
    func imageFromSampleBuffer(_ sampleBuffer : CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }

    /// Get the UIImage from the given CMSampleBuffer.
    ///
    /// - Parameter buffer: CMSampleBuffer
    /// - Returns: UIImage?
    func getImageFromSampleBuffer(buffer:CMSampleBuffer, orientation: UIImage.Orientation = .up) -> UIImage? {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            let imageRect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            
            if let image = context.createCGImage(ciImage, from: imageRect) {
                return UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: orientation)
                
            }
            
        }
        
        return nil
    }
}
