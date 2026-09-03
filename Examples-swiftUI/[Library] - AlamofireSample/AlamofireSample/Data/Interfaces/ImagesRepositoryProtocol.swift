import UIKit

protocol ImagesRepositoryProtocol {
    func loadImage(url: URL) async throws -> UIImage
}
