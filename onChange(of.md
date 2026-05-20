Chào bạn, tài liệu bạn đang đọc nói về những thay đổi rất đáng giá của modifier `.onChange` được Apple giới thiệu từ **iOS 17**. 

Trước iOS 17, `.onChange` chỉ trả về giá trị mới, khiến việc so sánh với giá trị cũ khá cồng kềnh. Ở phiên bản mới này, Apple đã cập nhật hai hàm `.onChange` chính:
1. **Cung cấp cả `oldValue` và `newValue`**: Rất tiện để so sánh sự thay đổi.
2. **Không cung cấp tham số (0-parameter)**: Dùng khi bạn chỉ cần biết "giá trị đã đổi" và muốn lấy thẳng giá trị hiện tại từ biến `@State`.
3. **Thêm tham số `initial`**: Cho phép trigger hành động ngay khi View vừa xuất hiện lần đầu (thay vì phải đợi đến khi có sự thay đổi đầu tiên).

Dưới đây là một đoạn code hoàn chỉnh, có thể chạy trực tiếp trên Xcode (phiên bản hỗ trợ iOS 17+) để bạn hình dung rõ nhất cách hai hàm này hoạt động trên thực tế.

### Đoạn code ví dụ hoàn chỉnh

Bạn có thể copy toàn bộ đoạn code này vào một file SwiftUI trong Xcode để chạy thử (ví dụ: `ContentView.swift`):

```swift
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
```

---

### Phân tích chi tiết những gì đang diễn ra

**1. `.onChange(of: playState, initial: true) { oldValue, newValue in ... }`**
* **`of: playState`**: Lắng nghe sự thay đổi của biến `playState`.
* **`initial: true`**: Ngay khi ứng dụng vừa chạy lên (View xuất hiện), closure này sẽ được gọi ngay lập tức 1 lần. Lúc này, cả `oldValue` và `newValue` đều sẽ mang giá trị khởi tạo ban đầu là `.stopped`. Khúc này cực kỳ hữu ích nếu bạn cần gọi API lấy dữ liệu dựa trên biến state ngay khi vào màn hình.
* **`oldValue, newValue`**: Khi bạn bấm chọn "Phát", closure sẽ cung cấp `oldValue` là `.stopped` và `newValue` là `.playing`. Nhờ đó, bạn có thể viết logic kiểu: *"Nếu đang từ 'Đang phát' chuyển sang 'Tạm dừng' thì lưu thời gian bài hát lại"*.

**2. `.onChange(of: volume) { ... }`**
* **Không có tham số closure**: Cách viết này ngắn gọn hơn. Nó được dùng khi sự thay đổi xảy ra, và bạn chỉ cần gọi một hàm nào đó (ví dụ: `saveVolumeSettings()`) hoặc đọc trực tiếp biến `@State volume` hiện tại.
* **`initial: false` (Mặc định)**: Vì chúng ta không truyền `initial`, closure này sẽ **không** chạy lúc View vừa load. Nó chỉ chạy khi bạn thực sự kéo thanh Slider làm thay đổi giá trị.

Trong tài liệu Apple cũng có nhắc một lưu ý quan trọng: *"avoid long-running tasks in the closure"* (tránh các tác vụ chạy quá lâu trong block này vì nó chạy trên Main Thread và có thể làm đơ UI). 

Bạn có đang định sử dụng `.onChange` này để gọi dữ liệu từ mạng (Network API Request) khi một biến nào đó thay đổi không?
