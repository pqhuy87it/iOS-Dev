import UIKit
import SwiftUI // Giả định bạn dùng LoadableSubject liên quan đến SwiftUI

struct ImagesInteractor: ImagesInteractorProtocol {
    
    let webRepository: ImagesWebRepositoryProtocol
    
    init(webRepository: ImagesWebRepositoryProtocol) {
        self.webRepository = webRepository
    }
    
    func load(image: LoadableSubject<UIImage>, url: URL?) {
        // Business logic: Nếu URL nil, set state về notRequested
        guard let url = url else {
            image.wrappedValue = .notRequested
            return
        }
        
        // Gọi xuống Repository để tải ảnh
        image.load {
            try await webRepository.loadImage(url: url)
        }
    }
}

// Giữ nguyên Stub để dùng cho SwiftUI Previews
struct StubImagesInteractor: ImagesInteractorProtocol {
    func load(image: LoadableSubject<UIImage>, url: URL?) {
        // Do nothing for preview
    }
}
