import SwiftUI

struct CleanArchitectureMainView: View {
    @Environment(\.viewModelFactory) private var factory
    @Environment(\.injected) private var diContainer

    // Local @State mirror của appState.routing.selectedTab
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
        // Người dùng chọn tab → ghi vào AppState (single source of truth)
        .onChange(of: selectedTab) { _, newTab in
            diContainer.appState[\.routing.selectedTab] = newTab
        }
        // AppState thay đổi từ bên ngoài (vd: deep link) → cập nhật local @State
        .onReceive(diContainer.appState.updates(for: \.routing.selectedTab)) { tab in
            selectedTab = tab
        }
    }
}

#Preview {
    CleanArchitectureMainView()
}
