# API Layer Abstraction — Giải thích chi tiết cho Senior iOS Developer

## 1. Vấn đề: Không có Abstraction

### Code thông thường — gọi URLSession trực tiếp trong ViewModel:

```swift
// ❌ ViewModel gọi URLSession trực tiếp
class ProductViewModel: ObservableObject {
    @Published var products: [Product] = []
    
    func fetchProducts() async {
        // URLSession nằm ngay trong business logic
        var request = URLRequest(url: URL(string: "https://api.myapp.com/products")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            products = try decoder.decode([Product].self, from: data)
        } catch {
            print(error)
        }
    }
    
    func fetchProductDetail(id: String) async -> Product? {
        // ❌ Lặp lại TOÀN BỘ boilerplate: tạo request, set headers, decode...
        var request = URLRequest(url: URL(string: "https://api.myapp.com/products/\(id)")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // ... lại decode, lại handle error, lại check status code...
    }
}
```

### Vấn đề phát sinh:

**Code lặp lại khắp nơi** — Mỗi API call đều phải tạo `URLRequest`, set headers, check status code, decode JSON... Copy-paste giữa các ViewModel, sửa một chỗ quên chỗ khác.

**Không test được** — `URLSession.shared` là singleton thật, gọi API thật. Unit test phải có mạng, phụ thuộc server, chạy chậm và không đáng tin cậy.

**Thay đổi là ác mộng** — Muốn thêm logging cho tất cả API call? Phải sửa từng ViewModel. Muốn đổi từ URLSession sang Alamofire? Sửa hàng chục file. Muốn thêm retry logic? Lại sửa khắp nơi.

**Vi phạm Single Responsibility** — ViewModel vừa xử lý business logic, vừa lo networking, vừa parse JSON. Quá nhiều trách nhiệm trong một class.

---

## 2. Giải pháp: Layered Abstraction

Chia networking thành **nhiều layer**, mỗi layer có một trách nhiệm duy nhất:

```
┌─────────────────────────────────────────────────────┐
│                    ViewModel                         │
│          (Chỉ biết Repository protocol)             │
│                        │                             │
│                        ▼                             │
│  ┌──────────────────────────────────────┐            │
│  │         Repository Layer             │            │
│  │  (Chuyển đổi DTO ↔ Domain Model)    │            │
│  └──────────────────┬───────────────────┘            │
│                     │                                │
│                     ▼                                │
│  ┌──────────────────────────────────────┐            │
│  │         API Client (Protocol)        │  ← LAYER  │
│  │  (Định nghĩa interface cho network) │    CHÍNH   │
│  └──────────────────┬───────────────────┘            │
│                     │                                │
│                     ▼                                │
│  ┌──────────────────────────────────────┐            │
│  │        Endpoint Definition           │            │
│  │  (URL, method, headers, body)        │            │
│  └──────────────────┬───────────────────┘            │
│                     │                                │
│                     ▼                                │
│  ┌──────────────────────────────────────┐            │
│  │      HTTP Client (URLSession)        │            │
│  │  (Thực hiện network call thật)       │            │
│  └──────────────────────────────────────┘            │
└─────────────────────────────────────────────────────┘
```

---

## 3. Triển khai từng Layer

### Layer 1: Endpoint — Mô tả API request

```swift
// ──────── HTTP Method ────────
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// ──────── Endpoint Protocol ────────
protocol Endpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Encodable? { get }
    var timeoutInterval: TimeInterval { get }
}

// Default values
extension Endpoint {
    var headers: [String: String]? { nil }
    var queryItems: [URLQueryItem]? { nil }
    var body: Encodable? { nil }
    var timeoutInterval: TimeInterval { 30 }
}
```

