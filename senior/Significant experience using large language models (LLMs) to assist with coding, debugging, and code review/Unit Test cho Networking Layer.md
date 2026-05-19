## Viết Unit Test cho Networking Layer phức tạp với LLM — Chi tiết cho Senior iOS Developer

### 1. Tại sao networking layer khó test?

Networking layer là một trong những phần phức tạp nhất để test vì nó liên quan đến nhiều tầng: request building, authentication, serialization/deserialization, error handling, retry logic, caching, token refresh, certificate pinning... Mỗi tầng có hàng chục edge case, và chúng tương tác với nhau theo những cách không dễ dự đoán.

### 2. Một networking layer thực tế

Trước hết, hãy xem một networking layer đủ phức tạp để minh hoạ:

```swift
// MARK: - Core Protocols

protocol HTTPClient {
    func execute(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

protocol TokenProvider {
    func currentToken() async throws -> AuthToken
    func refreshToken() async throws -> AuthToken
}

protocol RequestInterceptor {
    func intercept(_ request: URLRequest) async throws -> URLRequest
}

protocol ResponseValidator {
    func validate(_ response: HTTPURLResponse, data: Data) throws
}

// MARK: - Models

struct AuthToken {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    
    var isExpired: Bool { Date() >= expiresAt }
}

enum APIError: Error, Equatable {
    case unauthorized
    case forbidden
    case notFound
    case rateLimited(retryAfter: TimeInterval)
    case serverError(statusCode: Int)
    case decodingFailed
    case networkUnavailable
    case timeout
    case tokenRefreshFailed
    case maxRetriesExceeded
}

struct APIRequest<Response: Decodable> {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]
    let body: Encodable?
    let requiresAuth: Bool
    let retryPolicy: RetryPolicy
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
}

struct RetryPolicy {
    let maxRetries: Int
    let strategy: Strategy
    
    enum Strategy {
        case immediate
        case exponentialBackoff(base: TimeInterval, maxDelay: TimeInterval)
        case retryAfterHeader
    }
    
    static let `default` = RetryPolicy(
        maxRetries: 3,
        strategy: .exponentialBackoff(base: 1.0, maxDelay: 30.0)
    )
    static let noRetry = RetryPolicy(maxRetries: 0, strategy: .immediate)
}

// MARK: - Networking Service

final class NetworkingService {
    
    private let httpClient: HTTPClient
    private let tokenProvider: TokenProvider
    private let interceptors: [RequestInterceptor]
    private let responseValidator: ResponseValidator
    private let decoder: JSONDecoder
    private let baseURL: URL
    
    // Token refresh synchronization - chỉ 1 refresh tại 1 thời điểm
    private let tokenRefreshLock = NSLock()
    private var activeTokenRefreshTask: Task<AuthToken, Error>?
    
    init(
        baseURL: URL,
        httpClient: HTTPClient,
        tokenProvider: TokenProvider,
        interceptors: [RequestInterceptor] = [],
        responseValidator: ResponseValidator = DefaultResponseValidator(),
        decoder: JSONDecoder = .init()
    ) {
        self.baseURL = baseURL
        self.httpClient = httpClient
        self.tokenProvider = tokenProvider
        self.interceptors = interceptors
        self.responseValidator = responseValidator
        self.decoder = decoder
    }
    
    func perform<T: Decodable>(_ apiRequest: APIRequest<T>) async throws -> T {
        var currentRetry = 0
        
        while true {
            do {
                // 1. Build URLRequest
                var urlRequest = try buildRequest(apiRequest)
                
                // 2. Attach auth token if needed
                if apiRequest.requiresAuth {
                    let token = try await validToken()
                    urlRequest.setValue(
                        "Bearer \(token.accessToken)",
                        forHTTPHeaderField: "Authorization"
                    )
                }
                
                // 3. Apply interceptors
                for interceptor in interceptors {
                    urlRequest = try await interceptor.intercept(urlRequest)
                }
                
                // 4. Execute request
                let (data, response) = try await httpClient.execute(urlRequest)
                
                // 5. Validate response
                try responseValidator.validate(response, data: data)
                
                // 6. Decode
                return try decoder.decode(T.self, from: data)
                
            } catch APIError.unauthorized where apiRequest.requiresAuth {
                // Token expired mid-flight → refresh and retry once
                _ = try await forceRefreshToken()
                if currentRetry == 0 {
                    currentRetry += 1
                    continue
                }
                throw APIError.tokenRefreshFailed
                
            } catch APIError.rateLimited(let retryAfter) 
                where apiRequest.retryPolicy.strategy == .retryAfterHeader {
                guard currentRetry < apiRequest.retryPolicy.maxRetries else {
                    throw APIError.maxRetriesExceeded
                }
                try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                currentRetry += 1
                continue
                
            } catch let error as APIError where shouldRetry(
                error: error,
                retry: currentRetry,
                policy: apiRequest.retryPolicy
            ) {
                let delay = calculateDelay(
                    retry: currentRetry,
                    policy: apiRequest.retryPolicy
                )
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                currentRetry += 1
                continue
                
            } catch {
                throw error
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func buildRequest<T: Decodable>(_ apiRequest: APIRequest<T>) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(apiRequest.path)
        var request = URLRequest(url: url)
        request.httpMethod = apiRequest.method.rawValue
        request.timeoutInterval = 30
        
        apiRequest.headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        if let body = apiRequest.body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
    
    private func validToken() async throws -> AuthToken {
        let token = try await tokenProvider.currentToken()
        if token.isExpired {
            return try await forceRefreshToken()
        }
        return token
    }
    
    private func forceRefreshToken() async throws -> AuthToken {
        tokenRefreshLock.lock()
        if let existingTask = activeTokenRefreshTask {
            tokenRefreshLock.unlock()
            return try await existingTask.value
        }
        
        let task = Task { [weak self] () -> AuthToken in
            guard let self else { throw APIError.tokenRefreshFailed }
            defer {
                self.tokenRefreshLock.lock()
                self.activeTokenRefreshTask = nil
                self.tokenRefreshLock.unlock()
            }
            return try await self.tokenProvider.refreshToken()
        }
        activeTokenRefreshTask = task
        tokenRefreshLock.unlock()
        
        return try await task.value
    }
    
    private func shouldRetry(
        error: APIError,
        retry: Int,
        policy: RetryPolicy
    ) -> Bool {
        guard retry < policy.maxRetries else { return false }
        switch error {
        case .serverError, .timeout, .networkUnavailable:
            return true
        default:
            return false
        }
    }
    
    private func calculateDelay(retry: Int, policy: RetryPolicy) -> TimeInterval {
        switch policy.strategy {
        case .immediate:
            return 0
        case .exponentialBackoff(let base, let maxDelay):
            let delay = base * pow(2.0, Double(retry))
            return min(delay, maxDelay)
        case .retryAfterHeader:
            return 0
        }
    }
}

// MARK: - Default Implementations

struct DefaultResponseValidator: ResponseValidator {
    func validate(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                .flatMap(TimeInterval.init) ?? 60
            throw APIError.rateLimited(retryAfter: retryAfter)
        case 500...599:
            throw APIError.serverError(statusCode: response.statusCode)
        default:
            throw APIError.serverError(statusCode: response.statusCode)
        }
    }
}

// Helper for type-erased encoding
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ value: Encodable) {
        _encode = { try value.encode(to: $0) }
    }
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
```

