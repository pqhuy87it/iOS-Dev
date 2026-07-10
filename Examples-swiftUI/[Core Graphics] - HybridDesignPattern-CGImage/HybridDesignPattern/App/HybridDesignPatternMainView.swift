import SwiftUI

struct HybridDesignPatternMainView: View {
    @Environment(\.viewModelFactory) private var factory
    @Environment(\.injected) private var diContainer

    @State private var selectedTab: AppState.AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: AppState.AppTab.home) {
                PhotosListView(viewModel: factory.makePhotosViewModel())
            }

            Tab("Topic", systemImage: "scribble", value: AppState.AppTab.topics) {
                TopicsListView(viewModel: factory.makeTopicsViewModel())
            }

            Tab("Search", systemImage: "magnifyingglass", value: AppState.AppTab.search, role: .search) {
                SearchView(viewModel: factory.makeSearchViewModel())
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            diContainer.appState[\.routing.selectedTab] = newTab
        }
        .onReceive(diContainer.appState.updates(for: \.routing.selectedTab)) { tab in
            selectedTab = tab
        }
    }
}

#Preview {
    HybridDesignPatternMainView()
}
