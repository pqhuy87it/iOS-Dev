import SwiftUI
import ComposableArchitecture

struct PhotosListView: View {
    // Nhận Store chứa State và Action
    let store: StoreOf<PhotosFeature>
    
    private let columnCount = 2
    private let spacing: CGFloat = 12

    // Phân phối ảnh vào 2 cột: ảnh mới luôn điền vào cột có tổng chiều cao ngắn hơn
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

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView("Loading photos...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if let error = store.errorMessage {
                    ErrorView(error: NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: error])) {
                        store.send(.onAppear)
                    }
                } else {
                    ScrollView {
                        HStack(alignment: .top, spacing: spacing) {
                            ForEach(0..<columnCount, id: \.self) { col in
                                LazyVStack(spacing: spacing) {
                                    ForEach(masonryColumns(for: store.photos)[col]) { photo in
                                        NavigationLink(value: photo) {
                                            PhotoCell(photo: photo)
                                        }
                                        .buttonStyle(.plain)
                                        .onAppear {
                                            if photo.id == store.photos.last?.id {
                                                store.send(.loadMorePhotos)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()

                        if store.isLoadingMore {
                            ProgressView()
                                .padding(.vertical, 16)
                        }
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
