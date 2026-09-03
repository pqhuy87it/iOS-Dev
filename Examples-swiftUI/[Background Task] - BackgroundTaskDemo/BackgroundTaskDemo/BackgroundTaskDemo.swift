//
//  BackgroundTaskDemo.swift
//  Demo single-file: so sánh KHÔNG dùng vs CÓ dùng beginBackgroundTask
//
//  Cách dùng:
//  1. Tạo project SwiftUI mới (iOS App), xoá ContentView.swift và <Tên>App.swift
//  2. Copy toàn bộ file này vào project
//  3. Chạy trên MÁY THẬT (Simulator không mô phỏng đúng việc suspend)
//  4. QUAN TRỌNG: Sau khi build & run, bấm Stop trong Xcode rồi mở app từ Home Screen.
//     Khi debugger còn attach, iOS KHÔNG suspend app → cả 2 case đều "chạy ngon" và
//     bạn sẽ kết luận sai.
//

import SwiftUI
import UIKit
import Combine

// MARK: - ================== LOGGER ==================
// Ghi log kèm timestamp ra file, để sau khi app bị suspend/kill vẫn đọc lại được.

final class DemoLogger: ObservableObject {
    static let shared = DemoLogger()

    @Published private(set) var lines: [String] = []

    private let fileURL: URL
    private let ioQueue = DispatchQueue(label: "demo.logger.io")
    private let formatter: DateFormatter

    private init() {
        fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("bg_task_demo.log")

        formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"

        loadFromDisk()
    }

    func log(_ message: String) {
        let line = "[\(formatter.string(from: Date()))] \(message)"
        print(line)

        DispatchQueue.main.async {
            self.lines.append(line)
        }

        ioQueue.async {
            guard let data = (line + "\n").data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: self.fileURL.path),
               let handle = try? FileHandle(forWritingTo: self.fileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: self.fileURL)
            }
        }
    }

    func clear() {
        lines.removeAll()
        ioQueue.async { try? FileManager.default.removeItem(at: self.fileURL) }
    }

    private func loadFromDisk() {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        lines = text.split(separator: "\n").map(String.init)
    }
}

// MARK: - ================== HELPER ==================

enum BackgroundTime {
    /// backgroundTimeRemaining CHỈ có ý nghĩa khi app đang ở background.
    /// Ở foreground nó trả về .greatestFiniteMagnitude.
    /// Phải đọc trên main thread.
    static func remainingText() -> String {
        let read: () -> String = {
            let t = UIApplication.shared.backgroundTimeRemaining
            return t > 1_000_000 ? "∞ (foreground)" : String(format: "%.1fs", t)
        }
        if Thread.isMainThread {
            return read()
        } else {
            return DispatchQueue.main.sync(execute: read)
        }
    }
}

// MARK: - ================== CASE A: KHÔNG dùng beginBackgroundTask ==================
//
// Mô phỏng một tác vụ dài 25 giây (upload / ghi DB / export file).
// Khi bạn bấm Home, iOS cho app ~vài giây rồi SUSPEND toàn bộ thread.
// Kết quả: log dừng giữa chừng, và chỉ chạy tiếp khi bạn mở lại app.
// → Đây chính là nguồn gốc của "file ghi dở", "transaction treo", "upload nửa vời".

final class NaiveWorker {
    static let shared = NaiveWorker()
    private init() {}

    private let totalSteps = 25
    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true

        DemoLogger.shared.log("🅰️ ───── BẮT ĐẦU (KHÔNG beginBackgroundTask) ─────")

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }

            for step in 1...self.totalSteps {
                Thread.sleep(forTimeInterval: 1.0)   // giả lập 1 đơn vị công việc
                DemoLogger.shared.log("🅰️ step \(step)/\(self.totalSteps)")
            }

            DemoLogger.shared.log("🅰️ ───── HOÀN THÀNH ✅ ─────")
            self.isRunning = false
        }
    }
}

// MARK: - ================== CASE B: CÓ dùng beginBackgroundTask ==================
//
// 3 nguyên tắc bắt buộc:
//   1. begin trước khi bắt đầu việc, KHÔNG đợi đến lúc app vào background mới gọi.
//   2. LUÔN gọi endBackgroundTask trên MỌI nhánh thoát (xong, lỗi, huỷ, hết giờ).
//      Quên end → iOS terminate app (crash log: exception code 0x8badf00d).
//   3. expirationHandler = cảnh báo cuối cùng, chỉ còn ~vài giây.
//      Trong đó phải: dừng việc → lưu checkpoint → end task. Không làm việc nặng.

final class GuardedWorker {
    static let shared = GuardedWorker()
    private init() {}

    private let totalSteps = 25
    private var isRunning = false

    private var taskID: UIBackgroundTaskIdentifier = .invalid

