import Foundation
import Combine

final class CombinePostListVM: ObservableObject {
    @Published private(set) var posts: [Post] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var error: APIError?
    @Published var searchQuery = ""
    
    private(set) var currentPage = 1
    private(set) var hasMore = true
    
    private let service: CombinePostServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    // ↑ GIỮ reference cho subscriptions — nếu empty → auto cancel
    
    init(service: CombinePostServiceProtocol = CombinePostService()) {
        self.service = service
        setupSearchDebounce()
    }
    
    // === Load initial page ===
    func loadPosts() {
        isLoading = true
        error = nil
        currentPage = 1
        
        service.getPosts(page: 1)
            .receive(on: DispatchQueue.main)
            // ↑ Switch về main thread cho UI updates
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let err) = completion {
                        self?.error = err
                    }
                },
                receiveValue: { [weak self] posts in
                    self?.posts = posts
                    self?.hasMore = !posts.isEmpty
                }
            )
            .store(in: &cancellables)
            // ↑ Lưu subscription — cancel khi VM deinit
    }
    
    // === Load next page ===
    func loadMore() {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        
        service.getPosts(page: currentPage + 1)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingMore = false
                },
                receiveValue: { [weak self] newPosts in
                    self?.posts.append(contentsOf: newPosts)
                    self?.currentPage += 1
                    self?.hasMore = !newPosts.isEmpty
                }
            )
            .store(in: &cancellables)
    }
    
    // === Create post ===
    func createPost(title: String, body: String) {
        let request = CreatePostRequest(title: title, body: body, userId: 1)
        
        service.createPost(request)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let err) = completion { self?.error = err }
                },
                receiveValue: { [weak self] post in
                    self?.posts.insert(post, at: 0)
                }
            )
            .store(in: &cancellables)
    }
    
    // === Delete post ===
    func deletePost(id: Int) {
        service.deletePost(id: id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let err) = completion { self?.error = err }
                },
                receiveValue: { [weak self] in
                    self?.posts.removeAll { $0.id == id }
                }
            )
            .store(in: &cancellables)
    }
    
    // === COMBINE STRENGTH: Debounced Search ===
    // Combine shines khi cần reactive pipelines!
    
    private func setupSearchDebounce() {
        $searchQuery                              // Publisher từ @Published
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            // ↑ Chờ 400ms không gõ mới emit — built-in debounce!
            .removeDuplicates()
            // ↑ Bỏ qua nếu query KHÔNG thay đổi
            .map { query -> AnyPublisher<[Post], Never> in
                guard !query.isEmpty else {
                    // Query rỗng → trả về tất cả
                    return Just(self.posts).eraseToAnyPublisher()
                }
                
                // Filter local
                let filtered = self.posts.filter {
                    $0.title.localizedCaseInsensitiveContains(query)
                }
                return Just(filtered).eraseToAnyPublisher()
            }
            .switchToLatest()
            // ↑ Cancel search CŨ khi có query MỚI — tránh race condition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filtered in
                // Update filtered results
                // (Trong production: thường dùng biến filteredPosts riêng)
                _ = filtered
            }
            .store(in: &cancellables)
    }
    
    // === COMBINE STRENGTH: Parallel requests + merge ===
    func loadDashboard(userId: Int) {
        isLoading = true
        
        // CombineLatest: chờ CẢ HAI publishers emit rồi combine
        Publishers.CombineLatest(
            service.getPosts(page: 1),
            service.getUserPosts(userId: userId)
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion { self?.error = err }
            },
            receiveValue: { [weak self] allPosts, userPosts in
                self?.posts = allPosts
                // Dùng userPosts cho section khác...
            }
        )
        .store(in: &cancellables)
    }
    
    // === COMBINE STRENGTH: Retry with delay ===
    func loadWithRetry() {
        isLoading = true
        error = nil
        
        service.getPosts(page: 1)
            .retry(3)
            // ↑ Built-in retry 3 lần — 1 dòng code!
            // (Không có exponential backoff — cần custom cho production)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let err) = completion { self?.error = err }
                },
                receiveValue: { [weak self] posts in
                    self?.posts = posts
                }
            )
            .store(in: &cancellables)
    }
    
    // Retry với exponential backoff (custom):
    func loadWithExponentialRetry() {
        isLoading = true
        
        service.getPosts(page: 1)
            .catch { error -> AnyPublisher<[Post], APIError> in
                guard error.isRetryable else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
                // Retry after 2 seconds
                return self.service.getPosts(page: 1)
                    .delay(for: .seconds(2), scheduler: DispatchQueue.global())
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let err) = completion { self?.error = err }
                },
                receiveValue: { [weak self] posts in
                    self?.posts = posts
                }
            )
            .store(in: &cancellables)
    }
}
