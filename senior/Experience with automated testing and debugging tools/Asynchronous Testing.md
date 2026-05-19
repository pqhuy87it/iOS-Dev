# Asynchronous Testing trong iOS — Chi tiết cho Senior Developer

Async code chiếm phần lớn logic trong iOS app: gọi API, đọc database, xử lý image, Combine pipelines, Swift Concurrency... Nếu không biết test async đúng cách, bạn sẽ gặp **flaky tests** (test lúc pass lúc fail), **false positives** (test pass nhưng code sai), hoặc đơn giản là bỏ qua không test — cả 3 đều nguy hiểm.

---

## 1. XCTestExpectation — Cách tiếp cận truyền thống

### Cơ chế hoạt động

Ý tưởng đơn giản: bạn tạo một "lời hứa" (expectation), chạy async code, khi async hoàn thành thì "fulfill" lời hứa đó, và test sẽ **chờ** trong một khoảng thời gian nhất định.

```swift
func test_fetchUser_shouldReturnCorrectName() {
    // 1. Tạo expectation
    let expectation = expectation(description: "Fetch user completes")
    
    // 2. Chạy async code (completion handler style)
    sut.fetchUser(id: "123") { result in
        switch result {
        case .success(let user):
            XCTAssertEqual(user.name, "Huy")
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
        }
        
        // 3. Fulfill khi xong
        expectation.fulfill()
    }
    
    // 4. Chờ — timeout 5 giây
    wait(for: [expectation], timeout: 5.0)
}
```

### Các biến thể quan trọng mà Senior cần nắm

**Nhiều expectations cùng lúc** — khi test một flow cần nhiều async operations hoàn thành:

```swift
func test_parallelFetch_shouldCompleteAll() {
    let userExpectation = expectation(description: "User fetched")
    let ordersExpectation = expectation(description: "Orders fetched")
    
    sut.fetchUser { _ in userExpectation.fulfill() }
    sut.fetchOrders { _ in ordersExpectation.fulfill() }
    
    // Chờ cả 2, KHÔNG quan tâm thứ tự hoàn thành
    wait(for: [userExpectation, ordersExpectation], timeout: 5.0)
}
```

**`enforceOrder: true`** — khi thứ tự hoàn thành quan trọng:

```swift
func test_loginThenFetchProfile_shouldBeSequential() {
    let loginExp = expectation(description: "Login first")
    let profileExp = expectation(description: "Then fetch profile")
    
    sut.login { _ in loginExp.fulfill() }
    sut.fetchProfile { _ in profileExp.fulfill() }
    
    // Login PHẢI xong trước fetchProfile
    wait(for: [loginExp, profileExp], timeout: 5.0, enforceOrder: true)
}
```

**`expectedFulfillmentCount`** — khi một event phải xảy ra đúng N lần:

```swift
func test_progressCallback_shouldFireExactly3Times() {
    let progressExp = expectation(description: "Progress updates")
    progressExp.expectedFulfillmentCount = 3  // Phải fulfill đúng 3 lần
    
    sut.downloadFile(url: testURL) { progress in
        // Mỗi lần callback -> fulfill 1 lần
        progressExp.fulfill()
    }
    
    wait(for: [progressExp], timeout: 10.0)
}
```

**`isInverted`** — test rằng một điều **KHÔNG** xảy ra. Đây là pattern rất hay mà nhiều dev bỏ qua:

```swift
func test_cachedData_shouldNotTriggerNetworkCall() {
    let networkExp = expectation(description: "Network should NOT be called")
    networkExp.isInverted = true  // Expect rằng KHÔNG fulfill
    
    mockNetwork.onRequest = {
        networkExp.fulfill()  // Nếu network bị gọi -> test FAIL
    }
    
    sut.loadData(useCache: true) { _ in }
    
    // Chờ 2 giây, nếu không ai fulfill -> PASS
    wait(for: [networkExp], timeout: 2.0)
}
```

### Vấn đề với XCTestExpectation

Senior dev cần nhận ra các **pitfalls**:

**Timeout quá lớn** — `timeout: 30` làm CI chậm kinh khủng khi test fail. Rule of thumb: unit test timeout nên dưới 3 giây, nếu cần lâu hơn thì đang test sai thứ (hoặc chưa mock đúng).

**Fulfill nhiều lần** — gọi `fulfill()` nhiều hơn `expectedFulfillmentCount` sẽ crash test. Đây là bug phổ biến khi callback bị gọi lại không mong muốn.

**Race conditions trong assertions** — assertion chạy trên background thread có thể bị nuốt:

```swift
// ⚠️ SAI — XCTAssert trên background thread có thể không report đúng
sut.fetchUser { user in
    DispatchQueue.global().async {
        XCTAssertEqual(user.name, "Huy")  // Có thể bị miss
        expectation.fulfill()
    }
}

// ✅ ĐÚNG — Assert trước fulfill, trên cùng callback thread
sut.fetchUser { user in
    XCTAssertEqual(user.name, "Huy")
    expectation.fulfill()
}
```

---

