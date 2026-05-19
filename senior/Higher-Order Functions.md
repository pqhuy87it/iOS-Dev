**Higher-Order Functions (Hàm bậc cao)** là nền tảng của lập trình hàm (Functional Programming) trong Swift. Đối với một Senior iOS Developer, việc sử dụng chúng không chỉ để code ngắn hơn, mà là để viết code **Declarative (Khai báo)** – tức là mô tả **"Muốn làm gì"** thay vì mô tả **"Làm như thế nào"** (như vòng lặp `for`).

Dưới đây là phân tích chuyên sâu về các hàm bậc cao quan trọng nhất, các cạm bẫy và kỹ thuật tối ưu hiệu năng.

---

### 1. Bộ ba quyền lực: Map, Filter, Reduce

#### A. `map` (Biến đổi 1-1)

* **Chức năng:** Duyệt qua từng phần tử, biến đổi nó theo một công thức, và trả về một mảng mới có kích thước **bằng** mảng cũ.
* **Độ phức tạp:** O(n).

```swift
struct User {
    let id: Int
    let name: String
}

let users = [User(id: 1, name: "Tuan"), User(id: 2, name: "Hung")]

// Cách Junior: Viết closure dài dòng
let names1 = users.map { user in 
    return user.name 
}

// Cách Senior: KeyPath Expression (Swift 5.2+)
// Gọn gàng, dễ đọc, tận dụng tính năng của KeyPath
let names2 = users.map(\.name) 

```

#### B. `filter` (Sàng lọc)

* **Chức năng:** Giữ lại các phần tử thỏa mãn điều kiện (return `true`).
* **Độ phức tạp:** O(n).

```swift
let numbers = [1, 5, 10, 15, 20]

// Lọc số chẵn
let evenNumbers = numbers.filter { $0 % 2 == 0 }

// Senior Tip: Kết hợp với thuật toán tìm kiếm
// Kiểm tra tất cả có thỏa mãn không (allSatisfy) hoặc chỉ cần 1 (contains/first)
// Đừng dùng filter().isEmpty để check tồn tại -> Chậm vì nó phải duyệt hết mảng.
let hasEven = numbers.contains(where: { $0 % 2 == 0 }) // Dừng ngay khi tìm thấy số đầu tiên

```

#### C. `reduce` (Gộp lại thành một)

* **Chức năng:** Duyệt qua mảng và gộp tất cả lại thành **một giá trị duy nhất** (có thể là Int, String, hoặc Dictionary, Array...).

**Cấp độ 1: Tính tổng (Cơ bản)**

```swift
let prices = [10.0, 20.0, 5.0]
let total = prices.reduce(0, +) // 0 là giá trị khởi tạo, + là hàm cộng

```

**Cấp độ 2: `reduce` vs `reduce(into:)` (Senior Performance Check)**
Khi bạn dùng reduce để gom dữ liệu vào một **Array** hoặc **Dictionary**, `reduce` thường (bản cũ) có hiệu năng rất tệ vì nó copy giá trị tích lũy (accumulator) liên tục.

Hãy dùng **`reduce(into:)`** để mutate trực tiếp (tận dụng `inout`), tránh copy-on-write.

```swift
let words = ["apple", "banana", "apricot", "cherry"]

// Bài toán: Gom nhóm các từ theo chữ cái đầu.
// [ "a": ["apple", "apricot"], "b": ["banana"] ... ]

// ✅ Cách Tối ưu (O(n)): Dùng reduce(into:)
let grouped = words.reduce(into: [Character: [String]]()) { result, word in
    guard let firstLetter = word.first else { return }
    // 'result' ở đây là inout, sửa trực tiếp không tạo bản sao
    result[firstLetter, default: []].append(word)
}

```

---

### 2. Sự khác biệt "Chết người": Map vs CompactMap vs FlatMap

Đây là câu hỏi phỏng vấn kinh điển để kiểm tra việc xử lý **Optionals** và **Nested Arrays**.

#### A. `compactMap` (Map + Bỏ nil)

Dùng khi transformation có thể trả về `nil`. Nó sẽ tự động loại bỏ các giá trị `nil` đó và unwrap các giá trị `optional`.

* **UseCase:** Convert String sang Int, hoặc URL String sang URL.

```swift
let strings = ["1", "2", "ba", "4", "năm"]

// map trả về [Int?] -> [Optional(1), Optional(2), nil, Optional(4), nil]
let mapResult = strings.map { Int($0) } 

// compactMap trả về [Int] -> [1, 2, 4] -> Sạch sẽ!
let compactResult = strings.compactMap { Int($0) } 

```

