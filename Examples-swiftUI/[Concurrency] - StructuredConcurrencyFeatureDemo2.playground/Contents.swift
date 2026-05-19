import UIKit
import Foundation

func runTaskGroupCancellationTest() async {
    print("🚀 Khởi tạo Parent Task (a)...")
    
    // Tạo Task Cha (Unstructured Task)
    let a = Task {
        // Tạo một Task Group (Quản lý các Subtask)
        await withThrowingTaskGroup(of: String.self) { group in
            print("👨‍👩‍👧‍👦 Task Group đã được tạo.")
            
            // Subtask b
            group.addTask {
                print("▶️ [Subtask B] Đang xử lý dữ liệu...")
                // Giả lập công việc tốn 3 giây.
                // Nếu bị cancel giữa chừng, Task.sleep sẽ lập tức quăng lỗi CancellationError
                try await Task.sleep(nanoseconds: 3_000_000_000)
                print("✅ [Subtask B] Hoàn thành!") // Dòng này sẽ không chạy nếu bị hủy
                return "Kết quả B"
            }
            
            // Subtask c
            group.addTask {
                print("▶️ [Subtask C] Đang tải API...")
                try await Task.sleep(nanoseconds: 3_000_000_000)
                print("✅ [Subtask C] Hoàn thành!")
                return "Kết quả C"
            }
            
            // Vòng lặp chờ nhận kết quả từ các Subtask
            do {
                for try await result in group {
                    print("📦 Nhận được: \(result)")
                }
            } catch is CancellationError {
                // Bắt chính xác lỗi do lệnh a.cancel() gây ra
                print("❌ Task Group bị hủy! Toàn bộ tiến trình 'b' và 'c' đã bị ép dừng.")
            } catch {
                print("⚠️ Lỗi khác: \(error)")
            }
        }
        
        print("🛑 Khối lệnh của Parent Task kết thúc.")
    }
    
    // Đứng ở hàm Main, chúng ta đợi 0.5 giây để đảm bảo
    // Subtask B và C thực sự đã bắt đầu chạy bên trong Group.
    try? await Task.sleep(nanoseconds: 500_000_000)
    
    print("\n⚡️ RA LỆNH HỦY PARENT TASK (a.cancel())")
    // Hủy Parent Task. Lệnh này sẽ giật sập Task Group và tất cả các addTask bên trong.
    a.cancel()
    
    // Chờ Task 'a' xử lý dọn dẹp xong để xem log in ra
    _ = await a.result
    print("🏁 Bài test kết thúc.")
}

// Thực thi code
Task {
    await runTaskGroupCancellationTest()
}

// Nếu chạy bằng file Swift ngoài project iOS, cần dòng này để console không bị thoát
// RunLoop.main.run()
