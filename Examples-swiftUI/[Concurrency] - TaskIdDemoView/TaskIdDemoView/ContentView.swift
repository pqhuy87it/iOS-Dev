import SwiftUI

struct TaskIdDemoView: View {
    // Biến trạng thái để kích hoạt .task(id:)
    @State private var selectedUserId: Int = 1
    
    // Biến để hiển thị giao diện
    @State private var fetchedData: String = "Đang chờ..."
    @State private var isFetching: Bool = false

    var body: some View {
        VStack(spacing: 30) {
            Text("Màn Hình Tải Dữ Liệu")
                .font(.title2).bold()
            
            // Khu vực hiển thị trạng thái
            VStack(spacing: 10) {
                if isFetching {
                    ProgressView()
                }
                Text(fetchedData)
                    .font(.headline)
                    .foregroundColor(isFetching ? .gray : .green)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 100)
            
            Text("Đang chọn ID: \(selectedUserId)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Các nút để thay đổi ID
            HStack(spacing: 20) {
                Button("User 1") { selectedUserId = 1 }
                    .buttonStyle(.borderedProminent)
                
                Button("User 2") { selectedUserId = 2 }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                
                Button("User 3") { selectedUserId = 3 }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
            }
        }
        .padding()
        // Gắn .task(id:) vào một View bất kỳ.
        // Cứ mỗi lần selectedUserId thay đổi, khối code bên trong sẽ chạy lại từ đầu.
        .task(id: selectedUserId) {
            await fetchUserData(for: selectedUserId)
        }
    }
    
    // Hàm giả lập gọi API mạng
    private func fetchUserData(for id: Int) async {
        // Cập nhật UI: Bắt đầu tải
        isFetching = true
        fetchedData = "Đang tải dữ liệu cho User \(id)..."
        
        do {
            // Giả lập mạng chậm, mất 2 giây để tải xong
            // LƯU Ý: Nếu Task bị hủy trong lúc đang sleep, nó sẽ ném ra lỗi CancellationError ngay lập tức
            if #available(iOS 16.0, *) {
                try await Task.sleep(for: .seconds(2))
            } else {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }
            
            // Nếu không bị hủy, code sẽ chạy đến đây để cập nhật UI thành công
            fetchedData = "✅ Dữ liệu hoàn chỉnh của User \(id)!"
            isFetching = false
            
        } catch is CancellationError {
            // Bắt lỗi HỦY TASK.
            // Đoạn code này chạy khi bạn đang tải User 1 mà lại bấm sang User 2.
            print("🚨 Đã HỦY tiến trình tải của User \(id) vì ID đã thay đổi!")
            // Không set isFetching = false ở đây vì tiến trình mới của User 2 đã bắt đầu rồi.
            
        } catch {
            // Các lỗi khác (Mất mạng, v.v.)
            fetchedData = "❌ Lỗi không xác định"
            isFetching = false
        }
    }
}

#Preview {
    TaskIdDemoView()
}
