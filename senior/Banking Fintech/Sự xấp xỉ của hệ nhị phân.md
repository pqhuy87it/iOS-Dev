Đây là vấn đề cốt lõi về **Khoa học máy tính (Computer Science)** mà mọi Senior Developer làm việc trong mảng Fintech/Banking bắt buộc phải nắm rõ.

Lý do ngắn gọn: **`Double` và `Float` là hệ nhị phân (Binary), còn Tiền tệ là hệ thập phân (Decimal). Hai hệ này không tương thích hoàn toàn.**

Dưới đây là giải thích chi tiết từng lớp vấn đề:

---

### 1. Bản chất vấn đề: Sự xấp xỉ của hệ nhị phân (Binary Approximation)

Máy tính lưu trữ dữ liệu dưới dạng bit (0 và 1).

* Các số nguyên (Integer) như 1, 2, 100 có thể biểu diễn chính xác tuyệt đối sang nhị phân.
* Tuy nhiên, các số thực (Floating Point) như 0.1, 0.2... lại là một câu chuyện khác.

Trong toán học cơ bản:

* `1/3` trong hệ thập phân là `0.333333...` (số vô tỉ, kéo dài vô tận). Bạn không thể viết chính xác nó ra giấy.
* Tương tự, `0.1` (1/10) trong hệ nhị phân cũng là một số vô hạn tuần hoàn: `0.0001100110011...`

Vì bộ nhớ máy tính là hữu hạn (64-bit cho Double), nó buộc phải **cắt bớt** chuỗi vô hạn đó và làm tròn. **Việc làm tròn này tạo ra sai số.**

### 2. Ví dụ kinh điển: 0.1 + 0.2 != 0.3

Hãy thử đoạn code này trong Swift Playground:

```swift
let a: Double = 0.1
let b: Double = 0.2
let sum = a + b

print(sum) 
// Kết quả KHÔNG PHẢI 0.3
// Kết quả là: 0.30000000000000004

```

**Tại sao điều này nguy hiểm trong ngân hàng?**

* Bạn có thể nghĩ: *"Lệch 0.00000000000000004 đâu có đáng kể?"*
* **Sai lầm:** Trong hệ thống ngân hàng xử lý hàng triệu giao dịch mỗi ngày, hoặc khi tính lãi suất kép (compound interest), các sai số nhỏ này sẽ **cộng dồn (accumulate)** lại thành một số tiền lớn bị lệch (Discrepancy).
* Nếu bạn so sánh số dư: `if walletBalance == 0.3 { ... }`, điều kiện này sẽ trả về `false` và giao dịch thất bại oan uổng.

### 3. Giải pháp: `Decimal` hoạt động như thế nào?

`Decimal` (trong Swift) hay `NSDecimalNumber` (trong Objective-C) không sử dụng chuẩn dấu phẩy động nhị phân (IEEE 754). Thay vào đó, nó lưu trữ con số giống như cách con người viết toán học lớp 1: **Cơ số 10**.

Cấu trúc của `Decimal` bao gồm:

1. **Mantissa (Phần định trị):** Một số nguyên cực lớn.
2. **Exponent (Số mũ):** Vị trí của dấu chấm động.

Công thức: 

**Ví dụ với số 12.34:**

* **Double:** Sẽ cố gắng lưu xấp xỉ nhị phân của 12.34 (có sai số).
* **Decimal:** Sẽ lưu là .
* `Mantissa` = 1234 (Số nguyên -> Chính xác 100% trong máy tính).
* `Exponent` = -2 (Số nguyên -> Chính xác 100%).
* Kết quả tính toán luôn chính xác tuyệt đối.



### 4. Cách sử dụng đúng trong Swift (Cạm bẫy Junior hay gặp)

Chuyển sang dùng `Decimal` là đúng, nhưng khởi tạo sai cách thì vẫn chết như thường.

**❌ Cách SAI:**

```swift
// Khởi tạo Decimal từ một số Double
let price = Decimal(0.1) 
print(price) 
// Kết quả: 0.09999999999999999... 
// Tại sao? Vì bản thân số 0.1 (Double) đã bị sai số TRƯỚC KHI được nạp vào Decimal.

```

**✅ Cách ĐÚNG:**
Luôn khởi tạo Decimal từ **String**.

```swift
let price = Decimal(string: "0.1")!
let tax = Decimal(string: "0.2")!
let total = price + tax

print(total)
// Kết quả: 0.3 (Chính xác tuyệt đối)

```

### 5. Kết luận phỏng vấn

Khi trả lời phỏng vấn, hãy tóm tắt 3 ý:

1. **Nguyên nhân:** `Double` dùng hệ nhị phân (IEEE 754) nên không thể biểu diễn chính xác các số thập phân như 0.1, dẫn đến sai số làm tròn (rounding errors).
2. **Hậu quả:** Sai số này cộng dồn trong các phép tính tài chính gây lệch sổ sách hoặc sai logic so sánh (`==`).
3. **Giải pháp:** `Decimal` lưu trữ số dưới dạng `Mantissa` (số nguyên) x `10^Exponent`, đảm bảo độ chính xác tuyệt đối. **Lưu ý quan trọng:** Luôn khởi tạo `Decimal` từ `String` để tránh sai số ngay từ đầu vào.