```swift
// ──────── Gom tất cả endpoint của Product vào 1 enum ────────

enum ProductEndpoint: Endpoint {
    case list(page: Int, limit: Int)
    case detail(id: String)
    case create(CreateProductRequest)
    case update(id: String, UpdateProductRequest)
    case delete(id: String)
    case search(query: String, category: String?)
    case uploadImage(productId: String, imageData: Data)
    
    var path: String {
        switch self {
        case .list:                return "/products"
        case .detail(let id):      return "/products/\(id)"
        case .create:              return "/products"
        case .update(let id, _):   return "/products/\(id)"
        case .delete(let id):      return "/products/\(id)"
        case .search:              return "/products/search"
        case .uploadImage(let id, _): return "/products/\(id)/image"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .list, .detail, .search:  return .get
        case .create, .uploadImage:    return .post
        case .update:                  return .put
        case .delete:                  return .delete
        }
    }
    
    var queryItems: [URLQueryItem]? {
        switch self {
        case .list(let page, let limit):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        case .search(let query, let category):
            var items = [URLQueryItem(name: "q", value: query)]
            if let category {
                items.append(URLQueryItem(name: "category", value: category))
            }
            return items
        default:
            return nil
        }
    }
    
    var body: Encodable? {
        switch self {
        case .create(let request):    return request
        case .update(_, let request): return request
        default:                      return nil
        }
    }
    
    var timeoutInterval: TimeInterval {
        switch self {
        case .uploadImage: return 120  // Upload cần thời gian lâu hơn
        default:           return 30
        }
    }
}
```

**Lợi ích:** Tất cả thông tin về Product API nằm **một chỗ duy nhất**. Muốn biết app gọi những API nào liên quan đến Product? Mở file này ra là thấy hết. Muốn đổi path, thêm query parameter? Sửa một chỗ, ảnh hưởng toàn bộ nơi dùng endpoint đó.

### Layer 2: HTTPClient Protocol — Abstraction cho network call

```swift
// ──────── Response wrapper ────────
struct HTTPResponse {
    let data: Data
    let statusCode: Int
    let headers: [AnyHashable: Any]
}

// ──────── Protocol — ĐÂY LÀ ĐIỂM TRỪU TƯỢNG QUAN TRỌNG NHẤT ────────
protocol HTTPClient {
    func execute(
        baseURL: URL,
        endpoint: Endpoint,
        additionalHeaders: [String: String]
    ) async throws -> HTTPResponse
}
```

Toàn bộ phần còn lại của app **chỉ biết protocol này**. Không biết đằng sau là URLSession, Alamofire, hay bất cứ thứ gì.

### Layer 3: URLSession Implementation

```swift
final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let encoder: JSONEncoder
    
    init(session: URLSession = .shared, encoder: JSONEncoder = .init()) {
        self.session = session
        self.encoder = encoder
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    func execute(
        baseURL: URL,
        endpoint: Endpoint,
        additionalHeaders: [String: String] = [:]
    ) async throws -> HTTPResponse {
        
        let request = try buildRequest(baseURL: baseURL, endpoint: endpoint, additionalHeaders: additionalHeaders)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        return HTTPResponse(
            data: data,
            statusCode: httpResponse.statusCode,
            headers: httpResponse.allHeaderFields
        )
    }
    
    // ──────── Build URLRequest từ Endpoint ────────
    
    private func buildRequest(
        baseURL: URL,
        endpoint: Endpoint,
        additionalHeaders: [String: String]
    ) throws -> URLRequest {
        
        // URL + query items
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)!
        components.queryItems = endpoint.queryItems
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        // Request
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = endpoint.timeoutInterval
        
        // Headers: default + endpoint-specific + additional
        var allHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        endpoint.headers?.forEach { allHeaders[$0.key] = $0.value }
        additionalHeaders.forEach { allHeaders[$0.key] = $0.value }
        allHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        // Body
        if let body = endpoint.body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }
        
        return request
    }
}

// Helper để encode bất kỳ Encodable nào
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    
    init(_ value: Encodable) {
        self._encode = { encoder in
            try value.encode(to: encoder)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
```

---

## 4. API Client — Layer kết hợp Authentication + Decoding + Error Handling

