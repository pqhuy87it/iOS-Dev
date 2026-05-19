import SwiftUI

// Định nghĩa một biến TaskLocal để theo dõi việc context có được kế thừa hay không
enum ContextEnvironment {
    @TaskLocal static var traceID: String = "anonymous"
}

struct TaskDetachedDemoView: View {
    @State private var logOutput: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Thực hành Task vs Task.detached")
                    .font(.headline)
                
                Button("1. Task Thường (Có kế thừa)") {
                    runStandardTask()
                }
                .buttonStyle(.borderedProminent)
                
                Button("2. Task.detached (Mất kế thừa)") {
                    runDetachedTask()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                Button("3. Cách chuẩn iOS 18 (Executor Preference)") {
                    if #available(iOS 18.0, *) {
                        runTaskWithExecutorPreference()
                    } else {
                        log("⚠️ Tính năng này yêu cầu iOS 18 trở lên.")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Button("4. Gọi Background Task với nonisolated") {
                    runNonisolatedFunction()
                }
                .buttonStyle(.bordered)
                
                Divider()
                
                Text("Log Output:")
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(logOutput)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
    }
    
    // Hàm phụ trợ để hiển thị text lên UI
    private func log(_ message: String) {
        logOutput += "\(message)\n"
        print(message) // In ra console cho chắc chắn
    }
    
    // MARK: - Ví dụ 1: Task Thường
    private func runStandardTask() {
        // Gắn một giá trị cụ thể ("user-123") cho biến cục bộ TaskLocal
        ContextEnvironment.$traceID.withValue("user-123") {
            Task(priority: .high) {
                log("\n--- 1. Task Thông Thường ---")
                log("TraceID: \(ContextEnvironment.traceID)") // KẾ THỪA THÀNH CÔNG: Sẽ in ra "user-123"
            }
        }
    }
    
    // MARK: - Ví dụ 2: Task.detached (CÁCH DÙNG SAI LẦM)
    private func runDetachedTask() {
        ContextEnvironment.$traceID.withValue("user-123") {
            Task.detached {
                // Task.detached xoá bỏ hoàn toàn bối cảnh của môi trường gọi nó
                log("\n--- 2. Task.detached ---")
                log("TraceID: \(ContextEnvironment.traceID)") // MẤT KẾ THỪA: Trở về mặc định là "anonymous"
            }
        }
    }
    
    // MARK: - Ví dụ 3: Cách tiếp cận chuẩn xác từ iOS 18
    @available(iOS 18.0, *)
    private func runTaskWithExecutorPreference() {
        ContextEnvironment.$traceID.withValue("user-123") {
            // Chạy dưới pool ngầm (GCE) nhưng VẪN GIỮ ĐƯỢC biến TaskLocal và Priority
            Task(executorPreference: globalConcurrentExecutor) {
                log("\n--- 3. Executor Preference ---")
                let isMain = Thread.current.isMainThread
                log("Đang chạy trên Main Thread?: \(isMain)") // false (đã ở background)
                log("TraceID: \(ContextEnvironment.traceID)") // VẪN DUY TRÌ: In ra "user-123"
            }
        }
    }
    
    // MARK: - Ví dụ 4: Xử lý background đúng cách thay vì dùng Task.detached
    private func runNonisolatedFunction() {
        Task {
            log("\n--- 4. Gọi hàm Nonisolated ---")
            log("Task khởi tạo trên Main Thread?: \(Thread.current.isMainThread)") // true
            
            // Hàm này tự động nhảy sang Background (GCE) để chạy
            await doHeavyBackgroundWork()
            
            // Xong việc tự động nhảy lại về Main Thread để cập nhật UI
            log("Quay lại Main Thread sau khi await?: \(Thread.current.isMainThread)") // true
        }
    }
    
    // Hàm được đánh dấu nonisolated sẽ không bị ràng buộc vào @MainActor của View này
    nonisolated private func doHeavyBackgroundWork() async {
        let isMain = Thread.current.isMainThread
        log("Hàm xử lý nặng đang chạy trên Main Thread?: \(isMain)") // false (Chạy nền)
        try? await Task.sleep(nanoseconds: 500_000_000) // Giả lập công việc nặng mất 0.5s
    }
}

#Preview {
    TaskDetachedDemoView()
}