### 3. Bước 1 — Đưa cho LLM generate test: prompt đúng cách

Senior dev không chỉ paste code rồi nói "viết test". Cần cung cấp context:

```
Write comprehensive unit tests for the NetworkingService class.

Context:
- Using XCTest, Swift Concurrency
- Create mock implementations of HTTPClient, TokenProvider, 
  RequestInterceptor, ResponseValidator
- Test should be deterministic (no real network, no real delays)
- For Task.sleep in retry logic, accept that tests may need 
  small delays or use a Clock abstraction
- Group tests by behavior: happy path, auth flow, retry logic, 
  error handling, interceptors
- Use factory methods for creating test fixtures

Here's the code:
[paste full networking layer code]
```

### 4. Bước 2 — LLM output: Mocks & Basic Tests

LLM sẽ generate mocks và test cases cơ bản khá tốt:

```swift
// MARK: - Mocks

final class MockHTTPClient: HTTPClient {
    var results: [Result<(Data, HTTPURLResponse), Error>] = []
    private var callIndex = 0
    var executedRequests: [URLRequest] = []
    
    func execute(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        executedRequests.append(request)
        guard callIndex < results.count else {
            fatalError("MockHTTPClient: no result configured for call \(callIndex)")
        }
        let result = results[callIndex]
        callIndex += 1
        return try result.get()
    }
}

final class MockTokenProvider: TokenProvider {
    var currentTokenResult: Result<AuthToken, Error> = .success(
        AuthToken(
            accessToken: "valid-token",
            refreshToken: "refresh-token",
            expiresAt: Date().addingTimeInterval(3600)
        )
    )
    var refreshTokenResult: Result<AuthToken, Error> = .success(
        AuthToken(
            accessToken: "new-valid-token",
            refreshToken: "new-refresh-token",
            expiresAt: Date().addingTimeInterval(3600)
        )
    )
    var refreshTokenCallCount = 0
    
    func currentToken() async throws -> AuthToken {
        try currentTokenResult.get()
    }
    
    func refreshToken() async throws -> AuthToken {
        refreshTokenCallCount += 1
        return try refreshTokenResult.get()
    }
}

final class MockInterceptor: RequestInterceptor {
    var interceptedRequests: [URLRequest] = []
    var modifyRequest: ((URLRequest) -> URLRequest)?
    
    func intercept(_ request: URLRequest) async throws -> URLRequest {
        interceptedRequests.append(request)
        return modifyRequest?(request) ?? request
    }
}

// MARK: - Test Helpers

enum TestFixtures {
    static let baseURL = URL(string: "https://api.example.com")!
    
    static func makeResponse(
        statusCode: Int,
        headers: [String: String] = [:]
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: baseURL,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headers
        )!
    }
    
    static func makeJSON<T: Encodable>(_ value: T) -> Data {
        try! JSONEncoder().encode(value)
    }
    
    static func makeAuthRequest<T: Decodable>(
        path: String = "/user/profile",
        responseType: T.Type = TestUser.self,
        retryPolicy: RetryPolicy = .noRetry
    ) -> APIRequest<T> {
        APIRequest(
            path: path,
            method: .get,
            headers: [:],
            body: nil as String?,
            requiresAuth: true,
            retryPolicy: retryPolicy
        )
    }
    
    static func makePublicRequest<T: Decodable>(
        path: String = "/public/health",
        responseType: T.Type = TestHealth.self,
        retryPolicy: RetryPolicy = .noRetry
    ) -> APIRequest<T> {
        APIRequest(
            path: path,
            method: .get,
            headers: [:],
            body: nil as String?,
            requiresAuth: false,
            retryPolicy: retryPolicy
        )
    }
}

struct TestUser: Codable, Equatable {
    let id: Int
    let name: String
}

struct TestHealth: Codable, Equatable {
    let status: String
}
```

