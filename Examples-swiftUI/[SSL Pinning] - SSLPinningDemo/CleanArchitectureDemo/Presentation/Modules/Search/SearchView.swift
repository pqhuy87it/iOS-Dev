import SwiftUI

struct SearchView: View {
    
    @Environment(\.injected) private var injected: DIContainer
    
    // Search keyword state
    @State private var searchText: String = ""
    
    // Search result state (Use Loadable to manage UI)
    @State private var searchResultState: Loadable<[Photo]> = .notRequested
    
    // Add State to contain history
    @State private var searchHistory: [String] = []
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search Photos")
            // Integrate search bar into Navigation Bar
                .searchable(text: $searchText, prompt: "Enter keyword (e.g.: Nature, Cats...)")
            // Perform search when user taps "Search" on keyboard
                .onSubmit(of: .search) {
                    performSearch(with: searchText)
                }
                .onChange(of: searchText) { newValue in
                    if newValue.isEmpty {
                        searchResultState = .notRequested
                        loadSearchHistory() // Reload history to get latest information
                    }
                }
                .onAppear {
                    loadSearchHistory()
                }
                .navigationDestination(for: Photo.self) { photo in
                    PhotoDetailView(photo: photo)
                }
        }
    }
    
    @ViewBuilder private var content: some View {
        // If user clears search bar, show History again
        if searchResultState == .notRequested {
            historyView()
        } else {
            switch searchResultState {
            case .notRequested:
                EmptyView() // Handled above
            case .isLoading:
                ProgressView("Searching...")
                    .progressViewStyle(CircularProgressViewStyle())
            case let .loaded(photos):
                if photos.isEmpty {
                    placeholderView(message: "No results found", icon: "exclamationmark.triangle")
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
    // History display interface
    @ViewBuilder
    func historyView() -> some View {
        if searchHistory.isEmpty {
            placeholderView(message: "Search for something!", icon: "magnifyingglass")
        } else {
            List {
                Section(header: Text("Search History")) {
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
    
    
    func resultsGridView(_ photos: [Photo]) -> some View {
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
    
    // Load history logic
    func loadSearchHistory() {
        Task {
            if let history = try? await injected.interactors.photos.getSearchHistory() {
                self.searchHistory = history
            }
        }
    }
    
    // Logic to perform search & save DB
    func performSearch(with query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        // 1. Save keyword to SwiftData in background
        Task {
            try? await injected.interactors.photos.saveSearchKeyword(query)
            loadSearchHistory() // Refresh history array immediately
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