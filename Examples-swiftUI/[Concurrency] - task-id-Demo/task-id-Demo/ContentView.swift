import SwiftUI

// MARK: - 1. Model
struct Article: Identifiable, Hashable {
    let id: String
    let title: String
}

// MARK: - 2. Màn hình chi tiết bài viết (Destination)
struct ArticleView: View {
    let article: Article
    
    var body: some View {
        // 👉 Debug: In ra console khi View NÀY bị re-render
        let _ = Self._printChanges()
        VStack(spacing: 30) {
            Text("Đang xem: \(article.title)")
                .font(.largeTitle)
                .bold()
            
            VStack(spacing: 16) {
                Text("Push tiếp để test Stack:")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                // Nút để push sang bài B, C... từ bài hiện tại
                ForEach(["A", "B", "C"], id: \.self) { nextId in
                    if nextId != article.id {
                        NavigationLink(value: Article(id: nextId, title: "Bài viết \(nextId)")) {
                            Text("Push sang Bài \(nextId)")
                                .frame(width: 200)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .navigationTitle("Bài \(article.id)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear() {
            print("[.onAppear] on Article: \(article.id)")
        }
        .onDisappear() {
            print("[.onDisappear] on Article: \(article.id)")
        }
        .task {
            print("▶️ [.task] START - Bắt đầu fetch data cho Bài \(article.id)")
            
            do {
                // Giả lập một task chạy rất lâu (100 giây) để task không bị tự kết thúc
                try await Task.sleep(nanoseconds: 100_000_000_000)
                print("✅ [.task] DONE - Hoàn thành data cho Bài \(article.id)")
            } catch {
                // Khi View bị Pop khỏi NavigationStack, Task sẽ bị throw error (CancellationError)
                print("⏹️ [.task] CANCELLED - Đã huỷ task của Bài \(article.id)")
            }
        }
    }
}

// MARK: - 3. Màn hình chính (Home)
struct NavigationTaskTestView: View {
    let articles = [
        Article(id: "A", title: "Bài viết A"),
        Article(id: "B", title: "Bài viết B"),
        Article(id: "C", title: "Bài viết C")
    ]
    
    var body: some View {
        NavigationStack {
            List(articles) { article in
                NavigationLink(value: article) {
                    Text(article.title)
                        .font(.title3)
                        .padding(.vertical, 8)
                }
            }
            .navigationTitle("Trang chủ")
            .navigationDestination(for: Article.self) { article in
                ArticleView(article: article)
            }
        }
    }
}

#Preview {
    NavigationTaskTestView()
}
