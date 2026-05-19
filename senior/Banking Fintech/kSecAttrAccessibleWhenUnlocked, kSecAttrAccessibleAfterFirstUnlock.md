Đây là câu hỏi cốt lõi để đánh giá xem ứng viên có hiểu về **Data Protection Lifecycle** của iOS hay không. Trong các ứng dụng ngân hàng, việc chọn sai thuộc tính này có thể dẫn đến việc ứng dụng không thể chạy ngầm (background fetch) hoặc ngược lại, làm giảm mức độ bảo mật của dữ liệu.

Dưới đây là giải thích chi tiết và chiến lược bảo mật khi thiết bị bị mất.

---

### 1. So sánh `kSecAttrAccessibleWhenUnlocked` và `kSecAttrAccessibleAfterFirstUnlock`

Cả hai đều quy định **thời điểm** mà hệ điều hành cho phép ứng dụng đọc dữ liệu đã mã hóa từ Keychain. Sự khác biệt nằm ở trạng thái **Khóa màn hình (Device Locked)**.

#### **A. `kSecAttrAccessibleWhenUnlocked` (Mức độ bảo mật cao nhất)**

* **Cơ chế:** Dữ liệu chỉ có thể truy cập được khi thiết bị **đang được mở khóa** bởi người dùng.
* **Hành vi:**
* Khi người dùng tắt màn hình (Lock device) hoặc bấm nút nguồn: Sau khoảng 10 giây, hệ điều hành sẽ xóa keys giải mã khỏi bộ nhớ (RAM).
* Lúc này, nếu App của bạn đang chạy ngầm và cố gắng đọc Keychain -> **Sẽ thất bại (lỗi `errSecItemNotFound` hoặc tương tự).**


* **Sử dụng khi:** Lưu trữ dữ liệu cực kỳ nhạy cảm mà người dùng cần tương tác trực tiếp mới dùng đến (ví dụ: Private Key để ký giao dịch, mã PIN thẻ).
* **Ưu điểm:** Nếu hacker trộm điện thoại (đang khóa) và cố gắng jailbreak hoặc dump bộ nhớ RAM ngay lúc đó, họ sẽ không tìm thấy key giải mã.

#### **B. `kSecAttrAccessibleAfterFirstUnlock` (Thân thiện với Background Task)**

* **Cơ chế:** Dữ liệu có thể truy cập được sau lần mở khóa đầu tiên kể từ khi khởi động lại máy (Reboot).
* **Hành vi:**
* Người dùng khởi động lại máy -> Nhập passcode lần đầu -> Dữ liệu được giải mã ("Available").
* Người dùng tắt màn hình (Lock device) -> **Dữ liệu VẪN CÓ THỂ truy cập được.**


* **Sử dụng khi:** Ứng dụng cần truy cập Keychain trong khi đang chạy nền (Background Mode).
* *Ví dụ:* App ngân hàng chạy background fetch để cập nhật số dư, hoặc refresh token để giữ session sống. Nếu dùng `WhenUnlocked`, tác vụ background này sẽ thất bại ngay khi user khóa máy.


* **Nhược điểm:** Nếu thiết bị bị mất cắp khi đang bật nguồn (dù đang khóa màn hình), và hacker có công cụ khai thác phần cứng chuyên sâu (forensic tools), dữ liệu này vẫn nằm trong bộ nhớ ở trạng thái sẵn sàng giải mã.

| Đặc điểm | `WhenUnlocked` | `AfterFirstUnlock` |
| --- | --- | --- |
| **Khi thiết bị Restart** | Không đọc được | Không đọc được |
| **Sau lần mở khóa đầu tiên** | Đọc được | Đọc được |
| **Khi tắt màn hình (Lock)** | **KHÔNG ĐỌC ĐƯỢC** (Bảo mật cao) | **VẪN ĐỌC ĐƯỢC** (Tiện lợi) |
| **Phù hợp cho** | Foreground tasks | Background tasks |

---

### 2. Làm sao để dữ liệu vẫn an toàn ngay cả khi thiết bị bị mất?

Nếu thiết bị rơi vào tay kẻ xấu, iOS có cơ chế bảo vệ phần cứng (Secure Enclave), nhưng Senior Developer cần áp dụng thêm các lớp bảo vệ sau:

#### **Chiến thuật 1: Sử dụng hậu tố `...ThisDeviceOnly**`

Luôn luôn thêm hậu tố `ThisDeviceOnly` vào level truy cập.

* *Ví dụ:* `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
* **Tác dụng:** Dữ liệu Keychain này được mã hóa bằng một key phần cứng đặc biệt của **duy nhất thiết bị đó**.
* **Kịch bản:** Nếu hacker không unlock được máy, hắn tháo ổ cứng (NAND Flash) ra lắp sang một máy khác, hoặc cố gắng backup/restore dữ liệu sang máy khác -> **Dữ liệu sẽ trở thành rác**, không thể giải mã được. Nó ngăn chặn tấn công kiểu "Cloning device".

#### **Chiến thuật 2: Ứng dụng "App-Level Encryption" (Mã hóa 2 lớp)**

Đừng tin tưởng tuyệt đối vào Keychain của Apple (vì nếu user đặt passcode quá dễ như "1234", lớp bảo vệ của Apple cũng yếu theo).

* **Cách làm:** Trước khi lưu chuỗi `token` vào Keychain, hãy mã hóa nó bằng một thuật toán riêng (AES-256-GCM) của App bạn.
* **Key lấy ở đâu?** Key giải mã lớp thứ 2 này không lưu cứng trong code, mà được sinh ra từ **Passcode đăng nhập của App** (hoặc Bio-metric) kết hợp với **Salt**.
* **Kết quả:** Kể cả khi hacker vượt qua được lớp bảo mật của iOS (Jailbreak, bypass passcode máy), hắn mở được Keychain ra cũng chỉ thấy một chuỗi ký tự vô nghĩa vì thiếu Passcode riêng của App ngân hàng.

#### **Chiến thuật 3: Vô hiệu hóa dữ liệu từ xa (Remote Wipe Logic)**

Trong app ngân hàng, Server đóng vai trò tối cao.

* Khi user báo mất máy, Server sẽ đánh dấu `DeviceID` đó là "Compromised" (Bị lộ).
* Tất cả các Access Token/Refresh Token gắn với `DeviceID` đó sẽ bị Server thu hồi (Revoke) ngay lập tức.
* Dù hacker có lấy được Token trong máy, Token đó cũng vô dụng khi gọi API.

### Tóm tắt câu trả lời phỏng vấn (Banking Standard):

> *"Đối với dữ liệu nhạy cảm nhất (như Private Key ký giao dịch), tôi luôn sử dụng `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` để đảm bảo keys bị xóa khỏi bộ nhớ ngay khi user khóa máy.
> Tuy nhiên, với Refresh Token cần dùng cho background fetch, tôi buộc phải dùng `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
> Để đảm bảo an toàn tuyệt đối khi mất máy, tôi áp dụng mô hình **Defense in Depth (Bảo vệ chiều sâu)**:
> 1. Dùng `ThisDeviceOnly` để chống restore sang máy khác.
> 2. Không lưu Token thô (Raw), mà mã hóa nó thêm 1 lớp bằng AES với key được dẫn xuất từ mã PIN đăng nhập App.
> 3. Về phía Server, có cơ chế Blacklist thiết bị để vô hiệu hóa token ngay khi khách hàng báo mất."*
> 
>