## 2. Swift Concurrency — Test async/await trực tiếp

Từ Xcode 13.2+, XCTest hỗ trợ test function là `async`. Đây là cách tiếp cận **sạch hơn rất nhiều**.

### Cơ bản

```swift
// Function cần test
func fetchUser(id: String) async throws -> User {
    let data = try await networkService.request(.user(id: id))
    return try JSONDecoder().decode(User.self, from: data)
}

// Test — cực kỳ đơn giản, không cần expectation
func test_fetchUser_shouldDecodeCorrectly() async throws {
    // Arrange
    mockNetwork.mockResponse = validUserJSON
    
    // Act
    let user = try await sut.fetchUser(id: "123")
    
    // Assert
    XCTAssertEqual(user.name, "Huy")
    XCTAssertEqual(user.email, "huy@example.com")
}
```

Không cần `expectation`, không cần `wait`, không cần `timeout`. Code đọc như synchronous nhưng thực tế là async. Đây là lý do Swift Concurrency được ưa chuộng cho testing.

### Test async throws

```swift
func test_fetchUser_invalidID_shouldThrowNotFound() async {
    mockNetwork.mockError = NetworkError.notFound
    
    do {
        _ = try await sut.fetchUser(id: "invalid")
        XCTFail("Expected error to be thrown")
    } catch {
        XCTAssertEqual(error as? NetworkError, .notFound)
    }
}

// Hoặc gọn hơn với XCTAssertThrowsError cho async (iOS 16+):
func test_fetchUser_invalidID_shouldThrowNotFound_v2() async throws {
    mockNetwork.mockError = NetworkError.notFound
    
    await XCTAssertThrowsError(try await sut.fetchUser(id: "invalid")) { error in
        XCTAssertEqual(error as? NetworkError, .notFound)
    }
}
```

### Test TaskGroup / Concurrent operations

```swift
func test_fetchMultipleUsers_shouldReturnAll() async throws {
    mockNetwork.mockResponse = validUserJSON
    
    let users = try await withThrowingTaskGroup(of: User.self) { group in
        for id in ["1", "2", "3"] {
            group.addTask { try await self.sut.fetchUser(id: id) }
        }
        
        var results: [User] = []
        for try await user in group {
            results.append(user)
        }
        return results
    }
    
    XCTAssertEqual(users.count, 3)
}
```

### Test Actor isolation

```swift
actor CartManager {
    private var items: [CartItem] = []
    
    func add(_ item: CartItem) {
        items.append(item)
    }
    
    func totalCount() -> Int {
        items.count
    }
}

func test_cartManager_addItems_shouldBeThreadSafe() async {
    let cart = CartManager()
    
    // Simulate concurrent adds
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<100 {
            group.addTask {
                await cart.add(CartItem(id: "\(i)"))
            }
        }
    }
    
    // Actor đảm bảo thread safety — count phải chính xác
    let count = await cart.totalCount()
    XCTAssertEqual(count, 100)
}
```

### Test Timeout cho async — khi cần giới hạn thời gian

Swift Concurrency không có built-in timeout trong test, nhưng senior dev có thể tự tạo:

```swift
func test_slowOperation_shouldCompleteWithinLimit() async throws {
    // Race giữa operation thật và timeout
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            _ = try await self.sut.heavyOperation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 giây
            throw TestError.timeout
        }
        
        // Task nào xong trước thắng, cancel task còn lại
        try await group.next()
        group.cancelAll()
    }
}
```

---

## 3. Test Combine Pipelines

Combine là async nhưng dựa trên reactive streams, nên cần approach riêng.

### Cách 1: Dùng XCTestExpectation + sink

```swift
func test_searchViewModel_shouldDebounceAndFilter() {
    let expectation = expectation(description: "Search results updated")
    var cancellables = Set<AnyCancellable>()
    
    sut.$searchResults
        .dropFirst()  // Bỏ giá trị initial
        .sink { results in
            XCTAssertEqual(results.count, 5)
            expectation.fulfill()
        }
        .store(in: &cancellables)
    
    sut.searchText = "Swift"
    
    wait(for: [expectation], timeout: 3.0)
}
```

### Cách 2: Collect values rồi assert

Pattern mạnh hơn khi cần kiểm tra chuỗi giá trị emit qua thời gian:

```swift
func test_counter_shouldEmitIncrementalValues() {
    let expectation = expectation(description: "All values emitted")
    var receivedValues: [Int] = []
    var cancellables = Set<AnyCancellable>()
    
    sut.counterPublisher
        .prefix(3)  // Chỉ lấy 3 giá trị đầu
        .sink(
            receiveCompletion: { _ in expectation.fulfill() },
            receiveValue: { receivedValues.append($0) }
        )
        .store(in: &cancellables)
    
    sut.startCounting()
    
    wait(for: [expectation], timeout: 3.0)
    XCTAssertEqual(receivedValues, [1, 2, 3])
}
```

### Cách 3: Dùng `.values` (Combine + Swift Concurrency bridge)

Từ iOS 15+, bạn có thể dùng `publisher.values` để biến Combine stream thành `AsyncSequence`:

