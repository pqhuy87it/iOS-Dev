import UIKit
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Đăng ký Người điều phối (BGProcessingTask) theo cách truyền thống
        BGTaskScheduler.shared.register(forTaskWithIdentifier: ProcessingCoordinator.taskID, using: nil) { task in
            // Ép kiểu về BGProcessingTask
            guard let processingTask = task as? BGProcessingTask else { return }
            self.handleProcessingTask(task: processingTask)
        }
        
        return true
    }
    
    private func handleProcessingTask(task: BGProcessingTask) {
        // 1. LUÔN LUÔN phải có block này đề phòng hệ điều hành đổi ý, bắt app dừng lại sớm
        task.expirationHandler = {
            print("👔 Điều phối: Bị hệ điều hành cắt ngang, phải đi ngủ sớm!")
            // Nếu đang gọi API dở dang thì cancel ở đây
        }
        
        // 2. Chạy logic bất đồng bộ (async/await)
        Task {
            await ProcessingCoordinator.handleNightlySync()
            
            // 3. BẮT BUỘC: Báo cáo với hệ điều hành là đã xong việc để trả lại RAM
            task.setTaskCompleted(success: true)
        }
    }
}
