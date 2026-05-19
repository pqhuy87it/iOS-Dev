Đây là một câu hỏi về **Thiết kế API (API Design)** và **Cú pháp (Syntax Sugar)**.

Về cơ bản, **Variadic Function** (Hàm đa biến) là một loại hàm đặc biệt cho phép nhận số lượng tham số đầu vào **không giới hạn** (từ 0 đến N), trong khi **Regular Function** (Hàm thường) yêu cầu số lượng tham số cố định.

Dưới đây là sự khác biệt chi tiết từ góc độ **Compiler** và **Usage** dành cho Senior Developer:

---

### 1. Cú pháp & Cách gọi (Syntax & Call Site)

#### **Regular Function**

Bạn phải định nghĩa rõ ràng bao nhiêu tham số, tên là gì. Khi gọi hàm, phải truyền **đúng và đủ**.

```swift
// Định nghĩa: Cố định 2 tham số
func addTwoNumbers(a: Int, b: Int) -> Int {
    return a + b
}

// Gọi hàm:
let sum = addTwoNumbers(a: 5, b: 10) 
// Lỗi nếu truyền 3 số hoặc 1 số.

```

#### **Variadic Function**

Sử dụng toán tử ba chấm **`...`** sau kiểu dữ liệu.

```swift
// Định nghĩa: Nhận n tham số Int
func sum(_ numbers: Int...) -> Int {
    // Bên trong body, 'numbers' được coi là một [Int] (Array)
    return numbers.reduce(0, +)
}

// Gọi hàm: Cực kỳ linh hoạt
sum(1, 2)          // OK
sum(1, 2, 3, 4, 5) // OK
sum()              // OK (numbers rỗng)

```

---

### 2. Bản chất bên dưới (Under the Hood)

Đây là phần quan trọng để phân biệt trình độ.

* **Cơ chế:** Khi bạn khai báo `Int...`, trình biên dịch Swift thực chất sẽ chuyển đổi danh sách các đối số rời rạc đó thành một **Mảng (`Array<Int>`)** ngay tại thời điểm biên dịch.
* **Bộ nhớ:**
* **Regular Function:** Các tham số được đẩy vào Stack (hoặc Register) riêng lẻ.
* **Variadic Function:** Trình biên dịch phải cấp phát một mảng tạm thời (Array Allocation) để chứa các giá trị đó trước khi truyền vào hàm.


* **Hiệu năng:** Variadic function có một chút overhead (chi phí) nhỏ do việc tạo mảng. Tuy nhiên, với các kiểu dữ liệu đơn giản (Int, Struct nhỏ), chi phí này không đáng kể.

---

### 3. Những hạn chế "chí mạng" của Variadic Function

Senior Developer cần biết khi nào **KHÔNG NÊN** dùng Variadic.

#### A. Không thể truyền mảng vào Variadic Parameter (The "Splat" Problem)

Đây là điểm khó chịu nhất của Swift so với các ngôn ngữ khác (như Javascript spread operator `...arr`).

```swift
let myArray = [1, 2, 3]

// LỖI: Cannot pass array of type '[Int]' as variadic arguments of type 'Int'
sum(myArray) 

```

**Giải pháp:** Nếu bạn muốn hỗ trợ cả hai (truyền lẻ tẻ và truyền mảng), bạn phải viết **Overloading** (Viết 2 hàm cùng tên).

```swift
// Hàm 1: Cho người lười
func sum(_ numbers: Int...) -> Int {
    return sum(numbers) // Gọi hàm 2
}

// Hàm 2: Cho người có sẵn mảng
func sum(_ numbers: [Int]) -> Int {
    return numbers.reduce(0, +)
}

```

#### B. Tính mơ hồ (Ambiguity)

Trước Swift 5.4, bạn chỉ được phép có **tối đa 1 tham số Variadic** trong một hàm và nó phải nằm cuối cùng.
Từ Swift 5.4+, bạn có thể dùng **nhiều tham số Variadic**, miễn là chúng được phân tách bởi các label rõ ràng.

```swift
// Hợp lệ trong Swift 5.4+
func printData(numbers: Int..., tags: String...) { ... }

// Gọi:
printData(numbers: 1, 2, 3, tags: "A", "B")

```

---

### 4. Khi nào nên dùng Variadic? (Best Practices)

Dùng Variadic Function khi bạn muốn tạo ra các **API tiện ích (Utility APIs)** hoặc **DSL (Domain Specific Language)** giúp code phía người gọi (Caller side) sạch đẹp hơn.

**Ví dụ kinh điển:**

1. **`print(_ items: Any...)`**: Hàm print của chuẩn Swift là variadic. Bạn có thể in `print("A", "B", "C")` thay vì `print(["A", "B", "C"])`.
2. **SwiftUI `VStack`, `HStack**`: Các View Builder thực chất là một dạng biến thể cao cấp của Variadic (dùng Result Builders), cho phép bạn liệt kê các View con mà không cần đóng ngoặc vuông `[]`.
3. **Hàm format String**: `String(format: "%d %s", 10, "Hello")`.

### Tóm tắt câu trả lời phỏng vấn:

> *"Sự khác biệt chính nằm ở **tính linh hoạt** tại thời điểm gọi hàm (Call site).
> 1. **Regular Function** yêu cầu số lượng tham số cố định, chặt chẽ.
> 2. **Variadic Function** (dùng `...`) cho phép truyền số lượng tham số tùy ý (từ 0 đến N). Bên dưới lớp vỏ, Swift tự động đóng gói các tham số này thành một **Array**.
> 
> 
> **Lưu ý quan trọng cho Senior:** Variadic Function giúp API đẹp hơn, dễ đọc hơn (như hàm `print`), nhưng nó có hạn chế là **không thể truyền trực tiếp một mảng** vào tham số variadic (trừ khi overload hàm). Ngoài ra, cần lưu ý chi phí tạo mảng ngầm định nếu hiệu năng là yếu tố then chốt trong vòng lặp tight loop."*
