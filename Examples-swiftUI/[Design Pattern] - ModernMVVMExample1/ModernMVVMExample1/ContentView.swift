import SwiftUI
import Combine

// MARK: - 1. MODEL
// Nơi định nghĩa cấu trúc dữ liệu
struct User: Identifiable, Codable {
    let id: Int
    let name: String
    let email: String
}

// MARK: - 2. VIEWMODEL
// Nơi chứa State và Operations (Logic)
// @MainActor đảm bảo mọi thay đổi State đều tự động diễn ra trên luồng chính (Main Thread), an toàn tuyệt đối cho UI.
@MainActor
class UserViewModel: ObservableObject {
    
    // 👉 ĐÂY LÀ "PROPERTY WRAPPER OBSERVATION CHO STATE"
    // Khi 3 biến này thay đổi, View sẽ tự động cập nhật.
    @Published var users: [User] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // 👉 ĐÂY LÀ "ASYNC/AWAIT CHO OPERATIONS"
    func fetchUsers() async {
        // Cập nhật state trước khi gọi mạng
        isLoading = true
        errorMessage = nil
        
        do {
            // Giả lập mạng chậm 1 chút để thấy rõ UI loading (tùy chọn)
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Lấy dữ liệu bất đồng bộ với async/await
            let url = URL(string: "https://jsonplaceholder.typicode.com/users")!
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Giải mã dữ liệu và cập nhật State
            self.users = try JSONDecoder().decode([User].self, from: data)
            
        } catch {
            // Xử lý lỗi gọn gàng
            self.errorMessage = "Không thể tải dữ liệu: \(error.localizedDescription)"
        }
        
        // Kết thúc operation
        isLoading = false
    }
}

// MARK: - 3. VIEW
// Nơi vẽ giao diện dựa trên State của ViewModel
struct ModernMVVMView: View {
    
    // Khởi tạo ViewModel và giữ nó sống sót trong suốt vòng đời của View
    @StateObject private var viewModel = UserViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                // UI tự động phản ứng dựa vào State của ViewModel
                if viewModel.isLoading {
                    ProgressView("Đang tải danh sách...")
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Text(error).foregroundColor(.red)
                        Button("Thử lại") {
                            // Gọi lại operation nếu lỗi
                            Task { await viewModel.fetchUsers() }
                        }
                        .buttonStyle(.bordered)
                        .padding()
                    }
                } else {
                    List(viewModel.users) { user in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.name).font(.headline)
                            Text(user.email).font(.subheadline).foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Danh sách User")
            // 👉 .task là công cụ kết nối hoàn hảo giữa View và hàm async của ViewModel
            .task {
                // Chỉ tải nếu danh sách rỗng để tránh gọi API nhiều lần khi chuyển màn hình
                if viewModel.users.isEmpty {
                    await viewModel.fetchUsers()
                }
            }
        }
    }
}

#Preview {
    ModernMVVMView()
}
