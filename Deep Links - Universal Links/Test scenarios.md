Mình sẽ viết một SwiftUI project hoàn chỉnh. Architecture đi theo đúng pattern đã thảo luận: `RegistrationStore` persist state, `DeepLinkCoordinator` handle URL, auto-resume step khi cold start.

## Cấu trúc project

```
MyApp/
├── MyAppApp.swift           # Entry + onOpenURL
├── Models.swift             # Step enum, Draft model, AppRoute
├── Stores.swift             # RegistrationStore, AppState, DeepLinkCoordinator
└── Views/
    ├── RootView.swift
    ├── LoginView.swift
    ├── RegistrationContainerView.swift
    ├── StepIndicator.swift
    └── Steps/
        ├── Step1AccountView.swift
        ├── Step2PersonalInfoView.swift
        ├── Step3EmailView.swift
        └── Step4CompleteView.swift
```

## 1. Setup URL Scheme trong Xcode

Vào **Target → Info → URL Types** (hoặc edit `Info.plist`), thêm:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>myapp</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.example.myapp.deeplink</string>
    </dict>
</array>
```

## 2. Models.swift

```swift
import Foundation

// MARK: - Step

enum RegistrationStep: Int, Codable, CaseIterable {
    case notStarted = 0
    case step1Account = 1
    case step2PersonalInfo = 2
    case step3Email = 3
    case step4Complete = 4
    
    var title: String {
        switch self {
        case .notStarted:        return ""
        case .step1Account:      return "Account"
        case .step2PersonalInfo: return "Personal"
        case .step3Email:        return "Email"
        case .step4Complete:     return "Done"
        }
    }
}

// MARK: - Draft

struct RegistrationDraft: Codable, Equatable {
    // Step 1
    var username: String = ""
    var password: String = ""
    var confirmPassword: String = ""
    
    // Step 2
    var firstName: String = ""
    var lastName: String = ""
    var address: String = ""
    var phoneNumber: String = ""
    
    // Step 3
    var email: String = ""
    
    // Step 4 (từ deep link)
    var activeToken: String?
}

// MARK: - App Route

enum AppRoute {
    case login
    case registration
}
```

## 3. Stores.swift

```swift
import Foundation
import Combine

// MARK: - RegistrationStore

final class RegistrationStore: ObservableObject {
    
    @Published var draft: RegistrationDraft {
        didSet { persistDraft() }
    }
    
    @Published var currentStep: RegistrationStep {
        didSet { persistStep() }
    }
    
    private let draftKey = "registration.draft"
    private let stepKey  = "registration.step"
    private let defaults = UserDefaults.standard
    
    init() {
        // Load draft
        if let data = UserDefaults.standard.data(forKey: "registration.draft"),
           let saved = try? JSONDecoder().decode(RegistrationDraft.self, from: data) {
            self.draft = saved
        } else {
            self.draft = RegistrationDraft()
        }
        
        // Load step
        let raw = UserDefaults.standard.integer(forKey: "registration.step")
        self.currentStep = RegistrationStep(rawValue: raw) ?? .notStarted
    }
    
    // MARK: Public API
    
    func advance(to step: RegistrationStep) {
        currentStep = step
    }
    
    func reset() {
        draft = RegistrationDraft()
        currentStep = .notStarted
        defaults.removeObject(forKey: draftKey)
        defaults.removeObject(forKey: stepKey)
    }
    
    // MARK: Persistence
    
    private func persistDraft() {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        defaults.set(data, forKey: draftKey)
    }
    
    private func persistStep() {
        defaults.set(currentStep.rawValue, forKey: stepKey)
    }
}

// MARK: - AppState

final class AppState: ObservableObject {
    @Published var route: AppRoute = .login
}

// MARK: - DeepLinkCoordinator

final class DeepLinkCoordinator: ObservableObject {
    
    enum DeepLink {
        case activate(token: String)
    }
    
    /// Queue link nếu app chưa ready (cold start)
    private var pendingLink: DeepLink?
    private var isAppReady = false
    
    private weak var registrationStore: RegistrationStore?
    private weak var appState: AppState?
    
    func configure(store: RegistrationStore, appState: AppState) {
        self.registrationStore = store
        self.appState = appState
    }
    
    func appDidBecomeReady() {
        isAppReady = true
        if let pending = pendingLink {
            pendingLink = nil
            route(pending)
        }
    }
    
    func handle(_ url: URL) {
        guard let link = parse(url) else {
            print("⚠️ DeepLink không nhận diện được: \(url)")
            return
        }
        
        if isAppReady {
            route(link)
        } else {
            // Cold start — chưa setup xong UI, queue lại
            pendingLink = link
        }
    }
    
    // MARK: Private
    
    private func parse(_ url: URL) -> DeepLink? {
        guard url.scheme == "myapp" else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        // myapp://register?active_token=123456
        if components.host == "register",
           let token = components.queryItems?
                .first(where: { $0.name == "active_token" })?.value,
           !token.isEmpty {
            return .activate(token: token)
        }
        
        return nil
    }
    
