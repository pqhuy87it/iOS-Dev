import SwiftUI

struct PhotosListView: View {
    @Environment(\.viewModelFactory) private var factory
    @StateObject private var viewModel: PhotosViewModel
    @State private var navigationPath = NavigationPath()

    private let columnCount = 2
    private let spacing: CGFloat = 16

    init(viewModel: PhotosViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .navigationTitle("Unsplash Photos")
                .navigationDestination(for: Photo.self) { photo in
                    PhotoDetailView(viewModel: factory.makePhotoDetailViewModel(photo: photo))
                }
        }
    }
    
    @ViewBuilder private var content: some View {
        switch viewModel.state.photos {
        case .notRequested:
            Color.clear.onAppear {
                viewModel.send(.loadPhotos)
            }
        case .isLoading:
            ProgressView("Loading photos...")
                .progressViewStyle(CircularProgressViewStyle())
        case let .loaded(photos):
            loadedView(photos)
        case let .failed(error):
            ErrorView(error: error) { viewModel.send(.refreshPhotos) }
        }
    }
    
    private func loadedView(_ photos: [Photo]) -> some View {
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
                                // Khi ô cuối cùng xuất hiện -> tải thêm trang kế tiếp
                                if photo.id == photos.last?.id {
                                    viewModel.send(.loadMore)
                                }
                            }
                        }
                    }
                }
            }
            .padding()

            if viewModel.state.isLoadingMore {
                ProgressView()
                    .padding(.vertical, 16)
            }
        }
        .refreshable {
            viewModel.send(.refreshPhotos)
        }
    }
    
    // MARK: - Helper
    
    /// Divide the image into columns using the Masonry algorithm (the lowest column receives the next image).
    private func masonryColumns(for photos: [Photo]) -> [[Photo]] {
        var columns = Array(repeating: [Photo](), count: columnCount)
        var heights = Array(repeating: CGFloat(0), count: columnCount)

        for photo in photos {
            let shortest = heights.indices.min(by: { heights[$0] < heights[$1] })!
            columns[shortest].append(photo)
            heights[shortest] += CGFloat(photo.height) / CGFloat(photo.width)
        }

        return columns
    }
    
}
