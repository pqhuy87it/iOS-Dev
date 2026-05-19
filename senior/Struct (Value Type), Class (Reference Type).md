Đây là một chủ đề nền tảng nhưng cực kỳ quan trọng để phân biệt giữa Junior và Senior. Senior Developer cần hiểu sự khác biệt này để tối ưu hóa hiệu năng (performance optimization) và tránh các lỗi về trạng thái (state bugs).

Dưới đây là sự so sánh chi tiết dựa trên hai khía cạnh: **Bộ nhớ (Memory)** và **Cơ chế thực thi hàm (Dispatch)**.

---

### 1. Bộ nhớ: Stack vs. Heap

Sự khác biệt lớn nhất nằm ở chi phí khởi tạo (allocation) và hủy (deallocation).

#### **Struct (Value Type) -> Stack (Ngăn xếp)**

* **Cơ chế:** Stack là cấu trúc dữ liệu LIFO (Last In, First Out). Nó hoạt động cực kỳ đơn giản: Chỉ cần di chuyển "Stack Pointer" lên để cấp phát và hạ xuống để giải phóng.
* **Tốc độ:** Rất nhanh (O(1)). Không cần tìm kiếm ô nhớ trống, không cần quản lý sự phức tạp.
* **Thread Safety:** Mỗi Thread có một Stack riêng. Do đó, Struct mặc định là thread-safe (trừ khi bạn dùng `inout` hoặc chia sẻ qua closure).
* **Dữ liệu:** Lưu trữ trực tiếp giá trị. Khi bạn gán `var a = b`, toàn bộ dữ liệu của `b` được copy sang `a` (Copy on Write giúp tối ưu việc này nếu chưa sửa đổi).

#### **Class (Reference Type) -> Heap (Vùng nhớ động)**

* **Cơ chế:** Heap là một vùng nhớ hỗn độn và rộng lớn. Khi khởi tạo một Class:
1. Hệ điều hành phải quét vùng nhớ để tìm một khoảng trống đủ lớn.
2. Cấp phát vùng nhớ đó và trả về địa chỉ (Pointer).
3. Phải quản lý **ARC (Automatic Reference Counting)** để biết khi nào giải phóng.


* **Tốc độ:** Chậm hơn Stack nhiều. Chi phí bao gồm: Tìm chỗ trống + Thread locking (để đảm bảo an toàn khi cấp phát) + ARC overhead (tăng/giảm biến đếm retain count).
* **Truy cập:** Gián tiếp. Stack lưu con trỏ (pointer), con trỏ đó trỏ đến địa chỉ thật trên Heap.

> **Góc nhìn Senior (Nuance):**
> Không phải lúc nào Struct cũng ở trên Stack.
> * Nếu Struct quá lớn hoặc được bọc bên trong một Class (ví dụ: `class User { var info: UserInfoStruct }`), thì Struct đó sẽ **nằm trên Heap** (bên trong vùng nhớ của Class).
> * Nếu Struct bị "capture" bởi một escaping closure, nó cũng sẽ được đẩy lên Heap để tồn tại lâu hơn phạm vi hàm.
> 
> 

---

### 2. Method Dispatch: Static vs. Dynamic

Đây là cách chương trình xác định hàm nào sẽ được gọi khi chạy code.

#### **Struct -> Static Dispatch (Direct Dispatch)**

* **Cơ chế:** Trình biên dịch (Compiler) biết chính xác địa chỉ bộ nhớ của hàm cần gọi ngay tại thời điểm biên dịch (Compile time).
* **Hiệu năng:** Cực nhanh (Fastest).
* CPU nhảy thẳng đến địa chỉ code để chạy.
* **Aggressive Optimization:** Cho phép trình biên dịch thực hiện **Inlining** (thay vì gọi hàm, nó copy luôn code của hàm đó dán vào chỗ gọi, loại bỏ hoàn toàn chi phí gọi hàm).


* **Hạn chế:** Không hỗ trợ tính đa hình (Polymorphism) hay thừa kế (Inheritance). Bạn không thể `override` hàm trong Struct.

#### **Class -> Dynamic Dispatch (Table Dispatch)**

* **Cơ chế:** Vì Class hỗ trợ thừa kế và override, Compiler không biết chắc chắn hàm nào sẽ được gọi (hàm của cha hay hàm của con?). Nó phải xác định lúc chạy (Runtime).
* **V-Table (Virtual Method Table):** Mỗi Class có một bảng chứa các con trỏ hàm.
1. Khi gọi `object.method()`, chương trình đọc bảng V-Table của object đó.
2. Tìm địa chỉ của hàm tương ứng trong bảng.
3. Nhảy đến địa chỉ đó thực thi.


* **Hiệu năng:** Chậm hơn Static Dispatch do tốn thêm bước tra cứu bảng (indirection) và chặn đứng khả năng Inlining của compiler.

> **Góc nhìn Senior (Optimization):**
> Bạn có thể ép Class sử dụng Static Dispatch để tăng tốc bằng từ khóa **`final`**.
> * Khi khai báo `final class` hoặc `final func`, bạn nói với Compiler rằng: "Hàm này không bao giờ bị override".
> * Compiler sẽ chuyển từ Dynamic Dispatch sang **Static Dispatch**. Đây là lý do tại sao dùng `final` là một best practice nếu không có nhu cầu kế thừa.
> 
> 

---

### 3. Tóm tắt so sánh (Summary Table)

| Đặc điểm | Struct (Value Type) | Class (Reference Type) |
| --- | --- | --- |
| **Nơi lưu trữ** | **Stack** (Chủ yếu) | **Heap** |
| **Cơ chế cấp phát** | Di chuyển Stack Pointer (Rất nhanh) | Tìm chỗ trống + Thread Lock (Chậm hơn) |
| **Quản lý bộ nhớ** | Tự động khi thoát scope | **ARC** (Reference Counting) |
| **Method Dispatch** | **Static Dispatch** (Trực tiếp) | **Dynamic Dispatch** (Thông qua V-Table) |
| **Tối ưu hóa** | Hỗ trợ **Inlining** code | Ít tối ưu hơn (trừ khi dùng `final`) |
| **Độ phức tạp** | Thấp, Thread-safe mặc định | Cao, rủi ro Race Condition, Retain Cycle |

### Kết luận cho câu trả lời phỏng vấn:

*"Struct ưu việt hơn về hiệu năng vì nó tận dụng tốc độ của **Stack** và **Static Dispatch**, cho phép compiler tối ưu hóa code (Inlining). Class linh hoạt hơn nhờ tính kế thừa nhưng phải trả giá bằng chi phí quản lý bộ nhớ trên **Heap** (ARC) và độ trễ của **Dynamic Dispatch** khi tra cứu V-Table. Do đó, Swift khuyến khích dùng Struct mặc định (Default to Struct), chỉ dùng Class khi cần định danh (Identity), chia sẻ dữ liệu chung, hoặc cần kế thừa."*
