import SwiftUI
import Combine

// MARK: - 1. Nơi chứa Dữ liệu (Singleton để AppDelegate có thể truy cập)
class DraftManager: ObservableObject {
    static let shared = DraftManager()
    
    @Published var inputText: String = ""
    private let draftKey = "RegistrationDraftData"
    
    init() {
        // Nạp lại dữ liệu cũ khi App vừa mở lên
        self.inputText = UserDefaults.standard.string(forKey: draftKey) ?? ""
        print("🔄 [Init] Dữ liệu nháp hiện tại: '\(self.inputText)'")
    }
    
    func saveDraftToDisk() {
        UserDefaults.standard.set(inputText, forKey: draftKey)
        print("💾 [Save] Đã lưu dữ liệu xuống Disk: '\(inputText)'")
    }
    
    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
        inputText = ""
        print("🗑️ [Clear] Đã xoá nháp.")
    }
}

// MARK: - 2. Cấu hình AppDelegate để bắt sự kiện Terminate
class AppDelegate: NSObject, UIApplicationDelegate {
    func applicationWillTerminate(_ application: UIApplication) {
        print("⚠️ [Lifecycle] Bắt được sự kiện applicationWillTerminate!")
        
        // CỐ Ý LƯU DATA Ở ĐÂY ĐỂ KIỂM CHỨNG
        DraftManager.shared.saveDraftToDisk()
    }
}

// MARK: - 4. Giao diện (Form nhập liệu)
struct ContentView: View {
    @StateObject private var manager = DraftManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Form Đăng Ký"),
                        footer: Text("Hãy gõ vài chữ, KHÔNG bấm nút gì cả, sau đó vuốt từ dưới lên để Kill App từ App Switcher. Mở lại xem chữ có còn không.")) {
                    
                    TextField("Nhập tên của bạn...", text: $manager.inputText)
                }
                
                Section {
                    Button(role: .destructive, action: {
                        manager.clearDraft()
                    }) {
                        Text("Xoá dữ liệu nháp hiện tại")
                    }
                }
            }
            .navigationTitle("Test Kill App")
        }
    }
}
