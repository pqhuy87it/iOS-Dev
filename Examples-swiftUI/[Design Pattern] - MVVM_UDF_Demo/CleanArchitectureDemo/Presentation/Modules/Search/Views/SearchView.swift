import SwiftUI

struct SearchView: View {
    
    @Environment(\.viewModelFactory) private var factory
    @StateObject private var viewModel: SearchViewModel
    
    // Cầu nối Binding UDF cho SwiftUI Text Field
    private var searchTextBinding: Binding<String> {
        Binding(
            get: { viewModel.state.searchText },
            set: { viewModel.send(.updateSearchText($0)) }
        )
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    init(viewModel: @autoclosure @escaping () -> SearchViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search Photos")
                // Truyền custom Binding vào searchable
                .searchable(text: searchTextBinding, prompt: "Enter keyword (e.g.: Nature, Cats...)")
                .onSubmit(of: .search) {
                    viewModel.send(.performSearch(viewModel.state.searchText))
                }
                .onAppear {
                    viewModel.send(.loadHistory)
                }
                .navigationDestination(for: Photo.self) { photo in
                    PhotoDetailView(photo: photo) //
                }
        }
    }
    
    @ViewBuilder private var content: some View {
        if viewModel.state.searchResult == .notRequested {
            historyView()
        } else {
            switch viewModel.state.searchResult {
            case .notRequested:
                EmptyView()
            case .isLoading:
                ProgressView("Searching...")
                    .progressViewStyle(CircularProgressViewStyle()) //
            case let .loaded(photos):
                if photos.isEmpty {
                    placeholderView(message: "No results found", icon: "exclamationmark.triangle") //
                } else {
                    resultsGridView(photos)
                }
            case let .failed(error):
                ErrorView(error: error) {
                    viewModel.send(.performSearch(viewModel.state.searchText))
                }
            }
        }
    }
}

// MARK: - Subviews
private extension SearchView {
    @ViewBuilder
    func historyView() -> some View {
        if viewModel.state.searchHistory.isEmpty {
            placeholderView(message: "Search for something!", icon: "magnifyingglass") //
        } else {
            List {
                Section(header: Text("Search History")) {
                    ForEach(viewModel.state.searchHistory, id: \.self) { keyword in
                        Button(action: {
                            // Cập nhật text và tìm kiếm ngay khi click vào lịch sử
                            viewModel.send(.updateSearchText(keyword))
                            viewModel.send(.performSearch(keyword))
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
            .listStyle(InsetGroupedListStyle()) //
        }
    }
    
    func resultsGridView(_ photos: [Photo]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(photos) { photo in
                    NavigationLink(value: photo) {
                        // Nhúng ImageViewModel từ factory qua PhotoCell
                        PhotoCell(photo: photo) //
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding() //
        }
    }
    
    func placeholderView(message: String, icon: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon).font(.system(size: 50)).foregroundColor(.gray)
            Text(message).font(.headline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) //
    }
}
