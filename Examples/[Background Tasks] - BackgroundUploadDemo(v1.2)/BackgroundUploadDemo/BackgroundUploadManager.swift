import Foundation
import Combine

class BackgroundUploadManager: NSObject, ObservableObject {
    static let shared = BackgroundUploadManager()
    
    @Published var progress: Double = 0.0
    @Published var isUploading: Bool = false
    @Published var statusMessage: String = "Chưa bắt đầu"
    
    let sessionIdentifier = "com.myapp.heavyBackgroundUpload"
    private var session: URLSession!
    
    override private init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        let config = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        // BẮT BUỘC = false để ép hệ thống chạy upload ngay lập tức, không chờ Wi-Fi hay sạc pin
        config.isDiscretionary = false
        
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func startHeavyUpload() {
        self.statusMessage = "Đang tạo file 30MB..."
        
        // 1. Tạo file 30MB để thời gian upload đủ lâu để chúng ta test
        guard let fileURL = createHeavyDummyFile() else {
            self.statusMessage = "Lỗi tạo file"
            return
        }
        
        // 2. Tạo Request
        guard let url = URL(string: "https://httpbin.org/post") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 3. Khởi tạo Upload Task từ file
        let task = session.uploadTask(with: request, fromFile: fileURL)
        
        DispatchQueue.main.async {
            self.isUploading = true
            self.statusMessage = "Đang tải lên HTTPBin..."
            self.progress = 0.0
        }
        
        task.resume()
    }
    
    private func createHeavyDummyFile() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("heavy_test.dat")
        
        // Tạo khoảng 30MB data ngẫu nhiên
        let sizeInBytes = 30 * 1024 * 1024
        var data = Data(count: sizeInBytes)
        
        // Làm data thay đổi một chút để tránh bị nén quá mức ở tầng network
        for i in 0..<1000 {
            data[i] = UInt8.random(in: 0...255)
        }
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
}

extension BackgroundUploadManager: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let currentProgress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        DispatchQueue.main.async {
            self.progress = currentProgress
        }
        // In log ra để theo dõi trên Console nếu còn gắn cáp
        print("Tiến độ: \(currentProgress * 100)%")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            self.isUploading = false
            if let error = error {
                self.statusMessage = "Lỗi: \(error.localizedDescription)"
                print("Lỗi Upload: \(error)")
            } else {
                self.statusMessage = "Hoàn thành lúc: \(Date().formatted(date: .omitted, time: .standard))"
                print("✅ Upload xong hoàn toàn!")
            }
        }
    }
}
