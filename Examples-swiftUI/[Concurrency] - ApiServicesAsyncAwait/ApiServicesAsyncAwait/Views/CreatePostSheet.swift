import SwiftUI
import Foundation

// ╔══════════════════════════════════════════════════════════╗
// ║  SHARED: Create Post Sheet                                ║
// ╚══════════════════════════════════════════════════════════╝

struct CreatePostSheet: View {
    let onCreate: (String, String) async throws -> Post
    
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var bodyStr = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Tiêu đề", text: $title)
                TextField("Nội dung", text: $bodyStr, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle("Tạo bài viết")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tạo") {
                        isLoading = true
                        Task {
                            _ = try? await onCreate(title, bodyStr)
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty || isLoading)
                }
            }
        }
    }
}
