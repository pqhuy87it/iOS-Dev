//
//  SyncEngine.swift
//  Trái tim của demo.
//
//  KIẾN TRÚC CONCURRENCY — đọc kỹ chỗ này, đây là lý do class không phải @MainActor:
//
//  `expirationHandler` được iOS gọi trên main thread và ta chỉ còn VÀI GIÂY.
//  Nếu class là @MainActor thì từ trong closure đó ta phải `Task { @MainActor in ... }`,
//  tức là XẾP HÀNG công việc async — và có thể app bị suspend trước khi nó chạy.
//  Nên state tối quan trọng (bgTaskID, task handle) phải sửa được ĐỒNG BỘ
//  từ bất kỳ đâu → lock. UI thì publish riêng qua main queue.
//

import Foundation
import UIKit

// MARK: - Telemetry

struct BackgroundGrant: Codable, Identifiable {
    var id: Date { startedAt }
    let startedAt: Date
    /// backgroundTimeRemaining đọc được NGAY khi vào background.
    let reportedAtEntry: TimeInterval
    /// Thời gian thực tế từ lúc vào background đến lúc expirationHandler bắn.
    let actualUntilExpiration: TimeInterval?
    /// Nếu upload xong trước khi hết giờ thì đây là thời gian đã dùng.
    let finishedAfter: TimeInterval?
    let lowPowerMode: Bool
    let batchesUploadedInBackground: Int
}

final class BackgroundBudgetLog {
    static let shared = BackgroundBudgetLog()
    private let key = "background.grants.v1"

    func all() -> [BackgroundGrant] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([BackgroundGrant].self, from: data)
        else { return [] }
        return decoded.sorted { $0.startedAt > $1.startedAt }
    }

    func append(_ grant: BackgroundGrant) {
        var list = all()
        list.insert(grant, at: 0)
        list = Array(list.prefix(30))
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func clear() { UserDefaults.standard.removeObject(forKey: key) }
}

// MARK: - Engine

final class SyncEngine: ObservableObject {

    static let shared = SyncEngine()

    // Cấu hình
    var batchSize = 100
    var simulatedLatency: TimeInterval = 1.5
    var failureRate: Double = 0
    var useRealServer = false
    var serverURL = URL(string: "http://192.168.1.10:8000/upload")!

    // UI state — chỉ được sửa trên main thread
    @Published private(set) var isRunning = false
    @Published private(set) var totalRecords = 0
    @Published private(set) var syncedRecords = 0
    @Published private(set) var batchesThisRun = 0
    @Published private(set) var remainingTimeText = "—"
    @Published private(set) var grants: [BackgroundGrant] = []

    private let store = OutboxStore.shared

    // State tối quan trọng — truy cập đồng bộ từ mọi thread
    private let lock = NSLock()
    private var _bgTaskID: UIBackgroundTaskIdentifier = .invalid
    private var _runTask: Task<Void, Never>?
    private var _isInBackground = false
    private var _bgEnteredAt: Date?
    private var _batchesAtBackgroundEntry = 0
    private var _reportedAtEntry: TimeInterval = 0

    private var probeTimer: Timer?

    private init() {
        refreshCounts()
        grants = BackgroundBudgetLog.shared.all()
    }

    private var uploader: Uploader {
        useRealServer
            ? HTTPUploader(endpoint: serverURL)
            : MockUploader(latencyPerBatch: simulatedLatency, failureRate: failureRate)
    }

    // MARK: - Điều khiển

    func start() {
        lock.lock()
        guard _runTask == nil else { lock.unlock(); return }
        lock.unlock()

        publish { self.isRunning = true; self.batchesThisRun = 0 }
        Logger.shared.log("▶️ START — batchSize \(batchSize), latency \(simulatedLatency)s")

        let task = Task.detached(priority: .utility) { [weak self] in
            await self?.runLoop()
        }
        lock.lock(); _runTask = task; lock.unlock()
    }

    /// User bấm Stop. Cùng đường với expiration: đều là cooperative cancel.
    func stop(reason: String) {
        lock.lock()
        let task = _runTask
        lock.unlock()
        guard task != nil else { return }
        Logger.shared.log("⏹️ STOP — \(reason)")
        task?.cancel()
    }

    // MARK: - Vòng lặp chính

