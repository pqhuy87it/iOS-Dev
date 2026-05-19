import SwiftUI

// MARK: - 1. Worker tạo "Kẹt xe"
class ThreadTester {
    static func forceThreadHopping() async -> [String] {
        // Sử dụng TaskGroup để bắn 100 luồng cùng lúc
        let hoppedTasks = await withTaskGroup(of: String?.self) { group in
            
            // Bơm 100 Task vào hệ thống (Trong khi CPU chỉ có khoảng 6-8 luồng)
            for i in 1...100 {
                group.addTask {
                    // Lấy số ID của luồng trước khi ngủ
                    let threadBefore = Thread.current.description
                    
                    // Ngủ một khoảng thời gian RANDOM rất ngắn (10-50 mili-giây)
                    // Việc random này khiến các Task thức dậy lộn xộn, gây rối loạn cho hệ thống phân luồng
                    let randomDelay = UInt64.random(in: 10_000_000...50_000_000)
                    try? await Task.sleep(nanoseconds: randomDelay)
                    
                    // Lấy số ID của luồng sau khi thức dậy
                    let threadAfter = Thread.current.description
                    
                    // CHỈ GHI NHẬN NHỮNG TASK BỊ ĐỔI LUỒNG
                    if threadBefore != threadAfter {
                        return "Task \(i) nhảy luồng:\nTừ \(threadBefore)\nSang \(threadAfter)\n"
                    } else {
                        return nil // Trùng luồng thì bỏ qua
                    }
                }
            }
            
            // Gom kết quả lại
            var results: [String] = []
            for await message in group {
                if let msg = message {
                    results.append(msg)
                }
            }
            return results
        }
        
        return hoppedTasks
    }
}

// MARK: - 2. Giao diện hiển thị
struct ThreadStressTestView: View {
    @State private var logs: [String] = []
    @State private var isTesting = false
    @State private var summary = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Ép Nhảy Luồng (Stress Test)")
                .font(.headline)
            
            Text(summary)
                .font(.subheadline)
                .foregroundColor(.blue)
                .bold()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(logs, id: \.self) { log in
                        Text(log)
                            .font(.system(size: 12, design: .monospaced))
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 400)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
            
            Button(action: runTest) {
                Text(isTesting ? "Đang thả 100 Task..." : "Bắn 100 Task cùng lúc!")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isTesting)
        }
        .padding()
    }
    
    @MainActor
    func runTest() {
        logs.removeAll()
        summary = "Đang tính toán..."
        isTesting = true
        
        Task.detached {
            let resultLogs = await ThreadTester.forceThreadHopping()
            
            await MainActor.run {
                self.logs = resultLogs
                self.summary = "Phát hiện \(resultLogs.count)/100 Task bị đổi luồng!"
                self.isTesting = false
            }
        }
    }
}

#Preview {
    ThreadStressTestView()
}
