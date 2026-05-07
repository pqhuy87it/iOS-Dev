import SwiftUI

struct CleanArchitectureMainView: View {
    var body: some View {
        TabView {
            // Tab 1
            Tab("Home", systemImage: "house") {
                PhotosListView()
            }
            
            // Tab 2
            Tab("Topic", systemImage: "scribble") {
                TopicsListView()
            }
            
            // Tab 3
            Tab(role: .search) {
                SearchView()
            }
        }
    }
}

#Preview {
    CleanArchitectureMainView()
}
