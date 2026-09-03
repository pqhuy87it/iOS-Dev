import Foundation

protocol PhotosInteractorProtocol {
    func fetchPhotos(page: Int, perPage: Int) async throws -> [Photo]
}
