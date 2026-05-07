import UIKit

protocol ImagesWebRepositoryProtocol: WebRepositoryProtocol {
    func loadImage(url: URL) async throws -> UIImage
}