```swift
// ──────── API Error có cấu trúc ────────
enum APIError: Error, Equatable {
    case unauthorized                           // 401
    case forbidden                              // 403
    case notFound                               // 404
    case conflict(serverData: Data?)            // 409
    case validationError(messages: [String])    // 422
    case serverError(statusCode: Int)           // 5xx
    case rateLimited(retryAfter: TimeInterval?) // 429
    case networkError(Error)                    // No connection, timeout...
    case decodingError(Error)                   // JSON parse failed
    
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}

// ──────── API Client Protocol ────────
protocol APIClientProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func request(_ endpoint: Endpoint) async throws  // Cho API không trả data (DELETE...)
}
```

```swift
// ──────── Implementation ────────
final class APIClient: APIClientProtocol {
    private let httpClient: HTTPClient
    private let baseURL: URL
    private let tokenProvider: TokenProvider
    private let decoder: JSONDecoder
    
    init(
        httpClient: HTTPClient,
        baseURL: URL,
        tokenProvider: TokenProvider
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    // ──────── Request có response body ────────
    
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let response = try await executeWithAuth(endpoint)
        let mappedResponse = try mapResponse(response)
        
        do {
            return try decoder.decode(T.self, from: mappedResponse.data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    // ──────── Request không có response body ────────
    
    func request(_ endpoint: Endpoint) async throws {
        let response = try await executeWithAuth(endpoint)
        _ = try mapResponse(response)
    }
    
    // ──────── Tự động gắn Auth header ────────
    
    private func executeWithAuth(_ endpoint: Endpoint) async throws -> HTTPResponse {
        var authHeaders: [String: String] = [:]
        
        if let token = try? await tokenProvider.getValidToken() {
            authHeaders["Authorization"] = "Bearer \(token)"
        }
        
        do {
            return try await httpClient.execute(
                baseURL: baseURL,
                endpoint: endpoint,
                additionalHeaders: authHeaders
            )
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    // ──────── Map HTTP status code → APIError ────────
    
    private func mapResponse(_ response: HTTPResponse) throws -> HTTPResponse {
        switch response.statusCode {
        case 200...299:
            return response
            
        case 401:
            // Token hết hạn → thử refresh
            throw APIError.unauthorized
            
        case 403:
            throw APIError.forbidden
            
        case 404:
            throw APIError.notFound
            
        case 409:
            throw APIError.conflict(serverData: response.data)
            
        case 422:
            let messages = parseValidationErrors(response.data)
            throw APIError.validationError(messages: messages)
            
        case 429:
            let retryAfter = response.headers["Retry-After"] as? String
            throw APIError.rateLimited(
                retryAfter: retryAfter.flatMap(TimeInterval.init)
            )
            
        case 500...599:
            throw APIError.serverError(statusCode: response.statusCode)
            
        default:
            throw APIError.serverError(statusCode: response.statusCode)
        }
    }
    
    private func parseValidationErrors(_ data: Data) -> [String] {
        struct ValidationResponse: Decodable {
            let errors: [String]
        }
        return (try? decoder.decode(ValidationResponse.self, from: data))?.errors ?? []
    }
}
```

---

## 5. Token Management — Tự động Refresh Token

```swift
protocol TokenProvider {
    func getValidToken() async throws -> String
}

actor TokenManager: TokenProvider {
    private let httpClient: HTTPClient
    private let baseURL: URL
    private let tokenStore: TokenStore       // Keychain wrapper
    
    private var refreshTask: Task<String, Error>?
    
    init(httpClient: HTTPClient, baseURL: URL, tokenStore: TokenStore) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.tokenStore = tokenStore
    }
    
    func getValidToken() async throws -> String {
        // Nếu đang có refresh task → chờ kết quả (tránh gọi refresh nhiều lần)
        if let existingTask = refreshTask {
            return try await existingTask.value
        }
        
        guard let accessToken = tokenStore.accessToken else {
            throw APIError.unauthorized
        }
        
        // Token còn hạn → trả về luôn
        if !tokenStore.isAccessTokenExpired {
            return accessToken
        }
        
        // Token hết hạn → refresh
        return try await refreshToken()
    }
    
    private func refreshToken() async throws -> String {
        let task = Task<String, Error> {
            defer { refreshTask = nil }
            
            guard let refreshToken = tokenStore.refreshToken else {
                throw APIError.unauthorized
            }
            
            let endpoint = AuthEndpoint.refreshToken(refreshToken)
            let response = try await httpClient.execute(
                baseURL: baseURL,
                endpoint: endpoint,
                additionalHeaders: [:]
            )
            
            guard (200...299).contains(response.statusCode) else {
                // Refresh token cũng hết hạn → force logout
                tokenStore.clearAll()
                throw APIError.unauthorized
            }
            
            let tokenResponse = try JSONDecoder().decode(
                TokenResponse.self, from: response.data
            )
            
            tokenStore.save(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                expiresIn: tokenResponse.expiresIn
            )
            
            return tokenResponse.accessToken
        }
        
        refreshTask = task
        return try await task.value
    }
}
```

