import Combine
import SwiftUI

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

struct ContentView: View {
    @StateObject private var manager = DraftManager.shared
    @Environment(\.scenePhase) var scenePhase // Lắng nghe trạng thái Scene
    
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
        // BẮT SỰ KIỆN SCENE PHASE Ở ĐÂY
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                print("🌙 [ScenePhase] App rơi vào Background -> LƯU NGAY LẬP TỨC!")
                manager.saveDraftToDisk()
            }
        }
    }
}

#Preview {
    ContentView()
}
