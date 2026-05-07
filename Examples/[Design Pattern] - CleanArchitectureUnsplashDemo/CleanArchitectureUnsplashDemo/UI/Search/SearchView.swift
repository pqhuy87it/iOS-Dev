import SwiftUI

struct SearchView: View {
    
    @Environment(\.injected) private var injected: DIContainer
    
    // Trạng thái từ khóa tìm kiếm
    @State private var searchText: String = ""
    
    // Trạng thái kết quả tìm kiếm (Dùng Loadable để quản lý UI)
    @State private var searchResultState: Loadable<[ApiModel.Photo]> = .notRequested
    
    // Thêm State để chứa lịch sử
    @State private var searchHistory: [String] = []
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Tìm kiếm ảnh")
            // Tích hợp thanh tìm kiếm vào Navigation Bar
                .searchable(text: $searchText, prompt: "Nhập từ khóa (ví dụ: Nature, Cats...)")
            // Thực hiện tìm kiếm khi người dùng nhấn "Search" trên bàn phím
                .onSubmit(of: .search) {
                    performSearch(with: searchText)
                }
                .onChange(of: searchText) { newValue in
                    if newValue.isEmpty {
                        searchResultState = .notRequested
                        loadSearchHistory() // Load lại lịch sử để lấy thông tin mới nhất
                    }
                }
                .onAppear {
                    loadSearchHistory()
                }
                .navigationDestination(for: ApiModel.Photo.self) { photo in
                    PhotoDetailView(photo: photo)
                }
        }
    }
    
    @ViewBuilder private var content: some View {
        // Nếu user xoá thanh search, hiện lại Lịch sử
        if searchResultState == .notRequested {
            historyView()
        } else {
            switch searchResultState {
            case .notRequested:
                EmptyView() // Đã xử lý ở trên
            case .isLoading:
                ProgressView("Đang tìm kiếm...")
                    .progressViewStyle(CircularProgressViewStyle())
            case let .loaded(photos):
                if photos.isEmpty {
                    placeholderView(message: "Không tìm thấy kết quả", icon: "exclamationmark.triangle")
                } else {
                    resultsGridView(photos)
                }
            case let .failed(error):
                ErrorView(error: error) { performSearch(with: searchText) }
            }
        }
    }
}

// MARK: - Subviews & Logic
private extension SearchView {
    // Giao diện hiển thị lịch sử
    @ViewBuilder
    func historyView() -> some View {
        if searchHistory.isEmpty {
            placeholderView(message: "Hãy tìm kiếm gì đó!", icon: "magnifyingglass")
        } else {
            List {
                Section(header: Text("Lịch sử tìm kiếm")) {
                    ForEach(searchHistory, id: \.self) { keyword in
                        Button(action: {
                            searchText = keyword
                            performSearch(with: keyword)
                        }) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.gray)
                                Text(keyword)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
    }
    
    
    func resultsGridView(_ photos: [ApiModel.Photo]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(photos) { photo in
                    NavigationLink(value: photo) {
                        PhotoCell(photo: photo)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
    
    func placeholderView(message: String, icon: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Logic tải lịch sử
    func loadSearchHistory() {
        Task {
            if let history = try? await injected.interactors.photos.getSearchHistory() {
                self.searchHistory = history
            }
        }
    }
    
    // Logic thực hiện tìm kiếm & lưu DB
    func performSearch(with query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        // 1. Lưu keyword vào SwiftData chạy ngầm
        Task {
            try? await injected.interactors.photos.saveSearchKeyword(query)
            loadSearchHistory() // Làm mới mảng lịch sử ngay
        }
        
        // 2. Fetch API
        $searchResultState.load {
            let result = try await injected.interactors.photos.searchPhotos(query: query, page: 1, perPage: 30)
            return result.results
        }
    }
}

#Preview {
    SearchView()
}
