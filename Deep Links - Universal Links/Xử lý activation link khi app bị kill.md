# Xử lý activation link khi app bị kill — UIKit

## 1. Hiểu đúng bài toán

Vấn đề cốt lõi không phải là "deep link vào app", mà là **xử lý cold launch từ deep link khi app chưa setup xong UI hierarchy** + **persist trạng thái đăng ký dở dang** để resume đúng flow.

Có 3 scenarios cần handle riêng:

1. **App đang foreground** — user đang ở trong app, click link từ Mail/notification → app nhận link ngay, route tới activation screen.
2. **App ở background (suspended)** — app vẫn còn trong memory, OS resume lên → giống case 1, nhưng vào qua callback khác.
3. **App bị kill (terminated/cold start)** — app launch from scratch, deep link đến trước khi `rootViewController` ready. Đây là case khó nhất.

## 2. Entry point khác nhau giữa các scenarios

Với **UIKit + SceneDelegate** (iOS 13+), entry points cho Universal Link:

```swift
// Scenario 3: Cold start — link đến qua connectionOptions
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, 
           options connectionOptions: UIScene.ConnectionOptions) {
    // Universal Link
    if let userActivity = connectionOptions.userActivities.first(
        where: { $0.activityType == NSUserActivityTypeBrowsingWeb }) {
        handleDeepLink(userActivity.webpageURL)
    }
    // Custom URL Scheme
    if let urlContext = connectionOptions.urlContexts.first {
        handleDeepLink(urlContext.url)
    }
}

// Scenario 1, 2: App foreground/background — link đến qua delegate callback
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    handleDeepLink(userActivity.webpageURL)
}

func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    handleDeepLink(URLContexts.first?.url)
}
```

Nếu dùng **AppDelegate-only** (không SceneDelegate, project cũ):
```swift
// Cold start
func application(_ application: UIApplication, 
                 didFinishLaunchingWithOptions launchOptions: ...) -> Bool {
    if let url = launchOptions?[.url] as? URL { /* custom scheme */ }
    if let userActivityDict = launchOptions?[.userActivityDictionary] as? [String: Any],
       let activity = userActivityDict["UIApplicationLaunchOptionsUserActivityKey"] 
                      as? NSUserActivity {
        // universal link
    }
    return true
}
```

## 3. Pending Deep Link pattern — chìa khóa cho cold start

Vấn đề thực tế ở cold start: lúc `scene(_:willConnectTo:)` chạy, **`window.rootViewController` có thể chưa attach, hoặc đang là splash/launch screen**, chưa thể `present` activation screen ngay. Thậm chí app còn cần fetch config, check session, animate splash...

Pattern chuẩn là **queue deep link, replay khi app ready**:

```swift
final class DeepLinkCoordinator {
    static let shared = DeepLinkCoordinator()
    
    private var pendingLink: DeepLink?
    private var isAppReady = false
    
    enum DeepLink {
        case activation(token: String)
        case resetPassword(token: String)
        // ...
    }
    
    func handle(_ url: URL?) {
        guard let url, let link = parse(url) else { return }
        
        if isAppReady {
            route(link)
        } else {
            pendingLink = link  // Queue lại
        }
    }
    
    func appDidBecomeReady() {
        isAppReady = true
        if let link = pendingLink {
            pendingLink = nil
            route(link)
        }
    }
    
    private func route(_ link: DeepLink) {
        switch link {
        case .activation(let token):
            ActivationFlow.start(with: token)
        // ...
        }
    }
    
    private func parse(_ url: URL) -> DeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.path == "/activate",
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value
        else { return nil }
        return .activation(token: token)
    }
}
```

`appDidBecomeReady()` được gọi **sau khi**: splash xong, config loaded, session đã check. Đây là điểm sync giữa app launch sequence và deep link sequence — tránh race condition kinh điển ở cold start.

## 4. Persist trạng thái đăng ký dở dang

Phần quan trọng mà nhiều người quên: **server đã tạo user record (pending state) trước khi user click link**. App cũng cần nhớ user đang ở step nào để khi quay lại không bắt nhập lại từ đầu.

Lưu ở 2 nơi với 2 mục đích khác nhau:

**Keychain** — lưu thông tin nhạy cảm và bền vững:
```swift
struct PendingRegistration: Codable {
    let userId: String
    let email: String
    let createdAt: Date
    let stepCompleted: RegistrationStep
}

enum RegistrationStep: Int, Codable {
    case emailSubmitted     // đã tạo user, chờ activation
    case emailVerified      // đã click link, cần fill thêm info
    case profileCompleted   // xong
}
```

Lưu Keychain (qua wrapper `KeychainManager` mà bạn đã làm trước đây) vì:
- Survive cả uninstall trên iOS cũ và app reset (tùy access group config).
- Không lộ trên backup chưa encrypt.
- Phù hợp với token nhạy cảm.

