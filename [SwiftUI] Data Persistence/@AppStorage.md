Chào bạn, dựa trên bài viết từ blog Fatbobman, tác giả đã đi sâu vào cách sử dụng `@AppStorage` trong SwiftUI sao cho thanh lịch, hiệu quả và an toàn. Với background là một Senior Mobile Developer, chắc chắn bạn sẽ thấy những hướng tiếp cận về architecture và type safety trong bài viết này rất hữu ích so với cách khai báo truyền thống.

Dưới đây là tổng hợp các ý chính và đoạn code hoàn chỉnh để bạn có thể thực hành ngay.

### 1. Tổng hợp các ý chính từ bài viết

**Bản chất và Hạn chế của `@AppStorage`:**
* **Bản chất:** Là một property wrapper của `UserDefaults`. Nó hoạt động tương tự `@State`, tự động trigger redraw View khi giá trị thay đổi.
* **Không an toàn (Security):** Dữ liệu lưu dạng plain text, rất dễ bị trích xuất. **Tuyệt đối không lưu dữ liệu nhạy cảm** (như token, thông tin cá nhân quan trọng).
* **Thời điểm lưu (Persistence Timing) không chắc chắn:** OS không ghi xuống disk ngay lập tức mà sẽ tối ưu thời điểm ghi. Do đó, có rủi ro mất dữ liệu nếu app crash. Không nên dùng để lưu các state mang tính sống còn của luồng logic app.
* **Giới hạn kiểu dữ liệu:** Mặc định chỉ hỗ trợ `Bool`, `Int`, `Double`, `String`, `URL`, và `Data`.

**Các kỹ thuật nâng cao (Advanced Tips):**

1.  **Mở rộng kiểu dữ liệu hỗ trợ (Extending Types):** Bạn có thể lưu các kiểu phức tạp (như `Date`, `Array`, `Dictionary` hoặc custom model) bằng cách cho chúng conform theo protocol `RawRepresentable` (với `RawValue` là `String` hoặc `Int`), kết hợp với `JSONEncoder`/`JSONDecoder`.
2.  **Quản lý tập trung (Central Injection - Khuyên dùng):** Việc khai báo `@AppStorage("string_key")` rải rác khắp các View rất dễ gây ra lỗi typo và khó bảo trì. Từ iOS 14.5, Apple hỗ trợ `@AppStorage` bên trong một `ObservableObject` (nó sẽ tự động trigger `objectWillChange` giống hệt `@Published`). Bạn có thể gom tất cả config vào một class duy nhất và inject nó qua `@StateObject` hoặc `@EnvironmentObject`.

---

### 2. Code thực hành hoàn chỉnh

Đoạn code dưới đây áp dụng toàn bộ các best practice từ tác giả: Mở rộng `Array` và `Enum` qua `RawRepresentable`, sau đó gom toàn bộ biến vào một class `AppSettings` (`ObservableObject`) để quản lý tập trung.

```swift
import SwiftUI

// MARK: - 1. Mở rộng kiểu dữ liệu cho @AppStorage

// Hỗ trợ Enum (RawValue tự động tương thích)
enum AppTheme: String, CaseIterable {
    case light, dark, system
}

// Hỗ trợ Array thông qua RawRepresentable và JSON Encoder/Decoder
extension Array: RawRepresentable where Element: Codable {
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
```

**Cách hoạt động của code:**
1. Khi bạn gõ tên, đổi toggle, hay thêm/xóa số, `@AppStorage` sẽ tự động ghi dữ liệu xuống `UserDefaults` ở background.
2. Việc gói `@AppStorage` vào trong `AppSettings : ObservableObject` giải quyết triệt để bài toán hardcode string `"username"`, `"appTheme"` ở nhiều View khác nhau. Bạn gọi thẳng `settings.username` – điều này mang lại type safety cực kỳ tốt cho project scale lớn.