LLM tiếp tục generate các test case cơ bản:

```swift
// MARK: - Happy Path Tests

final class NetworkingServiceTests: XCTestCase {
    
    private var httpClient: MockHTTPClient!
    private var tokenProvider: MockTokenProvider!
    private var sut: NetworkingService!
    
    override func setUp() {
        super.setUp()
        httpClient = MockHTTPClient()
        tokenProvider = MockTokenProvider()
        sut = NetworkingService(
            baseURL: TestFixtures.baseURL,
            httpClient: httpClient,
            tokenProvider: tokenProvider
        )
    }
    
    override func tearDown() {
        httpClient = nil
        tokenProvider = nil
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Basic Request Tests
    
    func test_perform_successfulGET_decodesResponse() async throws {
        // Given
        let expectedUser = TestUser(id: 1, name: "Alice")
        httpClient.results = [
            .success((
                TestFixtures.makeJSON(expectedUser),
                TestFixtures.makeResponse(statusCode: 200)
            ))
        ]
        let request = TestFixtures.makeAuthRequest(
            responseType: TestUser.self
        )
        
        // When
        let result = try await sut.perform(request)
        
        // Then
        XCTAssertEqual(result, expectedUser)
        XCTAssertEqual(httpClient.executedRequests.count, 1)
        XCTAssertEqual(
            httpClient.executedRequests.first?.httpMethod, "GET"
        )
    }
    
    func test_perform_authenticatedRequest_attachesBearerToken() async throws {
        // Given
        let user = TestUser(id: 1, name: "Alice")
        httpClient.results = [
            .success((
                TestFixtures.makeJSON(user),
                TestFixtures.makeResponse(statusCode: 200)
            ))
        ]
        let request = TestFixtures.makeAuthRequest(
            responseType: TestUser.self
        )
        
        // When
        _ = try await sut.perform(request)
        
        // Then
        let authHeader = httpClient.executedRequests.first?
            .value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(authHeader, "Bearer valid-token")
    }
    
    func test_perform_publicRequest_doesNotAttachToken() async throws {
        // Given
        let health = TestHealth(status: "ok")
        httpClient.results = [
            .success((
                TestFixtures.makeJSON(health),
                TestFixtures.makeResponse(statusCode: 200)
            ))
        ]
        let request = TestFixtures.makePublicRequest(
            responseType: TestHealth.self
        )
        
        // When
        _ = try await sut.perform(request)
        
        // Then
        let authHeader = httpClient.executedRequests.first?
            .value(forHTTPHeaderField: "Authorization")
        XCTAssertNil(authHeader)
    }
    
    // MARK: - Error Mapping Tests
    
    func test_perform_401Response_throwsUnauthorized() async {
        // Given
        httpClient.results = [
            .success((
                Data(),
                TestFixtures.makeResponse(statusCode: 401)
            )),
            // Sau khi retry với token mới, vẫn 401
            .success((
                Data(),
                TestFixtures.makeResponse(statusCode: 401)
            ))
        ]
        let request = TestFixtures.makeAuthRequest(
            responseType: TestUser.self
        )
        
        // When/Then
        do {
            _ = try await sut.perform(request)
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? APIError, .tokenRefreshFailed)
        }
    }
    
    func test_perform_404Response_throwsNotFound() async {
        // Given
        httpClient.results = [
            .success((
                Data(),
                TestFixtures.makeResponse(statusCode: 404)
            ))
        ]
        let request = TestFixtures.makePublicRequest(
            responseType: TestHealth.self
        )
        
        // When/Then
        do {
            _ = try await sut.perform(request)
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? APIError, .notFound)
        }
    }
    
    func test_perform_invalidJSON_throwsDecodingError() async {
        // Given
        httpClient.results = [
            .success((
                Data("not json".utf8),
                TestFixtures.makeResponse(statusCode: 200)
            ))
        ]
        let request = TestFixtures.makePublicRequest(
            responseType: TestHealth.self
        )
        
        // When/Then
        do {
            _ = try await sut.perform(request)
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    // MARK: - Token Refresh Tests
    
    func test_perform_expiredToken_refreshesAndRetries() async throws {
        // Given
        tokenProvider.currentTokenResult = .success(
            AuthToken(
                accessToken: "expired-token",
                refreshToken: "refresh",
                expiresAt: Date().addingTimeInterval(-100) // expired
            )
        )
        let expectedUser = TestUser(id: 1, name: "Alice")
        httpClient.results = [
            .success((
                TestFixtures.makeJSON(expectedUser),
                TestFixtures.makeResponse(statusCode: 200)
            ))
        ]
        let request = TestFixtures.makeAuthRequest(
            responseType: TestUser.self
        )
        
        // When
        let result = try await sut.perform(request)
        
        // Then
        XCTAssertEqual(result, expectedUser)
        XCTAssertEqual(tokenProvider.refreshTokenCallCount, 1)
        let authHeader = httpClient.executedRequests.first?
            .value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(authHeader, "Bearer new-valid-token")
    }
    
    // MARK: - Retry Logic Tests
    
    func test_perform_serverErrorWithRetry_retriesAndSucceeds() async throws {
        // Given
        let user = TestUser(id: 1, name: "Alice")
        httpClient.results = [
            .success((
                Data(),
                TestFixtures.makeResponse(statusCode: 500)
            )),
            .success((
                Data(),
                TestFixtures.makeResponse(statusCode: 500)
            )),
            .success((
                TestFixtures.makeJSON(user),
                TestFixtures.makeResponse(statusCode: 200)
            ))
        ]
        let request = APIRequest<TestUser>(
            path: "/user",
            method: .get,
            headers: [:],
            body: nil as String?,
            requiresAuth: false,
            retryPolicy: .default
        )
        
        // When
        let result = try await sut.perform(request)
        
        // Then
        XCTAssertEqual(result, user)
        XCTAssertEqual(httpClient.executedRequests.count, 3)
    }
    
    func test_perform_exceedsMaxRetries_throwsMaxRetriesExceeded() async {
        // Given: 4 failures, max retry = 3
        httpClient.results = (0...3).map { _ in
            .success((
                Data(),
                TestFixtures.makeResponse(statusCode: 500)
            ))
        }
        let request = APIRequest<TestUser>(
            path: "/user",
            method: .get,
            headers: [:],
            body: nil as String?,
            requiresAuth: false,
            retryPolicy: .default
        )
        
        // When/Then
        do {
            _ = try await sut.perform(request)
            XCTFail("Expected maxRetriesExceeded")
        } catch {
            XCTAssertEqual(error as? APIError, .serverError(statusCode: 500))
        }
    }
    
    // MARK: - Interceptor Tests
    
    func test_perform_withInterceptor_appliesModification() async throws {
        // Given
        let interceptor = MockInterceptor()
        interceptor.modifyRequest = { request in
            var modified = request
            modified.setValue("custom-value", forHTTPHeaderField: "X-Custom")
            return modified
        }
        
        sut = NetworkingService(
            baseURL: TestFixtures.baseURL,
            httpClient: httpClient,
            tokenProvider: tokenProvider,
            interceptors: [interceptor]
        )
        
        let health = TestHealth(status: "ok")
        httpClient.results = [
            .success((
                TestFixtures.makeJSON(health),
                TestFixtures.makeResponse(statusCode: 200)
            ))
        ]
        let request = TestFixtures.makePublicRequest(
            responseType: TestHealth.self
        )
        
        // When
        _ = try await sut.perform(request)
        
        // Then
        let customHeader = httpClient.executedRequests.first?
            .value(forHTTPHeaderField: "X-Custom")
        XCTAssertEqual(customHeader, "custom-value")
    }
}
```

