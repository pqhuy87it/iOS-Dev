Đây là câu hỏi "xương sống" của SwiftUI. Việc hiểu sai các Property Wrapper này không chỉ dẫn đến code khó đọc mà còn gây ra **bug nghiêm trọng về vòng đời (Lifecycle)** – dữ liệu bị reset về 0 hoặc app bị crash ngẫu nhiên.

Đối với một Senior Developer, từ khóa quan trọng nhất để phân biệt chúng là **"OWNERSHIP" (Quyền sở hữu)**: *Ai là người tạo ra dữ liệu và ai là người giữ cho nó sống?*

Dưới đây là giải thích chi tiết:

---

### 1. `@State` (Value Type - Local Owner)

* **Bản chất:** Quản lý các **Value Type** đơn giản (Int, Bool, String, Struct) ngay bên trong View.
* **Ownership:** View **SỞ HỮU** dữ liệu này. SwiftUI sẽ cấp phát bộ nhớ (trong heap) để lưu trữ giá trị này và giữ nó tồn tại ngay cả khi `struct View` bị hủy đi và tạo lại mỗi lần render.
* **Khi nào dùng:**
* Dùng cho các trạng thái **nội bộ (Private)** của UI. Ví dụ: Trạng thái đóng/mở của một cái menu, màu sắc của nút bấm khi highlight, text trong TextField.
* **Best Practice:** Luôn đánh dấu là `private`.



```swift
struct CounterView: View {
    @State private var count = 0 // View sở hữu biến này
}

```

### 2. `@Binding` (Reference - No Ownership)

* **Bản chất:** Là một **con trỏ (pointer)** hoặc một đường ống dẫn đến dữ liệu nằm ở nơi khác. Nó cho phép View con đọc và ghi (Read/Write) dữ liệu của View cha.
* **Ownership:** View **KHÔNG SỞ HỮU** dữ liệu. Nó chỉ mượn tạm.
* **Khi nào dùng:**
* Khi bạn muốn truyền dữ liệu từ Cha -> Con và muốn Con thay đổi được dữ liệu đó, và thay đổi đó phản ánh ngược lại Cha.
* Ví dụ: Toggle switch (View con) thay đổi biến `isOn` (nằm ở View cha).



```swift
struct ToggleView: View {
    @Binding var isOn: Bool // Dữ liệu thật nằm ở View cha
}

```

---

### 3. `@ObservedObject` vs `@StateObject` (Reference Type - Class)

Đây là cặp đôi gây nhầm lẫn nhất và cũng là nơi phân loại trình độ Senior. Cả hai đều dùng cho Class tuân thủ `ObservableObject`.

#### `@ObservedObject` (Monitor - No Ownership)

* **Bản chất:** Quan sát một object. Nếu object thay đổi (`objectWillChange`), View sẽ vẽ lại.
* **Ownership:** View **KHÔNG ĐẢM BẢO** quyền sở hữu hay vòng đời của object.
* **Rủi ro (The Trap):** Nếu View chứa nó bị vẽ lại (redraw) bởi View cha, instance của object có thể bị hủy và tạo mới -> **Mất dữ liệu**.
* **Khi nào dùng:**
* Khi Object được truyền vào từ bên ngoài (Dependency Injection).
* Dùng cho View con nhận ViewModel từ View cha.



#### `@StateObject` (Owner - Lifecycle Manager) - *Có từ iOS 14*

* **Bản chất:** Giống ObservedObject nhưng thêm tính năng "Neo giữ".
* **Ownership:** View **SỞ HỮU** object này. SwiftUI đảm bảo instance này chỉ được khởi tạo **một lần duy nhất** kể cả khi View bị render lại hàng nghìn lần.
* **Khi nào dùng:**
* Khi bạn **khởi tạo** (`init`) một ViewModel ngay bên trong View đó.
* Đây là "Source of Truth" cho các Reference Type.



**Ví dụ phân biệt sống còn:**

```swift
struct ParentView: View {
    var body: some View {
        // Mỗi lần ParentView render lại, ChildView được gọi lại.
        ChildView() 
    }
}

struct ChildView: View {
    // SAI LẦM: Mỗi lần ParentView render, ViewModel này bị reset về 0.
    // @ObservedObject var vm = MyViewModel() 
    
    // ĐÚNG: SwiftUI sẽ giữ vm sống sót qua các lần render.
    @StateObject var vm = MyViewModel() 
}

```

---

### 4. `@EnvironmentObject` (Global Dependency Injection)

* **Bản chất:** Dữ liệu dùng chung cho cả một cây View (Subtree) mà không cần truyền qua từng cấp init (Constructor Injection).
* **Ownership:** Được sở hữu bởi cấp cao nhất (thường là `App` hoặc View gốc), sau đó được "tiêm" vào môi trường bằng `.environmentObject()`.
* **Khi nào dùng:**
* Dữ liệu toàn cục: User Profile, Theme Setting, Authen State.
* Dữ liệu cần truy cập ở màn hình cấp 5, cấp 6 mà bạn lười truyền qua cấp 2, 3, 4.


* **Lưu ý:** Nếu bạn quên `.environmentObject()` ở view cha mà view con cố truy cập -> **Crash App** ngay lập tức.

---

### Bảng Tóm tắt Quyết định (Decision Matrix)

Để dễ nhớ, hãy dùng sơ đồ tư duy này khi code:

| Câu hỏi | Câu trả lời | Dùng Wrapper nào? |
| --- | --- | --- |
| Dữ liệu là **Value Type** (Struct/Int/Bool)? | Và tôi tạo ra nó ở đây (Sở hữu) | `@State` |
|  | Và tôi nhận nó từ cha, cần sửa nó | `@Binding` |
|  | Và tôi nhận nó từ cha, chỉ đọc | `let` (biến thường) |
| Dữ liệu là **Reference Type** (Class)? | Và tôi khởi tạo nó ở đây (Sở hữu) | `@StateObject` |
|  | Và tôi nhận nó từ bên ngoài | `@ObservedObject` |
|  | Và nó là dữ liệu toàn cục | `@EnvironmentObject` |

### Ví dụ tổng hợp:

```swift
// 1. Class dữ liệu (Reference Type)
class UserSettings: ObservableObject {
    @Published var score = 0
}

struct ContentView: View {
    // 2. ContentView là OWNER -> Dùng StateObject
    @StateObject var settings = UserSettings()
    
    // 3. Value Type nội bộ -> Dùng State
    @State private var isToggleOn = false
    
    var body: some View {
        VStack {
            // Truyền Reference Type xuống con -> Con dùng ObservedObject
            ScoreView(settings: settings)
            
            // Truyền Value Type xuống con để sửa -> Con dùng Binding
            ToggleView(isOn: $isToggleOn)
            
            // Inject vào môi trường cho các cháu chắt chút chít dùng
            DeepNestedView().environmentObject(settings)
        }
    }
}

struct ScoreView: View {
    // Nhận từ cha -> Dùng ObservedObject
    @ObservedObject var settings: UserSettings
    
    var body: some View {
        Text("Score: \(settings.score)")
    }
}

struct ToggleView: View {
    // Nhận quyền sửa đổi từ cha -> Dùng Binding
    @Binding var isOn: Bool
    var body: some View {
        Toggle("Switch", isOn: $isOn)
    }
}

struct DeepNestedView: View {
    // Lấy từ không khí (môi trường) -> Dùng EnvironmentObject
    @EnvironmentObject var settings: UserSettings
    var body: some View {
        Button("Increase Score") {
            settings.score += 1
        }
    }
}

```
