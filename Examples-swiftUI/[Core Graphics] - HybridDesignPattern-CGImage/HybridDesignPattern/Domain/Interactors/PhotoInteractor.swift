import Foundation

struct PhotosInteractor: PhotosInteractorProtocol {
    let photosRepository: PhotosRepositoryProtocol

    func fetchPhotos(page: Int = 1, perPage: Int = 10) async throws -> [Photo] {
        let dtos = try await photosRepository.fetchPhotos(page: page, perPage: perPage)
        return dtos.map { $0.toDomain() }
    }
}
