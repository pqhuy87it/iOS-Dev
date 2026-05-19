Đây là một trong những câu hỏi quan trọng nhất về **Memory Management** và **Life Cycle** trong Swift. Hiểu sai về nó sẽ dẫn đến một trong hai hậu quả: Crash App (do truy cập vùng nhớ đã giải phóng) hoặc Retain Cycle (rò rỉ bộ nhớ).

Mặc định trong Swift, tất cả các closure đều là **Non-Escaping**.

Dưới đây là sự phân tích chi tiết:

---

### 1. Non-Escaping Closure (Mặc định)

**Định nghĩa:** Closure được gọi là "Non-Escaping" (Không trốn thoát) nếu nó được thực thi và hoàn thành **NGAY BÊN TRONG** hàm mà nó được truyền vào, trước khi hàm đó `return`.

* **Vòng đời:**
1. Hàm được gọi, closure được truyền vào.
2. Hàm chạy code.
3. Hàm thực thi closure.
4. Hàm kết thúc (`return`). Closure bị hủy ngay lập tức.


* **Đặc điểm:**
* **Đồng bộ (Synchronous):** Nó chạy tuần tự.
* **An toàn bộ nhớ:** Vì closure chết trước khi hàm chết, nó không cần thiết phải giữ strong reference tới `self`. Do đó, bạn dùng `self` bên trong closure này mà **không cần** `[weak self]`.
* **Tối ưu hóa:** Trình biên dịch (Compiler) tối ưu hóa rất mạnh tay vì biết rõ vòng đời của nó.



**Ví dụ:** Các hàm như `map`, `filter`, `reduce` hay `UIView.animate` (thực ra UIView.animate hơi đặc biệt, nhưng về logic sử dụng self thì tương tự) đều là non-escaping.

```swift
func doSomething(completion: () -> Void) {
    print("1. Bắt đầu hàm")
    completion() // Closure chạy ngay lập tức ở đây
    print("2. Kết thúc hàm")
}
// Output: 1 -> Closure -> 2. Closure không bao giờ sống sót ra ngoài hàm này.

```

---

### 2. @escaping Closure (Kẻ trốn thoát)

**Định nghĩa:** Closure được gọi là "Escaping" nếu nó vẫn còn tồn tại (sống sót) sau khi hàm chứa nó đã `return`. Nó "trốn thoát" ra khỏi phạm vi của hàm.

* **Khi nào xảy ra?**
1. **Bất đồng bộ (Asynchronous):** Closure được gọi sau khi một tác vụ tốn thời gian hoàn thành (API call, Timer, DispatchAsync).
2. **Lưu trữ (Storage):** Closure được gán vào một biến property bên ngoài phạm vi hàm để dùng sau (Delegate pattern dạng closure).


* **Đặc điểm:**
* **Bất đồng bộ:** Hàm chính đã chạy xong và thoát ra rồi, nhưng 5 giây sau closure mới được gọi.
* **Nguy cơ Retain Cycle:** Vì closure sống lâu hơn hàm, nó cần một nơi để bám víu (capture state). Nếu nó capture `self` mạnh (strong), và `self` lại giữ nó -> Retain Cycle. **Bắt buộc phải dùng `[weak self]` nếu cần.**



**Ví dụ kinh điển: Networking**

```swift
// Phải thêm từ khóa @escaping vì closure được gọi sau 2 giây (khi hàm performRequest đã return xong từ lâu)
func performRequest(completion: @escaping (Data?) -> Void) {
    print("1. Gửi request")
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        print("3. Có kết quả trả về")
        completion(nil) // Closure được gọi ở thì tương lai
    }
    
    print("2. Hàm kết thúc")
}
// Output: 1 -> 2 -> (Đợi 2s) -> 3.

```

---

### 3. Bảng so sánh cho Senior (Comparison Table)

| Đặc điểm | Non-Escaping (Mặc định) | @escaping |
| --- | --- | --- |
| **Từ khóa** | Không cần (Default) | Phải ghi rõ `@escaping` trước kiểu dữ liệu. |
| **Vòng đời** | Chết **trước** khi hàm return. | Chết **sau** khi hàm return. |
| **Cơ chế gọi** | Đồng bộ (Synchronous). | Thường là Bất đồng bộ (Async) hoặc được lưu lại. |
| **Memory (Self)** | **Không cần** `[weak self]`. Dùng `self` thoải mái. | **Bắt buộc** cân nhắc `[weak self]` để tránh Retain Cycle. |
| **Tối ưu hóa** | Tốt hơn (Compiler optimization). | Kém hơn (Cần cấp phát Heap cho closure context). |
| **Ví dụ** | `map`, `filter`, `forEach` | `URLSession.dataTask`, `DispatchQueue.async` |

---

### 4. Tại sao phân biệt này quan trọng? (Câu hỏi Why)

Tại sao Swift bắt chúng ta phải viết `@escaping` tường minh mà không tự động nhận diện?

1. **Cảnh báo lập trình viên:** Khi bạn gõ `@escaping`, đó là một lời nhắc nhở từ Compiler: *"Ê, cái closure này sống dai lắm đấy, cẩn thận Retain Cycle nha, coi chừng self bị nil nha!"*. Nó buộc bạn phải suy nghĩ về Memory Management.
2. **Hiệu năng:** Biết một closure là non-escaping giúp compiler không cần cấp phát bộ nhớ Heap để lưu trữ context của closure đó (vì nó chỉ chạy lướt qua trên Stack). Điều này giúp app chạy nhanh hơn.

### Tóm tắt câu trả lời phỏng vấn:

> *"Mặc định closure trong Swift là **Non-Escaping**, nghĩa là nó được thực thi và giải phóng ngay trong scope của hàm, rất an toàn và tối ưu, không cần `weak self`.
> Ngược lại, **`@escaping`** dùng cho các tác vụ bất đồng bộ (như API call) hoặc khi closure cần được lưu lại vào một biến để dùng sau. Khi dùng `@escaping`, closure sẽ sống lâu hơn hàm tạo ra nó, do đó ta phải cực kỳ cẩn thận xử lý **Retain Cycle** bằng cách sử dụng `[weak self]`."*