**Điểm quan trọng:** Dùng `actor` để đảm bảo thread-safety. Nếu 5 request cùng phát hiện token hết hạn, chỉ **1 refresh call** được thực hiện, 4 request còn lại chờ kết quả từ task đang chạy.

---

## 6. Interceptor / Middleware Pattern

Khi cần thêm các cross-cutting concerns (logging, retry, caching...) mà **không sửa code hiện tại**:

```swift
// ──────── Interceptor Protocol ────────
protocol HTTPInterceptor {
    func intercept(
        request: URLRequest,
        next: (URLRequest) async throws -> HTTPResponse
    ) async throws -> HTTPResponse
}
```

```swift
// ──────── Logging ────────
struct LoggingInterceptor: HTTPInterceptor {
    private let logger: Logger
    
    func intercept(
        request: URLRequest,
        next: (URLRequest) async throws -> HTTPResponse
    ) async throws -> HTTPResponse {
        let startTime = CFAbsoluteTimeGetCurrent()
        let requestId = UUID().uuidString.prefix(8)
        
        logger.debug("[\(requestId)] → \(request.httpMethod ?? "") \(request.url?.path ?? "")")
        
        do {
            let response = try await next(request)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            logger.debug("[\(requestId)] ← \(response.statusCode) (\(String(format: "%.0f", duration * 1000))ms)")
            return response
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.error("[\(requestId)] ✕ \(error) (\(String(format: "%.0f", duration * 1000))ms)")
            throw error
        }
    }
}

// Output:
// [a1b2c3d4] → GET /products
// [a1b2c3d4] ← 200 (142ms)
// [e5f6g7h8] → POST /orders
// [e5f6g7h8] ✕ networkError(timeout) (30004ms)
```

```swift
// ──────── Retry ────────
struct RetryInterceptor: HTTPInterceptor {
    let maxRetries: Int
    let retryableStatusCodes: Set<Int>
    
    init(maxRetries: Int = 3, retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503]) {
        self.maxRetries = maxRetries
        self.retryableStatusCodes = retryableStatusCodes
    }
    
    func intercept(
        request: URLRequest,
        next: (URLRequest) async throws -> HTTPResponse
    ) async throws -> HTTPResponse {
        
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let response = try await next(request)
                
                if retryableStatusCodes.contains(response.statusCode) && attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt))  // Exponential backoff
                    try await Task.sleep(for: .seconds(delay))
                    continue
                }
                
                return response
            } catch {
                lastError = error
                
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(for: .seconds(delay))
                }
            }
        }
        
        throw lastError ?? NetworkError.unknown
    }
}
```

```swift
// ──────── HTTPClient với Interceptor Chain ────────

final class InterceptableHTTPClient: HTTPClient {
    private let session: URLSession
    private let interceptors: [HTTPInterceptor]
    
    init(session: URLSession = .shared, interceptors: [HTTPInterceptor] = []) {
        self.session = session
        self.interceptors = interceptors
    }
    
    func execute(
        baseURL: URL,
        endpoint: Endpoint,
        additionalHeaders: [String: String]
    ) async throws -> HTTPResponse {
        
        let request = try buildURLRequest(baseURL: baseURL, endpoint: endpoint, additionalHeaders: additionalHeaders)
        
        // Xây dựng chain: Interceptor1 → Interceptor2 → ... → actual network call
        let chain = interceptors.reversed().reduce(
            { (req: URLRequest) async throws -> HTTPResponse in
                // Cuối chain: gọi network thật
                let (data, response) = try await self.session.data(for: req)
                let httpResponse = response as! HTTPURLResponse
                return HTTPResponse(
                    data: data,
                    statusCode: httpResponse.statusCode,
                    headers: httpResponse.allHeaderFields
                )
            }
        ) { next, interceptor in
            { request in
                try await interceptor.intercept(request: request, next: next)
            }
        }
        
        return try await chain(request)
    }
}
```

