Đây là một câu hỏi nền tảng về Cấu trúc dữ liệu (Data Structures). Tuy nhiên, để trả lời ở mức độ **Senior**, bạn không chỉ nên dừng lại ở việc "Array có thứ tự, Set thì không", mà phải phân tích sâu về **Hiệu năng thuật toán (Big O)** và **Cơ chế quản lý bộ nhớ**.

Dưới đây là bảng so sánh chi tiết và phân tích chuyên sâu:

---

### 1. Bảng so sánh tổng quan (Quick Comparison)

| Đặc điểm | Array (Mảng) | Set (Tập hợp) |
| --- | --- | --- |
| **Tính thứ tự** | **Có thứ tự (Ordered).** Truy cập bằng chỉ số (Index). | **Không thứ tự (Unordered).** Không có index. |
| **Tính duy nhất** | **Cho phép trùng lặp** (Duplicates allowed). | **Duy nhất** (Unique). Tự động loại bỏ phần tử trùng. |
| **Yêu cầu dữ liệu** | Mọi kiểu dữ liệu. | Phần tử bắt buộc phải tuân thủ **`Hashable`**. |
| **Tìm kiếm (`contains`)** | **Chậm: O(n)** (Linear Search). | **Siêu nhanh: O(1)** (Hash Lookup). |
| **Chèn (`insert`)** | **O(1)** (nếu append vào cuối). | **O(1)**. |
| **Bộ nhớ (RAM)** | Ít tốn kém hơn (Lưu trữ liền kề). | Tốn kém hơn (Cần bộ nhớ đệm cho Hash Table). |

---

### 2. Phân tích sâu về Hiệu năng (The "Why")

Tại sao `Set.contains` lại nhanh hơn `Array.contains` gấp hàng nghìn lần?

#### **Array: Linear Search (Tìm kiếm tuyến tính)**

* Dữ liệu được xếp thành một hàng dài liền kề trong bộ nhớ.
* Khi bạn hỏi: *"Số 5 có trong mảng không?"*, máy tính phải lật từng chiếc hộp từ đầu đến cuối: Hộp 0? Không phải. Hộp 1? Không phải... Hộp 1 triệu?
* Nếu mảng có 1 triệu phần tử, trường hợp xấu nhất nó phải so sánh 1 triệu lần. -> **Độ phức tạp O(n).**

#### **Set: Hash Table Lookup (Bảng băm)**

* Set không xếp hàng. Nó dùng thuật toán **Hashing** để tính toán địa chỉ.
* Khi bạn ném số `5` vào Set, máy tính tính toán: `hash(5) = địa_chỉ_A`. Nó cất số 5 vào đúng ô nhớ A.
* Khi bạn hỏi: *"Số 5 có trong Set không?"*, máy tính tính lại `hash(5) = địa_chỉ_A`. Nó nhảy dù thẳng xuống ô A và xem có gì ở đó không.
* Nó không cần quan tâm Set có bao nhiêu phần tử, nó chỉ thực hiện 1 phép tính nhảy dù. -> **Độ phức tạp O(1).**

---

### 3. Các phép toán Tập hợp (Set Operations)

Đây là vũ khí mạnh nhất của Set mà Array làm rất vất vả. Nếu đề bài yêu cầu tìm điểm chung, điểm riêng, hãy nghĩ ngay đến Set.

* **Intersection (`intersection`):** Tìm phần tử chung của 2 tập hợp (A ∩ B).
* **Union (`union`):** Gộp 2 tập hợp lại (A ∪ B).
* **Symmetric Difference (`symmetricDifference`):** Lấy những phần tử KHÔNG chung của cả 2 (A ∆ B).
* **Subtract (`subtracting`):** Có trong A nhưng không có trong B (A - B).

```swift
let mathStudents: Set = ["Nam", "Hoa", "Tuan"]
let codingStudents: Set = ["Tuan", "Hung", "Nam"]

// Ai học cả 2 môn?
let both = mathStudents.intersection(codingStudents) 
// Kết quả: ["Nam", "Tuan"] (Tốc độ cực nhanh)

```

---

### 4. Khi nào dùng cái nào? (Decision Matrix)

Là một Senior Developer, bạn chọn cấu trúc dữ liệu dựa trên **Use Case**:

#### **Chọn Array khi:**

1. **Thứ tự là quan trọng:** Danh sách tin nhắn (cũ nhất đến mới nhất), Danh sách công việc (ToDo List).
2. **Dữ liệu trùng lặp có ý nghĩa:** Lịch sử giao dịch (có thể chuyển 50k hai lần liên tiếp), nhật ký log.
3. **Dung lượng bộ nhớ hạn hẹp:** Array lưu trữ liền kề (contiguous memory) nên tối ưu bộ nhớ hơn và thân thiện với CPU Cache hơn Set.
4. **Cần truy cập ngẫu nhiên:** Bạn cần lấy phần tử thứ 5 (`array[4]`). Set không làm được điều này.

#### **Chọn Set khi:**

1. **Tính duy nhất là bắt buộc:** Danh sách Email đăng ký nhận tin (không gửi 2 mail cho 1 người), Danh sách các ID đã check (Selected Items).
2. **Cần kiểm tra sự tồn tại (`contains`) liên tục:** Ví dụ: Kiểm tra xem user ID này có nằm trong danh sách Blacklist (1 triệu dòng) hay không. Dùng Array sẽ làm treo App, Set thì xử lý trong tích tắc.
3. **Thực hiện phép toán tập hợp:** Tìm điểm chung giữa danh sách bạn bè của A và B.

### Mẹo phỏng vấn (Pro Tip):

Nếu người phỏng vấn hỏi: *"Làm thế nào để loại bỏ các phần tử trùng lặp trong một Array?"*
Đừng trả lời là dùng vòng lặp `for` để check. Hãy trả lời:
*"Cách nhanh nhất và gọn nhất là chuyển nó thành Set rồi chuyển ngược lại Array. Tuy nhiên, lưu ý là thứ tự ban đầu sẽ bị mất."*

```swift
let array = [1, 2, 2, 3, 1]
let unique = Array(Set(array)) // [2, 3, 1] - Mất thứ tự

```
