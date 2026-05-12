import SwiftUI

struct CleanArchitectureMainView: View {
    @Environment(\.viewModelFactory) private var factory

    var body: some View {
        TabView {
            // Tab 1
            Tab("Home", systemImage: "house") {
                PhotosListView(viewModel: factory.makePhotosViewModel())
            }

            // Tab 2
            Tab("Topic", systemImage: "scribble") {
                TopicsListView(viewModel: factory.makeTopicsViewModel())
            }

            // Tab 3
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                SearchView(viewModel: factory.makeSearchViewModel())
            }
        }
    }
}

#Preview {
    CleanArchitectureMainView()
}
