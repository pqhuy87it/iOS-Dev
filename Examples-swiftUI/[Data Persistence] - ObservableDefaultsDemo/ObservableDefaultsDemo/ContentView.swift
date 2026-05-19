import SwiftUI
import Combine
import ObservableDefaults // <--- Phải import thư viện của Fatbobman

// MARK: - 1. Khai báo State với @ObservableDefaults

@ObservableDefaults
class AppSettings {
    // 1. Biến tự động lưu vào UserDefaults (Lấy tên biến 'username' làm key)
    var username: String = "Guest"
    
    // 2. Tùy chỉnh tên key lưu trong UserDefaults thành 'app_theme_mode'
    @DefaultsKey(userDefaultsKey: "app_theme_mode")
    var themeMode: String = "System"
    
    // 3. Biến chỉ có tính chất Observable (trigger UI) nhưng KHÔNG lưu vào UserDefaults
    @ObservableOnly
    var sessionActiveTime: Int = 0
    
    // 4. Biến bỏ qua hoàn toàn, không lưu cũng không trigger UI
    @Ignore
    var temporaryCounter: Int = 0
}

// MARK: - 2. Giao diện thực hành

struct UserDefaultsObservationView: View {
    // Không cần @StateObject nữa, chỉ cần @State vì đang dùng Observation Framework
    @State private var settings = AppSettings()
    
    // Timer giả lập để test biến @ObservableOnly
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section(header: Text("Persisted Data (UserDefaults)")) {
                TextField("Username", text: $settings.username)
                
                Picker("Theme Mode", selection: $settings.themeMode) {
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                    Text("System").tag("System")
                }
            }
            
            Section(header: Text("Memory Only (@ObservableOnly)")) {
                Text("Session Time: \(settings.sessionActiveTime) seconds")
            }
            
            Section(header: Text("External Change Test")) {
                Button("Thay đổi Username trực tiếp qua UserDefaults") {
                    // Test chức năng "bá đạo" nhất của thư viện:
                    // Dù thay đổi ngầm, View vẫn sẽ tự động nhận biết và update
                    let randomID = Int.random(in: 1000...9999)
                    UserDefaults.standard.set("User_\(randomID)", forKey: "username")
                }
            }
        }
        .navigationTitle("Observation & Defaults")
        .onReceive(timer) { _ in
            settings.sessionActiveTime += 1
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        UserDefaultsObservationView()
    }
}