    // Cờ dừng được đọc/ghi từ nhiều thread → cần khoá.
    private let lock = NSLock()
    private var _shouldStop = false
    private var shouldStop: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _shouldStop }
        set { lock.lock(); _shouldStop = newValue; lock.unlock() }
    }

    /// Gọi từ main thread.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        shouldStop = false

        beginBackgroundTask()

        let resumeFrom = UserDefaults.standard.integer(forKey: "guarded.checkpoint")
        let startStep = max(resumeFrom, 0) + 1
        DemoLogger.shared.log("🅱️ ───── BẮT ĐẦU (CÓ beginBackgroundTask) từ step \(startStep) ─────")

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }

            for step in startStep...self.totalSteps {

                // Kiểm tra cờ dừng TRƯỚC mỗi đơn vị công việc.
                if self.shouldStop {
                    DemoLogger.shared.log("🅱️ ⏸️ Dừng sớm trước step \(step) — lưu checkpoint \(step - 1)")
                    UserDefaults.standard.set(step - 1, forKey: "guarded.checkpoint")
                    self.finish()
                    return
                }

                Thread.sleep(forTimeInterval: 1.0)
                DemoLogger.shared.log(
                    "🅱️ step \(step)/\(self.totalSteps) — còn lại: \(BackgroundTime.remainingText())"
                )
            }

            UserDefaults.standard.removeObject(forKey: "guarded.checkpoint")
            DemoLogger.shared.log("🅱️ ───── HOÀN THÀNH ✅ ─────")
            self.finish()
        }
    }

    // MARK: begin / end

    /// Phải gọi trên main thread (UIApplication là main-thread API).
    private func beginBackgroundTask() {
        endBackgroundTaskIfNeeded()   // phòng trường hợp còn task cũ chưa end → tránh leak

        taskID = UIApplication.shared.beginBackgroundTask(withName: "GuardedUpload") { [weak self] in
            // ⚠️ Closure này iOS gọi trên MAIN THREAD khi sắp hết thời gian.
            // Ở đây chỉ còn khoảng vài giây trước khi app bị suspend/terminate.
            DemoLogger.shared.log("🅱️ ⚠️ expirationHandler — hệ thống sắp thu hồi thời gian!")
            self?.shouldStop = true
            self?.endBackgroundTaskIfNeeded()
        }

        if taskID == .invalid {
            // iOS có quyền TỪ CHỐI cấp thời gian (pin yếu, Low Power Mode, quá nhiều task...)
            DemoLogger.shared.log("🅱️ ❌ Hệ thống từ chối cấp background time (taskID = .invalid)")
        } else {
            DemoLogger.shared.log("🅱️ beginBackgroundTask(id: \(taskID.rawValue))")
        }
    }

    private func finish() {
        isRunning = false
        DispatchQueue.main.async { self.endBackgroundTaskIfNeeded() }
    }

    /// Idempotent: gọi nhiều lần vẫn an toàn. Phải chạy trên main thread.
    private func endBackgroundTaskIfNeeded() {
        guard taskID != .invalid else { return }
        DemoLogger.shared.log("🅱️ endBackgroundTask(id: \(taskID.rawValue))")
        UIApplication.shared.endBackgroundTask(taskID)
        taskID = .invalid
    }
}

// MARK: - ================== BONUS: phiên bản async/await ==================
//
// Helper tái sử dụng được — đây là thứ nên có trong codebase production.
// expirationHandler cancel Task, còn `defer` đảm bảo end task ở mọi nhánh thoát.

@MainActor
func withBackgroundTask<T>(
    name: String,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let app = UIApplication.shared
    let handle = Task { try await operation() }

    let id = app.beginBackgroundTask(withName: name) {
        DemoLogger.shared.log("🅲 ⚠️ expiration → cancel Task")
        handle.cancel()
    }

    defer {
        if id != .invalid {
            DemoLogger.shared.log("🅲 endBackgroundTask(id: \(id.rawValue))")
            app.endBackgroundTask(id)
        }
    }

    return try await handle.value
}

enum ModernWorker {
    static func start() {
        Task { @MainActor in
            DemoLogger.shared.log("🅲 ───── BẮT ĐẦU (async/await) ─────")
            do {
                try await withBackgroundTask(name: "ModernUpload") {
                    for step in 1...25 {
                        // try Task.checkCancellation() ném CancellationError khi bị huỷ
                        try Task.checkCancellation()
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        await DemoLogger.shared.log("🅲 step \(step)/25")
                    }
                }
                DemoLogger.shared.log("🅲 ───── HOÀN THÀNH ✅ ─────")
            } catch is CancellationError {
                DemoLogger.shared.log("🅲 ⏸️ Bị huỷ giữa chừng (hết background time)")
            } catch {
                DemoLogger.shared.log("🅲 ❌ Lỗi: \(error)")
            }
        }
    }
}

// MARK: - ================== UI ==================

struct ContentView: View {
    @ObservedObject private var logger = DemoLogger.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var remaining: String = "—"

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            Text("beginBackgroundTask Demo")
                .font(.headline)

            Text("Thời gian còn lại: \(remaining)")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Button("🅰️ Chạy KHÔNG beginBackgroundTask") { NaiveWorker.shared.start() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                Button("🅱️ Chạy CÓ beginBackgroundTask") { GuardedWorker.shared.start() }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                Button("🅲 Chạy bản async/await") { ModernWorker.start() }
                    .buttonStyle(.bordered)

                Button("🗑️ Xoá log & checkpoint") {
                    logger.clear()
                    UserDefaults.standard.removeObject(forKey: "guarded.checkpoint")
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(logger.lines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .onChange(of: logger.lines.count) { _ in
                    if let last = logger.lines.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .padding()
        .onReceive(ticker) { _ in
            remaining = BackgroundTime.remainingText()
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:     DemoLogger.shared.log("📱 scenePhase → active")
            case .inactive:   DemoLogger.shared.log("📱 scenePhase → inactive")
            case .background: DemoLogger.shared.log("📱 scenePhase → background")
            @unknown default: break
            }
        }
    }
}

// MARK: - ================== APP ENTRY ==================

@main
struct BackgroundTaskDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
