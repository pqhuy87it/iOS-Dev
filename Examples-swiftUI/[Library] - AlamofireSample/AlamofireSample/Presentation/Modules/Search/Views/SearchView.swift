import SwiftUI

struct SearchView: View {
    @Environment(\.injected) private var injected: DIContainer

    @State private var searchText = ""
    @State private var searchHistory: [String] = []
    @State private var resultsState: Loadable<[Photo]> = .notRequested
    @State private var page = 1
    @State private var isLoadingMore = false
    @State private var canLoadMore = false
    @State private var currentQuery = ""
    
    private let perPage = 30
    private let columnCount = 2
    private let spacing: CGFloat = 16

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search Photos")
                .searchable(text: $searchText, prompt: "Enter keyword (e.g.: Nature, Cats...)")
                .onChange(of: searchText) { _, newValue in
                    if newValue.isEmpty { clearSearch() }
                }
                .onSubmit(of: .search) {
                    performSearch(searchText)
                }
                .task {
                    await loadHistory()
                }
                .navigationDestination(for: Photo.self) { photo in
                    PhotoDetailView(photo: photo)
                }
        }
    }

    @ViewBuilder private var content: some View {
        switch resultsState {
        case .notRequested:
            historyView()
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
            ErrorView(error: error) { performSearch(currentQuery) }
        }
    }

    // MARK: - Data loading

    private func loadHistory() async {
        if let history = try? await injected.interactors.search.getSearchHistory() {
            searchHistory = history
        }
    }

    private func performSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        searchText = trimmed
        currentQuery = trimmed
        page = 1
        canLoadMore = false
        resultsState = .isLoading(last: resultsState.value, cancelBag: CancelBag())

        Task {
            try? await injected.interactors.search.saveSearchKeyword(trimmed)
            await loadHistory()

            do {
                let result = try await injected.interactors.search.searchPhotos(query: trimmed, page: 1, perPage: perPage)
                resultsState = .loaded(result.results)
                canLoadMore = page < result.totalPages
                page = 2
            } catch {
                resultsState = .failed(error)
            }
        }
    }

    private func loadMore() async {
        guard case let .loaded(current) = resultsState,
              !isLoadingMore, canLoadMore, !currentQuery.isEmpty else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let result = try await injected.interactors.search.searchPhotos(query: currentQuery, page: page, perPage: perPage)
            resultsState = .loaded(current + result.results)
            canLoadMore = page < result.totalPages
            page += 1
        } catch {
            canLoadMore = false
        }
    }

    private func clearSearch() {
        resultsState = .notRequested
        canLoadMore = false
        currentQuery = ""
        Task { await loadHistory() }
    }
}

// MARK: - Subviews

private extension SearchView {
    @ViewBuilder
    func historyView() -> some View {
        if searchHistory.isEmpty {
            placeholderView(message: "Search for something!", icon: "magnifyingglass")
        } else {
            List {
                Section(header: Text("Search History")) {
                    ForEach(searchHistory, id: \.self) { keyword in
                        Button(action: {
                            performSearch(keyword)
                        }) {
                            HStack {
                                Image(systemName: "clock").foregroundColor(.gray)
                                Text(keyword).foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "magnifyingglass").foregroundColor(.blue).font(.caption)
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
            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<columnCount, id: \.self) { col in
                    LazyVStack(spacing: spacing) {
                        ForEach(masonryColumns(for: photos)[col]) { photo in
                            NavigationLink(value: photo) {
                                PhotoCell(photo: photo)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                // When the last cell appears -> load the next page
                                if photo.id == photos.last?.id {
                                    Task { await loadMore() }
                                }
                            }
                        }
                    }
                }
            }
            .padding()

            if isLoadingMore {
                ProgressView()
                    .padding(.vertical, 16)
            }
        }
    }

    /// Divide the image into columns using the Masonry algorithm (the lowest column receives the next image).
    func masonryColumns(for photos: [Photo]) -> [[Photo]] {
        var columns = Array(repeating: [Photo](), count: columnCount)
        var heights = Array(repeating: CGFloat(0), count: columnCount)

        for photo in photos {
            let shortest = heights.indices.min(by: { heights[$0] < heights[$1] })!
            columns[shortest].append(photo)
            heights[shortest] += CGFloat(photo.height) / CGFloat(photo.width)
        }

        return columns
    }

    func placeholderView(message: String, icon: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon).font(.system(size: 50)).foregroundColor(.gray)
            Text(message).font(.headline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
