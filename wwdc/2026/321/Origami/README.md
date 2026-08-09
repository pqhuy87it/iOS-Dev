# OrigamiLab

Demo thực hành cho WWDC26 session 321 — *Dive into lazy stacks and scrolling with SwiftUI*.
Tái hiện app **Origami** với `LazyVStack` + `LazyHStack` lồng nhau, và cho phép bật/tắt
trực tiếp giữa **pattern đúng** và **anti-pattern** để bạn cảm nhận khác biệt khi cuộn.

## Cách chạy
1. Xcode: `File ▸ New ▸ Project… ▸ iOS App` (SwiftUI), đặt tên **OrigamiLab**.
2. Xóa file mặc định, kéo toàn bộ `.swift` trong thư mục `OrigamiLab/` vào target.
   (Hoặc mở nhanh bằng cách tạo project rồi thay nội dung các file cùng tên.)
3. Chạy trên simulator hoặc thiết bị. Nhấn nút **slider** trên navigation bar để mở menu.

Yêu cầu: **Xcode 26+ / iOS 26** (dùng `onScrollTargetVisibilityChange`, `ScrollPosition`).
Nếu SDK của bạn thiếu API nào, xem phần "Ghi chú tương thích" bên dưới.

## Các công tắc trong menu và điều cần quan sát

| Toggle | GOOD (bật) | BAD (tắt) | Quan sát |
|---|---|---|---|
| **Filter at data level** | `ForEach` chỉ nhận step đã lọc | lọc bằng `if` trong `StepView` | Tắt đi rồi đổi Detail level: số subview động khiến cuộn kém mượt, ước lượng nhảy. |
| **Set up in init** | tạo `DiagramLoader(id:)` trong init, load qua `.task` | cấu hình trong `onAppear` | Bật: diagram sẵn sàng ngay khi cuộn tới (prefetch). Tắt: nhấp nháy mờ→rõ vì bắt đầu trễ. |
| **Custom layout** | `StepLayout` tính 1 lần | `onGeometryChange` đo rồi resize | Tắt: mỗi cell xuất hiện gây thêm 1 layout pass → giật khi cuộn nhanh. |

Ngoài ra demo có sẵn (luôn theo best practice):
- **Programmatic scroll**: nút "Jump to Showcase" dùng `ScrollPosition.scrollTo(id:)`
  tới `showcase-header` — cuộn được cả khi mục tiêu đang off-screen (lazy stack ước lượng vị trí).
- **Visibility tracking**: nút hiện/ẩn dựa trên `onScrollTargetVisibilityChange` (theo ID),
  không dùng offset tuyệt đối.
- **Pager state ngoài view con**: `ShowcasePager` sống ở `ShowcaseSection` (cha), nên ảnh
  đã tải không mất khi item cuộn khỏi màn hình; spinner cuối gọi `fetchNextPage()`.
- **Highlight state**: lưu trong `DemoSettings.highlighted` (nâng lên cha), sống sót khi
  `StepView` bị hủy do cuộn đi. Chạm vào một step để highlight, cuộn xa rồi quay lại để kiểm chứng.

## Đối chiếu với session
- **Layout / ước lượng kích thước** → `LazyVStack`, nested `LazyHStack`, `pinnedViews`.
- **Subview loading** → toggle *Filter at data level* minh họa số subview động vs tĩnh.
- **Prefetching** → toggle *Set up in init* (init vs onAppear) + `.task` + pager ở view cha.
- **Programmatic scrolling** → `ScrollPosition` + `scrollTo(id:)`, cạnh custom `StepLayout`.

## Cách đo (tùy chọn)
- Instruments → template **SwiftUI** (hoặc **Animation Hitches**): cuộn nhanh với BAD rồi GOOD,
  so số hitch / commit time.
- Bật *Debug ▸ View Debugging ▸ Rendering ▸ Color Changed Regions* trên simulator để thấy
  vùng vẽ lại nhiều hơn ở phiên bản BAD.

## Ghi chú tương thích
- `onScrollTargetVisibilityChange(idType:threshold:)` là API mới (WWDC26). Nếu SDK chưa có,
  tạm thay bằng `onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y > 100 } action:`
  để vẫn chạy (kém chính xác hơn — đúng như session lưu ý).
- `ScrollPosition` và `scrollPosition(_:)` có từ iOS 18; `scrollTo(id:)` dùng cho mục tiêu off-screen.
- `@Observable`, `@Bindable`, `.task`, custom `Layout` đều là API ổn định.
