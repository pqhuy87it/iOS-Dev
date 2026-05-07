import SwiftUI
import BackgroundTasks

@main
struct BackgroundUploadDemoApp: App {
    // Kết nối AppDelegate vào SwiftUI
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @Environment(\.scenePhase) private var phase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Khi app xuống nền, nhắc Người Điều Phối nhớ đặt báo thức
        .onChange(of: phase) { newPhase in
            if newPhase == .background {
                ProcessingCoordinator.scheduleNextTask()
            }
        }
        
        // CHỈ GIỮ LẠI ĐIỂM NEO CHO CÔNG NHÂN (URLSession)
        .backgroundTask(.urlSession(UploadWorker.shared.sessionID)) {
            print("🔄 OS đánh thức app vì Công nhân đã làm xong việc ngầm!")
            let _ = await UploadWorker.shared
        }
    }
}
