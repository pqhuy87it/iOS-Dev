## "Significant experience using LLMs to assist with coding, debugging, and code review" — Giải thích chi tiết cho Senior iOS Developer

Đây là một yêu cầu ngày càng phổ biến trong các job description hiện đại, phản ánh sự thay đổi lớn trong workflow của developer. Mình sẽ phân tích từng khía cạnh.

### 1. Bản chất của yêu cầu này

Công ty không tìm người "biết dùng ChatGPT". Họ tìm người đã **tích hợp LLM vào quy trình làm việc hàng ngày một cách có hệ thống**, biết khi nào nên dùng, khi nào không, và quan trọng nhất — biết **đánh giá chất lượng output** mà LLM trả về. Một senior developer dùng LLM khác hoàn toàn với một junior: senior biết đặt câu hỏi đúng vì đã hiểu sâu về domain.

### 2. Ba mảng cụ thể

**Coding (viết code mới)**

Không phải copy-paste code từ ChatGPT. Mà là biết cách dùng LLM để tăng tốc các công việc như: scaffold một module mới (VIPER/Clean Architecture), generate boilerplate cho Combine/async-await, viết extension cho các pattern lặp lại, hoặc prototype nhanh một feature. Điểm mấu chốt là bạn phải đủ kinh nghiệm để nhận ra khi LLM generate code sai về mặt architecture, memory management, hay thread safety — những thứ mà LLM rất hay sai một cách tinh vi trên iOS (ví dụ: retain cycle trong closure, main thread violation khi update UI từ async context).

**Debugging**

Đây là chỗ LLM thực sự mạnh nếu biết dùng. Ví dụ: paste một crash log hoặc stack trace vào và nhờ phân tích, mô tả một behavior bất thường để LLM gợi ý hướng điều tra, hoặc hỏi về edge case của một API mà Apple document không rõ. Senior developer biết cách cung cấp đủ context (iOS version, device, architecture pattern đang dùng) để LLM cho ra câu trả lời chính xác hơn, thay vì hỏi chung chung rồi nhận được câu trả lời generic.

**Code Review**

Đây là phần thú vị nhất. Bạn có thể dùng LLM để review PR trước khi người khác review, phát hiện potential issues như force unwrap không cần thiết, missing error handling, hay vi phạm SOLID principles. Một số team còn tích hợp LLM vào CI/CD pipeline để auto-review. Nhưng senior developer phải biết rằng LLM có xu hướng "hallucinate" — nó có thể flag một đoạn code là sai trong khi thực tế đó là pattern hợp lệ trên iOS, hoặc ngược lại, bỏ qua một bug thực sự.

### 3. Tại sao yêu cầu "significant experience"?

Vì có một learning curve thực sự:

Giai đoạn đầu, developer thường over-rely hoặc under-rely vào LLM. Qua thời gian, bạn phát triển được "intuition" về việc LLM giỏi cái gì (boilerplate, pattern matching, giải thích concept) và kém cái gì (complex state management, concurrency bugs đặc thù iOS, hiểu business logic cụ thể của project). "Significant" ở đây nghĩa là bạn đã qua giai đoạn thử nghiệm và đang ở mức dùng nó như một công cụ tự nhiên trong workflow.

### 4. Ví dụ thực tế trong iOS development

Một vài tình huống mà senior iOS dev dùng LLM hiệu quả:

- Migrate một codebase từ UIKit sang SwiftUI — dùng LLM để convert từng component, rồi tự review lại logic.
- Viết unit test cho một networking layer phức tạp — LLM generate test case nhanh, bạn bổ sung edge case mà chỉ người hiểu business logic mới biết.
- Refactor legacy Objective-C sang Swift — LLM handle syntax conversion, bạn đảm bảo semantic correctness.
- Dùng các tool như GitHub Copilot, Cursor, hoặc Claude Code trực tiếp trong IDE thay vì chỉ chat qua web.

### 5. Điều công ty thực sự muốn đánh giá

Họ muốn biết bạn có **pragmatic** không. Một senior dev mà từ chối hoàn toàn LLM vì "tôi tự viết code tốt hơn" thì cũng thiếu tính thực tế như một người phụ thuộc hoàn toàn vào LLM mà không kiểm tra output. Vị trí lý tưởng là: dùng LLM như một **junior pair programmer rất nhanh nhưng không đáng tin 100%** — bạn vẫn là người ra quyết định cuối cùng, nhưng tốc độ delivery của bạn tăng đáng kể.

Tóm lại, yêu cầu này thực chất là đánh giá khả năng **thích ứng với công cụ mới** và **tư duy phản biện khi dùng AI** — hai phẩm chất rất quan trọng ở senior level.
