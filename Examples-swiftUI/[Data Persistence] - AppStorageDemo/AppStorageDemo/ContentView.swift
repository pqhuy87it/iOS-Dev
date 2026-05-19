import SwiftUI
import Combine

// MARK: - 1. Mở rộng kiểu dữ liệu cho @AppStorage

// Hỗ trợ Enum (RawValue tự động tương thích)
enum AppTheme: String, CaseIterable {
    case light, dark, system
}

// Hỗ trợ Array thông qua RawRepresentable và JSON Encoder/Decoder
extension Array: @retroactive RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data) else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return result
    }
}

// MARK: - 2. Quản lý State tập trung (Central Injection)

class AppSettings: ObservableObject {
    // Không cần dùng @Published, @AppStorage sẽ tự động trigger objectWillChange
    @AppStorage("username") var username: String = ""
    @AppStorage("isNotificationsEnabled") var isNotificationsEnabled: Bool = true
    
    // Sử dụng Custom Enum
    @AppStorage("appTheme") var appTheme: AppTheme = .system
    
    // Sử dụng Array đã được mở rộng RawRepresentable
    @AppStorage("favoriteNumbers") var favoriteNumbers: [Int] = [1, 2, 3]
}

// MARK: - 3. UI Implementation

struct AppStoragePracticeView: View {
    // Inject tập trung một lần duy nhất
    @StateObject private var settings = AppSettings()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Thông tin cá nhân")) {
                    TextField("Tên người dùng", text: $settings.username)
                }

                Section(header: Text("Cài đặt chung")) {
                    Toggle("Nhận thông báo", isOn: $settings.isNotificationsEnabled)

                    Picker("Giao diện", selection: $settings.appTheme) {
                        Text("Sáng").tag(AppTheme.light)
                        Text("Tối").tag(AppTheme.dark)
                        Text("Hệ thống").tag(AppTheme.system)
                    }
                }

                Section(header: Text("Kiểu dữ liệu phức tạp (Array)")) {
                    Text("Dãy số hiện tại: \(settings.favoriteNumbers.map(String.init).joined(separator: ", "))")
                    
                    Button("Thêm số ngẫu nhiên") {
                        settings.favoriteNumbers.append(Int.random(in: 10...99))
                    }
                    
                    Button("Xóa tất cả") {
                        settings.favoriteNumbers.removeAll()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings (AppStorage)")
        }
    }
}

// MARK: - Preview
struct AppStoragePracticeView_Previews: PreviewProvider {
    static var previews: some View {
        AppStoragePracticeView()
    }
}
