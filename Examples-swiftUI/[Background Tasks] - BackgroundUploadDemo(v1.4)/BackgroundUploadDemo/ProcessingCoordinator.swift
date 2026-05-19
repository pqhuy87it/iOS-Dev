import Foundation
import BackgroundTasks

struct ProcessingCoordinator {
    static let taskID = "com.myapp.imgbbSync"
    
    // Thay API KEY của bạn vào đây
    static let imgbbAPIKey = "2a885ba734fdaba6b9df6117adced097"
    
    static func scheduleNextTask() {
        let request = BGProcessingTaskRequest(identifier: taskID)
        request.requiresExternalPower = false // Set false để test dễ hơn
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15) // Thử gọi lại sau 15s
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Lỗi đặt báo thức: \(error)")
        }
    }
    
    static func handleNightlySync() async {
        let pendingItems = UploadQueue.shared.getPendingItems()
        guard !pendingItems.isEmpty else { return }
        
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tempDir = FileManager.default.temporaryDirectory
        
        for item in pendingItems {
            let originalFileURL = docDir.appendingPathComponent(item.localFileName)
            
            // Đọc data ảnh gốc
            guard let imageData = try? Data(contentsOf: originalFileURL) else { continue }
            
            // Tạo file multipart
            let boundary = "Boundary-\(item.id)"
            let multipartFileURL = tempDir.appendingPathComponent("upload_\(item.id).tmp")
            
            if createMultipartFile(imageData: imageData, boundary: boundary, fileURL: multipartFileURL) {
                // Giao cho Công nhân
                UploadWorker.shared.upload(multipartFileURL: multipartFileURL, itemID: item.id)
            }
        }
        
        scheduleNextTask()
    }
    
    // Logic tạo file multipart form data
    private static func createMultipartFile(imageData: Data, boundary: String, fileURL: URL) -> Bool {
        var bodyData = Data()
        
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"key\"\r\n\r\n".data(using: .utf8)!)
        bodyData.append("\(imgbbAPIKey)\r\n".data(using: .utf8)!)
        
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        bodyData.append(imageData)
        bodyData.append("\r\n".data(using: .utf8)!)
        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        do {
            try bodyData.write(to: fileURL)
            return true
        } catch {
            return false
        }
    }
}
