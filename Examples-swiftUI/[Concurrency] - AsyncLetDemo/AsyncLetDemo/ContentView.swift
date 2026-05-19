import SwiftUI

// MARK: - 1. Các Model Dữ Liệu
struct UserProfile {
    let name: String
    let bio: String
}

struct UserStats {
    let followers: Int
    let posts: Int
}

// MARK: - 2. Giao diện hiển thị
struct AsyncLetDemoView: View {
    // Các biến lưu trữ dữ liệu sau khi tải xong
    @State private var profile: UserProfile?
    @State private var stats: UserStats?
    @State private var avatarImage: String? // Giả lập tên icon
    
    @State private var isFetching = false
    @State private var loadTime: Double = 0
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Trang Cá Nhân")
                .font(.largeTitle).bold()
            
            // Khu vực hiển thị thông tin
            VStack(spacing: 16) {
                if isFetching {
                    ProgressView("Đang tải dữ liệu đa luồng...")
                        .scaleEffect(1.2)
                } else if let profile = profile, let stats = stats, let avatar = avatarImage {
                    // Hiển thị khi đã có đủ dữ liệu
                    Image(systemName: avatar)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                    
                    Text(profile.name)
                        .font(.title2).bold()
                    Text(profile.bio)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 40) {
                        VStack {
                            Text("\(stats.posts)").font(.headline)
                            Text("Bài viết").font(.caption)
                        }
                        VStack {
                            Text("\(stats.followers)").font(.headline)
                            Text("Người theo dõi").font(.caption)
                        }
                    }
                    .padding(.top, 10)
                } else {
                    Text("Chưa có dữ liệu")
                        .foregroundColor(.gray)
                }
            }
            .frame(height: 250)
            
            if loadTime > 0 {
                Text(String(format: "⏱ Tổng thời gian tải: %.2f giây", loadTime))
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            // Nút kích hoạt
            Button("Tải Dữ Liệu Ngay") {
                Task {
                    await loadDashboardData()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isFetching)
        }
        .padding()
    }
    
    // MARK: - 3. Phép thuật của `async let`
    @MainActor
    func loadDashboardData() async {
        isFetching = true
        profile = nil
        stats = nil
        avatarImage = nil
        
        let startTime = Date()
        
        do {
            // 🚀 BẮN 3 LUỒNG ĐI CÙNG MỘT LÚC
            // Từ khóa `async let` khởi tạo tiến trình ngay lập tức trên background
            // Chú ý: Ở đây KHÔNG CÓ chữ `await`
            async let fetchedProfile = fetchProfile()    // Mất 2 giây
            async let fetchedStats = fetchStats()        // Mất 1 giây
            async let fetchedAvatar = fetchAvatar()      // Mất 3 giây
            
            // ⏳ GOM KẾT QUẢ
            // Đây là lúc chúng ta thực sự ĐỢI cả 3 thằng hoàn thành.
            // Hệ thống sẽ đợi thằng lâu nhất (fetchAvatar - 3 giây) xong thì mới đi tiếp.
            let (p, s, a) = try await (fetchedProfile, fetchedStats, fetchedAvatar)
            
            // Cập nhật UI
            self.profile = p
            self.stats = s
            self.avatarImage = a
            
        } catch {
            print("Có lỗi xảy ra trong quá trình tải: \(error)")
        }
        
        isFetching = false
        loadTime = Date().timeIntervalSince(startTime)
    }
    
    // MARK: - 4. Các hàm mạng giả lập (Network Mocks)
    
    func fetchProfile() async throws -> UserProfile {
        print("▶️ Bắt đầu tải Profile...")
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 giây
        print("✅ Tải Profile xong!")
        return UserProfile(name: "Nguyễn Văn A", bio: "Đam mê lập trình Swift")
    }
    
    func fetchStats() async throws -> UserStats {
        print("▶️ Bắt đầu tải Stats...")
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 giây
        print("✅ Tải Stats xong!")
        return UserStats(followers: 10500, posts: 42)
    }
    
    func fetchAvatar() async throws -> String {
        print("▶️ Bắt đầu tải Avatar...")
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 giây
        print("✅ Tải Avatar xong!")
        return "person.crop.circle.fill"
    }
}

#Preview {
    AsyncLetDemoView()
}
