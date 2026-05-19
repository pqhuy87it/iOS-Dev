Đây là câu hỏi kinh điển, nhưng để trả lời ở tầm **Senior**, chúng ta không chỉ dừng lại ở định nghĩa các chữ cái viết tắt. Chúng ta cần phân tích sâu về **Luồng dữ liệu (Data Flow)**, **Trách nhiệm (Responsibility)** và **Khả năng kiểm thử (Testability)**.

Dưới đây là sự so sánh chi tiết giữa MVC (Apple's MVC) và MVVM.

---

### 1. MVC (Model - View - Controller)

Trong thế giới iOS, MVC thường được nói đùa là **"Massive View Controller"**.

* **Cấu trúc:**
* **Model:** Dữ liệu (Structs, Classes, CoreData entities).
* **View:** Giao diện (UIView, XIB, Storyboard).
* **Controller:** `UIViewController`.


* **Luồng hoạt động:**
1. User tương tác với View (tap button).
2. View báo cho Controller (qua action/delegate).
3. Controller xử lý logic, cập nhật Model.
4. Controller định dạng lại dữ liệu từ Model và cập nhật trực tiếp View.


* **Vấn đề chí mạng (Tại sao Senior muốn bỏ MVC?):**
* **Trộn lẫn Lifecycle và Logic:** `UIViewController` vừa phải quản lý vòng đời (`viewDidLoad`, `viewWillAppear`) vừa phải xử lý logic nghiệp vụ (gọi API, validate form).
* **Tight Coupling (Dính chặt):** Controller nắm giữ tham chiếu trực tiếp tới View (`self.label.text = ...`).
* **Khó viết Unit Test:** Để test logic trong Controller, bạn phải khởi tạo cả cái View Controller, giả lập view load, rất phức tạp. Bạn không thể test logic tách biệt khỏi UI.



---

### 2. MVVM (Model - View - ViewModel)

MVVM ra đời để giải quyết vấn đề "Massive" của MVC bằng cách **tách logic hiển thị (Presentation Logic) ra khỏi View Controller**.

* **Cấu trúc:**
* **Model:** Giống MVC.
* **View:** Bao gồm cả `UIView` và `UIViewController`. (Lưu ý: Trong MVVM, VC được coi là phần View).
* **ViewModel:** Class trung gian chứa logic biến đổi dữ liệu.


* **Luồng hoạt động (Sự khác biệt cốt lõi):**
1. User tương tác với View.
2. View chuyển hành động đó cho **ViewModel**.
3. ViewModel xử lý logic, cập nhật Model.
4. ViewModel cập nhật các biến trạng thái của chính nó (State).
5. **Binding:** View tự động lắng nghe sự thay đổi từ ViewModel và tự cập nhật lại UI.


* **Quy tắc vàng của MVVM:**
* **View biết ViewModel.**
* **ViewModel KHÔNG biết View.** (ViewModel không được import `UIKit`, không được có `UILabel`, `UIButton`...).



---

### 3. Bảng so sánh chi tiết

| Đặc điểm | MVC (Apple's Flavor) | MVVM |
| --- | --- | --- |
| **Vai trò của UIViewController** | Là trung tâm điều khiển (Controller). Xử lý cả logic và UI. | Được coi là **View**. Chỉ làm nhiệm vụ setup layout và bind dữ liệu. |
| **Logic hiển thị (Presentation Logic)** | Nằm lẫn lộn trong Controller. (VD: `if date > now { label.color = .red }`) | Chuyển hết vào **ViewModel**. Controller chỉ việc hiển thị cái VM đưa ra. |
| **Kết nối với View** | Controller tham chiếu trực tiếp và gán giá trị cho View. | Sử dụng cơ chế **Binding** (Closures, Delegate, KVO, RxSwift, Combine). |
| **Unit Test** | Rất khó (Hard). | Rất dễ (Easy). Vì VM là một class thuần túy, input A -> output B. |
| **Kích thước file** | Controller thường rất lớn. | Code được chia nhỏ sang ViewModel, Controller gầy đi hẳn. |
| **Độ phức tạp** | Thấp. Dễ tiếp cận cho Junior. | Cao hơn. Cần hiểu về Binding và Reactive Programming. |

---

### 4. Code ví dụ minh họa sự khác biệt

**Bài toán:** Hiển thị tên User. Nếu user là VIP thì hiện icon ⭐️, không thì ẩn.

#### Cách viết MVC (Logic dính vào View):

```swift
// UserProfileViewController.swift
func render(user: User) {
    nameLabel.text = user.name
    
    // Logic hiển thị nằm ngay trong Controller -> Khó test, làm VC phình to
    if user.isPremium {
        vipIcon.isHidden = false
    } else {
        vipIcon.isHidden = true
    }
}

```

#### Cách viết MVVM (Logic tách biệt):

```swift
// UserProfileViewModel.swift (Không import UIKit)
class UserProfileViewModel {
    private let user: User
    
    // ViewModel chuẩn bị sẵn dữ liệu "sạch" cho View dùng
    var displayName: String { return user.name }
    var isVipVisible: Bool { return user.isPremium } // Logic nằm ở đây
}

// UserProfileViewController.swift
func bind(viewModel: UserProfileViewModel) {
    // View chỉ việc gán, không cần suy nghĩ logic
    nameLabel.text = viewModel.displayName
    vipIcon.isHidden = !viewModel.isVipVisible
}

```

### 5. Lời khuyên cho Senior (Khi nào dùng cái nào?)

1. **Dùng MVC khi:**
* Làm màn hình tĩnh, đơn giản, ít logic (VD: Màn hình Settings, About Us).
* Prototype nhanh (PoC).
* MVC không xấu, nó chỉ xấu khi bạn nhồi nhét quá nhiều.


2. **Dùng MVVM khi:**
* Màn hình có logic phức tạp, nhiều trạng thái (Loading, Error, Empty, Data).
* Dự án yêu cầu Unit Test cao.
* **Đặc biệt:** Khi làm việc với **SwiftUI**. SwiftUI được thiết kế dựa trên triết lý MVVM (`View` + `@StateObject ViewModel`). Chuyển từ MVVM UIKit sang SwiftUI rất mượt mà.



### Tóm lại:

MVC là **Imperative** (Ra lệnh trực tiếp: "Label ơi, hiện text này đi").
MVVM là **Declarative/Reactive** (Phản ứng: "Label ơi, cứ theo dõi biến `text` này của tôi, nó đổi sao thì bạn đổi vậy"). Sự tách biệt này giúp Code sạch hơn (Clean Code) và dễ bảo trì hơn (Maintainable).
