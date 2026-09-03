//
//  IconSyncService.swift
//  Tầng vận chuyển: background URLSession + xử lý silent push.
//

import Foundation
import UIKit
import CryptoKit
import Combine

// MARK: - Cấu hình server (đổi thành endpoint của bạn)

enum SyncConfig {
    /// Xem README để chạy local server thử: python3 -m http.server 8000
    static let manifestURL = URL(string: "http://192.168.1.10:8000/manifest.json")!
}

// MARK: - Service

final class IconSyncService: NSObject {

    static let shared = IconSyncService()

    /// Một identifier chỉ được tồn tại ĐÚNG MỘT session instance trong process.
    /// Tạo lần thứ hai với cùng ID → crash.
    static let sessionIdentifier = "com.exchain.iconsync.bg"

    private let store = IconStore.shared

    /// Handler mà iOS đưa cho ta ở `handleEventsForBackgroundURLSession`.
    /// Phải gọi nó, nếu không watchdog kill app.
    var backgroundCompletionHandler: (() -> Void)?

    /// Cho UI observe tiến trình.
    let progress = SyncProgress()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)

        // sessionSendsLaunchEvents = true → cho phép iOS relaunch app khi xong.
        // Bỏ dòng này thì app sẽ KHÔNG được đánh thức.
        config.sessionSendsLaunchEvents = true

        // ⚠️ Chỉ có hiệu lực với task tạo lúc app ở FOREGROUND.
        // Task tạo từ silent push (app đang ở background) LUÔN là discretionary,
        // bất kể dòng này — hệ thống chờ WiFi + sạc + máy rảnh, có thể hàng giờ.
        config.isDiscretionary = false

        // Tôn trọng lựa chọn của user. Bỏ qua Low Data Mode là cách nhanh nhất
        // để bị uninstall.
        config.allowsCellularAccess = true
        config.allowsConstrainedNetworkAccess = false   // Low Data Mode
        config.allowsExpensiveNetworkAccess = false     // hotspot / 5G đắt

        // Mặc định của background session là 7 NGÀY, không phải vô hạn.
        config.timeoutIntervalForResource = 60 * 60 * 12

        config.httpMaximumConnectionsPerHost = 4

        // delegateQueue: nil → URLSession tự tạo serial queue nền.
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    /// Chạm vào `session` để nó được khởi tạo và delegate bắt đầu nhận callback.
    /// Bắt buộc gọi ở `didFinishLaunching` và ở `handleEventsForBackgroundURLSession`.
    func warmUp() {
        _ = session
        Logger.shared.log("warmUp — session sống, delegate đã gắn")
    }

    // MARK: - Silent push entry point

    /// Trả về UIBackgroundFetchResult TRUNG THỰC.
    /// Hệ thống dùng chính tín hiệu này để điều chỉnh ngân sách push lần sau.
    /// Cứ trả .newData khi không có gì mới = tự bóp ngân sách của mình.
    func handleSilentPush(_ userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        Logger.shared.log("📨 silent push nhận được: \(userInfo["sync"] ?? "-")")

        // Optimisation: server gửi kèm version. Nếu bằng version local thì
        // khỏi cần gọi mạng.
        if let sync = userInfo["sync"] as? [String: Any],
           let remoteVersion = sync["version"] as? Int,
           remoteVersion <= store.manifestVersion {
            Logger.shared.log("↩️ version \(remoteVersion) không mới hơn local, bỏ qua")
            return .noData
        }

        return await syncNow(reason: "silent push")
    }

    // MARK: - Core sync

    /// Có thể gọi từ nhiều nguồn: silent push, foreground, pull-to-refresh,
    /// BGAppRefreshTask. Cùng một đường, khác nhau chỉ ở trigger.
    @discardableResult
    func syncNow(reason: String) async -> UIBackgroundFetchResult {
        await MainActor.run { progress.isSyncing = true }
        defer { Task { @MainActor in progress.isSyncing = false } }

        Logger.shared.log("🔄 syncNow — trigger: \(reason)")

        do {
            let manifest = try await fetchManifest()
            let needed = store.reconcile(manifest: manifest)

            guard !needed.isEmpty else {
                Logger.shared.log("✅ manifest v\(manifest.version) — không có icon mới")
                await refreshUI()
                return .noData
            }

            Logger.shared.log("⬇️ cần tải \(needed.count) icon → enqueue vào background session")
            for entry in needed { enqueue(entry) }
            await refreshUI()
            return .newData

        } catch {
            Logger.shared.log("❌ sync lỗi: \(error.localizedDescription)")
            return .failed
        }
    }

    /// Manifest nhỏ (JSON vài KB) nên dùng session thường, chạy ngay trong
    /// cửa sổ ~30s của silent push. Chỉ FILE LỚN mới đưa cho background session.
    private func fetchManifest() async throws -> IconManifest {
        var request = URLRequest(url: SyncConfig.manifestURL)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SyncError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(IconManifest.self, from: data)
    }

    private func enqueue(_ entry: IconEntry) {
        let task = session.downloadTask(with: entry.url)
        // taskDescription là thứ DUY NHẤT sống sót qua việc app bị relaunch.
        // Không set → sau relaunch bạn không biết task này là của icon nào.
        task.taskDescription = entry.id
        task.resume()
    }

    // MARK: - Force-quit recovery

    /// Nếu user force-quit app, iOS CANCEL toàn bộ transfer và KHÔNG relaunch.
    /// Nên mỗi lần app khởi động phải đối chiếu: cái nào ghi là `pending`
    /// mà không còn task tương ứng → đã bị huỷ, enqueue lại.
    func reconcileOnLaunch() {
        session.getAllTasks { [weak self] tasks in
            guard let self else { return }

            let inFlight = Set(tasks.compactMap(\.taskDescription))
            let orphaned = self.store.pendingIDs.subtracting(inFlight)

            if !orphaned.isEmpty {
                Logger.shared.log("♻️ \(orphaned.count) task mồ côi (force-quit?) → enqueue lại")
                for id in orphaned {
                    if let record = self.store.record(for: id) {
                        self.enqueue(record.entry)
                    }
                }
            } else {
                Logger.shared.log("♻️ reconcile — \(tasks.count) task đang chạy, không có mồ côi")
            }

            // Có staged còn tồn (app bị kill trước khi install) thì install nốt.
            let installed = self.store.installStaged()
            if installed > 0 {
                Logger.shared.log("📦 install nốt \(installed) icon staged từ phiên trước")
            }
            Task { await self.refreshUI() }
        }
    }

    @MainActor
    private func refreshUI() {
        progress.reload()
    }
}

