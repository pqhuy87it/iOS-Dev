import SwiftUI

struct CancellationHandlerDemo: View {
    @State private var status = "Chưa bắt đầu"
    @State private var isWorking = false
    
    // Biến lưu trữ Task để chúng ta có thể gọi lệnh hủy
    @State private var currentTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 30) {
            Text("Trạng thái:")
                .font(.headline)
            
            Text(status)
                .font(.title3)
                .foregroundColor(isWorking ? .blue : .primary)
                .bold()

            HStack(spacing: 20) {
                // NÚT BẮT ĐẦU
                Button("Bắt đầu tải dữ liệu") {
                    startWork()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking)

                // NÚT HỦY
                Button("Hủy (Cancel)") {
                    // Gọi lệnh hủy Task
                    currentTask?.cancel()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!isWorking)
            }
        }
        .padding()
    }

    // Đánh dấu @MainActor để đảm bảo việc cập nhật UI (status) an toàn
    @MainActor
    private func startWork() {
        status = "Đang tải dữ liệu (chờ 5 giây)..."
        isWorking = true

        currentTask = Task {
            await performHeavyTask()
        }
    }

    @MainActor
    private func performHeavyTask() async {
        // CÚ PHÁP MỚI THAY THẾ CHO HÀM BỊ DEPRECATED
        await withTaskCancellationHandler {
            // ----------------------------------------------------
            // KHỐI 1: OPERATION (Công việc chính)
            // ----------------------------------------------------
            do {
                // Giả lập việc tải dữ liệu tốn 5 giây
                try await Task.sleep(nanoseconds: 5_000_000_000)
                
                // Nếu Task không bị hủy giữa chừng, code sẽ chạy đến đây
                status = "✅ Tải dữ liệu thành công!"
                isWorking = false
            } catch is CancellationError {
                // Task.sleep sẽ ném ra lỗi này nếu Task bị hủy
                status = "❌ Công việc đã bị hủy bỏ!"
                isWorking = false
            } catch {
                status = "⚠️ Có lỗi xảy ra."
                isWorking = false
            }
            
        } onCancel: {
            // ----------------------------------------------------
            // KHỐI 2: ON CANCEL (Trình xử lý hủy bỏ)
            // ----------------------------------------------------
            // Đoạn code này CHẠY NGAY LẬP TỨC khi currentTask?.cancel() được gọi.
            // Dù khối Operation đang bị kẹt hay đang ngủ, onCancel vẫn xen ngang được.
            
            // LƯU Ý QUAN TRỌNG:
            // Bạn KHÔNG NÊN cập nhật UI (như biến status) ở trong khối onCancel này,
            // vì khối này chạy đồng bộ (sync) và có thể nằm ở một luồng (thread) bất kỳ của hệ thống.
            // Chỉ dùng nó để ngắt kết nối database, đóng session mạng, v.v.
            
            print("🚨 [HỆ THỐNG]: Đã nhận được lệnh Hủy! Đang ngắt các kết nối mạng để giải phóng bộ nhớ...")
        }
    }
}

#Preview {
    CancellationHandlerDemo()
}
