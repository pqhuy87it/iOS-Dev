import UIKit

protocol ImagesInteractorProtocol {
    func loadImage(url: URL) async throws -> UIImage
}
