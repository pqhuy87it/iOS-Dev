import SwiftUI
import ComposableArchitecture

struct PhotosListView: View {
    // Nhận Store chứa State và Action
    let store: StoreOf<PhotosFeature>
    
    // Cấu hình Grid như cũ
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView("Loading photos...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if let error = store.errorMessage {
                    // Gọi lại Action nếu muốn Retry
                    ErrorView(error: NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: error])) {
                        store.send(.onAppear)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(store.photos) { photo in
                                NavigationLink(value: photo) {
                                    PhotoCell(photo: photo)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        store.send(.onAppear)
                    }
                }
            }
            .navigationTitle("Unsplash Photos")
            .onAppear {
                // Kích hoạt Action khi View xuất hiện
                if store.photos.isEmpty {
                    store.send(.onAppear)
                }
            }
        }
    }
}

// Cấu hình Preview cực kỳ đơn giản với State giả lập
#Preview {
    PhotosListView(
        store: Store(initialState: PhotosFeature.State(photos: [.mock])) {
            PhotosFeature()
        }
    )
}
