import Foundation
import UIKit
import Combine

class BackgroundUploadManager: NSObject, ObservableObject {
    static let shared = BackgroundUploadManager()
    
    @Published var progress: Double = 0.0
    @Published var isUploading: Bool = false
    @Published var statusMessage: String = "Chưa bắt đầu"
    
    let sessionIdentifier = "com.myapp.backgroundUpload"
    private var session: URLSession!
    
    // ĐIỀN API KEY CỦA BẠN TỪ IMGBB VÀO ĐÂY
    private let imgbbAPIKey = "2a885ba734fdaba6b9df6117adced097"
    
    override private init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        let config = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        config.isDiscretionary = false // Chạy ngay khi có thể để dễ test
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    // Đổi tên hàm và thêm tham số truyền vào là imageData
    func startUpload(with imageData: Data) {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        // 1. Đóng gói dữ liệu thành chuẩn multipart/form-data và ghi ra file
        guard let fileURL = createMultipartFile(imageData: imageData, boundary: boundary) else {
            self.statusMessage = "Lỗi tạo file upload"
            return
        }
        
        // 2. Tạo Request gửi đến ImgBB
        guard let url = URL(string: "https://api.imgbb.com/1/upload") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 3. Khởi tạo Upload Task từ file tạm
        let task = session.uploadTask(with: request, fromFile: fileURL)
        
        DispatchQueue.main.async {
            self.isUploading = true
            self.statusMessage = "Đang tải ảnh lên ImgBB..."
            self.progress = 0.0
        }
        
        task.resume()
    }
    
    // MARK: - Helper: Tạo file Multipart
    /// Hàm này tạo ra cấu trúc thân (body) của HTTP Request và lưu thành file vật lý
    private func createMultipartFile(imageData: Data, boundary: String) -> URL? {
        var bodyData = Data()
        
        // Thêm trường API Key
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"key\"\r\n\r\n".data(using: .utf8)!)
        bodyData.append("\(imgbbAPIKey)\r\n".data(using: .utf8)!)
        
        // Thêm trường dữ liệu Ảnh
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"image\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        bodyData.append(imageData)
        bodyData.append("\r\n".data(using: .utf8)!)
        
        // Đóng boundary kết thúc
        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Lưu toàn bộ data này ra một file tạm
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("upload_multipart_\(UUID().uuidString).tmp")
        
        do {
            try bodyData.write(to: fileURL)
            return fileURL
        } catch {
            print("Lỗi ghi file multipart: \(error)")
            return nil
        }
    }
}

// MARK: - URLSessionTaskDelegate
extension BackgroundUploadManager: URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let currentProgress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        DispatchQueue.main.async {
            self.progress = currentProgress
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            self.isUploading = false
            if let error = error {
                self.statusMessage = "Lỗi: \(error.localizedDescription)"
            } else {
                self.statusMessage = "Tải ảnh thành công! (Chạy ngầm)"
            }
        }
        
        // (Tùy chọn) Xóa file tạm sau khi upload xong để giải phóng bộ nhớ
        if let originalRequest = task.originalRequest,
           let originalFile = originalRequest.url {
            try? FileManager.default.removeItem(at: originalFile)
        }
    }
}