### 5. Bước 3 — Senior Review: LLM đã bỏ sót gì?

Đây là phần quan trọng nhất. LLM generate được ~70% test cases cơ bản, nhưng **bỏ sót những edge case mà chỉ người hiểu business logic và production behavior mới biết**.

#### a) Token refresh race condition — LLM hầu như không test

Trong production, 5-10 request có thể fire cùng lúc khi token expired. Chỉ 1 refresh nên xảy ra. LLM không hiểu pattern này:

```swift
// ⚠️ LLM KHÔNG GENERATE TEST NÀY
func test_perform_concurrentRequestsWithExpiredToken_refreshesOnlyOnce() async throws {
    // Given: expired token
    tokenProvider.currentTokenResult = .success(
        AuthToken(
            accessToken: "expired",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(-100)
        )
    )
    
    // Simulate slow refresh
    let originalRefresh = tokenProvider.refreshTokenResult
    tokenProvider.refreshTokenResult = originalRefresh
    // Cần MockTokenProvider hỗ trợ delay:
    // tokenProvider.refreshDelay = 0.5  
    
    let user = TestUser(id: 1, name: "Alice")
    // Cần đủ results cho N concurrent requests
    httpClient.results = (0..<5).map { _ in
        .success((
            TestFixtures.makeJSON(user),
            TestFixtures.makeResponse(statusCode: 200)
        ))
    }
    
    // When: fire 5 requests concurrently
    let results = await withTaskGroup(
        of: Result<TestUser, Error>.self,
        returning: [Result<TestUser, Error>].self
    ) { group in
        for _ in 0..<5 {
            group.addTask {
                do {
                    let user: TestUser = try await self.sut.perform(
                        TestFixtures.makeAuthRequest(responseType: TestUser.self)
                    )
                    return .success(user)
                } catch {
                    return .failure(error)
                }
            }
        }
        var collected: [Result<TestUser, Error>] = []
        for await result in group {
            collected.append(result)
        }
        return collected
    }
    
    // Then: ALL requests succeed, but refresh chỉ gọi 1 LẦN
    let successes = results.filter {
        if case .success = $0 { return true }
        return false
    }
    XCTAssertEqual(successes.count, 5)
    XCTAssertEqual(tokenProvider.refreshTokenCallCount, 1,
        "Token refresh should be called exactly once for concurrent requests"
    )
}
```

