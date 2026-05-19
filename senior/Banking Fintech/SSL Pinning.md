Đây là một câu hỏi kỹ thuật rất sâu về bảo mật (Security), thường được dùng để đánh giá kinh nghiệm thực chiến của ứng viên Senior trong việc **vận hành và bảo trì (Maintenance)** hệ thống.

Cả hai đều là kỹ thuật **SSL Pinning** nhằm chống lại tấn công Man-in-the-Middle (MitM), nhưng sự khác biệt cốt lõi nằm ở **Độ linh hoạt khi chứng chỉ hết hạn (Rotation Strategy)**.

Dưới đây là bảng so sánh và phân tích chi tiết:

---

### 1. Bản chất kỹ thuật

* **Certificate Pinning (Pin chứng chỉ):**
* Bạn nhúng (hardcode) **toàn bộ file chứng chỉ** (`.cer`, `.der`) vào trong ứng dụng.
* Khi bắt tay (handshake), App so sánh từng byte của chứng chỉ server gửi về với file chứng chỉ đã nhúng trong App. Nếu khớp 100% thì mới tin tưởng.
* **Tư duy:** "Tôi chỉ tin tờ giấy chứng minh thư này, đúng số hiệu này, đúng ngày cấp này."


* **Public Key Pinning (Pin khóa công khai - Khuyên dùng):**
* Bạn chỉ trích xuất **chuỗi Public Key** (thường là mã băm SHA-256 của `Subject Public Key Info` - SPKI) từ chứng chỉ và nhúng chuỗi hash đó vào App.
* **Tư duy:** "Tôi không quan tâm tờ giấy chứng minh thư (Certificate) mới hay cũ, do ai cấp lại. Tôi chỉ quan tâm **dấu vân tay** (Public Key) của người cầm nó có đúng là Server của tôi không."



---

### 2. Sự khác biệt cốt lõi (So sánh)

| Đặc điểm | Certificate Pinning | Public Key Pinning |
| --- | --- | --- |
| **Đối tượng Pin** | Toàn bộ file chứng chỉ (bao gồm ngày hết hạn, chữ ký CA, thông tin tổ chức...). | Chỉ đoạn mã Public Key nằm bên trong chứng chỉ. |
| **Độ chặt chẽ** | Rất chặt chẽ (Strict). | Chặt chẽ vừa đủ (Flexible). |
| **Vấn đề hết hạn** | **Rất rủi ro.** Khi chứng chỉ server hết hạn (thường là 1 năm), bạn phải update chứng chỉ mới. Nếu App user chưa update -> **App chết (Brick).** | **An toàn hơn.** Bạn có thể gia hạn chứng chỉ mới (Renew Certificate) nhưng vẫn **giữ nguyên Public Key cũ** (Certificate Rotation). App cũ vẫn chạy tốt. |
| **Độ khó triển khai** | Dễ. Chỉ cần ném file vào bundle. | Khó hơn xíu. Cần dùng lệnh OpenSSL để trích xuất chuỗi hash SHA-256. |
| **Khuyên dùng** | Không khuyến khích cho App thương mại lớn. | **Best Practice** (Tiêu chuẩn ngành). |

---

### 3. Tại sao Public Key Pinning lại chiến thắng? (Kịch bản thực tế)

Hãy tưởng tượng kịch bản vận hành thực tế tại ngân hàng:

1. **Ngày 01/01/2024:** Server mua chứng chỉ SSL, hạn 1 năm.
2. **Kịch bản dùng Certificate Pinning:**
* Ngày 01/01/2025: Chứng chỉ hết hạn. Đội DevOps mua chứng chỉ mới thay vào Server.
* Hậu quả: Tất cả App version cũ (chứa chứng chỉ 2024) **ngay lập tức không kết nối được mạng**. Bạn bắt buộc phải ép user update App mới nhất mới dùng được. Đây là thảm họa với trải nghiệm người dùng.


3. **Kịch bản dùng Public Key Pinning:**
* Khi mua chứng chỉ mới (Renew), DevOps tạo ra một *Certificate Signing Request (CSR)* **dựa trên Private Key cũ**.
* Kết quả: Chứng chỉ mới có ngày hết hạn mới (2026), nhưng **Public Key bên trong vẫn y hệt cái cũ**.
* Hậu quả: App cũ check hash Public Key thấy vẫn khớp -> Kết nối bình thường. Không ai bị gián đoạn.



---

### 4. Chiến lược "Backup Pins" (Câu trả lời ghi điểm Senior)

Dù bạn chọn cách nào, rủi ro lớn nhất là: **Server bị lộ Private Key và buộc phải thay đổi Key mới đột xuất**. Lúc này App sẽ chết vì Pin sai Key.

Để trả lời phỏng vấn xuất sắc, bạn cần nhắc đến **Backup Strategy**:

> *"Khi thực hiện Pinning (thường dùng Public Key Pinning), tôi không bao giờ chỉ pin 1 key duy nhất. Tôi luôn cấu hình ít nhất **2 keys**:*
> 1. ***Primary Key:** Key đang dùng hiện tại.*
> 2. ***Backup Key:** Một Key dự phòng (đã tạo sẵn Private Key cất vào két sắt, chưa dùng để generate chứng chỉ active).*
> 
> 
> *Nếu server bị tấn công hoặc lộ key chính, DevOps sẽ dùng Key dự phòng để tạo chứng chỉ mới deploy lên server. App lúc này vẫn hoạt động vì nó đã tin tưởng sẵn Backup Key này rồi."*

### Tóm tắt

* **Certificate Pinning:** Dễ làm nhưng dễ "tự sát" khi chứng chỉ hết hạn.
* **Public Key Pinning:** Khó lấy hash hơn một chút nhưng linh hoạt, cho phép gia hạn chứng chỉ server mà không bắt user update app. **Đây là lựa chọn của Senior.**
