import UIKit
import SwiftUI

struct ImagesInteractor: ImagesInteractorProtocol {
    
    let webRepository: ImagesWebRepositoryProtocol
    
    init(webRepository: ImagesWebRepositoryProtocol) {
        self.webRepository = webRepository
    }
    
    func load(image: LoadableSubject<UIImage>, url: URL?) {
        guard let url else {
            image.wrappedValue = .notRequested;
            return
        }
        
        image.load {
            try await webRepository.loadImage(url: url)
        }
    }
}

struct StubImagesInteractor: ImagesInteractorProtocol {
    func load(image: LoadableSubject<UIImage>, url: URL?) {
    }
}
