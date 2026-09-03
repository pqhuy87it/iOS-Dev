//
//  IconSyncDemoApp.swift
//  Entry point + AppDelegate.
//
//  Ba hook BẮT BUỘC, thiếu một là hệ thống hỏng ngầm:
//    1. didFinishLaunching                     → warmUp + reconcile
//    2. didReceiveRemoteNotification:fetch...  → silent push
//    3. handleEventsForBackgroundURLSession    → nhận kết quả sau relaunch
//

import SwiftUI
import UIKit
import UserNotifications

@main
struct BackgroundURLSessionDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        Logger.shared.log("🚀 didFinishLaunching (state: \(application.applicationState.name))")

        // 1. Tái tạo session + gắn delegate NGAY. Nếu app được relaunch để giao
        //    kết quả download, callback sẽ không chảy về nếu chưa có delegate.
        IconSyncService.shared.warmUp()

        // 2. Đối chiếu state: phát hiện transfer bị huỷ do force-quit, install nốt staged.
        IconSyncService.shared.reconcileOnLaunch()

        // 3. Silent push KHÔNG cần quyền notification của user —
        //    chỉ cần registerForRemoteNotifications().
        //    (Xin quyền ở đây chỉ để demo alert push nếu bạn muốn thử thêm.)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        application.registerForRemoteNotifications()

        return true
    }

    // MARK: - Device token

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Logger.shared.log("🔑 device token: \(token)")
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.shared.log("🔑 register push lỗi: \(error.localizedDescription)")
    }

    // MARK: - Silent push
    //
    // Callback này nằm trên UIApplicationDelegate, KHÔNG đi qua
    // UNUserNotificationCenterDelegate. Rất nhiều người tìm sai chỗ.
    //
    // Ta có ~30 giây và BẮT BUỘC gọi completionHandler đúng một lần.

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard userInfo["sync"] != nil else {
            Logger.shared.log("📨 push không phải icon-sync → noData")
            completionHandler(.noData)
            return
        }

        // Chốt an toàn: nếu vì lý do gì đó ta không kịp trả lời trong 25s,
        // tự gọi .failed. Không gọi completionHandler = watchdog kill app.
        let guardTask = DispatchWorkItem {
            Logger.shared.log("⏰ hết thời gian silent push → failed")
            completionHandler(.failed)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: guardTask)

        Task {
            let result = await IconSyncService.shared.handleSilentPush(userInfo)
            guard !guardTask.isCancelled else { return }
            guardTask.cancel()
            Logger.shared.log("📨 silent push trả về: \(result.name)")
            completionHandler(result)
        }
    }

    // MARK: - Background URLSession events
    //
    // iOS gọi hàm này khi app được relaunch/resume để giao kết quả transfer.
    // Chỉ làm 2 việc: giữ handler, tái tạo session. Không xử lý gì nặng ở đây.

    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {

        Logger.shared.log("🌙 handleEventsForBackgroundURLSession: \(identifier)")

        guard identifier == IconSyncService.sessionIdentifier else {
            completionHandler()
            return
        }

        // Giữ lại, CHƯA gọi. Nó sẽ được gọi trong urlSessionDidFinishEvents.
        IconSyncService.shared.backgroundCompletionHandler = completionHandler
        IconSyncService.shared.warmUp()
    }
}

// MARK: - Debug helper

extension UIApplication.State {
    var name: String {
        switch self {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }
}

extension UIBackgroundFetchResult {
    var name: String {
        switch self {
        case .newData: return "newData"
        case .noData: return "noData"
        case .failed: return "failed"
        @unknown default: return "unknown"
        }
    }
}