#### b) 401 mid-flight: token valid khi gửi nhưng expired khi server nhận

```swift
// ⚠️ LLM thường test "expired token" nhưng KHÔNG test scenario:
// Token chưa expired locally, nhưng server đã revoke/expire
func test_perform_tokenValidLocallyButServerReturns401_refreshesAndRetries() async throws {
    // Given: token còn hạn theo local check
    tokenProvider.currentTokenResult = .success(
        AuthToken(
            accessToken: "looks-valid-but-revoked",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600) // còn hạn
        )
    )
    
    let user = TestUser(id: 1, name: "Alice")
    httpClient.results = [
        // Lần 1: server reject token
        .success((
            Data(),
            TestFixtures.makeResponse(statusCode: 401)
        )),
        // Lần 2: sau refresh, thành công
        .success((
            TestFixtures.makeJSON(user),
            TestFixtures.makeResponse(statusCode: 200)
        ))
    ]
    
    let request = TestFixtures.makeAuthRequest(responseType: TestUser.self)
    
    // When
    let result = try await sut.perform(request)
    
    // Then
    XCTAssertEqual(result, user)
    XCTAssertEqual(tokenProvider.refreshTokenCallCount, 1)
    XCTAssertEqual(httpClient.executedRequests.count, 2)
    // Verify lần 2 dùng new token
    let secondAuthHeader = httpClient.executedRequests[1]
        .value(forHTTPHeaderField: "Authorization")
    XCTAssertEqual(secondAuthHeader, "Bearer new-valid-token")
}
```

