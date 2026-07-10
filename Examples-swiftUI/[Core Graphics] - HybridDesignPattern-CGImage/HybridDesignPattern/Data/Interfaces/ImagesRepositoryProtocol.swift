import UIKit

// Domain abstraction
protocol ImagesRepositoryProtocol {
    func loadImage(url: URL) async throws -> UIImage
}
