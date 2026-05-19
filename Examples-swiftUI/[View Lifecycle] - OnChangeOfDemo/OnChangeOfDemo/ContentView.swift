import SwiftUI

// 1. Định nghĩa trạng thái của Player
enum PlayState: String, Equatable {
    case paused = "Tạm dừng"
    case playing = "Đang phát"
    case stopped = "Đã dừng"
}

struct ContentView: View {
    // Biến state thứ 1: Quản lý trạng thái phát nhạc
    @State private var playState: PlayState = .stopped
    
    // Biến state thứ 2: Quản lý âm lượng
    @State private var volume: Double = 50.0
    
    // Biến phụ để hiển thị log ra màn hình giúp bạn dễ quan sát
    @State private var actionLogs: [String] = []
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Trình Phát Nhạc Demo")
                .font(.title)
                .bold()
            
            // --- KHU VỰC ĐIỀU KHIỂN ---
            VStack(spacing: 15) {
                // Điều khiển PlayState
                Picker("Trạng thái", selection: $playState) {
                    Text("Dừng").tag(PlayState.stopped)
                    Text("Phát").tag(PlayState.playing)
                    Text("Tạm dừng").tag(PlayState.paused)
                }
                .pickerStyle(.segmented)
                
                // Điều khiển Volume
                VStack {
                    Text("Âm lượng: \(Int(volume))")
                    Slider(value: $volume, in: 0...100, step: 10)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // --- KHU VỰC HIỂN THỊ LOG ---
            VStack(alignment: .leading) {
                Text("Lịch sử thay đổi (Logs):")
                    .font(.headline)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(actionLogs.indices, id: \.self) { index in
                            Text(actionLogs[index])
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 150)
                .padding()
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
                
                Button("Xóa Log") {
                    actionLogs.removeAll()
                }
            }
        }
        .padding()
        
        // ==========================================
        // ÁP DỤNG .onChange (CÁCH 1 - CÓ OLD & NEW)
        // ==========================================
        // Áp dụng cho biến `playState`.
        // initial: true nghĩa là nó sẽ ghi log ngay khi View vừa load lần đầu.
        .onChange(of: playState, initial: true) { oldValue, newValue in
            let logMsg = "🎵 PlayState đổi: [\(oldValue.rawValue)] -> [\(newValue.rawValue)]"
            actionLogs.insert(logMsg, at: 0) // Thêm log mới lên đầu
        }
        
        // ==========================================
        // ÁP DỤNG .onChange (CÁCH 2 - KHÔNG THAM SỐ)
        // ==========================================
        // Áp dụng cho biến `volume`.
        // Dùng khi bạn không cần biết giá trị cũ là gì, chỉ cần biết nó vừa thay đổi.
        .onChange(of: volume) {
            // Lấy trực tiếp giá trị mới từ biến state `volume`
            let logMsg = "🔊 Âm lượng vừa được cập nhật thành: \(Int(volume))"
            actionLogs.insert(logMsg, at: 0)
        }
    }
}

#Preview {
    ContentView()
}
