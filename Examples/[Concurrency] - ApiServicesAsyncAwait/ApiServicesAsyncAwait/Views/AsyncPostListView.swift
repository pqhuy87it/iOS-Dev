import SwiftUI

// ╔══════════════════════════════════════════════════════════╗
// ║  A4. VIEW — ASYNC/AWAIT                                   ║
// ╚══════════════════════════════════════════════════════════╝

struct AsyncPostListView: View {
    @State private var vm = AsyncPostListVM()
    @State private var showCreate = false
    
    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.posts.isEmpty {
                    ProgressView("Đang tải...")
                } else if let error = vm.error, vm.posts.isEmpty {
                    errorView(error)
                } else {
                    postList
                }
            }
            .navigationTitle("Posts (Async)")
            .toolbar {
                Button { showCreate = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await vm.loadPosts() }
        .refreshable { await vm.loadPosts() }
        .sheet(isPresented: $showCreate) {
            CreatePostSheet { title, body in
                try await vm.createPost(title: title, body: body)
            }
        }
    }
    
    private var postList: some View {
        List {
            ForEach(vm.posts) { post in
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.title).font(.headline)
                    Text(post.body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                .onAppear {
                    if post.id == vm.posts.last?.id {
                        Task { await vm.loadMore() }
                    }
                }
                .swipeActions {
                    Button("Xoá", role: .destructive) {
                        Task { try? await vm.deletePost(id: post.id) }
                    }
                }
            }
            
            if vm.isLoadingMore {
                ProgressView().frame(maxWidth: .infinity).listRowSeparator(.hidden)
            }
        }
    }
    
    private func errorView(_ error: APIError) -> some View {
        ContentUnavailableView {
            Label("Lỗi", systemImage: "wifi.exclamationmark")
        } description: {
            Text(error.errorDescription ?? "")
        } actions: {
            if error.isRetryable {
                Button("Thử lại") { Task { await vm.loadWithRetry() } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
