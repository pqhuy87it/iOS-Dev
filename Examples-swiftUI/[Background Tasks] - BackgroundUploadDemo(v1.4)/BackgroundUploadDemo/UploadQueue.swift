import Foundation
import SwiftUI
import Combine

// Trạng thái của từng ảnh
enum UploadStatus: String, Codable {
    case pending = "Chờ xử lý"
    case uploading = "Đang tải lên..."
    case success = "Thành công"
    case failed = "Lỗi"
}

// Model đại diện cho 1 ảnh
struct UploadItem: Identifiable, Codable {
    let id: String // Dùng làm taskDescription
    let localFileName: String // Tên file lưu trong thư mục Documents
    var status: UploadStatus
}

class UploadQueue: ObservableObject {
    static let shared = UploadQueue()
    private let queueKey = "my_upload_queue"
    
    // UI sẽ lắng nghe biến này để cập nhật dấu tích xanh
    @Published var items: [UploadItem] = []
    
    init() {
        loadQueue()
    }
    
    // Đọc data từ UserDefaults
    func loadQueue() {
        if let data = UserDefaults.standard.data(forKey: queueKey),
           let saved = try? JSONDecoder().decode([UploadItem].self, from: data) {
            self.items = saved
        }
    }
    
    // Lưu data
    private func saveQueue() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
    }
    
    // Thêm ảnh mới vào hàng đợi
    func addItem(imageData: Data) {
        let id = UUID().uuidString
        let fileName = "\(id).jpg"
        
        // Lưu ảnh gốc vào Documents Directory để hệ điều hành không xóa mất
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        try? imageData.write(to: fileURL)
        
        let newItem = UploadItem(id: id, localFileName: fileName, status: .pending)
        DispatchQueue.main.async {
            self.items.append(newItem)
            self.saveQueue()
        }
    }
    
    // Cập nhật trạng thái (Dùng khi task hoàn thành)
    func updateStatus(id: String, newStatus: UploadStatus) {
        DispatchQueue.main.async {
            if let index = self.items.firstIndex(where: { $0.id == id }) {
                self.items[index].status = newStatus
                self.saveQueue()
            }
        }
    }
    
    func getPendingItems() -> [UploadItem] {
        return items.filter { $0.status == .pending || $0.status == .failed }
    }
}
