import SwiftUI

// MARK: - 1. Định nghĩa Actor (Bảo vệ dữ liệu)
actor BankAccount {
    // Biến này được bảo vệ nghiêm ngặt (Isolated state)
    // Không một luồng nào từ bên ngoài được sửa nó trực tiếp.
    private var balance: Double
    
    init(initialBalance: Double) {
        self.balance = initialBalance
    }
    
    func reset(balance: Double) {
        self.balance = balance
    }
    
    /*
     // Hàm thay đổi dữ liệu bên trong Actor
     func withdraw(amount: Double) -> String {
     // Nếu là class, 3 thread có thể lọt vào hàm if này cùng lúc.
     // Nhưng với actor, các thread bị ép phải đi qua cánh cửa này từng-người-một.
     if balance >= amount {
     balance -= amount
     return "✅ Rút thành công \(amount)đ. Số dư còn: \(balance)đ"
     } else {
     return "❌ Hết tiền! Không thể rút \(amount)đ. Số dư: \(balance)đ"
     }
     }
     */
    // Hàm rút tiền bây giờ có chữ 'async' vì chứa Task.sleep
    func withdraw(amount: Double, threadName: String) async -> String {
        // 1. NGỦ TRƯỚC (Simulate Network Delay)
        // Đây là lúc Actor mở cửa cho các luồng khác cùng vào ngủ chung.
        let delay = Int.random(in: 1...5)
        try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
        
        // 2. THAO TÁC LIỀN MẠCH (Synchronous execution)
        // Bắt đầu từ dòng này trở xuống không có chữ 'await' nào nữa.
        // Luồng nào thức dậy trước sẽ khóa cửa lại, kiểm tra tiền và trừ tiền ngay lập tức.
        if balance >= amount {
            balance -= amount
            return "✅ [\(threadName)] Rút thành công! (Mất \(delay)s). Số dư: \(balance)đ"
        } else {
            return "❌ [\(threadName)] Hết tiền! (Mất \(delay)s). Số dư: \(balance)đ"
        }
    }
    
    // nonisolated: Đánh dấu hàm này KHÔNG chạm vào dữ liệu nhạy cảm (balance).
    // Bất kỳ ai cũng có thể gọi hàm này mọi lúc mà không cần xếp hàng.
    nonisolated func getBankName() -> String {
        return "SwiftUI Bank"
    }
}

// MARK: - 2. Giao diện hiển thị
struct ActorDemoView: View {
    // Khởi tạo một Actor tài khoản ngân hàng với 1000đ
    let account = BankAccount(initialBalance: 1000)
    
    @State private var logs: [String] = []
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Actor Demo: Ngân Hàng")
                .font(.title).bold()
            
            Text("Số dư ban đầu: 1000đ")
                .font(.headline)
                .foregroundColor(.blue)
            
            // Khu vực in Log
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(logs, id: \.self) { log in
                        Text(log)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Nút kích hoạt xung đột
            Button(action: runConcurrentWithdrawals) {
                Text(isProcessing ? "Đang xử lý..." : "Rút 400đ (Bằng 3 luồng cùng lúc)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)
            
            //reset account balance
            Button("Reset tài khoản") {
                // 1. Tạo một Task (Tiến trình bất đồng bộ)
                Task {
                    // 2. Thêm chữ 'await' để báo hiệu: "Tôi chấp nhận đợi đến lượt để được reset"
                    await account.reset(balance: 1000)
                    
                    // 3. Sau khi reset xong, bạn có thể cập nhật UI
                    logs.append("🔄 Đã reset tài khoản về 1000đ")
                }
            }
            
            // Gọi hàm nonisolated không cần await
            Text("Được bảo trợ bởi \(account.getBankName())")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - 3. Mô phỏng luồng chạy song song
    func runConcurrentWithdrawals() {
        logs.removeAll()
        isProcessing = true
        logs.append("Bắt đầu gọi 3 luồng cùng lúc...")
        
        Task {
            // TaskGroup cho phép tạo nhiều tiến trình chạy song song (Concurrent)
            await withTaskGroup(of: String.self) { group in
                
                // Bơm 3 Task vào chạy đua với nhau
                for i in 1...3 {
                    group.addTask {
                        // 🔴 TẠI SAO PHẢI CÓ AWAIT?
                        // Vì account là một actor. Luồng này có thể bị hệ thống "tạm ngưng" (suspend)
                        // để ép nó phải XẾP HÀNG nếu đang có một luồng khác đang dùng account.
//                        let result = await account.withdraw(amount: 400)
//                        return "Luồng \(i): \(result)"
                        // Gọi hàm rút tiền, truyền tên luồng vào để dễ theo dõi
                                                return await account.withdraw(amount: 400, threadName: "Luồng \(i)")
                    }
                }
                
                // Thu thập kết quả khi các luồng chạy xong
                for await message in group {
                    await MainActor.run {
                        logs.append(message)
                    }
                }
            }
            
            await MainActor.run {
                isProcessing = false
                logs.append("--- Kết thúc ---")
            }
        }
    }
}

#Preview {
    ActorDemoView()
}
