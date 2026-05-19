import UIKit
import Foundation

// MARK: - 1. Hàm Cập Nhật (Mục tiêu cuối cùng)
func update() {
    print("✨ CẬP NHẬT THÀNH CÔNG: Dữ liệu đã được ghi vào Database và hiển thị lên UI!")
}

// MARK: - 2. Hàm chứa logic của bạn
func subtaskUpdate() async {
    print("▶️ Bắt đầu hàm subtaskUpdate()...")
    
    // Định nghĩa một subtask không tự động throw lỗi khi bị cancel
    let subtask: () async -> Void = {
        print("   ⏳ [Subtask] Đang tính toán dữ liệu nặng (Mất 3 giây)...")
        
        // Giả lập một vòng lặp tính toán nặng tốn 3 giây.
        // Khác với Task.sleep, vòng lặp này KHÔNG tự dừng lại khi Task bị cancel.
        let endTime = Date().addingTimeInterval(3.0)
        while Date() < endTime {
            // ... CPU đang làm việc miệt mài ...
        }
        
        print("   ✅ [Subtask] Tính toán xong!")
    }
    
    // Đứng chờ subtask chạy xong.
    // Dù bên ngoài có gọi cancel, dòng này vẫn phải đợi block closure trên tính toán xong.
    await subtask()
    
    // ĐIỂM CỐT LÕI NẰM Ở ĐÂY:
    print("🔍 Đang kiểm tra xem Task có bị người dùng hủy giữa chừng không...")
    
    if !Task.isCancelled {
        // Nếu không bị hủy, tiến hành cập nhật
        update()
    } else {
        // Nếu đã bị bật cờ hủy, bỏ qua bước cập nhật
        print("❌ PHÁT HIỆN TASK BỊ HỦY! Bỏ qua lệnh update() để bảo vệ an toàn dữ liệu.")
    }
}

// MARK: - 3. Kịch bản Test
func runCooperativeCancellationTest() async {
    print("🚀 Bắt đầu kịch bản...")
    
    // Khởi tạo một Task chạy độc lập
    let myTask = Task {
        await subtaskUpdate()
    }
    
    // Giả sử sau 1 giây, người dùng cảm thấy lâu quá và bấm nút "HỦY" (Thoát màn hình)
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    print("\n🛑 NGƯỜI DÙNG BẤM HỦY (myTask.cancel())")
    myTask.cancel()
    
    // Đứng chờ myTask hoàn tất quá trình dọn dẹp để xem log
    _ = await myTask.value
    print("🏁 Kịch bản kết thúc.")
}

// Thực thi
Task {
    await runCooperativeCancellationTest()
}

// (Nếu chạy ngoài project iOS, cần dòng này để console không thoát ngay)
// RunLoop.main.run()
