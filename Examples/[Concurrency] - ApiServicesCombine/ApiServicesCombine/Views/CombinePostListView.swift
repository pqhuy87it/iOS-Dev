import SwiftUI
import Combine

struct CombinePostListView: View {
    @StateObject private var vm = CombinePostListVM()
    // ↑ @StateObject cho ObservableObject (Combine VM)
    // Async VM dùng @State + @Observable
    
    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.posts.isEmpty {
                    ProgressView("Đang tải...")
                } else if let error = vm.error, vm.posts.isEmpty {
                    Text(error.errorDescription ?? "Error")
                } else {
                    List(vm.posts) { post in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.title).font(.headline)
                            Text(post.body).font(.caption).lineLimit(2)
                        }
                        .onAppear {
                            if post.id == vm.posts.last?.id { vm.loadMore() }
                        }
                        .swipeActions {
                            Button("Xoá", role: .destructive) { vm.deletePost(id: post.id) }
                        }
                    }
                    .searchable(text: $vm.searchQuery)
                    // ↑ searchQuery là @Published → tự trigger debounce pipeline
                }
            }
            .navigationTitle("Posts (Combine)")
        }
        .onAppear { vm.loadPosts() }
        // ⚠️ Combine VM: dùng .onAppear thay .task
        // Vì loadPosts() KHÔNG async — nó tạo subscription internally
    }
}
