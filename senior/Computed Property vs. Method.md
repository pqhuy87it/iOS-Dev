Đây là một câu hỏi về **Style Guide** và **Code Semantics** (Ngữ nghĩa mã nguồn). Về mặt kỹ thuật, cả hai đều có thể trả về cùng một kết quả, nhưng việc chọn sai sẽ dẫn đến hiểu nhầm cho người đọc code về **hiệu năng (performance)** và **chi phí tính toán**.

Dưới đây là sự phân tích chi tiết:

---

### 1. Sự khác biệt về Cú pháp (Syntax)

Hãy xem ví dụ tính diện tích hình chữ nhật:

**Computed Property (Thuộc tính tính toán):**
Trông giống một biến, không có ngoặc `()`.

```swift
struct Rect {
    let width: Double
    let height: Double
    
    // Đọc như một dữ liệu có sẵn
    var area: Computed {
        return width * height
    }
}
let val = rect.area

```

**Method (Phương thức):**
Trông giống một hành động, có ngoặc `()`.

```swift
struct Rect {
    let width: Double
    let height: Double
    
    // Đọc như một mệnh lệnh thực thi
    func calculateArea() -> Double {
        return width * height
    }
}
let val = rect.calculateArea()

```

---

### 2. Bảng so sánh cốt lõi (Core Differences)

| Đặc điểm | Computed Property (`var`) | Method (`func`) |
| --- | --- | --- |
| **Ngữ nghĩa (Semantics)** | Là một **đặc tính** (Noun/Adjective). Trả lời cho câu hỏi: *"Nó là gì?"* | Là một **hành động** (Verb). Trả lời cho câu hỏi: *"Nó làm gì?"* |
| **Tham số (Arguments)** | **Không thể nhận tham số.** | **Có thể nhận tham số.** |
| **Chi phí kỳ vọng** | **Rất thấp (O(1)).** Người dùng mong đợi nó trả về kết quả gần như tức thì. | **Có thể cao (O(n)).** Người dùng chấp nhận việc hàm này tốn thời gian tính toán. |
| **Side Effects** | Thường không thay đổi dữ liệu bên ngoài (Side-effect free). | Thường dùng để thay đổi trạng thái hoặc thực hiện tác vụ (Network/DB). |
| **Setter** | Hỗ trợ `set` (nếu muốn). | Không hỗ trợ setter trực tiếp. |

---

### 3. Quy tắc "Vàng" để lựa chọn (Decision Framework)

Là một Senior Developer, bạn cần tuân thủ **Uniform Access Principle** (Nguyên lý truy cập thống nhất). Hãy chọn dựa trên các tiêu chí sau:

#### ✅ Dùng Computed Property khi:

1. **Độ phức tạp O(1):** Việc tính toán cực nhanh (phép cộng trừ nhân chia đơn giản, format string).
2. **Không có tham số:** Bạn không cần input nào khác ngoài các biến `self` đang có.
3. **Thuần túy (Pure):** Gọi 100 lần thì kết quả trả về y hệt nhau (nếu state của object không đổi) và không gây ra side-effect (như không ghi log, không gọi API).
4. **Ví dụ chuẩn:**
* `fullName` (gép `firstName` + `lastName`).
* `isEmpty` (kiểm tra `count == 0`).
* `color` (trả về UIColor tương ứng với status enum).



#### ✅ Dùng Method khi:

1. **Độ phức tạp O(n) hoặc không xác định:** Cần duyệt mảng, sort, filter, hoặc tính toán logic nặng.
2. **Cần tham số:** Ví dụ `func area(unit: Unit) -> Double`.
3. **Tác vụ nặng (Heavy Work):** Đọc file, truy vấn Database, parse JSON. Nếu bạn để cái này vào Property, người dùng sẽ scroll TableView và bị giật lag (Dropped frames) mà không hiểu tại sao.
4. **Có Side Effect:** Hàm này làm thay đổi trạng thái của object hoặc hệ thống (ví dụ: `updateCache()`, `fetchData()`).
5. **Hành động:** Tên bắt đầu bằng động từ (`calculate`, `fetch`, `compute`, `get`).

---

### 4. Một ví dụ "Bad Practice" điển hình

**❌ SAI:**

```swift
// Sai lầm: Property nhưng lại thực hiện filter (O(n))
var activeUsers: [User] {
    // Nếu mảng allUsers có 1 triệu phần tử, dòng này sẽ treo UI
    return allUsers.filter { $0.isActive }
}

```

*Lý do:* Lập trình viên khác khi dùng `obj.activeUsers` sẽ nghĩ đây là một biến có sẵn (O(1)). Họ có thể vô tư gọi nó trong vòng lặp `for` hoặc `cellForRowAt`, dẫn đến hiệu năng thảm họa.

**✅ ĐÚNG:**

```swift
// Sửa lại: Chuyển thành func để cảnh báo người dùng đây là việc nặng
func getActiveUsers() -> [User] {
    return allUsers.filter { $0.isActive }
}

```

*Lý do:* Nhìn thấy `()` người ta sẽ cân nhắc cache lại kết quả thay vì gọi đi gọi lại.

### Tóm tắt câu trả lời phỏng vấn:

> *"Tôi phân biệt Computed Property và Method dựa trên **Ngữ nghĩa** và **Kỳ vọng về hiệu năng**.
> * Tôi dùng **Computed Property** cho các đặc tính nội tại của đối tượng (như `fullName`, `isEmpty`) với chi phí tính toán rẻ (O(1)) và không có tham số.
> * Tôi dùng **Method** cho các hành động (Verbs), các tính toán phức tạp (O(n)), hoặc khi cần tham số đầu vào.
> 
> 
> Việc tuân thủ quy tắc này giúp người đọc code (và chính tôi) dự đoán được chi phí của dòng code đó, tránh việc vô tình gọi một Property tốn kém bên trong Main Thread gây lag UI."*