```swift
// ──────── Setup ────────

let httpClient = InterceptableHTTPClient(
    interceptors: [
        LoggingInterceptor(logger: .network),
        RetryInterceptor(maxRetries: 3),
        // Thêm interceptor mới? Chỉ cần thêm vào đây
        // CacheInterceptor(),
        // MetricsInterceptor(),
        // EncryptionInterceptor(),
    ]
)
```

**Luồng thực thi:**

```
Request đi qua:
  LoggingInterceptor (log request)
    → RetryInterceptor (retry nếu fail)
      → Actual URLSession call
    ← RetryInterceptor
  ← LoggingInterceptor (log response)
```

Muốn thêm tính năng mới (caching, encryption, analytics...)? **Tạo interceptor mới, thêm vào mảng.** Không sửa bất kỳ code hiện có nào. Đây chính là **Open/Closed Principle**.

---

## 7. Repository Layer — Chuyển đổi DTO ↔ Domain Model

```swift
// ──────── DTO: cấu trúc theo server response ────────
struct ProductDTO: Decodable {
    let id: String
    let productName: String
    let priceInCents: Int
    let categoryId: String
    let categoryName: String
    let imageUrls: [String]
    let isAvailable: Bool
    let createdAt: Date
}

// ──────── Domain Model: cấu trúc theo logic app ────────
struct Product: Identifiable, Equatable {
    let id: String
    let name: String
    let price: Decimal              // Đã chuyển từ cents → decimal
    let category: Category
    let images: [URL]               // Đã chuyển từ String → URL
    let isAvailable: Bool
    let createdAt: Date
}

struct Category: Equatable {
    let id: String
    let name: String
}
```

```swift
// ──────── Repository: biên dịch giữa 2 thế giới ────────

protocol ProductRepositoryProtocol {
    func getProducts(page: Int) async throws -> [Product]
    func getProduct(id: String) async throws -> Product
    func createProduct(_ draft: ProductDraft) async throws -> Product
    func deleteProduct(id: String) async throws
}

final class ProductRepository: ProductRepositoryProtocol {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    func getProducts(page: Int) async throws -> [Product] {
        let dtos: [ProductDTO] = try await apiClient.request(
            ProductEndpoint.list(page: page, limit: 20)
        )
        return dtos.map { mapToDomain($0) }  // DTO → Domain
    }
    
    func getProduct(id: String) async throws -> Product {
        let dto: ProductDTO = try await apiClient.request(
            ProductEndpoint.detail(id: id)
        )
        return mapToDomain(dto)
    }
    
    func createProduct(_ draft: ProductDraft) async throws -> Product {
        let request = CreateProductRequest(       // Domain → DTO
            name: draft.name,
            priceInCents: Int(draft.price * 100),
            categoryId: draft.category.id,
            imageUrls: draft.images.map(\.absoluteString)
        )
        
        let dto: ProductDTO = try await apiClient.request(
            ProductEndpoint.create(request)
        )
        return mapToDomain(dto)                   // DTO → Domain
    }
    
    func deleteProduct(id: String) async throws {
        try await apiClient.request(ProductEndpoint.delete(id: id))
    }
    
    // ──────── Mapping ────────
    
    private func mapToDomain(_ dto: ProductDTO) -> Product {
        Product(
            id: dto.id,
            name: dto.productName,
            price: Decimal(dto.priceInCents) / 100,
            category: Category(id: dto.categoryId, name: dto.categoryName),
            images: dto.imageUrls.compactMap(URL.init),
            isAvailable: dto.isAvailable,
            createdAt: dto.createdAt
        )
    }
}
```