#### B. `flatMap` (Làm phẳng mảng lồng nhau)

Dùng khi bạn có mảng trong mảng (`[[T]]`) và muốn gộp thành một mảng phẳng (`[T]`).

* **UseCase:** Gộp danh sách skill của nhiều nhân viên.

```swift
struct Employee {
    let name: String
    let skills: [String]
}

let staff = [
    Employee(name: "A", skills: ["Swift", "iOS"]),
    Employee(name: "B", skills: ["Java", "Android"])
]

// map trả về mảng lồng nhau: [["Swift", "iOS"], ["Java", "Android"]]
let nestedSkills = staff.map { $0.skills }

// flatMap trả về mảng phẳng: ["Swift", "iOS", "Java", "Android"]
let flatSkills = staff.flatMap { $0.skills }

```

---

### 3. Functional Chaining & Lazy Evaluation (Kỹ thuật Senior)

Sức mạnh của HOFs là khả năng nối chuỗi (Chaining) để tạo thành một "Data Pipeline".

**Ví dụ:** Cho mảng số, lấy các số chẵn, bình phương chúng, rồi tính tổng.

```swift
let nums = [1, 2, 3, 4, 5, 6]

// Pipeline rõ ràng, dễ đọc
let result = nums
    .filter { $0 % 2 == 0 } // [2, 4, 6]
    .map { $0 * $0 }        // [4, 16, 36]
    .reduce(0, +)           // 56

```

#### Vấn đề hiệu năng (Performance Issue):

Đoạn code trên tạo ra **2 mảng trung gian** (`filter` tạo 1 mảng, `map` tạo thêm 1 mảng nữa) trước khi ra kết quả cuối. Với mảng nhỏ thì không sao, nhưng với mảng 1 triệu phần tử, bạn đang lãng phí RAM khủng khiếp.

#### Giải pháp: `lazy` Collections

Sử dụng từ khóa `.lazy` để trì hoãn việc tính toán cho đến khi thực sự cần thiết. Nó không tạo mảng trung gian.

```swift
let result = nums.lazy   // Biến thành LazySequence
    .filter { $0 % 2 == 0 } // Chưa chạy ngay
    .map { $0 * $0 }        // Chưa chạy ngay
    .reduce(0, +)           // Giờ mới chạy 1 lượt duy nhất qua mảng gốc

```

**Lưu ý:** Chỉ dùng `.lazy` cho các chuỗi xử lý lớn (Large Collections). Với mảng nhỏ, overhead của việc quản lý trạng thái lazy có thể chậm hơn chạy trực tiếp.

---

### 4. Các hàm bậc cao khác nên biết

* **`forEach`:**
* Giống vòng lặp `for-in` nhưng không thể dùng `break` hoặc `continue` (phải dùng `return` để thoát closure hiện tại - tương đương `continue`).
* *Lời khuyên:* Nên dùng vòng lặp `for-in` truyền thống nếu logic phức tạp cần `break/continue` để code dễ đọc hơn.


* **`sort` vs `sorted`:**
* `sort()`: Sắp xếp **in-place** (sửa mảng gốc), hiệu năng tốt hơn vì không cấp phát bộ nhớ mới. Dùng cho `var`.
* `sorted()`: Trả về **mảng mới**, mảng gốc giữ nguyên. Dùng cho `let` hoặc chuỗi chaining.


* **`zip`:**
* Ghép đôi 2 mảng thành 1 mảng các tuples.
* Ví dụ: Ghép mảng `Students` và mảng `Grades`.



### Tóm tắt câu trả lời phỏng vấn

> *"Higher-Order Functions giúp code Swift trở nên Declarative và dễ bảo trì hơn.
> 1. Tôi sử dụng **`map`** để biến đổi, **`filter`** để chọn lọc và **`reduce`** để tổng hợp dữ liệu.
> 2. Tôi phân biệt rõ **`compactMap`** (để loại bỏ nil) và **`flatMap`** (để làm phẳng mảng lồng nhau).
> 3. Về hiệu năng, tôi luôn ưu tiên dùng **`reduce(into:)`** khi gom dữ liệu vào Collection để tránh copy-on-write.
> 4. Với các tập dữ liệu lớn cần chaining nhiều bước, tôi sử dụng **`lazy`** collection để tránh tạo các mảng trung gian gây lãng phí bộ nhớ."*
> 
>
