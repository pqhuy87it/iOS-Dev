import SwiftUI

struct ContentView: View {
    // Các biến lưu trữ dữ liệu người dùng nhập
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var phoneNumber: String = ""
    
    // Các biến quản lý trạng thái đang focus (chọn) của từng TextField
    @State private var isEditingEmail = false
    @State private var isEditingPassword = false
    @State private var isEditingPhone = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Màu nền nhẹ nhàng cho ứng dụng
                Color(UIColor.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 25) {
                    
                    // Tiêu đề
                    VStack(spacing: 8) {
                        Text("Tạo Tài Khoản")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Sử dụng iTextField mạnh mẽ")
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 20)
                    
                    // 1. Trường nhập Email
                    iTextField("Nhập địa chỉ Email", text: $email, isEditing: $isEditingEmail)
                        .keyboardType(.emailAddress) // Bàn phím có nút @
                        .autocapitalization(.none)   // Không viết hoa chữ đầu
                        .disableAutocorrection(true) // Tắt sửa lỗi chính tả
                        .returnKeyType(.next)        // Nút return hiển thị chữ "Next"
                        .onReturn {
                            // Khi bấm Next, tự động nhảy con trỏ xuống ô Mật khẩu
                            self.isEditingEmail = false
                            self.isEditingPassword = true
                        }
                    // Dùng hàm style có sẵn của thư viện để làm đẹp nhanh chóng
                        .style(
                            height: 55,
                            backgroundColor: .white,
                            accentColor: .blue, // Màu con trỏ
                            hasShadow: true,
                            image: Image(systemName: "envelope.fill") // Thêm icon
                        )
                        .foregroundColor(.blue) // Đổi màu chữ khi gõ
                    
                    // 2. Trường nhập Mật khẩu
                    iTextField("Nhập mật khẩu", text: $password, isEditing: $isEditingPassword)
                        .isSecure(true)              // Biến thành ô nhập mật khẩu (dấu chấm)
                        .returnKeyType(.next)
                        .showsClearButton(true)      // Hiện nút X để xóa nhanh
                        .onReturn {
                            // Khi bấm Next, tự động nhảy xuống ô Số điện thoại
                            self.isEditingPassword = false
                            self.isEditingPhone = true
                        }
                        .style(
                            height: 55,
                            backgroundColor: .white,
                            accentColor: .purple,
                            hasShadow: true,
                            image: Image(systemName: "lock.fill")
                        )
                    
                    // 3. Trường nhập Số điện thoại (Test giới hạn ký tự)
                    iTextField("Số điện thoại (Tối đa 10 số)", text: $phoneNumber, isEditing: $isEditingPhone)
                        .keyboardType(.numberPad)    // Bàn phím chỉ có số
                        .characterLimit(10)          // TÍNH NĂNG ĐẶC BIỆT: Chặn không cho gõ quá 10 ký tự
                        .returnKeyType(.done)
                        .onReturn {
                            // Bấm Done thì ẩn bàn phím
                            self.isEditingPhone = false
                        }
                        .style(
                            height: 55,
                            backgroundColor: .white,
                            accentColor: .green,
                            hasShadow: true,
                            image: Image(systemName: "phone.fill")
                        )
                    
                    // Nút Đăng ký
                    Button(action: {
                        // Ẩn bàn phím khi bấm đăng ký
                        self.isEditingEmail = false
                        self.isEditingPassword = false
                        self.isEditingPhone = false
                        
                        print("Email: \(email), Pass: \(password), Phone: \(phoneNumber)")
                    }) {
                        Text("Đăng Ký Ngay")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(
                                LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
            }
            .navigationBarHidden(true)
        }
        // Để chạm ra ngoài màn hình thì ẩn bàn phím
        .onTapGesture {
            self.isEditingEmail = false
            self.isEditingPassword = false
            self.isEditingPhone = false
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