    private func runLoop() async {
        defer {
            lock.lock(); _runTask = nil; lock.unlock()
            publish { self.isRunning = false }
            endBackgroundTaskIfNeeded(note: "vòng lặp kết thúc")
        }

        while true {
            // Điểm kiểm tra 1: trước khi lấy batch mới.
            if Task.isCancelled {
                Logger.shared.log("⏸️ cancelled — dừng trước batch tiếp theo")
                return
            }

            let batch = store.fetchUnsynced(limit: batchSize)
            guard !batch.isEmpty else {
                Logger.shared.log("🎉 hết record, không còn gì để upload")
                return
            }

            let batchID = UUID().uuidString
            let short = String(batchID.prefix(8))
            let started = Date()

            do {
                try await uploader.upload(batch, batchID: batchID)
            } catch is CancellationError {
                // ⚠️ Điểm tinh tế nhất của cả demo.
                // Cancel xảy ra khi request ĐANG BAY. Ta KHÔNG biết server đã
                // nhận hay chưa. Nên KHÔNG mark synced → lần sau batch này
                // được gửi lại → server dedup bằng Idempotency-Key.
                // Chọn "gửi lại có thể trùng" thay vì "mất dữ liệu".
                Logger.shared.log("⏸️ cancel giữa batch \(short) — không commit, sẽ gửi lại")
                return
            } catch {
                Logger.shared.log("❌ batch \(short) lỗi: \(error.localizedDescription) — dừng")
                return
            }

            // KHÔNG có `await` nào giữa upload thành công và markSynced.
            // Cancellation là cooperative nên không có gì chen vào được ở đây.
            // Nếu chèn một `await` vào giữa, bạn tạo ra cửa sổ mất dữ liệu.
            store.markSynced(ids: batch.map(\.id), batchID: batchID)

            let elapsed = Date().timeIntervalSince(started)
            lock.lock(); let inBG = _isInBackground; lock.unlock()

            publish {
                self.batchesThisRun += 1
                self.refreshCountsInline()
            }
            Logger.shared.log(
                "📤 batch \(short): \(batch.count) record trong \(String(format: "%.2f", elapsed))s"
                + (inBG ? " [BG, còn \(readRemainingText())]" : " [FG]")
            )
        }
    }

    // MARK: - Vòng đời app

    func handleDidEnterBackground() {
        lock.lock()
        _isInBackground = true
        let running = _runTask != nil
        lock.unlock()

        guard running else {
            Logger.shared.log("📱 → background (không có upload đang chạy, không xin thêm giờ)")
            return
        }

        beginBackgroundTask()
        startProbe()
    }

    func handleWillEnterForeground() {
        lock.lock()
        _isInBackground = false
        let enteredAt = _bgEnteredAt
        let batchesAtEntry = _batchesAtBackgroundEntry
        let reported = _reportedAtEntry
        _bgEnteredAt = nil
        lock.unlock()

        stopProbe()

        // Nếu upload xong trước khi hết giờ, ghi lại đã dùng bao lâu.
        if let enteredAt, currentBackgroundTaskIsActive == false {
            let grant = BackgroundGrant(
                startedAt: enteredAt,
                reportedAtEntry: reported,
                actualUntilExpiration: nil,
                finishedAfter: Date().timeIntervalSince(enteredAt),
                lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                batchesUploadedInBackground: max(0, batchesThisRun - batchesAtEntry)
            )
            BackgroundBudgetLog.shared.append(grant)
        }

        endBackgroundTaskIfNeeded(note: "về foreground")
        publish {
            self.remainingTimeText = "∞ (foreground)"
            self.grants = BackgroundBudgetLog.shared.all()
            self.refreshCountsInline()
        }
        Logger.shared.log("📱 → foreground")
    }

    private var currentBackgroundTaskIsActive: Bool {
        lock.lock(); defer { lock.unlock() }
        return _bgTaskID != .invalid
    }

    // MARK: - beginBackgroundTask

