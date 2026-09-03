//
//  Logger.swift
//  Ghi log kèm timestamp ra file — bắt buộc phải có với loại demo này,
//  vì phần lớn sự kiện xảy ra khi app đang ở background hoặc bị kill,
//  lúc đó không có console nào để xem.
//

import Foundation
import Combine

final class Logger: ObservableObject {

    static let shared = Logger()

    @Published private(set) var lines: [String] = []

    private let fileURL: URL
    private let ioQueue = DispatchQueue(label: "iconsync.logger")
    private let formatter: DateFormatter
    private let maxLines = 500

    private init() {
        fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iconsync.log")

        formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss.SSS"

        if let text = try? String(contentsOf: fileURL, encoding: .utf8) {
            lines = text.split(separator: "\n").map(String.init).suffix(maxLines)
        }
    }

    func log(_ message: String) {
        let line = "[\(formatter.string(from: Date()))] \(message)"
        print(line)

        DispatchQueue.main.async {
            self.lines.append(line)
            if self.lines.count > self.maxLines { self.lines.removeFirst() }
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
}