// MARK: - URLSessionDownloadDelegate

extension IconSyncService: URLSessionDownloadDelegate {

    /// ⚠️ File tạm bị XOÁ ngay khi hàm này return.
    /// Phải move SYNCHRONOUSLY tại đây. Dispatch async ra queue khác = mất file.
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {

        guard let id = downloadTask.taskDescription else {
            Logger.shared.log("⚠️ task không có taskDescription, bỏ")
            return
        }

        // Bẫy hay bị bỏ: didFinishDownloadingTo VẪN được gọi khi server trả
        // 404 hoặc 500 — body lỗi được coi là "download thành công".
        // Không check status code thì bạn install một trang HTML làm icon.
        if let http = downloadTask.response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            store.markFailed(id, reason: "HTTP \(http.statusCode)")
            Logger.shared.log("❌ \(id): HTTP \(http.statusCode)")
            return
        }

        let dest = store.stagingURL(for: id)
        do {
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: location, to: dest)
            store.markStaged(id)
            Logger.shared.log("✅ \(id) → staging")
        } catch {
            store.markFailed(id, reason: error.localizedDescription)
            Logger.shared.log("❌ \(id) move lỗi: \(error.localizedDescription)")
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {

        let id = task.taskDescription ?? "?"
        guard let error = error as NSError? else { return }

        // iOS cho biết CHÍNH XÁC vì sao transfer bị huỷ.
        if let reason = error.userInfo[NSURLErrorBackgroundTaskCancelledReasonKey] as? Int {
            switch reason {
            case NSURLErrorCancelledReasonUserForceQuitApplication:
                Logger.shared.log("🚫 \(id): user force-quit app → iOS huỷ transfer")
            case NSURLErrorCancelledReasonBackgroundUpdatesDisabled:
                Logger.shared.log("🚫 \(id): user tắt Background App Refresh")
            case NSURLErrorCancelledReasonInsufficientSystemResources:
                Logger.shared.log("🚫 \(id): hệ thống thiếu tài nguyên")
            default:
                Logger.shared.log("🚫 \(id): huỷ, reason \(reason)")
            }
            store.markFailed(id, reason: "cancelled(\(reason))")
            return
        }

        store.markFailed(id, reason: error.localizedDescription)
        Logger.shared.log("❌ \(id) lỗi: \(error.localizedDescription)")
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        // Chỉ log ở foreground cho đỡ rác; ở background không ai xem.
        guard totalBytesExpectedToWrite > 0 else { return }
        let pct = Int(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) * 100)
        if pct % 50 == 0 {
            Logger.shared.log("… \(downloadTask.taskDescription ?? "?") \(pct)%")
        }
    }

    /// Gọi MỘT LẦN sau khi mọi task xong, chỉ khi app được đánh thức để giao kết quả.
    /// Đây là nơi duy nhất được gọi backgroundCompletionHandler.
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Logger.shared.log("🏁 didFinishEvents — install staged rồi trả handler")

        // Icon = move file, rất rẻ, làm luôn trong wake window được.
        // Nếu là merge Core Data thì ở đây chỉ ghi marker + submit BGProcessingTask.
        let installed = store.installStaged()
        Logger.shared.log("📦 installed \(installed) icon")

        DispatchQueue.main.async {
            self.progress.reload()
            // BẮT BUỘC main thread. BẮT BUỘC gọi. Quên → watchdog kill app.
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}

// MARK: - Phụ trợ

enum SyncError: LocalizedError {
    case badStatus(Int)
    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "Server trả HTTP \(code)"
        }
    }
}

@MainActor
final class SyncProgress: ObservableObject {
    @Published var isSyncing = false
    @Published var icons: [(id: String, url: URL)] = []
    @Published var records: [String: IconRecord] = [:]

    func reload() {
        icons = IconStore.shared.installedIcons
        records = IconStore.shared.snapshot()
    }
}

enum SHA256Digest {
    static func hexString(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
