import Foundation
import Combine

class BackgroundUploadManager: NSObject, ObservableObject {
    static let shared = BackgroundUploadManager() // Dùng Singleton để đảm bảo delegate luôn sống
    
    @Published var progress: Double = 0.0
    @Published var isUploading: Bool = false
    @Published var statusMessage: String = "Chưa bắt đầu"
    
    // Định danh này phải khớp với App.swift
    let sessionIdentifier = "com.myapp.backgroundUpload"
    private var session: URLSession!
    
    override private init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        // Cấu hình URLSession chạy ngầm
        let config = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        
        // Cờ này cho phép hệ thống tự quyết định thời điểm tối ưu để upload (dựa vào pin, wifi...)
        // Khi test trên máy thật, bạn có thể set = false để nó chạy ngay lập tức.
        config.isDiscretionary = false
        
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func startUpload() {
        // 1. Tạo một file tạm để giả lập việc upload
        guard let fileURL = createDummyFile() else { return }
        
        // 2. Tạo Request (Dùng httpbin để test API nhận POST request)
        guard let url = URL(string: "https://httpbin.org/post") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 3. Khởi tạo Upload Task bằng FILE (Bắt buộc với Background Session)
        let task = session.uploadTask(with: request, fromFile: fileURL)
        
        DispatchQueue.main.async {
            self.isUploading = true
            self.statusMessage = "Đang tải lên..."
            self.progress = 0.0
        }
        
        task.resume()
    }
    
    // Hàm tạo file text giả lập dung lượng khoảng 5MB để thấy được thanh progress chạy
    private func createDummyFile() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_upload.txt")
        let dummyText = String(repeating: "Hello SwiftUI Background Upload. ", count: 100_000)
        
        do {
            try dummyText.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Lỗi tạo file: \(error)")
            return nil
        }
    }
}

// MARK: - URLSessionTaskDelegate
extension BackgroundUploadManager: URLSessionTaskDelegate {
    
    // Lắng nghe tiến độ Upload
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let currentProgress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        
        // Cập nhật UI phải ở Main Thread
        DispatchQueue.main.async {
            self.progress = currentProgress
        }
    }
    
    // Khi Task hoàn thành (thành công hoặc thất bại)
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            self.isUploading = false
            if let error = error {
                self.statusMessage = "Lỗi: \(error.localizedDescription)"
            } else {
                self.statusMessage = "Tải lên thành công! (Chạy ngầm)"
            }
        }
    }
}