    private func beginBackgroundTask() {
        // UIApplication là main-thread API. handleDidEnterBackground được gọi
        // từ scenePhase nên đã ở main, nhưng khẳng định lại cho chắc.
        assert(Thread.isMainThread)

        lock.lock()
        guard _bgTaskID == .invalid else { lock.unlock(); return }
        lock.unlock()

        let id = UIApplication.shared.beginBackgroundTask(withName: "OutboxUpload") { [weak self] in
            // ⚠️ Main thread, chỉ còn vài giây. Mọi thứ ở đây phải ĐỒNG BỘ.
            self?.handleExpiration()
        }

        let entered = Date()
        let reported = UIApplication.shared.backgroundTimeRemaining

        lock.lock()
        _bgTaskID = id
        _bgEnteredAt = entered
        _reportedAtEntry = reported
        _batchesAtBackgroundEntry = batchesThisRun
        lock.unlock()

        if id == .invalid {
            // iOS có quyền TỪ CHỐI: pin yếu, Low Power Mode, quá nhiều task.
            Logger.shared.log("❌ hệ thống từ chối cấp background time")
        } else {
            Logger.shared.log(
                "🕐 beginBackgroundTask(id: \(id.rawValue)) — "
                + "iOS báo còn \(String(format: "%.1f", reported))s"
                + (ProcessInfo.processInfo.isLowPowerModeEnabled ? " [LOW POWER MODE]" : "")
            )
        }
    }

    /// Chỉ làm ba việc, tất cả đồng bộ: ghi telemetry, cancel, end task.
    private func handleExpiration() {
        lock.lock()
        let enteredAt = _bgEnteredAt
        let reported = _reportedAtEntry
        let batchesAtEntry = _batchesAtBackgroundEntry
        let task = _runTask
        lock.unlock()

        let actual = enteredAt.map { Date().timeIntervalSince($0) }
        Logger.shared.log(
            "⚠️ EXPIRATION — thực tế được \(actual.map { String(format: "%.1f", $0) } ?? "?")s "
            + "(iOS báo lúc đầu: \(String(format: "%.1f", reported))s)"
        )

        if let enteredAt {
            BackgroundBudgetLog.shared.append(BackgroundGrant(
                startedAt: enteredAt,
                reportedAtEntry: reported,
                actualUntilExpiration: actual,
                finishedAfter: nil,
                lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                batchesUploadedInBackground: max(0, batchesThisRun - batchesAtEntry)
            ))
        }

        // Cancel là cooperative: nó chỉ SET CỜ. Vòng lặp phải tự kiểm tra.
        // Task.cancel() an toàn gọi từ mọi thread.
        task?.cancel()

        // Bắt buộc end, ngay tại đây, đồng bộ.
        // Quên → iOS terminate app (crash log 0x8badf00d).
        endBackgroundTaskIfNeeded(note: "expiration")
    }

    private func endBackgroundTaskIfNeeded(note: String) {
        lock.lock()
        let id = _bgTaskID
        _bgTaskID = .invalid
        lock.unlock()

        guard id != .invalid else { return }

        let end = {
            UIApplication.shared.endBackgroundTask(id)
            Logger.shared.log("🔚 endBackgroundTask(id: \(id.rawValue)) — \(note)")
        }
        if Thread.isMainThread { end() } else { DispatchQueue.main.async(execute: end) }
    }

    // MARK: - Probe đo thời gian còn lại

    private func startProbe() {
        stopProbe()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let text = readRemainingText()
            self.publish { self.remainingTimeText = text }
            Logger.shared.log("⏱️ còn \(text)")
        }
        RunLoop.main.add(timer, forMode: .common)
        probeTimer = timer
    }

    private func stopProbe() {
        probeTimer?.invalidate()
        probeTimer = nil
    }

    // MARK: - Tiện ích

    func refreshCounts() {
        let c = store.counts()
        publish { self.totalRecords = c.total; self.syncedRecords = c.synced }
    }

    /// Gọi khi đã ở trong publish block.
    private func refreshCountsInline() {
        let c = store.counts()
        totalRecords = c.total
        syncedRecords = c.synced
    }

    func clearGrants() {
        BackgroundBudgetLog.shared.clear()
        publish { self.grants = [] }
    }

    /// ObservableObject bắt buộc publish trên main thread.
    private func publish(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }
}

/// Phải đọc trên main thread. Ở foreground trả về .greatestFiniteMagnitude.
func readRemainingText() -> String {
    let read: () -> String = {
        let t = UIApplication.shared.backgroundTimeRemaining
        return t > 1_000_000 ? "∞ (foreground)" : String(format: "%.1fs", t)
    }
    return Thread.isMainThread ? read() : DispatchQueue.main.sync(execute: read)
}
