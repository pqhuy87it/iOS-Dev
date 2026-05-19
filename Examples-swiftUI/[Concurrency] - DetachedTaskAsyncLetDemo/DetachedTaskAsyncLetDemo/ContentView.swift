import SwiftUI

// MARK: - 1. Dịch vụ giả lập
class AnalyticsService {
    static let shared = AnalyticsService()
    
    // Lưu ý: Thêm 'throws' để hàm có thể ném ra lỗi khi bị Hủy (CancellationError)
    func sendLog(message: String) async throws -> String {
        print("📊 [Bắt đầu] Đang xử lý: '\(message)'...")
        
        // Ngủ 3 giây. Nếu tiến trình bị hủy trong lúc ngủ, nó sẽ quăng lỗi ngay lập tức!
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        let successMsg = "✅ [Thành công] Đã gửi: '\(message)'"
        print(successMsg)
        return successMsg
    }
}

// MARK: - 2. Giao diện Demo
struct AsyncLetCancellationView: View {
    @State private var logs: [String] = []
    
    // Chỉ cần MỘT biến lưu Task cha duy nhất
    @State private var mainTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 20) {
            Text("async let vs Task.detached")
                .font(.headline)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(logs, id: \.self) { log in
                        Text(log).font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .frame(height: 250)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Button("Bắt đầu Chạy") {
                runTasks()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Bấm HỦY ngay lập tức") {
                // Hủy Task cha -> Sẽ truyền lệnh hủy xuống async let
                mainTask?.cancel()
                addLog("⬅️ Đã phát lệnh HỦY mainTask!")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
    }
    
    // MARK: - 3. Logic xử lý Concurrency
    @MainActor
    private func runTasks() {
        logs.removeAll()
        addLog("▶️ Bắt đầu mainTask...")
        
        mainTask = Task {
            // ---------------------------------------------------------
            // 1. DÙNG ASYNC LET (Structured Task - Con ngoan)
            // Nó là tiến trình con, sinh ra và gắn liền với mainTask.
            // ---------------------------------------------------------
            async let structuredLog = AnalyticsService.shared.sendLog(message: "Log bằng async let")
            
            // ---------------------------------------------------------
            // 2. DÙNG TASK.DETACHED (Unstructured Task - Kẻ thoát ly)
            // Bắn ra khỏi hệ thống, không nhận mainTask làm cha.
            // ---------------------------------------------------------
            Task.detached(priority: .background) {
                do {
                    let result = try await AnalyticsService.shared.sendLog(message: "Log bằng Detached")
                    await MainActor.run { addLog(result) }
                } catch {
                    await MainActor.run { addLog("❌ Detached bị lỗi/hủy (Chuyện này sẽ không xảy ra)") }
                }
            }
            
            // ---------------------------------------------------------
            // 3. ĐỢI KẾT QUẢ CỦA ASYNC LET
            // ---------------------------------------------------------
            do {
                // Lệnh 'try await' này là nơi mainTask hứng kết quả hoặc hứng lỗi từ async let
                let result = try await structuredLog
                addLog(result)
            } catch is CancellationError {
                // Nếu bạn bấm nút Hủy, code sẽ nhảy thẳng vào đây!
                addLog("❌ [BỊ HỦY] Tiến trình 'async let' đã chết theo mainTask!")
            } catch {
                addLog("⚠️ Lỗi khác: \(error)")
            }
        }
    }
    
    private func addLog(_ message: String) {
        logs.append(message)
    }
}

#Preview {
    AsyncLetCancellationView()
}
