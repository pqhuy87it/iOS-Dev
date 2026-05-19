Đây là một yêu cầu bảo mật tiêu chuẩn (Standard Security Requirement) cho các ứng dụng Banking/Fintech. Mục đích là để ngăn hệ điều hành iOS chụp lại ảnh màn hình (Snapshot) chứa thông tin nhạy cảm khi người dùng mở màn hình đa nhiệm (App Switcher).

Dưới đây là hướng dẫn chi tiết cách triển khai cho cả **UIKit (SceneDelegate)** và **SwiftUI**.

---

### Cách 1: Triển khai với UIKit (SceneDelegate)

Đây là cách phổ biến nhất cho các dự án hiện tại. Chúng ta sẽ can thiệp vào vòng đời của `UIWindowScene`.

**File cần sửa:** `SceneDelegate.swift`

#### Bước 1: Khai báo View che màn hình

Trong class `SceneDelegate`, khai báo một biến để giữ tham chiếu tới view làm mờ (để sau này còn gỡ nó ra).

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    // Khai báo biến giữ view che
    private var privacyProtectionWindow: UIWindow?

    // ... các hàm khác
}

```

#### Bước 2: Viết hàm hiển thị và ẩn Blur View

Thêm 2 hàm này vào `SceneDelegate` để xử lý logic thêm/bớt view.

```swift
extension SceneDelegate {
    
    // Hàm gọi khi App sắp sửa vào Background (Inactive)
    func showPrivacyProtectionWindow() {
        guard let windowScene = self.window?.windowScene else { return }
        
        // Tạo một UIWindow mới nằm đè lên Window chính
        let privacyWindow = UIWindow(windowScene: windowScene)
        privacyWindow.frame = UIScreen.main.bounds
        privacyWindow.windowLevel = .alert + 1 // Đảm bảo nó nằm trên cùng, đè cả Alert
        
        // Cách 1: Dùng Blur Effect (Mờ ảo)
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = privacyWindow.bounds
        privacyWindow.addSubview(blurView)
        
        // Cách 2: (Tuỳ chọn) Thêm Logo ngân hàng vào giữa cho đẹp
        let logoImageView = UIImageView(image: UIImage(named: "app_logo"))
        logoImageView.center = privacyWindow.center
        privacyWindow.addSubview(logoImageView)
        
        // Hiển thị
        privacyWindow.makeKeyAndVisible()
        self.privacyProtectionWindow = privacyWindow
    }
    
    // Hàm gọi khi App quay lại Foreground
    func hidePrivacyProtectionWindow() {
        // Hủy window che đi, trả lại quyền điều khiển cho window chính
        self.privacyProtectionWindow?.isHidden = true
        self.privacyProtectionWindow = nil
        self.window?.makeKeyAndVisible()
    }
}

```

#### Bước 3: Gọi hàm đúng thời điểm (Quan trọng)

Bạn phải gọi hàm ở `sceneWillResignActive`.

* **Tại sao không phải `sceneDidEnterBackground`?** Vì `DidEnterBackground` đôi khi chạy trễ hơn thời điểm iOS chụp ảnh màn hình (Snapshot). `WillResignActive` xảy ra ngay khi người dùng vuốt thanh Home bar lên, đảm bảo che kịp thời.

```swift
func sceneWillResignActive(_ scene: UIScene) {
    // Gọi ngay khi user vuốt đa nhiệm
    showPrivacyProtectionWindow()
}

func sceneDidBecomeActive(_ scene: UIScene) {
    // Gọi khi user quay lại app
    hidePrivacyProtectionWindow()
}

```

---

### Cách 2: Triển khai với SwiftUI (Native)

Nếu bạn dùng 100% SwiftUI (App Protocol), logic sẽ nằm ở file chính của App (`MyApp.swift`) và lắng nghe `scenePhase`.

**File:** `YourApp.swift`

```swift
import SwiftUI

@main
struct BankApp: App {
    // Lắng nghe trạng thái của App
    @Environment(\.scenePhase) var scenePhase
    
    // Trạng thái để kích hoạt blur
    @State private var isBlurring: Bool = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Màn hình chính của App
                ContentView()
                
                // Lớp phủ Blur nằm đè lên trên
                if isBlurring {
                    Color.white.opacity(0.1) // Nền nhẹ
                        .background(.ultraThinMaterial) // Hiệu ứng Blur chuẩn iOS
                        .ignoresSafeArea()
                        .overlay(
                            // Thêm Logo hoặc Text tuỳ ý
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.gray)
                        )
                        .transition(.opacity) // Animation mượt mà
                }
            }
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .active:
                    // App đang hoạt động -> Gỡ Blur
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isBlurring = false
                    }
                case .inactive, .background:
                    // App sắp ẩn -> Bật Blur ngay lập tức
                    // Không dùng animation ở đây để che tức thì
                    isBlurring = true
                @unknown default:
                    break
                }
            }
        }
    }
}

```

---

### Một số lưu ý cho Senior Developer:

1. **Đừng dùng `UIView` thêm vào `keyWindow` (Cách cũ):**
* Trước đây chúng ta hay làm `window.addSubview(blurView)`.
* **Nhược điểm:** Nếu App đang hiển thị bàn phím hoặc Alert, việc `addSubview` đôi khi không che được các thành phần này (vì bàn phím nằm ở window khác).
* **Giải pháp tốt nhất (như Cách 1):** Tạo hẳn một `UIWindow` mới và set `windowLevel = .alert + 1`. Nó sẽ che phủ tuyệt đối mọi thứ, kể cả bàn phím hệ thống hay các popup đang hiện.


2. **Trải nghiệm người dùng (UX):**
* Khi người dùng quay lại app (`DidBecomeActive`), nếu bạn dùng FaceID, **đừng gỡ Blur vội**.
* Hãy giữ Blur view đó, hiển thị popup FaceID đè lên trên. Chỉ khi FaceID thành công mới gỡ Blur. Điều này giúp trải nghiệm mượt mà và bảo mật hơn (không bị nháy lộ nội dung trước khi FaceID kịp chạy).


3. **Snapshot Test:**
* Để kiểm tra xem code chạy đúng không, hãy chạy App trên máy thật/simulator -> Vuốt ra màn hình Home -> Chụp màn hình điện thoại.
* Sau đó mở thư viện ảnh xem ảnh screenshot đó có bị mờ không. (Lưu ý: Không dùng tính năng screenshot bằng nút cứng để test, vì lúc đó app vẫn đang `Active`).
