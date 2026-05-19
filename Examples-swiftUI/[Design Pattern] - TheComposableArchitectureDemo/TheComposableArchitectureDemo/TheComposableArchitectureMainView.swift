import ComposableArchitecture
import SwiftUI

struct TheComposableArchitectureMainView: View {
    // Khởi tạo Store cho màn hình Home (PhotosList)
    // Dùng 'let' vì Store trong TCA (phiên bản mới) tự động quản lý vòng đời của nó rất tốt
    let photosStore = Store(initialState: PhotosFeature.State()) {
        PhotosFeature()
    }
    
    let topicsStore = Store(initialState: TopicsFeature.State()) {
        TopicsFeature()
    }
    
    let searchStore = Store(initialState: SearchFeature.State()) {
        SearchFeature()
    }
    
    var body: some View {
        TabView {
            // Tab 1
            Tab("Home", systemImage: "house") {
                // Truyền store vào giao diện mới
                PhotosListView(store: photosStore)
            }
            
            // Tab 2
            Tab("Topic", systemImage: "scribble") {
                TopicsListView(store: topicsStore)
            }
            
            // Tab 3
            Tab(role: .search) {
                SearchView(store: searchStore)
            }
        }
    }
}

#Preview {
    TheComposableArchitectureMainView()
}