**Tại sao tách DTO và Domain Model?**

Server trả `priceInCents: 1999` (integer), nhưng app cần `price: 19.99` (Decimal). Server trả `imageUrls: ["https://..."]` (String), nhưng app cần `images: [URL]`. Server trả flat `categoryId + categoryName`, nhưng app cần nested `Category` object.

Nếu server đổi response format (ví dụ: `product_name` thành `title`), bạn **chỉ sửa DTO và mapping**, không ảnh hưởng ViewModel hay View.

---

## 8. Dễ thay thế thư viện — Sức mạnh của Protocol

Giả sử team quyết định chuyển từ URLSession sang Alamofire:

```swift
// ──────── Chỉ cần viết implementation mới cho HTTPClient protocol ────────

import Alamofire

final class AlamofireHTTPClient: HTTPClient {
    private let session: Session
    
    init(session: Session = .default) {
        self.session = session
    }
    
    func execute(
        baseURL: URL,
        endpoint: Endpoint,
        additionalHeaders: [String: String]
    ) async throws -> HTTPResponse {
        
        let url = baseURL.appendingPathComponent(endpoint.path)
        let method = Alamofire.HTTPMethod(rawValue: endpoint.method.rawValue)
        
        var headers = HTTPHeaders()
        endpoint.headers?.forEach { headers.add(name: $0.key, value: $0.value) }
        additionalHeaders.forEach { headers.add(name: $0.key, value: $0.value) }
        
        let response = await session.request(
            url,
            method: method,
            parameters: endpoint.body.map { AnyEncodable($0) },
            encoder: JSONParameterEncoder.default,
            headers: headers
        )
        .validate()
        .serializingData()
        .response
        
        guard let httpResponse = response.response else {
            throw NetworkError.invalidResponse
        }
        
        return HTTPResponse(
            data: response.data ?? Data(),
            statusCode: httpResponse.statusCode,
            headers: httpResponse.allHeaderFields
        )
    }
}
```

```swift
// ──────── Thay đổi DUY NHẤT ở composition root ────────

// TRƯỚC:
let httpClient: HTTPClient = URLSessionHTTPClient()

// SAU:
let httpClient: HTTPClient = AlamofireHTTPClient()

// Toàn bộ app KHÔNG CẦN SỬA GÌ — vì chỉ biết HTTPClient protocol
```

Tương tự, bạn có thể tạo `GRPCHTTPClient`, `GraphQLHTTPClient`, hay bất cứ thứ gì — miễn conform `HTTPClient` protocol.

---

## 9. Testing — Mock mọi layer

### 9.1. Mock HTTPClient

```swift
final class MockHTTPClient: HTTPClient {
    // Cho phép test quy định response sẽ trả về
    var stubbedResult: Result<HTTPResponse, Error> = .success(
        HTTPResponse(data: Data(), statusCode: 200, headers: [:])
    )
    
    // Capture request để verify
    private(set) var executedEndpoints: [Endpoint] = []
    
    func execute(
        baseURL: URL,
        endpoint: Endpoint,
        additionalHeaders: [String: String]
    ) async throws -> HTTPResponse {
        executedEndpoints.append(endpoint)
        return try stubbedResult.get()
    }
}
```

### 9.2. Mock APIClient

```swift
final class MockAPIClient: APIClientProtocol {
    var stubbedResponses: [String: Any] = [:]   // path → response object
    var requestedEndpoints: [Endpoint] = []
    
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        requestedEndpoints.append(endpoint)
        
        guard let response = stubbedResponses[endpoint.path] as? T else {
            throw APIError.notFound
        }
        return response
    }
    
    func request(_ endpoint: Endpoint) async throws {
        requestedEndpoints.append(endpoint)
    }
}
```

### 9.3. Test ViewModel (không cần mạng, không cần server)

