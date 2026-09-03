//
//  Uploader.swift
//

import Foundation

protocol Uploader: Sendable {
    /// batchID để server dedup. Xem ghi chú về idempotency trong SyncEngine.
    func upload(_ records: [OutboxRecord], batchID: String) async throws
}

// MARK: - Mock

/// Dùng để đo background time mà không cần server.
/// `Task.sleep` phản hồi cancellation — đây là điểm khác biệt sống còn
/// so với `Thread.sleep`, thứ hoàn toàn phớt lờ cancel.
struct MockUploader: Uploader {
    let latencyPerBatch: TimeInterval
    let failureRate: Double

    func upload(_ records: [OutboxRecord], batchID: String) async throws {
        try await Task.sleep(nanoseconds: UInt64(latencyPerBatch * 1_000_000_000))
        if failureRate > 0, Double.random(in: 0...1) < failureRate {
            throw UploadError.serverRejected(503)
        }
    }
}

// MARK: - HTTP thật

/// Xem README để chạy server Python kèm theo.
struct HTTPUploader: Uploader {
    let endpoint: URL

    func upload(_ records: [OutboxRecord], batchID: String) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Idempotency key: server thấy batchID đã xử lý thì trả 200 luôn,
        // không ghi trùng. Đây là thứ làm cho việc gửi lại an toàn.
        request.setValue(batchID, forHTTPHeaderField: "Idempotency-Key")
        request.timeoutInterval = 20

        let body = ["batch_id": batchID,
                    "records": records.map { ["id": $0.id, "payload": $0.payload] }] as [String: Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // URLSession async API tự cancel HTTP request khi Task bị cancel.
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UploadError.noResponse }
        guard (200...299).contains(http.statusCode) else {
            throw UploadError.serverRejected(http.statusCode)
        }
    }
}

enum UploadError: LocalizedError {
    case serverRejected(Int)
    case noResponse

    var errorDescription: String? {
        switch self {
        case .serverRejected(let code): return "Server trả HTTP \(code)"
        case .noResponse: return "Không có response"
        }
    }
}
