import SwiftUI

// MARK: - View Con (Nơi chứa .task)
struct ArticleDetailView: View {
    let articleID: Int
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Đang xem bài viết số:")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("\(articleID)")
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
        
        // 1. Dùng .task không có id
        .task {
            // Chỉ chạy DUY NHẤT một lần khi ArticleDetailView xuất hiện lần đầu trên màn hình
            print("🔴 [.task trơn] Bắt đầu fetch data cho Article: \(articleID)")
        }
        
        // 2. Dùng .task có id
        .task(id: articleID) {
            // Chạy khi xuất hiện lần đầu, VÀ chạy lại mỗi khi articleID thay đổi
            print("🟢 [.task(id:)] Bắt đầu fetch data cho Article: \(articleID)")
        }
    }
}

// MARK: - View Cha (Nơi thay đổi dữ liệu)
struct TaskTestView: View {
    @State private var currentArticleID: Int = 1
    
    var body: some View {
        VStack(spacing: 40) {
            // Truyền property thay đổi liên tục vào View con
            ArticleDetailView(articleID: currentArticleID)
            
            Button(action: {
                currentArticleID += 1
            }) {
                Text("Chuyển sang bài viết \(currentArticleID + 1)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            
            Text("Mở Console (Log) để xem sự khác biệt!")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    TaskTestView()
}
