import SwiftUI

struct PhotosListView: View {
    
    // Sử dụng @StateObject cho ViewModel
    @StateObject private var viewModel: PhotosViewModel
    @State private var navigationPath = NavigationPath()
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    init(viewModel: PhotosViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .navigationTitle("Unsplash Photos")
                .navigationDestination(for: Photo.self) { photo in
                    PhotoDetailView(photo: photo) //
                }
        }
    }
    
    @ViewBuilder private var content: some View {
        // Truy cập State trực tiếp từ ViewModel
        switch viewModel.state.photos {
        case .notRequested:
            Color.clear.onAppear {
                viewModel.send(.loadPhotos) // Bắn Action thay vì gọi hàm
            }
        case .isLoading:
            ProgressView("Loading photos...")
                .progressViewStyle(CircularProgressViewStyle()) //
        case let .loaded(photos):
            loadedView(photos)
        case let .failed(error):
            // Truyền action vào ErrorView để retry
            ErrorView(error: error) { viewModel.send(.refreshPhotos) } //
        }
    }
    
    private func loadedView(_ photos: [Photo]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(photos) { photo in
                    NavigationLink(value: photo) {
                        PhotoCell(photo: photo) //
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .refreshable {
            viewModel.send(.refreshPhotos) // Bắn Action khi Pull-to-refresh
        }
    }
}
