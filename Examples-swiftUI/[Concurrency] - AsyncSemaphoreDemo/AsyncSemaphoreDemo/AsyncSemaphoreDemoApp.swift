import Foundation

// MARK: - Ví dụ thực hành

/// Giả lập một tác vụ tốn thời gian (ví dụ: tải file, xử lý dữ liệu)
func performHeavyTask(id: Int) async {
    // Giả lập thời gian xử lý ngẫu nhiên từ 1 đến 3 giây
    let sleepTime = UInt64.random(in: 1...3) * 1_000_000_000
    try? await Task.sleep(nanoseconds: sleepTime)
    print("✅ Tác vụ [\(id)] đã hoàn thành sau \(sleepTime / 1_000_000_000) giây.")
}

@main
struct AsyncSemaphoreExample {
    static func main() async {
        // 1. Tạo semaphore cho phép tối đa 2 tác vụ chạy đồng thời
        let maxConcurrentTasks = 2
        let semaphore = AsyncSemaphore(value: maxConcurrentTasks)
        
        let totalTasks = 5
        print("🚀 Bắt đầu chạy \(totalTasks) tác vụ.")
        print("⚠️ Chỉ cho phép \(maxConcurrentTasks) tác vụ chạy cùng lúc.\n")
        
        // 2. Sử dụng TaskGroup để chạy các tác vụ đồng thời một cách an toàn
        await withTaskGroup(of: Void.self) { group in
            for i in 1...totalTasks {
                group.addTask {
                    print("⏳ Tác vụ [\(i)] đang chờ để được cấp phép...")
                    
                    // 3. Yêu cầu quyền thực thi từ semaphore
                    await semaphore.wait()
                    
                    // 4. Sử dụng `defer` để đảm bảo luôn trả lại quyền (signal) khi xong việc,
                    // kể cả khi hàm bị lỗi (throw error) hoặc return sớm.
                    defer {
                        print("🔓 Tác vụ [\(i)] đã trả lại quyền cho Semaphore.")
                        semaphore.signal()
                    }
                    
                    // 5. Nếu vượt qua `wait()`, tác vụ được phép chạy
                    print("🔒 Tác vụ [\(i)] ĐANG CHẠY...")
                    await performHeavyTask(id: i)
                }
            }
        }
        
        print("\n🎉 Tất cả các tác vụ đã hoàn tất!")
    }
}
