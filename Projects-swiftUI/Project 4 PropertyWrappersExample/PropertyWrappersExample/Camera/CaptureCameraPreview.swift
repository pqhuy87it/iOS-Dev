
import SwiftUI

struct CaptureCameraPreview: UIViewControllerRepresentable {
    var previewLayer:CALayer
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<CaptureCameraPreview>) -> UIViewController {
        let viewController = UIViewController()
        
        viewController.view.layer.addSublayer(previewLayer)
        previewLayer.frame = viewController.view.layer.bounds
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<CaptureCameraPreview>) {
        previewLayer.frame = uiViewController.view.layer.bounds
    }
}
