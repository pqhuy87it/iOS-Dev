import Foundation
import BackgroundTasks
import Combine

// MARK: - 1. KHO CHỨA VIỆC (The Queue)
/// Quản lý danh sách các file cần upload, lưu vào UserDefaults để sống sót khi app bị kill
class UploadQueue {
    static let shared = UploadQueue()
    private let queueKey = "pending_upload_files"
    
    // Lấy danh sách file đang chờ
    func getPendingFiles() -> [URL] {
        guard let paths = UserDefaults.standard.stringArray(forKey: queueKey) else { return [] }
        return paths.map { URL(fileURLWithPath: $0) }
    }
    
    // Thêm việc vào kho
    func enqueueFile(fileURL: URL) {
        var current = UserDefaults.standard.stringArray(forKey: queueKey) ?? []
        if !current.contains(fileURL.path) {
            current.append(fileURL.path)
            UserDefaults.standard.setValue(current, forKey: queueKey)
        }
    }
    
    // Xóa việc khỏi kho khi đã xong
    func removeCompletedFile(fileURL: URL) {
        var current = UserDefaults.standard.stringArray(forKey: queueKey) ?? []
        current.removeAll { $0 == fileURL.path }
        UserDefaults.standard.setValue(current, forKey: queueKey)
    }
}

// MARK: - 2. CÔNG NHÂN (The Worker - URLSession)
/// Chịu trách nhiệm thực sự đẩy data lên mạng. Cứ làm, không quan tâm app sống hay chết.
class UploadWorker: NSObject, ObservableObject {
    static let shared = UploadWorker()
    
    @Published var activeUploadsCount: Int = 0
    let sessionID = "com.phuy.myapp.backgroundWorker"
    private var session: URLSession!
    
    override private init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: sessionID)
        config.isDiscretionary = false // Trong thực tế có thể set true để tiết kiệm pin
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    /// Nhận task từ Người Điều Phối và đẩy vào queue của hệ điều hành
    func upload(fileURL: URL) {
        guard let targetURL = URL(string: "https://httpbin.org/post") else { return }
        var request = URLRequest(url: targetURL)
        request.httpMethod = "POST"
        
        // Khởi tạo task từ file. LÚC NÀY OS SẼ TIẾP QUẢN!
        let task = session.uploadTask(with: request, fromFile: fileURL)
        task.resume()
        
        DispatchQueue.main.async {
            self.activeUploadsCount += 1
        }
        print("👷‍♂️ Công nhân: Đã nhận file \(fileURL.lastPathComponent) và bắt đầu đẩy lên mạng.")
    }
}

// Xử lý callback của Công nhân
extension UploadWorker: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let originalURL = task.originalRequest?.url else { return }
        // Lưu ý: task.originalRequest?.url thường là URL của API, không phải file nội bộ.
        // Để lấy file nội bộ, cần tracking qua task.taskDescription hoặc map quản lý riêng.
        // Ở đây đơn giản hóa bằng cách clear toàn bộ queue nếu gọi test thành công.
        
        DispatchQueue.main.async {
            self.activeUploadsCount = max(0, self.activeUploadsCount - 1)
        }
        
        if let error = error {
            print("👷‍♂️ Công nhân: Lỗi upload - \(error.localizedDescription)")
        } else {
            print("👷‍♂️ Công nhân: ✅ Upload Xong 1 task. Vẫn âm thầm làm tiếp nếu còn việc.")
            // (Thực tế bạn sẽ map lại để tìm ra fileURL và gọi UploadQueue.shared.removeCompletedFile)
        }
    }
}

// MARK: - 3. NGƯỜI ĐIỀU PHỐI (The Coordinator - BGProcessingTask)
/// Thức dậy, check Kho, ném cho Công nhân, đi ngủ.
struct ProcessingCoordinator {
    static let taskID = "com.phuy.myapp.nightlySync"
    
    static func scheduleNextTask() {
        let request = BGProcessingTaskRequest(identifier: taskID)
        // Yêu cầu máy phải cắm sạc và có mạng wifi (rất phù hợp để đồng bộ ban đêm)
        request.requiresExternalPower = true
        request.requiresNetworkConnectivity = true
        
        // Cài đặt báo thức (Ví dụ: ít nhất 1 tiếng sau mới được chạy)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("👔 Điều phối: Đã đặt báo thức lịch check DB cho lần tới.")
        } catch {
            print("👔 Điều phối: ❌ Không thể đặt báo thức: \(error)")
        }
    }
    
    static func handleNightlySync() async {
        print("👔 Điều phối: Ngáp... Đang thức dậy để check Kho...")
        
        // 1. Đọc Kho
        let pendingFiles = UploadQueue.shared.getPendingFiles()
        print("👔 Điều phối: Tìm thấy \(pendingFiles.count) file cần upload.")
        
        // 2. Ném việc cho Công nhân
        for file in pendingFiles {
            UploadWorker.shared.upload(fileURL: file)
            // Đánh dấu là đã giao việc để lần sau không giao trùng (Đơn giản hóa: xóa luôn khỏi kho)
            UploadQueue.shared.removeCompletedFile(fileURL: file)
        }
        
        // 3. Đặt báo thức cho đêm mai
        scheduleNextTask()
        
        // 4. Báo cáo xong việc (Trả về luồng ngay lập tức trong vài mili-giây)
        print("👔 Điều phối: Đã giao xong việc cho Công nhân. Đi ngủ tiếp đây 💤")
    }
}