```swift
func test_publisher_withAsyncValues() async {
    let publisher = [1, 2, 3, 4, 5].publisher
    
    var collected: [Int] = []
    for await value in publisher.values {
        collected.append(value)
    }
    
    XCTAssertEqual(collected, [1, 2, 3, 4, 5])
}
```

### Custom Test Helper — Scheduler Injection

Senior dev thường inject `Scheduler` vào ViewModel để kiểm soát thời gian trong test:

```swift
class SearchViewModel<S: Scheduler>: ObservableObject {
    @Published var query = ""
    @Published var results: [String] = []
    
    init(scheduler: S, searchService: SearchServiceProtocol) {
        $query
            .debounce(for: .milliseconds(300), scheduler: scheduler)
            .removeDuplicates()
            .flatMap { searchService.search($0) }
            .assign(to: &$results)
    }
}

// Trong test — dùng ImmediateScheduler, KHÔNG chờ debounce thật
func test_search_withImmediateScheduler() {
    let sut = SearchViewModel(
        scheduler: DispatchQueue.test,  // Hoặc ImmediateScheduler.shared
        searchService: mockService
    )
    
    sut.query = "Swift"
    
    // Advance scheduler manually (nếu dùng TestScheduler)
    // Không cần chờ 300ms thật
}
```

---

## 4. Bridging: Test Legacy Callback Code bằng async/await

Trong thực tế, codebase thường mix cả callback, Combine, và async/await. Senior dev cần biết cách bridge:

### Wrap completion handler thành async cho test

```swift
// Legacy API
func fetchProfile(completion: @escaping (Result<Profile, Error>) -> Void) { ... }

// Wrap để test dễ hơn
func test_legacyFetchProfile() async throws {
    let profile: Profile = try await withCheckedThrowingContinuation { continuation in
        sut.fetchProfile { result in
            continuation.resume(with: result)
        }
    }
    
    XCTAssertEqual(profile.name, "Huy")
}
```

Cách này giúp bạn viết test theo style async/await cho cả code cũ, thống nhất codebase test.

---

## 5. Patterns & Best Practices cho Senior

### Mock async dependencies bằng Protocol

```swift
protocol UserRepositoryProtocol {
    func fetchUser(id: String) async throws -> User
}

// Mock cho testing
class MockUserRepository: UserRepositoryProtocol {
    var stubbedResult: Result<User, Error> = .success(User.mock)
    var fetchCallCount = 0
    
    func fetchUser(id: String) async throws -> User {
        fetchCallCount += 1
        return try stubbedResult.get()
    }
}

func test_viewModel_callsRepositoryOnce() async throws {
    let mockRepo = MockUserRepository()
    let vm = UserViewModel(repository: mockRepo)
    
    await vm.loadUser(id: "123")
    
    XCTAssertEqual(mockRepo.fetchCallCount, 1)
    XCTAssertEqual(vm.userName, "Mock User")
}
```

### Test Cancellation

Một điểm mà nhiều dev bỏ qua — senior cần verify rằng task bị cancel thì resource được cleanup đúng:

```swift
func test_taskCancellation_shouldStopFetching() async {
    let task = Task {
        try await sut.longRunningFetch()
    }
    
    // Cancel ngay lập tức
    task.cancel()
    
    let result = await task.result
    
    switch result {
    case .failure(let error where error is CancellationError):
        break  // Expected
    default:
        XCTFail("Should have thrown CancellationError")
    }
}
```

### Tránh Flaky Tests — Nguyên tắc vàng

Flaky async test là nỗi ác mộng của CI. Senior dev tuân theo:

- **Không depend vào real timing** — mock scheduler, inject delay, dùng `ImmediateScheduler`
- **Không depend vào thứ tự execution** trừ khi test chính thứ tự đó
- **Luôn mock I/O** — network, disk, database đều phải mock trong unit test
- **Timeout nhỏ** — unit test timeout 2-3 giây max, nếu cần hơn thì review lại test design
- **Mỗi test độc lập** — không share state giữa các test case, `setUp()` và `tearDown()` phải reset sạch

---

## Tóm tắt so sánh các approach

| Approach | Dùng khi | Ưu điểm | Nhược điểm |
|---|---|---|---|
| `XCTestExpectation` | Completion handlers, delegate callbacks, NotificationCenter | Hoạt động với mọi async pattern | Verbose, dễ quên fulfill, timeout tuning |
| `async` test functions | async/await code (Swift 5.5+) | Clean, đọc như sync, compiler check | Chỉ cho async/await code |
| Combine + sink + expectation | Combine publishers | Linh hoạt, test stream values | Boilerplate nhiều, cần manage cancellables |
| Combine `.values` + async | Combine → AsyncSequence bridge | Kết hợp 2 thế giới | iOS 15+ only |

Senior dev thành thạo **cả 4 approach** và biết chọn đúng cái cho đúng context. Quan trọng hơn, bạn phải có khả năng thiết kế code production sao cho nó dễ test async — đó mới là skill thực sự ở level senior.
