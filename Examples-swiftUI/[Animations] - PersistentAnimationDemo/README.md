Hai file này giải quyết bài toán: animation Core Animation bình thường sẽ **mất khi app vào background rồi quay lại** — extension của Philip Vasilchenko lưu lại animation lúc `didEnterBackground` và khôi phục lúc `willEnterForeground`, đồng thời giữ đúng trạng thái pause/play.

Mình sẽ viết một demo SwiftUI hoàn chỉnh, chạy được ngay, dùng đúng 2 extension đó. Demo sẽ có animation lặp vô hạn (để bạn thấy rõ hiệu ứng persistent khi background/foreground) cùng nút pause/resume.Xong. Demo dùng đúng cả 2 extension bạn đính kèm.

**Cách chạy (Xcode):**
1. Tạo project SwiftUI mới (hoặc dùng project sẵn có).
2. Thêm vào target 3 file: `CALayer+AnimationPlayback.swift`, `CALayer+PersistentAnimations.swift` (của bạn) và `PersistentAnimationDemoView.swift` (mới tạo).
3. Trỏ entry point tới view demo:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            PersistentAnimationDemoView()
        }
    }
}
```

**Từng extension được dùng ở đâu:**

- `makeAnimationsPersistent()` (từ `CALayer+PersistentAnimations.swift`) — gọi một lần trong `init` của UIView. Đây là thứ tự động lưu animation lúc `didEnterBackground` và khôi phục lúc `willEnterForeground`.
- `pauseAnimations()` / `resumeAnimations()` / `isAnimationsPaused` (từ `CALayer+AnimationPlayback.swift`) — dùng cho nút Pause/Resume và cũng được chính file persistent gọi nội bộ.

**Cách kiểm chứng hiệu ứng chính** (phải chạy trên thiết bị thật hoặc Simulator, không thấy trong Preview vì Preview không có vòng đời background/foreground thật):
- Bấm Start → ô vuông chạy qua lại lặp vô hạn.
- Nhấn Home / vuốt app ra → chờ vài giây → mở lại. Animation vẫn tiếp tục đúng chỗ. Nếu gỡ dòng `layer.makeAnimationsPersistent()` đi, khi quay lại foreground animation sẽ biến mất — đó chính là vấn đề mà 2 file này khắc phục.

Mình chọn animation `position.x` lặp vô hạn với `autoreverses` để hiệu ứng persistent dễ quan sát nhất. Nếu bạn muốn demo với nhiều loại animation cùng lúc (ví dụ thêm xoay hoặc đổi màu) để test việc lưu/khôi phục nhiều key animation, mình bổ sung được.