    private func route(_ link: DeepLink) {
        switch link {
        case .activate(let token):
            guard let store = registrationStore, let appState = appState else { return }
            store.draft.activeToken = token
            store.advance(to: .step4Complete)
            appState.route = .registration
        }
    }
}
```

## 4. MyAppApp.swift

```swift
import SwiftUI

@main
struct MyAppApp: App {
    @StateObject private var registrationStore = RegistrationStore()
    @StateObject private var appState           = AppState()
    @StateObject private var deepLinkCoordinator = DeepLinkCoordinator()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(registrationStore)
                .environmentObject(appState)
                .environmentObject(deepLinkCoordinator)
                .onOpenURL { url in
                    deepLinkCoordinator.handle(url)
                }
                .task {
                    // Setup coordinator
                    deepLinkCoordinator.configure(
                        store: registrationStore,
                        appState: appState
                    )
                    
                    // Restore route theo step đã lưu (resume sau khi kill app)
                    if registrationStore.currentStep != .notStarted {
                        appState.route = .registration
                    }
                    
                    // Báo coordinator: app ready, replay pending deep link nếu có
                    deepLinkCoordinator.appDidBecomeReady()
                }
        }
    }
}
```

## 5. RootView.swift

```swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        switch appState.route {
        case .login:
            LoginView()
        case .registration:
            RegistrationContainerView()
        }
    }
}
```

## 6. LoginView.swift

```swift
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var registrationStore: RegistrationStore
    
    @State private var username = ""
    @State private var password = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                Text("Welcome")
                    .font(.largeTitle.bold())
                
                VStack(spacing: 12) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button {
                    // Mock login
                } label: {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Create new user") {
                    registrationStore.reset()
                    registrationStore.advance(to: .step1Account)
                    appState.route = .registration
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Login")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
```

## 7. RegistrationContainerView.swift

```swift
import SwiftUI

struct RegistrationContainerView: View {
    @EnvironmentObject var registrationStore: RegistrationStore
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StepIndicator(currentStep: registrationStore.currentStep)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                
                Divider()
                
                Group {
                    switch registrationStore.currentStep {
                    case .notStarted, .step1Account:
                        Step1AccountView()
                    case .step2PersonalInfo:
                        Step2PersonalInfoView()
                    case .step3Email:
                        Step3EmailView()
                    case .step4Complete:
                        Step4CompleteView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if registrationStore.currentStep != .step4Complete {
                        Button("Cancel") {
                            registrationStore.reset()
                            appState.route = .login
                        }
                    }
                }
            }
        }
    }
}
```

## 8. StepIndicator.swift

```swift
import SwiftUI

struct StepIndicator: View {
    let currentStep: RegistrationStep
    
    private let steps: [RegistrationStep] = [
        .step1Account, .step2PersonalInfo, .step3Email, .step4Complete
    ]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                stepCircle(index: index, step: step)
                
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(isCompleted(steps[index + 1]) ? Color.accentColor 
                                                            : Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
    }
    
    private func stepCircle(index: Int, step: RegistrationStep) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isCompleted(step) ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                
                if step.rawValue < currentStep.rawValue {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundColor(isCompleted(step) ? .white : .secondary)
                }
            }
            
            Text(step.title)
                .font(.caption2)
                .foregroundColor(isCompleted(step) ? .primary : .secondary)
        }
    }
    
    private func isCompleted(_ step: RegistrationStep) -> Bool {
        step.rawValue <= currentStep.rawValue
    }
}
```

## 9. Step1AccountView.swift

```swift
import SwiftUI

struct Step1AccountView: View {
    @EnvironmentObject var registrationStore: RegistrationStore
    
    var body: some View {
        Form {
            Section("Account Info") {
                TextField("Username", text: $registrationStore.draft.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                SecureField("Password", text: $registrationStore.draft.password)
                
                SecureField("Confirm Password", 
                            text: $registrationStore.draft.confirmPassword)
            }
            
            if let error = validationError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Section {
                Button("Next") {
                    registrationStore.advance(to: .step2PersonalInfo)
                }
                .frame(maxWidth: .infinity)
                .disabled(validationError != nil)
            }
        }
    }
    
    private var validationError: String? {
        let d = registrationStore.draft
        if d.username.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Username is required"
        }
        if d.password.count < 6 {
            return "Password must be at least 6 characters"
        }
        if d.password != d.confirmPassword {
            return "Passwords do not match"
        }
        return nil
    }
}
```

## 10. Step2PersonalInfoView.swift

```swift
import SwiftUI

struct Step2PersonalInfoView: View {
    @EnvironmentObject var registrationStore: RegistrationStore
    
