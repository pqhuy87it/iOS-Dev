import SwiftUI
import Combine

// MARK: - 1. Model dữ liệu
enum DownloadState {
    case waiting     // Đang chờ tới lượt
    case downloading // Đang được tải
    case done        // Đã tải xong
}

struct ImageItem: Identifiable {
    let id: Int
    var state: DownloadState = .waiting
}

// MARK: - 2. ViewModel xử lý logic Concurrency
@MainActor // Đảm bảo mọi cập nhật UI đều chạy trên Main Thread
class ImageLoaderViewModel: ObservableObject {
    @Published var items: [ImageItem]
    
    let totalItems = 100
    let maxConcurrentTasks = 3 // Giới hạn đúng 3 thread chạy cùng lúc
    
    init() {
        // Khởi tạo 100 items ở trạng thái chờ
        self.items = (0..<totalItems).map { ImageItem(id: $0, state: .waiting) }
    }
    
    func startDownloading() {
        // Reset lại dữ liệu nếu người dùng bấm chạy lại nhiều lần
        self.items = (0..<totalItems).map { ImageItem(id: $0, state: .waiting) }
        
        // Khởi chạy tiến trình bất đồng bộ
        Task {
            await runDownloadPool()
        }
    }
    
    // Thuật toán Worker Pool (Quản lý số lượng Task)
    private func runDownloadPool() async {
        var pendingIds = Array(0..<totalItems) // Danh sách ID các ảnh cần tải
        
        // Tạo một TaskGroup trả về Int (ID của ảnh vừa tải xong)
        await withTaskGroup(of: Int.self) { group in
            
            // 1. KHỞI ĐỘNG: Bơm 3 task đầu tiên vào group
            for _ in 0..<maxConcurrentTasks {
                if !pendingIds.isEmpty {
                    let id = pendingIds.removeFirst()
                    await updateState(id: id, state: .downloading)
                    
                    group.addTask {
                        await self.downloadWorker(id: id)
                        return id // Trả về ID khi tải xong
                    }
                }
            }
            
            // 2. DUY TRÌ: Cứ 1 task chạy xong, báo Done và nhét thêm 1 task mới vào
            for await completedId in group {
                // Cập nhật UI thành chữ "Done"
                await updateState(id: completedId, state: .done)
                
                // Nếu vẫn còn ảnh chưa tải, bơm ngay vào vị trí vừa trống
                if !pendingIds.isEmpty {
                    let nextId = pendingIds.removeFirst()
                    await updateState(id: nextId, state: .downloading)
                    
                    group.addTask {
                        await self.downloadWorker(id: nextId)
                        return nextId
                    }
                }
            }
        }
    }
    
    // Cập nhật trạng thái an toàn trên Main Thread
    private func updateState(id: Int, state: DownloadState) async {
        self.items[id].state = state
    }
    
    // Hàm worker thực thi việc tải dữ liệu (Chạy trên Background Thread)
    private nonisolated func downloadWorker(id: Int) async {
        // Random thời gian tải từ 1 đến 5 giây
        let delayInSeconds = UInt64.random(in: 1...5)
        
        // Task.sleep không hề block thread hệ thống, nó chỉ tạm ngưng Task hiện tại
        try? await Task.sleep(nanoseconds: delayInSeconds * 1_000_000_000)
    }
}

// MARK: - 3. Giao diện hiển thị
struct ConcurrentImageGrid: View {
    @StateObject private var viewModel = ImageLoaderViewModel()
    
    // Khai báo layout 4 cột linh hoạt
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
    
    var body: some View {
        VStack {
            // Nút điều khiển
            Button(action: {
                viewModel.startDownloading()
            }) {
                Text("Bắt Đầu Tải Ảnh")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding()
            
            // Lưới hiển thị 100 items
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(viewModel.items) { item in
                        ItemCellView(item: item)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Max 3 Threads")
    }
}

// MARK: - 4. Giao diện từng ô (Cell)
struct ItemCellView: View {
    let item: ImageItem
    
    var body: some View {
        ZStack {
            // Hình nền thay đổi theo trạng thái
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .aspectRatio(1, contentMode: .fit) // Ép khung hình vuông
            
            VStack(spacing: 8) {
                Text("Ảnh \(item.id)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                // Hiển thị vòng xoay nếu đang tải, hoặc chữ "Done" nếu tải xong
                if item.state == .downloading {
                    ProgressView()
                        .tint(.white)
                } else if item.state == .done {
                    Text("Done")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.white)
                }
            }
        }
        .animation(.easeInOut, value: item.state)
    }
    
    // Logic đổi màu nền
    var backgroundColor: Color {
        switch item.state {
        case .waiting:
            return Color.gray.opacity(0.3)
        case .downloading:
            return Color.orange
        case .done:
            return Color.green
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        ConcurrentImageGrid()
    }
}
