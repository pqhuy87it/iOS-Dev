Lĩnh vực Ngân hàng (Banking/FinTech) là một trong những môi trường khắt khe nhất đối với iOS Developer. Ngoài kiến thức kỹ thuật thông thường, nhà tuyển dụng sẽ xoáy sâu vào **Bảo mật (Security)**, **Độ tin cậy (Reliability)** và **Kiến trúc mở rộng (Scalability)**.

Dưới đây là các chủ đề trọng tâm bạn cần chuẩn bị cho cuộc phỏng vấn Senior iOS trong ngành ngân hàng:

---

### 1. Bảo mật Ứng dụng (App Security) - Quan trọng nhất

Đây là "xương sống" của mọi ứng dụng ngân hàng. Bạn phải chứng minh được tư duy "Security First".

* **Lưu trữ dữ liệu nhạy cảm:**
* **Keychain Services:** Tại sao không bao giờ được lưu token/password trong `UserDefaults` hay `CoreData` không mã hóa?
* **Access Control:** Giải thích các mức độ truy cập của Keychain (`kSecAttrAccessibleWhenUnlocked` vs `kSecAttrAccessibleAfterFirstUnlock`). Làm sao để dữ liệu vẫn an toàn ngay cả khi thiết bị bị mất?
* **Secure Enclave:** Cách sử dụng phần cứng để lưu trữ Private Key mà hệ điều hành cũng không thể đọc được.


* **Bảo mật đường truyền (Network Security):**
* **SSL Pinning:** Đây là câu hỏi bắt buộc.
* Sự khác biệt giữa **Certificate Pinning** và **Public Key Pinning**?
* Làm thế nào để tránh việc app bị "chết" (brick) khi server thay đổi chứng chỉ? (Backup keys).
* Cách chống lại các cuộc tấn công **Man-in-the-Middle (MitM)** dùng Charles Proxy hay Wireshark.




* **Chống dịch ngược & Tấn công (Anti-Tampering):**
* **Jailbreak Detection:** Làm sao để phát hiện thiết bị đã Jailbreak? (Kiểm tra file hệ thống, Cydia URL schemes, quyền ghi vào thư mục root...). Xử lý thế nào khi phát hiện? (Crash app hay hạn chế tính năng?).
* **Code Obfuscation:** Làm sao để làm rối code, ngăn chặn hacker đọc logic app?
* **Debugger Detection:** Ngăn chặn hacker attach debugger (LLDB) vào app đang chạy.


* **Bảo vệ dữ liệu hiển thị:**
* Làm mờ màn hình (Blur Screen) khi app vào chế độ Background (App Switcher) để tránh lộ số dư tài khoản.



### 2. Xử lý dữ liệu tài chính (Financial Data Handling)

Sai một xu cũng là lỗi nghiêm trọng (Critical Bug).

* **Kiểu dữ liệu tiền tệ:**
* **Tuyệt đối không dùng `Double` hoặc `Float**` để tính toán tiền tệ. Tại sao? (Vấn đề sai số dấu phẩy động - Floating Point Errors).
* **Giải pháp:** Phải dùng **`Decimal`** (`NSDecimalNumber`) trong Swift để đảm bảo độ chính xác tuyệt đối.


* **Tính toàn vẹn (Data Integrity):**
* **Idempotency (Tính năng lũy đẳng):** Xử lý thế nào khi user bấm nút "Chuyển tiền" 2 lần liên tục do mạng lag? (Client gửi `idempotency_key` lên server).
* **Concurrency:** Xử lý race condition khi cập nhật số dư tài khoản trên UI.



### 3. Kiến trúc & Modularization (Architecture)

Ứng dụng ngân hàng thường rất lớn ("Super App") với nhiều đội (team chuyển tiền, team tiết kiệm, team thẻ) cùng làm việc.

* **Modular Architecture:**
* Bạn tổ chức project thế nào? (Swift Package Manager, CocoaPods, hay Tuist?).
* Làm sao để tách module sao cho Team A sửa code không làm crash tính năng của Team B?
* Giao tiếp giữa các module (Module Interface) mà không phụ thuộc vòng (Circular Dependency).


* **Design Patterns:**
* **VIPER / Clean Architecture:** Rất được ưa chuộng trong ngân hàng vì khả năng test cao và tách biệt logic rõ ràng.
* **Coordinator Pattern:** Quản lý luồng điều hướng phức tạp (Ví dụ: Flow đăng ký eKYC -> Chụp CMND -> Quay mặt -> Nhập OTP -> Success).



### 4. Xác thực sinh trắc học (Biometric Authentication)

* **Local Authentication:**
* Sử dụng framework `LocalAuthentication` (FaceID, TouchID).
* **Fallback mechanism:** Xử lý thế nào khi FaceID thay đổi (ví dụ: user thêm khuôn mặt mới vào máy)? App ngân hàng thường yêu cầu đăng nhập lại bằng password để bảo mật (kiểm tra `evaluatedPolicyDomainState`).
* Phân biệt giữa việc chỉ xác thực để **mở app** và xác thực để **ký giao dịch** (cần độ bảo mật cao hơn).



### 5. Testing & CI/CD (Quy trình)

* **Unit Test & UI Test:**
* Coverage yêu cầu thường rất cao (>80%).
* Bạn mock API như thế nào để test các case chuyển tiền thất bại, timeout, hoặc lỗi server 500?


* **Security Scanning:**
* Kinh nghiệm với các tool quét lỗ hổng bảo mật tự động (SAST/DAST) trong pipeline CI/CD (như SonarQube, Veracode).



### 6. Kiến thức Domain cụ thể (Banking Domain)

Hiểu thuật ngữ nghiệp vụ là điểm cộng lớn:

* **eKYC (Electronic Know Your Customer):** Quy trình định danh điện tử. Bạn đã từng làm việc với các SDK nhận diện khuôn mặt (Liveness detection) hay OCR (quét căn cước) chưa?
* **OTP Handling:** Xử lý Auto-fill OTP từ tin nhắn iOS. Bảo mật OTP (Smart OTP/Soft Token) thay vì SMS OTP truyền thống.
* **Accessibility (VoiceOver):** Các app ngân hàng buộc phải hỗ trợ người khiếm thị theo quy định pháp luật. Bạn đã bao giờ tối ưu VoiceOver cho các nút bấm chuyển tiền chưa?

### Câu hỏi tình huống mẫu (Behavioral/System Design):

1. *"Chúng ta cần implement tính năng Soft OTP (sinh mã OTP offline trên máy thay vì nhận SMS). Bạn sẽ thiết kế giải pháp lưu trữ key và thuật toán sinh mã (TOTP) như thế nào để đảm bảo an toàn?"*
2. *"App đang bị báo cáo là khởi động chậm. Với kiến trúc module hiện tại, bạn sẽ profile và tối ưu hóa thời gian startup (pre-main và post-main) như thế nào?"*
3. *"Làm thế nào để đảm bảo session của user hết hạn (auto logout) chính xác sau 5 phút không thao tác, kể cả khi app đang chạy background?"*