    var body: some View {
        Form {
            Section("Personal Info") {
                TextField("First Name", text: $registrationStore.draft.firstName)
                TextField("Last Name",  text: $registrationStore.draft.lastName)
                TextField("Address",    text: $registrationStore.draft.address,
                          axis: .vertical)
                    .lineLimit(2...4)
                TextField("Phone Number", text: $registrationStore.draft.phoneNumber)
                    .keyboardType(.phonePad)
            }
            
            Section {
                HStack {
                    Button("Back") {
                        registrationStore.advance(to: .step1Account)
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Next") {
                        registrationStore.advance(to: .step3Email)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        let d = registrationStore.draft
        return !d.firstName.isEmpty 
            && !d.lastName.isEmpty 
            && !d.phoneNumber.isEmpty
    }
}
```

## 11. Step3EmailView.swift

```swift
import SwiftUI

struct Step3EmailView: View {
    @EnvironmentObject var registrationStore: RegistrationStore
    
    @State private var codeSent = false
    
    var body: some View {
        Form {
            Section("Email") {
                TextField("Email", text: $registrationStore.draft.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            
            Section {
                Button(codeSent ? "Code Sent ✓" : "Send Activation Code") {
                    sendCode()
                }
                .frame(maxWidth: .infinity)
                .disabled(!isEmailValid || codeSent)
            }
            
            if codeSent {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("📧 Đã gửi link kích hoạt tới email của bạn")
                            .font(.subheadline.bold())
                        
                        Text("Mở email và click vào link để hoàn tất đăng ký.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        Text("🧪 Test trên Simulator:")
                            .font(.caption.bold())
                        
                        Text("xcrun simctl openurl booted 'myapp://register?active_token=123456'")
                            .font(.system(.caption2, design: .monospaced))
                            .padding(8)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(6)
                            .textSelection(.enabled)
                        
                        Text("Hoặc: Kill app → mở Safari → gõ URL trên → app sẽ mở Step 4")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section {
                Button("Back") {
                    registrationStore.advance(to: .step2PersonalInfo)
                }
            }
        }
    }
    
    private var isEmailValid: Bool {
        registrationStore.draft.email.contains("@") &&
        registrationStore.draft.email.contains(".")
    }
    
    private func sendCode() {
        // Mock: backend gửi email với link myapp://register?active_token=...
        codeSent = true
    }
}
```

## 12. Step4CompleteView.swift

```swift
import SwiftUI

struct Step4CompleteView: View {
    @EnvironmentObject var registrationStore: RegistrationStore
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Register Complete!")
                .font(.largeTitle.bold())
            
            VStack(spacing: 8) {
                infoRow(label: "Username",  value: registrationStore.draft.username)
                infoRow(label: "Full Name", 
                        value: "\(registrationStore.draft.firstName) \(registrationStore.draft.lastName)")
                infoRow(label: "Email",     value: registrationStore.draft.email)
                infoRow(label: "Active Token", 
                        value: registrationStore.draft.activeToken ?? "-")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            Button("Go to Login") {
                registrationStore.reset()
                appState.route = .login
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
        }
        .padding()
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

## 13. Cách test deep link

**Cách 1: Terminal với Simulator đang chạy**
```bash
xcrun simctl openurl booted "myapp://register?active_token=123456"
```

**Cách 2: Trong Safari (Simulator hoặc device)**
- Mở Safari, gõ vào address bar: `myapp://register?active_token=123456`
- Safari sẽ hỏi "Open in MyApp?" → tap Open.

**Cách 3: Notes app**
- Tạo note có link `myapp://register?active_token=123456`
- Tap vào link.

## 14. Test scenarios để verify hoạt động đúng

| Test case | Cách test | Expected |
|---|---|---|
| Resume Step 1 sau kill | Nhập username dở → kill app → mở lại | Vào thẳng Step 1 với data cũ |
| Resume Step 2 sau kill | Hoàn thành Step 1 → vào Step 2 nhập dở → kill app → mở lại | Vào thẳng Step 2 với data Step 1 + Step 2 |
| Deep link khi app foreground | App đang ở Step 3 → chạy `xcrun simctl openurl` | Nhảy tới Step 4 với token |
| Deep link khi app killed | Kill app → chạy `xcrun simctl openurl` | App cold start → vào thẳng Step 4 |
| Deep link khi chưa login | Chưa từng đăng ký → click deep link | App vào Step 4 với token (do `pendingLink` queue + `appDidBecomeReady`) |
| Reset sau khi complete | Step 4 → nhấn "Go to Login" | UserDefaults clean, quay về login |

## 15. Lưu ý production-grade

Code này là **practice scope** nên dùng UserDefaults cho cả password — **production tuyệt đối không làm vậy**. Đúng pattern:

- **Password trong Step 1**: không persist locally, hoặc nếu cần resume, lưu hash + Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).
- **Activation token Step 4**: Keychain.
- **Personal info Step 2**: có thể UserDefaults nếu không nhạy cảm, hoặc Core Data nếu cần structured.
- **Server validate token**: Step 4 phải call API verify token, không trust URL blindly.
- **Reset draft khi đăng nhập user khác**: tránh leak data giữa các user trên cùng device.

Để upgrade lên production, swap `UserDefaults` trong `RegistrationStore` bằng `KeychainManager` cho field nhạy cảm là xong — interface không đổi.
