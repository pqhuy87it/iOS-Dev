import SwiftUI

struct PhotosListView: View {
    
    // Inject DIContainer để gọi Interactor
    @Environment(\.injected) private var injected: DIContainer
    
    // Quản lý trạng thái load dữ liệu
    @State private var photosState: Loadable<[ApiModel.Photo]> = .notRequested
    
    // Quản lý điều hướng
    @State private var navigationPath = NavigationPath()
    
    // Setup Grid chia cột tự động co giãn (kích thước min 150pt)
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .navigationTitle("Unsplash Photos")
                // Đăng ký đích đến khi bấm vào 1 Photo
                .navigationDestination(for: ApiModel.Photo.self) { photo in
                    PhotoDetailView(photo: photo)
                }
        }
    }
    
    // MARK: - View Builder phân luồng trạng thái
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
        ProgressView("Đang tải ảnh...")
            .progressViewStyle(CircularProgressViewStyle())
    }
    
    func failedView(_ error: Error) -> some View {
        // Tái sử dụng ErrorView từ project cũ
        ErrorView(error: error) {
            loadPhotos()
        }
    }
    
    func loadedView(_ photos: [ApiModel.Photo]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(photos) { photo in
                    NavigationLink(value: photo) {
                        PhotoCell(photo: photo)
                    }
                    .buttonStyle(.plain) // Bỏ hiệu ứng xanh của thẻ Link
                }
            }
            .padding()
        }
        .refreshable { // Kéo xuống để reload
            loadPhotos()
        }
    }
    
    // Hàm gọi API thông qua Interactor
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
