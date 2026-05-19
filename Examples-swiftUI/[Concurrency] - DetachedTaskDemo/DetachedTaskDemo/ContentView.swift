import SwiftUI

// MARK: - 1. Hệ thống Log độc lập (Analytics)
class AnalyticsService {
    static let shared = AnalyticsService()
    
    // Hàm mô phỏng việc gửi dữ liệu lên server tốn thời gian
    func sendLog(message: String) async {
        print("📊 [Analytics] Bắt đầu gửi log: '\(message)'...")
        
        do {
            // Giả lập mạng chậm tốn 3 giây
            try await Task.sleep(nanoseconds: 3_000_000_000)
            
            // Nếu Task không bị hủy, dòng này sẽ được in ra
            print("✅ [Analytics] Đã gửi thành công: '\(message)'")
        } catch {
            // Sẽ nhảy vào đây nếu tiến trình bị hủy (Cancel)
            print("❌ [Analytics] Gửi log THẤT BẠI. Bị hủy giữa chừng!")
        }
    }
}

// MARK: - 2. Màn hình hiển thị
struct DetachedTaskDemoView: View {
    @State private var logs: [String] = []
    
    // Lưu trữ Task chính (Tải dữ liệu) để có thể chủ động hủy nó
    @State private var mainTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Demo: Task vs Task.detached")
                .font(.headline)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(logs, id: \.self) { log in
                        Text(log).font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .frame(height: 200)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Button("Bắt đầu Mở Màn Hình") {
                openScreen()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Bấm Back (HỦY Màn Hình)") {
                // Giả lập người dùng thoát ra ngay khi đang tải
                mainTask?.cancel()
                addLog("⬅️ Đã bấm Back, hủy Main Task!")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
    }
    
    // MARK: - 3. Thử nghiệm Sự khác biệt
    @MainActor
    private func openScreen() {
        logs.removeAll()
        addLog("▶️ Bắt đầu mở màn hình...")
        
        mainTask = Task {
            addLog("Tải UI trên luồng: \(Thread.isMainThread ? "Main" : "Background")")
            
            // Sử dụng TaskGroup để tạo ra Structured Concurrency (Cấu trúc phân tầng)
            await withTaskGroup(of: Void.self) { group in
                
                // 🔴 1. STRUCTURED TASK: Đứa con ngoan
                // Vì được add vào group, nó nằm trong cấu trúc của mainTask.
                // Nếu mainTask bị cancel, group sẽ truyền lệnh cancel xuống cho nó.
                group.addTask {
                    print("--- Chạy thử bằng Structured Task ---")
                    await AnalyticsService.shared.sendLog(message: "(Lỗi) Log bằng Structured Task")
                }
            }
            
            // 🟢 2. DETACHED TASK: Kẻ thoát ly
            // Bắn ra khỏi hệ thống. Không liên quan gì đến group hay mainTask.
            Task.detached(priority: .background) {
                print("--- Chạy thử bằng Task.detached ---")
                await AnalyticsService.shared.sendLog(message: "(Tốt) Log bằng Detached")
            }
            
            // Giả lập việc tải UI (chỉ chạy đến đây nếu không bị hủy)
            if !Task.isCancelled {
                addLog("✅ Tải UI thành công!")
            }
        }
    }
    
    private func addLog(_ message: String) {
        logs.append(message)
    }
}

#Preview {
    DetachedTaskDemoView()
}
