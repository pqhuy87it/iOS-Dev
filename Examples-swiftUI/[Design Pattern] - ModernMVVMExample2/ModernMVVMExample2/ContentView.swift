import SwiftUI
import Combine

// MARK: - VIEW MODEL
@MainActor
class RegistrationViewModel: ObservableObject {
    
    // 1. INPUTS (Từ View gửi vào)
    @Published var username: String = ""
    @Published var isAgreedToTerms: Bool = false
    
    // 2. OUTPUTS (View lắng nghe để hiển thị)
    @Published var usernameMessage: String = "Vui lòng nhập tên đăng nhập."
    @Published var isValidUsername: Bool = false
    @Published var isRegisterButtonEnabled: Bool = false
    @Published var isLoading: Bool = false
    
    // Nơi lưu trữ các pipeline của Combine
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupPipelines()
    }
    
    private func setupPipelines() {
        
        // --- PIPELINE 1: Debounce cho ô nhập Username ---
        $username
            .debounce(for: .seconds(0.8), scheduler: RunLoop.main) // Chờ người dùng ngừng gõ 0.8s
            .removeDuplicates() // Nếu gõ chữ giống hệt lần trước thì bỏ qua
            .sink { [weak self] text in
                guard let self = self else { return }
                
                if text.isEmpty {
                    self.usernameMessage = "Vui lòng nhập tên đăng nhập."
                    self.isValidUsername = false
                } else if text.count < 3 {
                    self.usernameMessage = "Tên phải có ít nhất 3 ký tự."
                    self.isValidUsername = false
                } else {
                    // 👉 KẾT HỢP COMBINE VÀ ASYNC/AWAIT
                    // Gõ hợp lệ rồi, bắt đầu bọc Task để gọi API bất đồng bộ
                    Task {
                        await self.checkUsernameAvailability(username: text)
                    }
                }
            }
            .store(in: &cancellables) // Bắt buộc phải lưu lại để không bị giải phóng bộ nhớ
        
        
        // --- PIPELINE 2: CombineLatest để bật/tắt nút Đăng Ký ---
        Publishers.CombineLatest($isValidUsername, $isAgreedToTerms)
            .map { isValid, isAgreed in
                // Chỉ bật nút khi (Username hợp lệ) VÀ (Đã đồng ý điều khoản)
                return isValid && isAgreed
            }
            // Bắn kết quả thẳng vào biến output
            .assign(to: &$isRegisterButtonEnabled)
    }
    
    // 👉 ASYNC/AWAIT dùng cho API Operation
    private func checkUsernameAvailability(username: String) async {
        self.isLoading = true
        self.usernameMessage = "Đang kiểm tra..."
        
        do {
            // Giả lập gọi API tốn 1.5 giây
            try await Task.sleep(nanoseconds: 1_500_000_000)
            
            // Giả lập logic server: Tên "admin" đã bị trùng
            if username.lowercased() == "admin" {
                self.usernameMessage = "❌ Tên đăng nhập đã tồn tại."
                self.isValidUsername = false
            } else {
                self.usernameMessage = "✅ Tên đăng nhập hợp lệ!"
                self.isValidUsername = true
            }
        } catch {
            self.usernameMessage = "⚠️ Lỗi kết nối."
            self.isValidUsername = false
        }
        
        self.isLoading = false
    }
}

// MARK: - VIEW
struct RegistrationView: View {
    @StateObject private var viewModel = RegistrationViewModel()
    
    var body: some View {
        Form {
            Section(header: Text("Thông tin tài khoản")) {
                
                // Ô nhập liệu
                HStack {
                    TextField("Tên đăng nhập", text: $viewModel.username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
                
                // Hiển thị trạng thái (Lấy từ Combine Pipeline 1)
                Text(viewModel.usernameMessage)
                    .font(.caption)
                    .foregroundColor(viewModel.isValidUsername ? .green : .red)
            }
            
            Section {
                // Ô checkbox
                Toggle("Tôi đồng ý với điều khoản sử dụng", isOn: $viewModel.isAgreedToTerms)
            }
            
            Section {
                // Nút đăng ký (Lấy trạng thái từ Combine Pipeline 2)
                Button(action: {
                    print("Đã gửi đăng ký cho: \(viewModel.username)")
                }) {
                    Text("ĐĂNG KÝ")
                        .frame(maxWidth: .infinity)
                        .bold()
                }
                .disabled(!viewModel.isRegisterButtonEnabled) // Nút sẽ bị xám nếu biến này = false
            }
        }
        .navigationTitle("Tạo tài khoản")
    }
}

#Preview {
    NavigationView {
        RegistrationView()
    }
}
