import SwiftUI

struct PhotosListView: View {
    
    // Inject DIContainer to call Interactor
    @Environment(\.injected) private var injected: DIContainer
    
    // Manage data load state
    @State private var photosState: Loadable<[Photo]> = .notRequested
    
    // Manage navigation
    @State private var navigationPath = NavigationPath()
    
    // Setup Grid with automatic flexible columns (min size 150pt)
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .navigationTitle("Unsplash Photos")
                // Register destination when clicking on 1 Photo
                .navigationDestination(for: Photo.self) { photo in
                    PhotoDetailView(photo: photo)
                }
        }
    }
    
    // MARK: - View Builder state branching
    @ViewBuilder private var content: some View {
        switch photosState {
        case .notRequested:
            defaultView()
        case .isLoading:
            loadingView()
        case let .loaded(photos):
            loadedView(photos)
        case let .failed(error):
            failedView(error)
        }
    }
}

// MARK: - Subviews & Side Effects
private extension PhotosListView {
    
    func defaultView() -> some View {
        Color.clear.onAppear {
            loadPhotos()
        }
    }
    
    func loadingView() -> some View {
        ProgressView("Loading photos...")
            .progressViewStyle(CircularProgressViewStyle())
    }
    
    func failedView(_ error: Error) -> some View {
        // Reuse ErrorView from old project
        ErrorView(error: error) {
            loadPhotos()
        }
    }
    
    func loadedView(_ photos: [Photo]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(photos) { photo in
                    NavigationLink(value: photo) {
                        PhotoCell(photo: photo)
                    }
                    .buttonStyle(.plain) // Remove blue effect of Link tag
                }
            }
            .padding()
        }
        .refreshable { // Pull down to reload
            loadPhotos()
        }
    }
    
    // API call function via Interactor
    private func loadPhotos() {
        $photosState.load {
            try await injected.interactors.photos.fetchPhotos(page: 1, perPage: 30)
        }
    }
}

// MARK: - Routing

extension PhotosListView {
    struct Routing: Equatable {
        var id: String?
    }
}