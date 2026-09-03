import SwiftUI

struct PhotosListView: View {
    @Environment(\.injected) private var injected: DIContainer
    
    @State private var photosState: Loadable<[Photo]> = .notRequested
    @State private var navigationPath = NavigationPath()
    @State private var page = 1
    @State private var isLoadingMore = false
    @State private var canLoadMore = true
    
    private let perPage = 30
    private let columnCount = 2
    private let spacing: CGFloat = 16

    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .navigationTitle("Unsplash Photos")
                .navigationDestination(for: Photo.self) { photo in
                    PhotoDetailView(photo: photo)
                }
        }
    }

    @ViewBuilder private var content: some View {
        switch photosState {
        case .notRequested:
            Color.clear.onAppear { loadPhotos() }
        case .isLoading:
            ProgressView("Loading photos...")
                .progressViewStyle(CircularProgressViewStyle())
        case let .loaded(photos):
            loadedView(photos)
        case let .failed(error):
            ErrorView(error: error) { loadPhotos() }
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
                                if photo.id == photos.last?.id {
                                    Task { await loadMore(currentPhotos: photos) }
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
        .refreshable {
            loadPhotos()
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

    // MARK: - Data loading

    // Call Interactor directly via DIContainer
    private func loadPhotos() {
        page = 1
        canLoadMore = true
        $photosState.load {
            try await injected.interactors.photos.fetchPhotos(page: 1, perPage: perPage)
        }
    }

    private func loadMore(currentPhotos photos: [Photo]) async {
        guard !isLoadingMore, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let next = try await injected.interactors.photos.fetchPhotos(page: page + 1, perPage: perPage)
            page += 1
            canLoadMore = next.count == perPage
            photosState = .loaded(photos + next)
        } catch {
            canLoadMore = false
        }
    }
}
