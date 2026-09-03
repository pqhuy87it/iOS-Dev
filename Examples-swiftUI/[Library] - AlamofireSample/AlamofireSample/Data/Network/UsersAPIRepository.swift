import Foundation
import Alamofire

// MARK: - Data implementation

struct UsersAPIRepository: UsersRepositoryProtocol {
    let apiClient: ApiClient
    let baseURL: String

    init(apiClient: ApiClient = .shared, baseURL: String = "https://api.example.com/v1") {
        self.apiClient = apiClient
        self.baseURL = baseURL
    }

    func fetchUsers() async throws -> [UserDTO] {
        try await apiClient.request(API.getUsers(baseURL: baseURL))
    }
}

// Define specific endpoints for User
extension UsersAPIRepository {
    enum API {
        case getUsers(baseURL: String)
        case createUser(baseURL: String, payload: Data)
    }
}

extension UsersAPIRepository.API: URLRequestConvertible {
    private var baseURL: String {
        switch self {
        case let .getUsers(baseURL), let .createUser(baseURL, _): baseURL
        }
    }

    private var path: String { "/users" }

    private var method: HTTPMethod {
        switch self {
        case .getUsers: .get
        case .createUser: .post
        }
    }

    private func body() -> Data? {
        switch self {
        case .getUsers: nil
        case let .createUser(_, payload): payload
        }
    }

    func asURLRequest() throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.method = method
        request.headers = HTTPHeaders([
            "Accept": "application/json",
            "Content-Type": "application/json",
        ])
        request.httpBody = body()
        return request
    }
}
