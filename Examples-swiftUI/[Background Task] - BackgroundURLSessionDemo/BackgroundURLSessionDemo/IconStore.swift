//
//  IconStore.swift
//  Quản lý state đồng bộ + file trên đĩa.
//
//  Vì sao dùng NSLock chứ không dùng actor:
//  `didFinishDownloadingTo` là callback ĐỒNG BỘ và file tạm bị xoá ngay khi
//  hàm đó return. Không await được ở đó. Nên state phải truy cập được
//  synchronously từ delegate queue → lock, không phải actor.
//

import Foundation

// MARK: - Model

struct IconManifest: Codable {
    let version: Int
    let icons: [IconEntry]
}

struct IconEntry: Codable, Equatable {
    let id: String
    let url: URL
    let sha256: String?     // optional; nếu server cung cấp thì verify
}

enum IconState: String, Codable {
    case pending        // đã biết cần tải, task đã enqueue
    case staged         // đã tải xong, chờ install
    case installed      // dùng được
    case failed
}

struct IconRecord: Codable {
    let entry: IconEntry
    var state: IconState
    var attempts: Int = 0
    var lastError: String?
}

private struct PersistedState: Codable {
    var manifestVersion: Int = 0
    var records: [String: IconRecord] = [:]
}

// MARK: - Store

final class IconStore {

    static let shared = IconStore()

    private let lock = NSLock()
    private var state = PersistedState()

    private let fm = FileManager.default
    private let baseDir: URL
    private let stagingDir: URL
    private let installedDir: URL
    private let stateFile: URL

    /// Số lần thử lại tối đa cho một icon trước khi bỏ.
    private let maxAttempts = 3

    private init() {
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        baseDir      = support.appendingPathComponent("IconSync", isDirectory: true)
        stagingDir   = baseDir.appendingPathComponent("staging", isDirectory: true)
        installedDir = baseDir.appendingPathComponent("installed", isDirectory: true)
        stateFile    = baseDir.appendingPathComponent("state.json")

        for dir in [baseDir, stagingDir, installedDir] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // BẮT BUỘC: không để nội dung tải về lọt vào iCloud backup của user.
        // Bỏ bước này = vài trăm MB rác trong backup, và là lý do bị App Review hỏi.
        excludeFromBackup(baseDir)

        load()
    }

    private func excludeFromBackup(_ url: URL) {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: stateFile),
              let decoded = try? JSONDecoder().decode(PersistedState.self, from: data)
        else { return }
        state = decoded
    }

    /// Gọi bên trong lock.
    private func saveLocked() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        // .atomic: ghi ra file tạm rồi rename. App bị kill giữa lúc ghi
        // vẫn không làm hỏng state cũ.
        try? data.write(to: stateFile, options: .atomic)
    }

    // MARK: - Đọc

    var manifestVersion: Int {
        lock.lock(); defer { lock.unlock() }
        return state.manifestVersion
    }

    var installedIcons: [(id: String, url: URL)] {
        lock.lock(); defer { lock.unlock() }
        return state.records
            .filter { $0.value.state == .installed }
            .keys
            .sorted()
            .map { ($0, installedDir.appendingPathComponent("\($0).png")) }
    }

    /// ID của các icon đã enqueue nhưng chưa tải xong.
    var pendingIDs: Set<String> {
        lock.lock(); defer { lock.unlock() }
        return Set(state.records.filter { $0.value.state == .pending }.keys)
    }

    var stagedIDs: [String] {
        lock.lock(); defer { lock.unlock() }
        return state.records.filter { $0.value.state == .staged }.keys.sorted()
    }

    func record(for id: String) -> IconRecord? {
        lock.lock(); defer { lock.unlock() }
        return state.records[id]
    }

    func snapshot() -> [String: IconRecord] {
        lock.lock(); defer { lock.unlock() }
        return state.records
    }

    func stagingURL(for id: String) -> URL {
        stagingDir.appendingPathComponent("\(id).png")
    }

    // MARK: - Ghi

    /// So manifest mới với state hiện tại, trả về danh sách CẦN tải.
    /// Đây là chỗ delta sync xảy ra: icon đã có thì không tải lại.
    func reconcile(manifest: IconManifest) -> [IconEntry] {
        lock.lock(); defer { lock.unlock() }

        var needed: [IconEntry] = []

        for entry in manifest.icons {
            if let existing = state.records[entry.id] {
                // URL đổi = nội dung đổi → tải lại.
                let urlChanged = existing.entry.url != entry.url
                switch existing.state {
                case .installed where !urlChanged:
                    continue
                case .staged where !urlChanged:
                    continue
                case .failed where existing.attempts >= maxAttempts && !urlChanged:
                    continue
                default:
                    break
                }
            }
            let attempts = state.records[entry.id]?.attempts ?? 0
            state.records[entry.id] = IconRecord(entry: entry, state: .pending, attempts: attempts)
            needed.append(entry)
        }

        // Icon bị xoá khỏi manifest → dọn file.
        let manifestIDs = Set(manifest.icons.map(\.id))
        for id in state.records.keys where !manifestIDs.contains(id) {
            try? fm.removeItem(at: installedDir.appendingPathComponent("\(id).png"))
            try? fm.removeItem(at: stagingDir.appendingPathComponent("\(id).png"))
            state.records[id] = nil
        }

        state.manifestVersion = manifest.version
        saveLocked()
        return needed
    }

    func markStaged(_ id: String) {
        lock.lock(); defer { lock.unlock() }
        state.records[id]?.state = .staged
        state.records[id]?.lastError = nil
        saveLocked()
    }

    func markFailed(_ id: String, reason: String) {
        lock.lock(); defer { lock.unlock() }
        state.records[id]?.state = .failed
        state.records[id]?.attempts += 1
        state.records[id]?.lastError = reason
        saveLocked()
    }

    /// Chuyển staging → installed. Với icon thì chỉ là move file nên rẻ,
    /// chạy được ngay trong wake window ~30s.
    /// Nếu là merge database thì việc này phải đẩy sang BGProcessingTask.
    @discardableResult
    func installStaged() -> Int {
        lock.lock(); defer { lock.unlock() }

        var installed = 0
        for (id, record) in state.records where record.state == .staged {
            let from = stagingDir.appendingPathComponent("\(id).png")
            let to   = installedDir.appendingPathComponent("\(id).png")

            // Verify checksum trước khi install, nếu server có cung cấp.
            if let expected = record.entry.sha256,
               let actual = Self.sha256(of: from),
               actual != expected {
                state.records[id]?.state = .failed
                state.records[id]?.attempts += 1
                state.records[id]?.lastError = "Checksum mismatch"
                try? fm.removeItem(at: from)
                continue
            }

            do {
                try? fm.removeItem(at: to)
                try fm.moveItem(at: from, to: to)
                state.records[id]?.state = .installed
                installed += 1
            } catch {
                state.records[id]?.lastError = error.localizedDescription
            }
        }
        if installed > 0 { saveLocked() }
        return installed
    }

    func resetEverything() {
        lock.lock(); defer { lock.unlock() }
        state = PersistedState()
        for dir in [stagingDir, installedDir] {
            try? fm.removeItem(at: dir)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        saveLocked()
    }

    // MARK: - Helper

    private static func sha256(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return SHA256Digest.hexString(data)
    }
}
