import UIKit
import Foundation

// MARK: - 1. Hàm mô phỏng tác vụ mạng (Subtask)
func load(taskName: String) async throws -> String {
    print("▶️ [\(taskName)] Bắt đầu chạy...")
    
    // Giả lập một tiến trình mất 3 giây.
    // LƯU Ý QUAN TRỌNG: Hàm Task.sleep của Swift cực kỳ thông minh.
    // Nếu Task bị cancel trong lúc nó đang sleep, nó sẽ lập tức thức dậy và ném ra lỗi CancellationError.
    try await Task.sleep(nanoseconds: 3_000_000_000)
    
    // Dòng này sẽ KHÔNG BAO GIỜ được in ra nếu Task bị cancel giữa chừng
    print("✅ [\(taskName)] Tải xong dữ liệu!")
    return "Dữ liệu của \(taskName)"
}

// MARK: - 2. Thực thi kịch bản hủy Task
func runCancellationTest() async {
    print("🚀 Bắt đầu tạo Parent Task (a)...")
    
    // Khởi tạo Task Cha (Unstructured Task)
    let parentTask = Task {
        do {
            print("👨‍👦 Parent Task đang tạo các Subtasks (b và c)...")
            
            // Tạo 2 subtasks chạy song song
            async let b = load(taskName: "Subtask B")
            async let c = load(taskName: "Subtask C")
            
            print("⏳ Parent Task đang chờ b và c hoàn thành...")
            
            // Chờ kết quả của cả 2.
            // Nếu Parent bị cancel, lệnh await này sẽ quăng ra lỗi CancellationError ngay lập tức.
            let (resultB, resultC) = try await (b, c)
            
            print("🎉 Thành công: \(resultB), \(resultC)")
        } catch is CancellationError {
            // Hứng lỗi hủy task
            print("❌ Parent Task bị hủy! Các tiến trình 'async let' bên trong cũng đã bị ép dừng.")
        } catch {
            print("⚠️ Lỗi khác: \(error)")
        }
    }
    
    // Đứng ở ngoài (Main thread), chúng ta đợi 0.5 giây để đảm bảo
    // Subtask B và C đã thực sự bắt đầu chạy (in ra dòng "Bắt đầu chạy...").
    try? await Task.sleep(nanoseconds: 500_000_000)
    
    print("\n🛑 RA LỆNH HỦY PARENT TASK!")
    // Hủy Task Cha. Lập tức tín hiệu này sẽ giật sập b và c.
    parentTask.cancel()
    
    // Đợi Parent Task xử lý xong xuôi để xem log in ra
    _ = await parentTask.result
    print("🏁 Bài test kết thúc.")
}

// MARK: - 3. Chạy thử
Task {
    await runCancellationTest()
}

// Giữ cho command-line không thoát (Nếu chạy trong file Swift bình thường)
// RunLoop.main.run()