#### c) Token refresh thất bại — rồi sao?

```swift
// ⚠️ LLM test "refresh succeeds" nhưng quên test "refresh fails"
func test_perform_tokenRefreshFails_throwsTokenRefreshFailed() async {
    // Given: expired token + refresh fails
    tokenProvider.currentTokenResult = .success(
        AuthToken(
            accessToken: "expired",
            refreshToken: "bad-refresh",
            expiresAt: Date().addingTimeInterval(-100)
        )
    )
    tokenProvider.refreshTokenResult = .failure(APIError.tokenRefreshFailed)
    
    let request = TestFixtures.makeAuthRequest(responseType: TestUser.self)
    
    // When/Then
    do {
        _ = try await sut.perform(request)
        XCTFail("Expected tokenRefreshFailed")
    } catch {
        XCTAssertEqual(error as? APIError, .tokenRefreshFailed)
    }
    
    // CRITICAL: verify không có request nào được gửi đi
    XCTAssertEqual(httpClient.executedRequests.count, 0,
        "No network request should be made if token refresh fails"
    )
}

// ⚠️ Còn edge case: concurrent requests khi refresh fails
func test_perform_concurrentRequests_allFailWhenRefreshFails() async {
    tokenProvider.currentTokenResult = .success(
        AuthToken(
            accessToken: "expired",
            refreshToken: "bad",
            expiresAt: Date().addingTimeInterval(-100)
        )
    )
    tokenProvider.refreshTokenResult = .failure(APIError.tokenRefreshFailed)
    
    let results = await withTaskGroup(
        of: Result<TestUser, Error>.self,
        returning: [Result<TestUser, Error>].self
    ) { group in
        for _ in 0..<3 {
            group.addTask {
                do {
                    let user: TestUser = try await self.sut.perform(
                        TestFixtures.makeAuthRequest(responseType: TestUser.self)
                    )
                    return .success(user)
                } catch {
                    return .failure(error)
                }
            }
        }
        var collected: [Result<TestUser, Error>] = []
        for await result in group {
            collected.append(result)
        }
        return collected
    }
    
    // ALL requests should fail
    let failures = results.filter {
        if case .failure = $0 { return true }
        return false
    }
    XCTAssertEqual(failures.count, 3)
    // Và refresh chỉ gọi 1 lần (không retry refresh 3 lần)
    XCTAssertEqual(tokenProvider.refreshTokenCallCount, 1)
}
```

#### d) Rate limiting — business logic phức tạp

