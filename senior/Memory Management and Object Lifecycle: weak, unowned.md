Đây là một câu hỏi kinh điển để phân loại mức độ hiểu biết về **Memory Management** và **Object Lifecycle** của ứng viên. Ở level Senior, bạn không chỉ cần biết nó là gì, mà phải biết **khi nào dùng (Use Cases)** và **tại sao lại nguy hiểm**.

Dưới đây là sự so sánh chi tiết và kịch bản sử dụng cụ thể:

---

### 1. Bảng so sánh nhanh (Quick Comparison)

| Đặc điểm | `weak` (Yếu) | `unowned` (Không sở hữu) |
| --- | --- | --- |
| **Kiểu dữ liệu** | Phải là **Optional** (`Let?`, `Var?`...) | Là **Non-Optional** (thường là `let` hoặc `var` không `?`) |
| **Khi đối tượng bị hủy** | Tự động gán về `nil` (Zeroing). | Giữ nguyên địa chỉ ô nhớ (Dangling Pointer). |
| **Truy cập** | Cần unwrap (dùng `if let`, `guard let`). | Truy cập trực tiếp (như force unwrap `!`). |
| **Độ an toàn** | **An toàn**. Truy cập khi object chết sẽ ra nil. | **Nguy hiểm**. Truy cập khi object chết sẽ **Crash App**. |
| **Về hiệu năng** | Chậm hơn xíu (do cơ chế lock/tracking để set nil). | Nhanh hơn (do ít overhead hơn). |

---

### 2. Bản chất sâu xa (Deep Dive)

#### **`weak` Reference**

Dùng cho mối quan hệ **"Có thể không tồn tại"**.

* Khi đối tượng mà nó tham chiếu tới bị giải phóng (deallocated), ARC sẽ tự động set biến `weak` thành `nil`.
* Vì nó có thể thay đổi giá trị thành `nil` trong quá trình runtime, nên `weak` luôn phải khai báo là `var` và là `Optional`.

#### **`unowned` Reference**

Dùng cho mối quan hệ **"Chắc chắn tồn tại song song hoặc lâu hơn"**.

* Swift giả định rằng đối tượng này **luôn luôn có giá trị** trong suốt vòng đời của đối tượng đang nắm giữ nó.
* ARC không set nó về `nil`. Nếu đối tượng kia chết, mà bạn vẫn gọi `unowned` reference, ứng dụng sẽ crash (lỗi: *bad access*).

---

### 3. Khi nào CHẮC CHẮN dùng `unowned`?

Bạn chỉ dùng `unowned` khi thỏa mãn **cả hai** điều kiện sau:

1. **Chắc chắn tồn tại:** Đối tượng được tham chiếu (Referenced Object) có vòng đời **bằng hoặc lâu hơn** đối tượng nắm giữ (Holding Object).
2. **Logic nghiệp vụ:** Logic của chương trình yêu cầu biến đó không bao giờ được phép `nil` khi sử dụng.

Có 2 trường hợp cụ thể thường dùng `unowned`:

#### Trường hợp 1: Mối quan hệ ràng buộc chặt chẽ (Initialization Dependency)

Ví dụ điển hình của Apple: **Khách hàng (Customer)** và **Thẻ tín dụng (CreditCard)**.

* Một Khách hàng có thể có hoặc không có thẻ.
* Nhưng một Thẻ tín dụng **bắt buộc** phải gắn liền với một Khách hàng thì mới có giá trị. Thẻ không thể tồn tại độc lập.

```swift
class Customer {
    let name: String
    var card: CreditCard? // Khách hàng sở hữu thẻ (Strong)
    
    init(name: String) { self.name = name }
    
    deinit { print("\(name) is being deinitialized") }
}

class CreditCard {
    let number: UInt64
    // Dùng UNOWNED vì Thẻ không thể tồn tại nếu không có Khách hàng.
    // Và Khách hàng (chủ thẻ) chắc chắn sống lâu hơn hoặc chết cùng lúc với thẻ.
    unowned let customer: Customer 
    
    init(number: UInt64, customer: Customer) {
        self.number = number
        self.customer = customer
    }
    
    deinit { print("Card #\(number) is being deinitialized") }
}

```

* **Tại sao dùng `unowned` ở đây tốt hơn `weak`?**
* Về mặt ngữ nghĩa (Semantics): Nó khẳng định `customer` không bao giờ là `nil`. Bạn không cần phải viết `if let customer = self.customer` mỗi khi dùng nó trong class `CreditCard`. Code gọn và đúng logic hơn.



#### Trường hợp 2: Capture List trong Closures (Self owns Closure)

Đây là trường hợp phổ biến nhất mà Senior Dev hay cân nhắc.
Bạn dùng `[unowned self]` trong closure khi: **Closure và `self` sẽ bị hủy cùng một lúc.**

Ví dụ: Một `ViewController` sở hữu một `Closure`, và `Closure` đó chỉ chạy trong quá trình `ViewController` còn sống.

```swift
class MyViewController: UIViewController {
    var onDataProcessed: (() -> Void)?
    
    func setupData() {
        // Tình huống: Closure này được lưu bởi MyViewController.
        // MyViewController sở hữu Closure.
        // Nếu dùng strong self -> Retain Cycle.
        
        // Quyết định: Weak hay Unowned?
        self.onDataProcessed = { [unowned self] in 
            // Chúng ta dùng unowned vì closure này chỉ được gọi
            // khi MyViewController còn tồn tại.
            // Nếu MyVC dealloc, closure cũng dealloc theo.
            self.updateUI() 
        }
    }
    
    func updateUI() { print("UI Updated") }
}

```

---

### 4. Lời khuyên cho Senior (The "Safeguard" Mindset)

Mặc dù `unowned` nhanh hơn và tiện hơn (không cần unwrap), nhưng trong thực tế phát triển phần mềm hiện đại, xu hướng là **ưu tiên sự an toàn**.

**Rủi ro của `unowned`:**
Trong môi trường bất đồng bộ (Asynchronous) hiện nay (gọi API, delay, background task), rất khó để đảm bảo 100% rằng `self` chưa bị dealloc khi closure chạy xong.

> **Quy tắc vàng:**
> Nếu bạn **nghi ngờ** dù chỉ 1% rằng đối tượng kia có thể bị giải phóng trước -> **Hãy dùng `weak**`.
> Chỉ dùng `unowned` khi class này **không thể khởi tạo** nếu thiếu class kia (như ví dụ CreditCard ở trên).

**Câu trả lời "ghi điểm" khi phỏng vấn:**
*"Về lý thuyết, `unowned` dùng khi vòng đời của object tham chiếu dài hơn object nắm giữ. Tuy nhiên, trong các dự án thực tế, tôi có xu hướng sử dụng `weak` (kết hợp với `guard let self = self else { return }`) cho các **Closures** xử lý API hoặc async task. Lý do là để tránh các trường hợp crash ngẫu nhiên (race conditions) khi màn hình đã bị đóng nhưng API mới trả về. Tôi chỉ dùng `unowned` cho các mối quan hệ object ràng buộc 1-1 chặt chẽ trong Core Logic."*
