import Foundation

protocol PhotosRepositoryProtocol {
    func fetchPhotos(page: Int, perPage: Int) async throws -> [PhotoDTO]
}