```swift
// ⚠️ LLM test "429 → retry" nhưng không test header parsing
func test_perform_rateLimited_usesRetryAfterHeader() async throws {
    let user = TestUser(id: 1, name: "Alice")
    httpClient.results = [
        .success((
            Data(),
            TestFixtures.makeResponse(
                statusCode: 429,
                headers: ["Retry-After": "2"]
            )
        )),
        .success((
            TestFixtures.makeJSON(user),
            TestFixtures.makeResponse(statusCode: 200)
        ))
    ]
    
    let request = APIRequest<TestUser>(
        path: "/user",
        method: .get,
        headers: [:],
        body: nil as String?,
        requiresAuth: false,
        retryPolicy: RetryPolicy(maxRetries: 1, strategy: .retryAfterHeader)
    )
    
    let start = Date()
    let result = try await sut.perform(request)
    let elapsed = Date().timeIntervalSince(start)
    
    XCTAssertEqual(result, user)
    // Verify đã wait ít nhất ~2 giây
    XCTAssertGreaterThanOrEqual(elapsed, 1.8)
}

// ⚠️ LLM không test: missing Retry-After header → fallback?
func test_perform_rateLimited_missingRetryAfterHeader_usesFallback() async throws {
    let user = TestUser(id: 1, name: "Alice")
    httpClient.results = [
        .success((
            Data(),
            TestFixtures.makeResponse(
                statusCode: 429,
                headers: [:]  // KHÔNG có Retry-After
            )
        )),
        .success((
            TestFixtures.makeJSON(user),
            TestFixtures.makeResponse(statusCode: 200)
        ))
    ]
    
    let request = APIRequest<TestUser>(
        path: "/user",
        method: .get,
        headers: [:],
        body: nil as String?,
        requiresAuth: false,
        retryPolicy: RetryPolicy(maxRetries: 1, strategy: .retryAfterHeader)
    )
    
    // Verify fallback default = 60s 
    // (trong DefaultResponseValidator)
    // → Test này reveal bug: 60s fallback quá lâu?
    // → Senior dev nhận ra cần thảo luận với team về policy
}
```

#### e) Interceptor chain order — LLM test 1 interceptor nhưng không test nhiều

```swift
// ⚠️ Interceptor order matters — LLM không test
func test_perform_multipleInterceptors_appliedInOrder() async throws {
    let first = MockInterceptor()
    first.modifyRequest = { req in
        var r = req
        r.setValue("first", forHTTPHeaderField: "X-Chain")
        return r
    }
    
    let second = MockInterceptor()
    second.modifyRequest = { req in
        var r = req
        // Đọc giá trị từ interceptor trước
        let previous = req.value(forHTTPHeaderField: "X-Chain") ?? ""
        r.setValue(previous + ",second", forHTTPHeaderField: "X-Chain")
        return r
    }
    
    sut = NetworkingService(
        baseURL: TestFixtures.baseURL,
        httpClient: httpClient,
        tokenProvider: tokenProvider,
        interceptors: [first, second]  // order matters!
    )
    
    let health = TestHealth(status: "ok")
    httpClient.results = [
        .success((
            TestFixtures.makeJSON(health),
            TestFixtures.makeResponse(statusCode: 200)
        ))
    ]
    
    _ = try await sut.perform(
        TestFixtures.makePublicRequest(responseType: TestHealth.self)
    )
    
    let chainHeader = httpClient.executedRequests.first?
        .value(forHTTPHeaderField: "X-Chain")
    XCTAssertEqual(chainHeader, "first,second")
}

// ⚠️ Interceptor throw error — LLM không test
func test_perform_interceptorThrows_propagatesError() async {
    let failingInterceptor = MockInterceptor()
    // Cần extend MockInterceptor để support throwing
    // failingInterceptor.shouldThrow = SomeCustomError()
    
    // Verify: error propagates, request không gửi đi
}
```

#### f) Task cancellation — Senior level concern

```swift
// ⚠️ LLM hầu như KHÔNG BAO GIỜ test cancellation
func test_perform_taskCancelled_stopsRetrying() async {
    httpClient.results = (0...10).map { _ in
        .success((
            Data(),
            TestFixtures.makeResponse(statusCode: 500)
        ))
    }
    
    let request = APIRequest<TestUser>(
        path: "/user",
        method: .get,
        headers: [:],
        body: nil as String?,
        requiresAuth: false,
        retryPolicy: RetryPolicy(
            maxRetries: 10,
            strategy: .exponentialBackoff(base: 1.0, maxDelay: 30.0)
        )
    )
    
    let task = Task {
        try await sut.perform(request)
    }
    
    // Cancel sau 0.5s — không nên đợi hết 10 retries
    try? await Task.sleep(nanoseconds: 500_000_000)
    task.cancel()
    
    let result = await task.result
    switch result {
    case .failure(let error):
        XCTAssertTrue(error is CancellationError)
    case .success:
        XCTFail("Should have been cancelled")
    }
    
    // Verify: không retry hết 10 lần
    XCTAssertLessThan(httpClient.executedRequests.count, 5)
}
```

