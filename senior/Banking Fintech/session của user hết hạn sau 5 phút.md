Đây là một câu hỏi kinh điển trong phỏng vấn lĩnh vực Ngân hàng/Fintech. Để giải quyết bài toán này **chính xác** và **bảo mật**, bạn không thể chỉ dựa vào một bộ đếm thời gian (Timer) đơn thuần vì Timer sẽ bị hệ điều hành đóng băng (suspend) khi App vào background.

Giải pháp chuẩn cho Senior iOS Developer bao gồm sự kết hợp của 3 kỹ thuật: **Subclass UIWindow (để bắt sự kiện chạm), Timestamp Comparison (So sánh thời gian), và Lifecycle Monitoring.**

Dưới đây là kiến trúc chi tiết và code mẫu:

### 1. Nguyên lý hoạt động (The Logic)

1. **Khi App đang chạy (Foreground):** Sử dụng một `Timer` đếm ngược. Mỗi khi người dùng chạm vào màn hình, reset Timer về 5 phút. Nếu Timer chạy về 0 -> Logout.
2. **Khi App vào Background:**
* Hủy Timer (để tiết kiệm pin và tránh lỗi).
* Lưu lại **Thời điểm vào background** (hoặc thời điểm thao tác cuối cùng).
* Làm mờ màn hình (Blur) để bảo mật thông tin trong App Switcher.


3. **Khi App quay lại (Enter Foreground):**
* Lấy thời gian hiện tại trừ đi thời gian thao tác cuối cùng.
* Nếu `Current Time - Last Interaction Time > 5 phút` -> Logout ngay lập tức trước khi hiển thị bất kỳ màn hình nào.



---

### 2. Triển khai kỹ thuật (Implementation)

Chúng ta sẽ tạo một `SessionManager` singleton và custom `UIWindow`.

#### Bước 1: Tạo SessionManager

Class này chịu trách nhiệm quản lý logic hết hạn.

```swift
import UIKit

class SessionManager {
    static let shared = SessionManager()
    
    private var inactivityTimer: Timer?
    private let timeoutInterval: TimeInterval = 5 * 60 // 5 phút
    private var lastInteractionDate: Date = Date()
    
    // Callback để gọi logout từ bên ngoài
    var onSessionExpired: (() -> Void)?
    
    private init() {
        // Lắng nghe sự kiện Lifecycle
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    // Hàm được gọi mỗi khi user chạm vào màn hình
    func resetTimer() {
        // Cập nhật thời gian tương tác cuối cùng
        lastInteractionDate = Date()
        
        // Restart Timer (chỉ có ý nghĩa khi ở Foreground)
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(timeInterval: timeoutInterval, target: self, selector: #selector(handleTimeout), userInfo: nil, repeats: false)
    }
    
    @objc private func handleTimeout() {
        logoutUser()
    }
    
    private func logoutUser() {
        inactivityTimer?.invalidate()
        print("Session expired! Logging out...")
        // Gọi logic logout (clear token, chuyển về màn hình Login)
        onSessionExpired?()
    }
    
    // MARK: - Lifecycle Handling
    
    @objc private func appDidEnterBackground() {
        // Khi vào background, Timer sẽ bị suspend hoặc kill.
        // Ta invalidate nó để tránh hành vi không xác định.
        // Quan trọng: lastInteractionDate đã được lưu lần cuối ở hàm resetTimer()
        inactivityTimer?.invalidate()
    }
    
    @objc private func appWillEnterForeground() {
        // Khi quay lại, kiểm tra khoảng thời gian trôi qua
        let timeElapsed = Date().timeIntervalSince(lastInteractionDate)
        
        if timeElapsed >= timeoutInterval {
            // Đã quá 5 phút -> Logout ngay
            logoutUser()
        } else {
            // Chưa hết hạn -> Chạy lại timer cho khoảng thời gian còn lại
            // Hoặc đơn giản là reset lại 5 phút (tuỳ nghiệp vụ ngân hàng)
            // Ngân hàng thường reset lại 5 phút nếu session chưa chết.
            resetTimer()
        }
    }
}

```

#### Bước 2: Subclass UIWindow (Chìa khóa quan trọng)

Làm sao để biết user chạm vào màn hình mà không cần gắn code vào từng nút bấm? Ta ghi đè hàm `sendEvent` của `UIWindow`. Mọi sự kiện chạm (touch) đều phải đi qua đây.