```swift
@Test
func testFetchProducts_success() async {
    // Arrange
    let mockAPI = MockAPIClient()
    mockAPI.stubbedResponses["/products"] = [
        ProductDTO(id: "1", productName: "iPhone", priceInCents: 99900, ...),
        ProductDTO(id: "2", productName: "MacBook", priceInCents: 199900, ...)
    ]
    
    let repository = ProductRepository(apiClient: mockAPI)
    let viewModel = ProductListViewModel(repository: repository)
    
    // Act
    await viewModel.fetchProducts()
    
    // Assert
    #expect(viewModel.products.count == 2)
    #expect(viewModel.products[0].name == "iPhone")
    #expect(viewModel.products[0].price == 999.00)  // cents → decimal
    #expect(viewModel.products[1].name == "MacBook")
    #expect(!viewModel.isLoading)
    #expect(viewModel.error == nil)
}

@Test
func testFetchProducts_networkError_showsErrorMessage() async {
    // Arrange
    let mockAPI = MockAPIClient()
    // Không stub response → sẽ throw notFound
    
    let repository = ProductRepository(apiClient: mockAPI)
    let viewModel = ProductListViewModel(repository: repository)
    
    // Act
    await viewModel.fetchProducts()
    
    // Assert
    #expect(viewModel.products.isEmpty)
    #expect(viewModel.error != nil)
}
```

### 9.4. Test Endpoint (verify request được build đúng)

```swift
@Test
func testProductListEndpoint_buildsCorrectRequest() {
    let endpoint = ProductEndpoint.list(page: 2, limit: 20)
    
    #expect(endpoint.path == "/products")
    #expect(endpoint.method == .get)
    #expect(endpoint.queryItems == [
        URLQueryItem(name: "page", value: "2"),
        URLQueryItem(name: "limit", value: "20")
    ])
    #expect(endpoint.body == nil)
}

@Test
func testProductCreateEndpoint_includesBody() {
    let request = CreateProductRequest(name: "Test", priceInCents: 100, categoryId: "cat1", imageUrls: [])
    let endpoint = ProductEndpoint.create(request)
    
    #expect(endpoint.path == "/products")
    #expect(endpoint.method == .post)
    #expect(endpoint.body != nil)
}
```

---

## 10. Dependency Graph — Tổng kết

```
ViewModel
  │ (chỉ biết protocol)
  ▼
ProductRepositoryProtocol ←── ProductRepository
  │                               │ (chỉ biết protocol)
  │                               ▼
  │                        APIClientProtocol ←── APIClient
  │                                                │ (chỉ biết protocol)
  │                                                ▼
  │                                         HTTPClient protocol
  │                                           ╱          ╲
  │                              URLSessionHTTPClient   AlamofireHTTPClient
  │                              (production)            (alternative)
  │
  └── MockProductRepository (test)

Mỗi layer chỉ biết PROTOCOL của layer bên dưới.
Không layer nào biết implementation cụ thể.
→ Thay thế bất kỳ layer nào mà không ảnh hưởng các layer khác.
```

```
Composition Root (App entry point):
  ┌─ URLSessionHTTPClient()
  ├─ APIClient(httpClient: ^)
  ├─ ProductRepository(apiClient: ^)
  └─ ProductListViewModel(repository: ^)

Test:
  ┌─ MockAPIClient()
  ├─ ProductRepository(apiClient: ^)
  └─ ProductListViewModel(repository: ^)   ← Code GIỐNG HỆT production
```

---

## 11. Tổng kết

API Layer Abstraction là việc **tạo ranh giới rõ ràng** giữa "cần gì từ network" (protocol) và "làm network như thế nào" (implementation). Với Senior iOS Developer, điều quan trọng không chỉ là biết cách gọi API, mà là thiết kế networking layer sao cho mỗi phần có trách nhiệm riêng biệt, dễ test từng layer độc lập, dễ mở rộng thêm tính năng mới (interceptor), và có thể thay thế implementation mà không ảnh hưởng business logic. Kết quả là codebase có khả năng chịu được thay đổi theo thời gian — đổi thư viện, đổi API format, thêm yêu cầu mới — mà không phải refactor cả ứng dụng.

Bạn muốn mình đi sâu hơn phần nào? Ví dụ: Multipart upload abstraction, GraphQL integration, hay cách xử lý pagination trong API layer?