#### g) Exponential backoff — verify timing chính xác

```swift
// ⚠️ LLM test "retry works" nhưng không verify delay timing
func test_calculateDelay_exponentialBackoff_correctValues() {
    // Đây là lý do senior dev thường extract hàm pure 
    // ra để test riêng, thay vì test qua integration

    // base=1.0, maxDelay=30.0
    // retry 0 → 1.0 * 2^0 = 1.0s
    // retry 1 → 1.0 * 2^1 = 2.0s
    // retry 2 → 1.0 * 2^2 = 4.0s
    // retry 3 → 1.0 * 2^3 = 8.0s
    // retry 5 → 1.0 * 2^5 = 32.0 → capped at 30.0s
    
    // Cần expose calculateDelay hoặc 
    // extract thành RetryDelayCalculator
}
```

#### h) Business-specific edge cases — LLM không thể biết

```swift
// ====================================================
// NHỮNG TEST NÀY CHỈ SENIOR DEV HIỂU BUSINESS LOGIC 
// MỚI BIẾT CẦN VIẾT
// ====================================================

// 1) Payment endpoint KHÔNG ĐƯỢC retry
// → Business rule: charge duplicate = thảm hoạ
func test_perform_paymentEndpoint_noRetryOnServerError() async {
    // Verify rằng POST /payments dùng .noRetry
    // Dù server trả 500, KHÔNG retry
    // → Đây là test cho business rule, không phải technical
}

// 2) Logout khi refresh token expired
// → Business rule: app phải force logout
func test_perform_refreshTokenExpiredServerSide_triggersLogout() async {
    // Khi refreshToken() throws .unauthorized 
    // (refresh token cũng expired)
    // → App phải notify (NotificationCenter / delegate) 
    //   để force logout user
    // LLM không biết business rule này
}

// 3) Offline → queue requests
// → Business rule: một số request (analytics, sync) 
//   cần queue khi offline
func test_perform_networkUnavailable_analyticsRequestQueued() async {
    // Verify: analytics requests được save 
    // và retry khi online
    // Nhưng user-facing requests throw immediately
}

// 4) Server maintenance mode
// → Business rule: 503 với header X-Maintenance: true 
//   → show maintenance screen, không retry
func test_perform_maintenanceMode_doesNotRetry() async {
    // Custom header mà chỉ team backend mới định nghĩa
    // LLM không thể biết convention này
}

// 5) A/B test header injection
// → Business rule: mọi request cần gắn experiment variant
func test_perform_attachesExperimentHeaders() async {
    // Verify: X-Experiment-Variant: "checkout_v2"
    // được attach vào mọi request
    // → Interceptor test, nhưng business logic xác định 
    //   HEADER NÀO cần gắn
}

// 6) Sensitive data: token KHÔNG xuất hiện trong log
func test_perform_authToken_notLoggedInErrorDescription() async {
    // Verify: khi request fail, error message 
    // KHÔNG chứa access token
    // → Security requirement mà LLM không biết
}
```

### 6. Tổng kết: LLM generate gì vs Senior dev bổ sung gì

| LLM generate tốt | Senior dev phải bổ sung |
|---|---|
| Happy path (200 → decode OK) | Concurrency / race conditions |
| Basic error mapping (401, 404, 500) | Token refresh edge cases (revoked, concurrent) |
| Simple retry (fail → retry → success) | Cancellation behavior |
| Single interceptor | Interceptor chain order, interceptor errors |
| Mock setup boilerplate | Business-specific rules (payment no-retry, force logout) |
| Standard assertion patterns | Security concerns (token not in logs) |
| Basic test naming convention | Performance edge cases (memory, timing) |

**Workflow hiệu quả nhất:**

1. **LLM** generate mocks, helpers, fixtures, và ~20-25 basic test cases → tiết kiệm 2-3 giờ viết boilerplate.
2. **Senior dev** review output, fix sai sót (state, assertion logic), rồi bổ sung ~10-15 edge case tests dựa trên kiến thức về business logic, production incidents từng gặp, và security requirements → phần này không thể thay thế.
3. **Kết quả**: test suite hoàn chỉnh trong 1 ngày thay vì 3-4 ngày, với coverage bao phủ cả technical edge cases lẫn business-critical scenarios.
