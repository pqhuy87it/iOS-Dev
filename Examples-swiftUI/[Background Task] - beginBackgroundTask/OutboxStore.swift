//
//  OutboxStore.swift
//  Outbox pattern trên SQLite thuần (không cần .xcdatamodeld, copy vào là chạy).
//
//  Bảng: id, payload, synced, batch_id
//  Vòng đời một record: synced = 0  →  upload OK  →  synced = 1 + batch_id
//
//  Điểm quan trọng: bản thân DB CHÍNH LÀ checkpoint.
//  Không cần lưu "đã tới batch số mấy" ở đâu cả — record nào synced = 0
//  thì lần sau tự động được lấy lại. Bị kill giữa đường cũng không mất mát.
//

import Foundation
import SQLite3

struct OutboxRecord: Identifiable, Hashable {
    let id: Int64
    let payload: String
}

final class OutboxStore {

    static let shared = OutboxStore()

    private var db: OpaquePointer?
    /// sqlite3 handle không thread-safe theo cách ta dùng ở đây → serial queue.
    private let queue = DispatchQueue(label: "outbox.sqlite")

    private init() {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("outbox.sqlite")

        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            Logger.shared.log("❌ không mở được DB")
            return
        }

        exec("PRAGMA journal_mode = WAL;")
        exec("""
            CREATE TABLE IF NOT EXISTS outbox (
                id       INTEGER PRIMARY KEY AUTOINCREMENT,
                payload  TEXT    NOT NULL,
                synced   INTEGER NOT NULL DEFAULT 0,
                batch_id TEXT
            );
            """)
        exec("CREATE INDEX IF NOT EXISTS idx_synced ON outbox(synced);")
    }

    // MARK: - Helper

    private func exec(_ sql: String) {
        queue.sync {
            var err: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK, let err {
                Logger.shared.log("❌ SQL: \(String(cString: err))")
                sqlite3_free(err)
            }
        }
    }

    // MARK: - Seed

    /// Nạp dữ liệu giả để thực hành. Một transaction cho cả lô, nếu không
    /// sqlite fsync từng row và 5000 record sẽ mất cả phút.
    func seed(count: Int) {
        queue.sync {
            sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, "INSERT INTO outbox (payload) VALUES (?);", -1, &stmt, nil)
            for i in 0..<count {
                let payload = #"{"event":"tap","index":\#(i),"ts":\#(Int(Date().timeIntervalSince1970))}"#
                sqlite3_bind_text(stmt, 1, payload, -1, nil)
                sqlite3_step(stmt)
                sqlite3_reset(stmt)
            }
            sqlite3_finalize(stmt)
            sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        }
        Logger.shared.log("🌱 seed \(count) record")
    }

    // MARK: - Đọc

    /// Lấy batch tiếp theo. ORDER BY id để thứ tự ổn định giữa các lần chạy.
    func fetchUnsynced(limit: Int) -> [OutboxRecord] {
        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(
                db,
                "SELECT id, payload FROM outbox WHERE synced = 0 ORDER BY id LIMIT ?;",
                -1, &stmt, nil) == SQLITE_OK else { return [] }

            sqlite3_bind_int(stmt, 1, Int32(limit))

            var out: [OutboxRecord] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let payload = String(cString: sqlite3_column_text(stmt, 1))
                out.append(OutboxRecord(id: id, payload: payload))
            }
            return out
        }
    }

    func counts() -> (total: Int, synced: Int) {
        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            sqlite3_prepare_v2(
                db,
                "SELECT COUNT(*), COALESCE(SUM(synced), 0) FROM outbox;",
                -1, &stmt, nil)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return (0, 0) }
            return (Int(sqlite3_column_int(stmt, 0)), Int(sqlite3_column_int(stmt, 1)))
        }
    }

    // MARK: - Ghi

    /// Commit một batch. ĐỒNG BỘ và trong một transaction:
    /// hoặc cả 100 record được mark, hoặc không record nào.
    /// Đây là lý do hàm này không async — không được có suspension point
    /// giữa lúc upload thành công và lúc commit (xem SyncEngine).
    func markSynced(ids: [Int64], batchID: String) {
        guard !ids.isEmpty else { return }
        queue.sync {
            sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(
                db,
                "UPDATE outbox SET synced = 1, batch_id = ? WHERE id = ?;",
                -1, &stmt, nil)
            for id in ids {
                sqlite3_bind_text(stmt, 1, batchID, -1, nil)
                sqlite3_bind_int64(stmt, 2, id)
                sqlite3_step(stmt)
                sqlite3_reset(stmt)
            }
            sqlite3_finalize(stmt)
            sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        }
    }

    func reset() {
        exec("DELETE FROM outbox;")
        exec("DELETE FROM sqlite_sequence WHERE name = 'outbox';")
        Logger.shared.log("🗑️ reset DB")
    }

    func unmarkAll() {
        exec("UPDATE outbox SET synced = 0, batch_id = NULL;")
        Logger.shared.log("↩️ đặt lại toàn bộ về synced = 0")
    }
}
