import UIKit
import SwiftUI

struct ImagesInteractor: ImagesInteractorProtocol {
    let webRepository: ImagesWebRepositoryProtocol
    
    func loadImage(url: URL) async throws -> UIImage {
        return try await webRepository.loadImage(url: url) //
    }
}