```swift
import UIKit

class InactivityTrackingWindow: UIWindow {
    
    override func sendEvent(_ event: UIEvent) {
        // Mỗi khi có sự kiện (chạm, lắc, remote control...)
        // Kiểm tra xem đó có phải là sự kiện chạm tay không
        if let touches = event.allTouches, let touch = touches.first, touch.phase == .began {
            // Reset timer trong SessionManager
            SessionManager.shared.resetTimer()
        }
        
        // Tiếp tục gửi sự kiện đi để App hoạt động bình thường
        super.sendEvent(event)
    }
}

```

#### Bước 3: Cấu hình trong SceneDelegate (hoặc AppDelegate)

Bạn cần bảo đảm App sử dụng `InactivityTrackingWindow` thay vì `UIWindow` mặc định.

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Sử dụng Custom Window
        let customWindow = InactivityTrackingWindow(windowScene: windowScene)
        
        // Setup Root View Controller
        customWindow.rootViewController = LoginViewController() // Ví dụ
        self.window = customWindow
        customWindow.makeKeyAndVisible()
        
        // Bắt đầu theo dõi ngay khi app chạy
        SessionManager.shared.resetTimer()
        
        // Xử lý callback logout
        SessionManager.shared.onSessionExpired = { [weak self] in
            self?.performLogout()
        }
    }
    
    func performLogout() {
        // Code điều hướng về màn hình Login
        // Xóa Token trong Keychain
        DispatchQueue.main.async {
            let loginVC = LoginViewController()
            self.window?.rootViewController = loginVC
        }
    }
}

```

---

### 3. Yếu tố "Banking Standard" (Điểm cộng cho Senior)

Để trả lời xuất sắc câu hỏi này, bạn cần bổ sung các yếu tố bảo mật đặc thù của ngân hàng:

1. **Bảo vệ App Switcher (Snapshot Protection):**
Ngay cả khi session chưa hết hạn, khi user vuốt app ra đa nhiệm (background), bạn **bắt buộc** phải che nội dung lại để người đứng cạnh không nhìn thấy số dư.
* *Cách làm:* Tại `sceneWillResignActive`, add một `UIVisualEffectView` (Blur view) phủ lên toàn bộ `window`. Tại `sceneDidBecomeActive`, remove view đó đi.


2. **Server-side Validation (Double Check):**
Client check 5 phút là chưa đủ (vì user có thể đổi giờ hệ thống trên điện thoại).
* *Giải pháp:* Token (JWT) gửi kèm request cũng phải có thời gian hết hạn (expiration time). Nếu Client tính sai mà gửi request lên, Server sẽ trả về `401 Unauthorized`, lúc đó App bắt sự kiện này và đá user ra.


3. **Local Authentication Fallback:**
Nếu user quay lại app sau 3 phút (chưa hết hạn 5 phút), app ngân hàng thường không logout nhưng yêu cầu **xác thực lại nhanh** bằng FaceID/TouchID để tiếp tục phiên làm việc, thay vì bắt nhập password.
4. **Xử lý Accessibility:**
Nếu user đang dùng VoiceOver, thao tác "nghe" nội dung đôi khi không tạo ra sự kiện touch `.began`. Cần handle thêm các sự kiện accessibility trong `sendEvent` để tránh logout oan người khiếm thị.

### Tóm tắt câu trả lời phỏng vấn:

> *"Để giải quyết vấn đề này, tôi sẽ sử dụng một kiến trúc tập trung xoay quanh `UIWindow`. Tôi tạo một class `SessionManager` để quản lý thời gian và một subclass của `UIWindow` để override hàm `sendEvent`. Cách này giúp bắt mọi tương tác của user trên toàn app mà không cần sửa code từng màn hình.
> Đối với vấn đề background, tôi không dựa vào Timer vì nó sẽ bị suspend. Thay vào đó, tôi lưu `timestamp` tại thời điểm user tương tác cuối cùng. Khi app `willEnterForeground`, tôi so sánh `Date()` hiện tại với timestamp đã lưu. Nếu quá 5 phút, tôi thực hiện logout và xóa sạch dữ liệu nhạy cảm trong bộ nhớ trước khi UI kịp hiển thị. Ngoài ra, tôi cũng kết hợp che mờ màn hình (Blur snapshot) ngay khi app vào background để đảm bảo bảo mật thị giác."*
