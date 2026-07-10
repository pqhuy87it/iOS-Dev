import UIKit
import SwiftUI

struct ImagesInteractor: ImagesInteractorProtocol {
    let repository: ImagesRepositoryProtocol

    func loadImage(url: URL) async throws -> UIImage {
        return try await repository.loadImage(url: url)
    }
}
