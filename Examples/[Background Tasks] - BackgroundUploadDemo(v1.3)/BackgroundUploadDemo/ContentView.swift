import SwiftUI

struct ContentView: View {
    @StateObject private var worker = UploadWorker.shared
    @State private var queueCount = UploadQueue.shared.getPendingFiles().count
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Mô hình Coordinator - Worker")
                .font(.headline)
            
            HStack(spacing: 40) {
                VStack {
                    Text("\(queueCount)")
                        .font(.system(size: 40, weight: .bold))
                    Text("File trong Kho")
                }
                
                VStack {
                    Text("\(worker.activeUploadsCount)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.blue)
                    Text("Công nhân đang xử lý")
                }
            }
            .padding()
            
            Button("Tạo 1 File rác & Lưu vào DB") {
                createDummyFileAndEnqueue()
                queueCount = UploadQueue.shared.getPendingFiles().count
            }
            .buttonStyle(.borderedProminent)
            
            Text("Lưu ý: Không bấm upload ở đây.\nVuốt thoát app, dùng LLDB kích hoạt Điều Phối, Điều Phối sẽ tự gọi Công nhân.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding()
        }
        .onAppear {
            queueCount = UploadQueue.shared.getPendingFiles().count
        }
    }
    
    private func createDummyFileAndEnqueue() {
        let fileName = "log_data_\(UUID().uuidString.prefix(4)).txt"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? "Dữ liệu người dùng phát sinh trong ngày".write(to: fileURL, atomically: true, encoding: .utf8)
        
        UploadQueue.shared.enqueueFile(fileURL: fileURL)
        print("📦 Đã thêm file vào kho: \(fileName)")
    }
}
