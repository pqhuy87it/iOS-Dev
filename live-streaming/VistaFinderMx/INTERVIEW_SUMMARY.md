# VistaFinderMx — Tóm tắt trả lời phỏng vấn

## Câu trả lời chính (~30 giây)

> "Đây là ứng dụng iOS live-streaming từ thiết bị thực địa lên trung tâm điều hành, viết bằng Objective-C/C++. Toàn bộ tầng streaming được tự implement chứ không dùng WebRTC hay thư viện có sẵn: video encode H.264 bằng VideoToolbox, audio AAC bằng AudioConverter, sau đó tôi tự đóng gói RTP theo RFC 3984 — single-NAL, FU-A cho NAL lớn, STAP-A cho SPS/PPS — mã hóa payload bằng KCipher2 rồi gửi qua UDP socket. Song song có một kênh TCP riêng làm control channel để nhận feedback từ server và điều chỉnh bitrate/fps theo điều kiện mạng."

## Nếu được hỏi sâu hơn — 4 điểm nói thêm

1. **Kiến trúc hai chặng.** Encoder không gửi trực tiếp ra Internet mà gửi RTP về `127.0.0.1`; một lớp relay (`VideoSwitcher`/`AudioSwitcher`) bắt lại rồi mới forward lên server. Chặng trung gian này là nơi chèn rate control, packet queue, đo throughput/delay từng packet, và xử lý handover Wi-Fi ↔ 4G mà không phải restart encoder.

2. **Adaptive bitrate tự viết.** Server gửi feedback qua kênh TCP → parse → chọn cấu hình resolution/fps/bitrate phù hợp → set lại `VTCompressionSession` đồng thời giới hạn tốc độ ở lớp relay.

3. **Mã hóa chịu được mất gói.** KCipher2 chỉ mã hóa payload, giữ nguyên RTP header để server đọc được sequence number. Vị trí keystream tính theo `4096 × sequence_number`, nên mất packet không làm mất đồng bộ giải mã — điểm quan trọng khi chạy trên UDP và mạng di động.

4. **NAT traversal + chế độ RTSP.** Có tích hợp SDK NAT traversal cho kết nối qua mạng di động, và một chế độ RTSP client riêng để lấy stream từ camera Wi-Fi ngoài.

## Câu hỏi ngược có thể gặp

**"Sao không dùng WebRTC?"**
Project thiết kế khoảng 2013, thời điểm đó WebRTC trên iOS chưa ổn định. Đổi lại, việc tự implement cho toàn quyền kiểm soát đo lường — delay từng packet, throughput theo cửa sổ thời gian — nên rate control sát với thực tế mạng hơn. Nếu làm lại hôm nay tôi sẽ chọn WebRTC hoặc SRT, vì chúng đã có sẵn congestion control, FEC, retransmit và NAT traversal được kiểm chứng.

**"Hạn chế lớn nhất của hệ thống?"**
Không có RTCP, không FEC, không retransmit — mất packet là mất vĩnh viễn, và feedback đi qua TCP nên phản ứng với nghẽn mạng chậm hơn WebRTC. Ngoài ra code dùng OpenGL ES và manual retain/release, đã lỗi thời.

**"Bạn đã làm gì cụ thể?"**
→ *Điều chỉnh phần này theo vai trò thực tế của bạn trong dự án.*

## Từ khóa nên nhắc

`H.264` · `VideoToolbox` · `AAC` · `RTP / RFC 3984` · `FU-A` · `STAP-A` · `UDP socket` · `TCP control channel` · `KCipher2` · `adaptive bitrate` · `NAT traversal` · `RTSP` · `Objective-C++`
