import Foundation

// MARK: - Data implementation

struct PhotosRepository: PhotosRepositoryProtocol, APIRepositoryProtocol {
    let session: URLSession
    let baseURL: String = "https://api.unsplash.com"

    // API key from Secrets.plist
    let clientId: String = AppConfig.unsplashClientID

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchPhotos(page: Int, perPage: Int) async throws -> [PhotoDTO] {
        try await call(
            endpoint: API.latestPhotos(page: page, perPage: perPage, clientId: clientId)
        )
    }
}

// MARK: - Configure Endpoints for Unsplash

extension PhotosRepository {
    enum API {
        case latestPhotos(page: Int, perPage: Int, clientId: String)
    }
}

extension PhotosRepository.API: APICall {
    var path: String {
        switch self {
        case let .latestPhotos(page, perPage, _):
            // Attach query parameters directly to the path
            return "/photos?page=\(page)&per_page=\(perPage)"
        }
    }

    var method: String {
        return "GET"
    }

    var headers: [String: String]? {
        // Extract API key to inject into header
        let clientId: String
        switch self {
        case let .latestPhotos(_, _, key):
            clientId = key
        }

        // Unsplash requires Accept-Version and Authorization headers
        return [
            "Accept-Version": "v1",
            "Authorization": "Client-ID \(clientId)",
            "Accept": "application/json"
        ]
    }

    func body() throws -> Data? {
        return nil // GET method does not have a body
    }
}

// MARK: - Stub (For Xcode Previews & Unit Tests)
struct StubPhotosInteractor: PhotosInteractorProtocol {
    func fetchPhotos(page: Int, perPage: Int) async throws -> [Photo] {
        // Return an empty array or Mock data for Preview to display immediately
        return []
    }
}
