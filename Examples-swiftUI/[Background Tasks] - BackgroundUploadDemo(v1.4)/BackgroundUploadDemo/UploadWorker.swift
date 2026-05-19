import Foundation

class UploadWorker: NSObject {
    static let shared = UploadWorker()
    let sessionID = "com.myapp.imgbbUploadWorker"
    private var session: URLSession!
    
    override private init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: sessionID)
        config.isDiscretionary = false
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    // Nhận file multipart từ Điều phối và ID của ảnh
    func upload(multipartFileURL: URL, itemID: String) {
        guard let url = URL(string: "https://api.imgbb.com/1/upload") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Extract boundary từ tên file hoặc tự định nghĩa lại (để đơn giản, ta cố định boundary khi tạo file)
        let boundary = "Boundary-\(itemID)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let task = session.uploadTask(with: request, fromFile: multipartFileURL)
        
        // ĐIỂM CHỐT LÕI: Gán ID vào task
        task.taskDescription = itemID
        task.resume()
        
        UploadQueue.shared.updateStatus(id: itemID, newStatus: .uploading)
    }
}

extension UploadWorker: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Đọc lại ID từ task
        guard let itemID = task.taskDescription else { return }
        
        // Cập nhật trạng thái
        if let error = error {
            print("Lỗi upload task \(itemID): \(error)")
            UploadQueue.shared.updateStatus(id: itemID, newStatus: .failed)
        } else {
            print("✅ Upload thành công task \(itemID)!")
            UploadQueue.shared.updateStatus(id: itemID, newStatus: .success)
        }
        
        // Xóa file multipart tạm sau khi xong (Tiết kiệm bộ nhớ)
        if let tempFile = task.originalRequest?.url {
            try? FileManager.default.removeItem(at: tempFile)
        }
    }
}
