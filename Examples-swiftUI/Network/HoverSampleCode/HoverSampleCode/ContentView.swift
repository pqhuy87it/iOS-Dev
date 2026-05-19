import SwiftUI
import Combine
// Nếu thư viện Hover được build thành một module riêng thì bạn cần thêm: import Hover
// Nếu bạn để chung các file Hover trong cùng Project thì không cần import.

// MARK: - 1. Model (Dữ liệu trả về từ API)
// Chúng ta sử dụng API miễn phí từ: https://jsonplaceholder.typicode.com/users
struct User: Codable, Identifiable {
    let id: Int
    let name: String
    let email: String
    let phone: String
}

// MARK: - 2. Network Target (Định nghĩa API theo chuẩn của Hover)
// Hover yêu cầu tạo một enum tuân thủ protocol `NetworkTarget`
enum UserTarget: NetworkTarget {
    case fetchUsers
    
    var baseURL: URL {
        return URL(string: "https://jsonplaceholder.typicode.com")!
    }
    
    var path: String {
        switch self {
        case .fetchUsers:
            return "users"
        }
    }
    
    var methodType: MethodType {
        return .get
    }
    
    var workType: WorkType {
        return .requestPlain // Không có body parameters
    }
    
    var providerType: AuthProviderType {
        return .none // Không cần Token
    }
    
    var contentType: ContentType? {
        return .applicationJson
    }
    
    var headers: [String : String]? {
        return nil
    }
}

// MARK: - 3. ViewModel (Xử lý logic gọi API bằng Hover)
@MainActor
class UserViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // Khởi tạo đối tượng Hover
    private let hover = Hover()
    
    init() {
        // Bật tính năng Debug của Hover để xem log chi tiết trên Console
        Hover.prefference.isDebuggingEnabled = true
    }
    
    // Sử dụng tính năng Async/Await cực kỳ hiện đại của Hover (iOS 15+)
    func fetchUsers() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Cú pháp gọi API siêu ngắn gọn của Hover
            let fetchedUsers = try await hover.request(
                with: UserTarget.fetchUsers,
                class: [User].self
            )
            
            self.users = fetchedUsers
            self.isLoading = false
            
        } catch let error as ProviderError {
            // Hover có enum ProviderError xử lý lỗi rất chi tiết
            self.errorMessage = error.errorDescription
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
}

// MARK: - 4. Giao diện (SwiftUI View)
struct ContentView: View {
    @StateObject private var viewModel = UserViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    // Đang tải dữ liệu
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Hover đang tải dữ liệu...")
                            .foregroundColor(.gray)
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    // Có lỗi xảy ra
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text("Lỗi API:")
                            .font(.headline)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Thử lại") {
                            Task {
                                await viewModel.fetchUsers()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                    .padding()
                } else {
                    // Hiển thị danh sách thành công
                    List(viewModel.users) { user in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(user.name)
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.gray)
                                Text(user.email)
                                    .font(.subheadline)
                            }
                            
                            HStack {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.gray)
                                Text(user.phone)
                                    .font(.subheadline)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Hover Users")
        }
        // Gọi API ngay khi màn hình xuất hiện
        .task {
            // Đảm bảo chỉ gọi API 1 lần nếu danh sách trống
            if viewModel.users.isEmpty {
                await viewModel.fetchUsers()
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
