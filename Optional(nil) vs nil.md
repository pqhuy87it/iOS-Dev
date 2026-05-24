Lỗi này nhìn qua trông có vẻ cực kỳ vô lý (tại sao `nil` lại không bằng `nil`?), nhưng thực chất nó là một "đặc sản" kinh điển trong Swift.

Lý do gốc rễ đến từ việc Swift quản lý kiểu dữ liệu **Optional** vô cùng nghiêm ngặt. Khi bạn gặp lỗi này, bạn đang rơi vào 1 trong 2 trường hợp dưới đây:

---

### Trường hợp 1 (Phổ biến nhất): Lỗi "Optional lồng nhau" (Double Optional)

Đây là tình huống bạn đang có một kiểu dữ liệu dạng `Type??` (tức là `Optional<Optional<Type>>`).

**Hãy tưởng tượng Optional là một cái hộp:**

* `nil` thông thường: Bạn **không có** cái hộp nào cả.
* `Optional(nil)`: Bạn **có một cái hộp**, nhưng mở ra thì bên trong lại là một cái hộp rỗng.

Khi bạn dùng `XCTAssertEqual(a, b)` để so sánh "có hộp" và "không có hộp", XCTest sẽ đánh giá là chúng khác nhau và báo lỗi.

**Kịch bản gây lỗi thường gặp (Dùng Any? hoặc Dictionary):**

```swift
let dictionary: [String: Any?] = ["key": nil]

// dict["key"] trả về một cái hộp (Optional) chứa giá trị bên trong.
// Nhưng bản thân giá trị bên trong lại là kiểu `Any?` mang giá trị `nil`.
// => Kết quả sinh ra Double Optional: Optional.some(Optional.none)
let value = dictionary["key"] 

XCTAssertEqual(value, nil) // LỖI: ("Optional(nil)") is not equal to ("nil")

```

#### Cách khắc phục:

**Cách 1: Ép kiểu (Cast) về đúng định dạng phẳng**
Thay vì so sánh trực tiếp, hãy ép kiểu nó về một Optional thông thường (1 lớp) trước khi so sánh.

```swift
// Nếu bạn biết chắc kiểu dữ liệu bên trong là gì (ví dụ: String)
XCTAssertEqual(value as? String, nil)

// Hoặc dùng XCTAssertNil (Khuyên dùng trong Test)
XCTAssertNil(value as? String) 

```

**Cách 2: Làm phẳng (Flatten) bằng `flatMap**`
Nếu bạn không muốn ép kiểu, bạn có thể dùng `flatMap` để bóc lớp vỏ hộp bên ngoài đi.

```swift
XCTAssertNil(value.flatMap { $0 })

```

---

### Trường hợp 2: Lỗi ép Optional thành Chuỗi (String Interpolation)

Trường hợp này xảy ra khi bạn vô tình lấy một biến Optional và "nhét" nó vào một chuỗi (String) để mang đi so sánh.

**Kịch bản gây lỗi:**

```swift
let myVariable: Int? = nil

// Khi dùng String Interpolation, Swift sẽ biến chữ nil thành chuỗi "nil"
let text1 = "\(myVariable)" // text1 có giá trị là chuỗi "nil"
let text2 = String(describing: myVariable) // text2 có giá trị là chuỗi "nil"

// Nhưng nếu bạn gán nó vào một biến khác một cách phức tạp hơn:
let nestedVariable: Int?? = nil
let text3 = String(describing: nestedVariable) // text3 = chuỗi "Optional(nil)"

XCTAssertEqual(text3, text1) // LỖI: ("Optional(nil)") is not equal to ("nil")

```

#### Cách khắc phục:

Tuyệt đối không dùng `String(describing:)` hoặc `\()` để kiểm tra giá trị `nil`. Nếu bạn cần kiểm tra xem một biến Optional có rỗng hay không, hãy so sánh trực tiếp với `nil`, đừng ép nó ra String.

```swift
// SAI
XCTAssertEqual("\(myVariable)", "nil")

// ĐÚNG
XCTAssertNil(myVariable)

```