**UserDefaults** — chỉ flag UI state nhẹ (ví dụ: "đã show tutorial chưa"), không lưu activation token.

## 5. Validate token với server, đừng tin URL

URL từ email có thể đã bị forward, expired, hoặc đã used. **Đừng route blindly**, phải validate trước:

```swift
final class ActivationFlow {
    static func start(with token: String) {
        // 1. Hiện loading state ngay
        let loadingVC = LoadingViewController()
        UIApplication.shared.topMostViewController()?
            .present(loadingVC, animated: false)
        
        // 2. Validate với server
        Task {
            do {
                let result = try await AuthService.verifyActivationToken(token)
                
                await MainActor.run {
                    loadingVC.dismiss(animated: false) {
                        switch result {
                        case .valid(let userId):
                            // Update local state, present completion screen
                            PendingRegistrationStore.update(
                                userId: userId, 
                                step: .emailVerified
                            )
                            presentCompleteProfileScreen(userId: userId)
                            
                        case .alreadyActivated:
                            presentLoginScreen(message: "Tài khoản đã được kích hoạt")
                            
                        case .expired:
                            presentResendActivationScreen()
                            
                        case .invalid:
                            presentErrorAlert()
                        }
                    }
                }
            } catch {
                // Network error — keep token, allow retry
            }
        }
    }
}
```

## 6. Reset navigation stack đúng cách

Khi cold start từ deep link, không nên push activation screen lên trên màn login bình thường. Nên **replace root** hoặc dùng dedicated navigation stack:

```swift
func presentCompleteProfileScreen(userId: String) {
    let vc = CompleteProfileViewController(userId: userId)
    let nav = UINavigationController(rootViewController: vc)
    nav.modalPresentationStyle = .fullScreen
    
    // Option A: thay root
    UIApplication.shared.firstKeyWindow?.rootViewController = nav
    
    // Option B: present trên top
    // UIApplication.shared.topMostViewController()?.present(nav, animated: true)
}
```

Option A clean hơn cho cold start (user chưa có context gì trong app), Option B phù hợp warm start (user đang dùng app khác trong app).

## 7. Edge cases senior phải nghĩ tới

**App bị uninstall rồi reinstall**: Keychain mặc định bị xoá khi uninstall (từ iOS 10.3+). User click link → app cold start nhưng không còn `pendingRegistration` local. Solution: server là source of truth, token tự nó đủ identify user, app chỉ cần token là verify được.

**Token chứa trong path vs query**: Universal Link nên là `https://example.com/activate/<token>` (path) hơn là `?token=<token>` (query) — query dễ bị log lại trong analytics, server access log, browser history nếu fallback web. Path component an toàn hơn.

**Multiple taps / re-entry**: User click link 2 lần, hoặc activation screen đang mở lại nhận link mới → cần debounce hoặc check state hiện tại trước khi route. `DeepLinkCoordinator` nên có cờ "currently processing" để skip duplicate.

**Activation link mở Safari thay vì app** (Universal Link "broken" sau khi user chọn "Open in Safari"): Server-side fallback page nên có **Smart App Banner** + button "Open in App" gọi custom scheme `myapp://activate?token=...` làm backup. Tức là backend serve cùng URL có thể fallback web → sang custom scheme.

**Token trong URL là one-time-use**: Sau khi `verifyActivationToken` success, server invalidate token đó. Nếu user vô tình click lại link cũ → trả về `.alreadyActivated`, app handle gracefully.

**App đang ở chế độ guest/logged-in user khác**: Nếu app đã có session của user A, click activation link của user B → cần warning/logout flow rõ ràng, không silent override.

**Background fetch / silent push trước khi user click link**: Trong khoảng thời gian giữa "tạo user" và "click link", có thể app đã sync data ở background và xoá pending state cache. → Server vẫn là single source of truth, đừng phụ thuộc cache.

## 8. Tổng kết flow

Tóm gọn lại các thành phần:

1. **`SceneDelegate`** — bắt link ở cả cold start (`willConnectTo`) và warm start (`continue`/`openURLContexts`).
2. **`DeepLinkCoordinator`** — parse URL, queue nếu app chưa ready, route khi ready.
3. **App launch sequence** — sau khi splash + config + session check xong, gọi `coordinator.appDidBecomeReady()`.
4. **`PendingRegistrationStore`** (Keychain) — persist progress để resume.
5. **`AuthService.verifyActivationToken`** — server validate, trả về state rõ ràng.
6. **`ActivationFlow`** — orchestrate UI: loading → server validate → branch theo result → reset navigation root.

Architecture này tách biệt 3 concerns: **bắt link** (SceneDelegate), **điều phối** (Coordinator), **business logic** (ActivationFlow). Dễ test, dễ mock, và scale được khi có thêm các loại deep link khác (reset password, open product, share content...).
