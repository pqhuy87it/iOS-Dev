import Foundation
import Alamofire

// MARK: - Data implementation

struct PhotosRepository: PhotosRepositoryProtocol {
    let apiClient: ApiClient

    // API key from Secrets.plist
    let clientId: String = AppConfig.unsplashClientID

    init(apiClient: ApiClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchPhotos(page: Int, perPage: Int) async throws -> [PhotoDTO] {
        try await apiClient.request(
            API.latestPhotos(page: page, perPage: perPage, clientId: clientId)
        )
    }
}

// MARK: - Configure Endpoints for Unsplash

extension PhotosRepository {
    enum API {
        case latestPhotos(page: Int, perPage: Int, clientId: String)
    }
}

extension PhotosRepository.API: URLRequestConvertible {
    func asURLRequest() throws -> URLRequest {
        switch self {
        case let .latestPhotos(page, perPage, clientId):
            return try Unsplash.makeRequest(
                path: "/photos?page=\(page)&per_page=\(perPage)",
                clientId: clientId
            )
        }
    }
}

// MARK: - Stub (For Xcode Previews & Unit Tests)
struct StubPhotosInteractor: PhotosInteractorProtocol {
    func fetchPhotos(page: Int, perPage: Int) async throws -> [Photo] {
        // Return an empty array or Mock data for Preview to display immediately
        return []
    }
}
