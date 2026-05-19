import SwiftUI
import Synchronization // Bắt buộc cho Swift 6 Mutex

// MARK: - ViewModel quản lý luồng chạy
@MainActor
@Observable
class SuspendDemoModel {
    var logs: [String] = []
    var isWorking = false
    private var activeTask: Task<Void, Never>?

    // Hàm in log lên màn hình
    func log(_ msg: String) {
        logs.append(msg)
    }

    // 🔴 Kịch bản A: Khởi chạy bình thường, chờ người dùng bấm nút Hủy
    func runLateCancellation() {
        logs.removeAll()
        isWorking = true
        log("--- KỊCH BẢN A: HỦY TRỄ (ĐỢI BẤM NÚT) ---")

        activeTask = Task {
            await untilCancelled()
            isWorking = false
        }
    }

    // 🔴 Kịch bản B: Khởi chạy và lập tức Hủy ngay bằng code
    func runEarlyCancellation() {
        logs.removeAll()
        isWorking = true
        log("--- KỊCH BẢN B: HỦY SỚM (TỰ ĐỘNG) ---")

        activeTask = Task {
            await untilCancelled()
            isWorking = false
        }

        // Kích hoạt hủy ngay tắp lự, không có độ trễ
        log("=> [Hệ thống] Đang gọi cancel() ngay lập tức...")
        activeTask?.cancel()
        log("=> [Hệ thống] Đã gọi cancel() xong.")
    }

    // Hủy bằng tay khi bấm nút
    func cancelManually() {
        log("=> [Người dùng] Đang gọi cancel()...")
        activeTask?.cancel()
    }

    // MARK: - Core Logic (Từ bài phân tích)
    private func untilCancelled() async {
        log("1. Tiến trình con bắt đầu")

        // Tạo Mutex bảo vệ biến Continuation (Khởi tạo giá trị ban đầu là nil)
        let mutex = Mutex<CheckedContinuation<Void, Never>?>(nil)

        await withTaskCancellationHandler {
            log("2. Đi vào khối operation")
            
            await withCheckedContinuation { continuation in
                log("3. Đang tạo continuation")

                mutex.withLock { state in
                    // Kiểm tra an toàn trước khi đóng băng
                    if Task.isCancelled {
                        log("⚠️ abort: Phát hiện lệnh hủy sớm! Không đóng băng nữa.")
                        continuation.resume()
                        return
                    }

                    log("4. An toàn. Lưu continuation và BẮT ĐẦU ĐÓNG BĂNG ❄️")
                    state = continuation
                }
            }
            
        } onCancel: {
            // Khối onCancel sẽ nhảy vào đây
            let extractedContinuation = mutex.withLock { state -> CheckedContinuation<Void, Never>? in
                let temp = state
                state = nil // Đưa state về nil giống hàm .take() để tránh gọi resume lần 2
                return temp
            }

            // Gọi MainActor để in log an toàn lên UI
            Task { @MainActor in
                self.log("5. onCancel đã chộp được lệnh! Lấy continuation ra khỏi Mutex.")
            }

            // Đánh thức tiến trình đang bị đóng băng
            extractedContinuation?.resume()
        }

        log("6. Tiến trình con kết thúc an toàn ✅")
    }
}

// MARK: - Giao Diện SwiftUI
struct CancellationPracticeView: View {
    @State private var model = SuspendDemoModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Thực Hành Mutex & Cancellation")
                .font(.headline)

            // Khu vực in Log
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(model.logs.indices, id: \.self) { index in
                            Text(model.logs[index])
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index) // Gắn ID để tự động cuộn
                        }
                    }
                    .padding()
                }
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                // Tự động cuộn xuống dòng log mới nhất
                .onChange(of: model.logs.count) {
                    if let lastIndex = model.logs.indices.last {
                        withAnimation { proxy.scrollTo(lastIndex, anchor: .bottom) }
                    }
                }
            }
            .frame(maxHeight: 400)

            // Khu vực Nút Bấm
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button("Kịch bản A (Chờ Hủy)") {
                        model.runLateCancellation()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isWorking)

                    Button("Nút Hủy Bằng Tay") {
                        model.cancelManually()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(!model.isWorking)
                }

                Button("Kịch bản B (Hủy Sớm / Tự Động)") {
                    model.runEarlyCancellation()
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(model.isWorking)
            }
        }
        .padding()
    }
}

#Preview {
    CancellationPracticeView()
}
