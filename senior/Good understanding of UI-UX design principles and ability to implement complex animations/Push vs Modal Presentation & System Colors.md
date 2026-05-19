# Push vs Modal Presentation & System Colors / Dynamic Type

---

## 1. UINavigationController Push vs Modal Presentation

### Nguyên tắc cốt lõi

Đây không phải chuyện kỹ thuật thuần túy, mà là chuyện **information architecture** — cách user hiểu mình đang ở đâu trong app.

**Push (Show)** thể hiện quan hệ **hierarchical drilling down** — user đang đi sâu hơn vào cùng một luồng thông tin. Ví dụ: Settings → Wi-Fi → chọn một network. Mỗi bước push tạo một breadcrumb trong navigation stack, user luôn biết mình đã đi qua đâu và quay lại bằng back button hoặc swipe-from-edge.

**Modal (Present)** thể hiện **một task tách biệt** khỏi luồng hiện tại — user đang tạm rời context chính để hoàn thành một việc gì đó riêng. Ví dụ: đang browse feed → tap compose để viết post mới. Modal có thể dismiss (kéo xuống hoặc tap Cancel/Done), và nó có ý nghĩa tâm lý: "xong việc này rồi quay lại chỗ cũ".

### Khi nào dùng Push

Push phù hợp khi navigation mang tính **khám phá tuần tự** trong cùng một content domain:

- List → Detail (danh sách sản phẩm → chi tiết sản phẩm)
- Category → Subcategory → Item
- Profile → Edit Profile → Change Password

User flow ở đây có tính **linear và predictable**. User mong đợi back button ở góc trái để quay lại bước trước. Về mặt UX, push giữ navigation bar liên tục, tạo sense of place — user không bao giờ mất orientation.

```swift
// Hierarchical navigation - user đang drill down
navigationController?.pushViewController(detailVC, animated: true)
```

### Khi nào dùng Modal

Modal phù hợp khi task có tính **self-contained**, có điểm bắt đầu và kết thúc rõ ràng:

- Compose (email, message, post) — có Cancel/Send
- Login/Signup flow — tách biệt khỏi main app
- Alert, confirmation — cần user quyết định trước khi tiếp tục
- Settings/Preferences popup — quick config rồi dismiss
- Media preview (ảnh fullscreen, video player)

```swift
// Self-contained task - user tạm rời context chính
let composeVC = ComposeViewController()
let nav = UINavigationController(rootViewController: composeVC)
nav.modalPresentationStyle = .pageSheet
present(nav, animated: true)
```

Lưu ý: modal thường **wrap trong UINavigationController riêng** nếu bên trong có nhiều bước (ví dụ: multi-step form), nhưng navigation stack đó thuộc về modal context, không phải main navigation.

### Modal Presentation Styles — chọn đúng style

Từ iOS 13, Apple đổi default modal style sang `.pageSheet` (card-style) thay vì `.fullScreen`. Đây là quyết định design có chủ đích:

**`.pageSheet` / `.formSheet`** — user vẫn thấy screen phía dưới bị dim, nhận ra mình đang ở "tầng trên" và có thể kéo xuống để dismiss. Phù hợp cho hầu hết modal task, tạo spatial awareness rõ ràng.

**`.fullScreen`** — chiếm toàn bộ screen, che hoàn toàn context phía dưới. Chỉ dùng khi task yêu cầu toàn bộ sự chú ý: onboarding flow, camera capture, immersive media playback. Lưu ý quan trọng: `fullScreen` **không trigger** `viewWillAppear`/`viewDidAppear` trên presenting VC khi dismiss, khác với `pageSheet`.

**`.overCurrentContext` / `.overFullScreen`** — không remove view controller phía dưới khỏi hierarchy. Dùng cho custom popup, tooltip, semi-transparent overlay.

### Sai lầm phổ biến

**Dùng modal cho hierarchical navigation** — Ví dụ: tap item trong list → present detail modally. User mất back gesture quen thuộc, cảm giác "đứt gãy" flow. Và nếu từ detail cần push thêm, bạn phải tạo navigation stack mới bên trong modal → phức tạp hóa vô ích.

**Dùng push cho unrelated task** — Ví dụ: đang ở Home tab → push sang Compose screen. User tap back thì quay lại Home, nhưng về mặt UX, Compose không phải "con" của Home — nó là task riêng. Đặt sai relationship khiến user confused về mental model.

**Quên handle dismiss cho modal** — Với `.pageSheet`, user có thể swipe down bất cứ lúc nào. Nếu modal có unsaved data, bạn cần implement `UIAdaptivePresentationControllerDelegate`:

```swift
func presentationControllerDidAttemptToDismiss(
    _ presentationController: UIPresentationController
) {
    // Hiện confirmation alert "Discard changes?"
    showDiscardAlert()
}

// Phải set isModalInPresentation = true để trigger method trên
nav.isModalInPresentation = hasUnsavedChanges
```

### Quyết định ở level Senior

Senior dev cần đưa ra **guideline rõ ràng** cho team. Ví dụ tạo decision tree đơn giản:

Hỏi: "User đang đi sâu hơn vào cùng content?" — Nếu **có** → Push. Hỏi: "User đang bắt đầu một task mới, tách biệt?" — Nếu **có** → Modal. Hỏi: "Task có thể cancel/complete độc lập?" — Nếu **có** → Modal. Hỏi: "User cần quay lại nhiều bước?" — Nếu **có** → Push với navigation stack.

---

## 2. System Colors & Dynamic Type

### System Colors — Tại sao không hardcode hex

Apple cung cấp semantic colors như `UIColor.label`, `UIColor.systemBackground`, `UIColor.secondarySystemGroupedBackground`... Nhiều junior dev bỏ qua và hardcode `.white`, `.black`, `#333333`. Senior cần hiểu tại sao đây là vấn đề lớn.

**Dark Mode adaptation tự động** — `UIColor.label` là đen trên Light Mode, trắng trên Dark Mode. Hardcode `.black` cho text → Dark Mode sẽ invisible. Và Dark Mode không phải "nice to have", Apple review có thể reject app nếu Dark Mode support quá tệ, và user expectation đã coi đây là standard.

**Accessibility: Increase Contrast** — Trong Settings → Accessibility → Increase Contrast, system colors tự adjust để tăng contrast ratio. Hardcode color thì bỏ qua hoàn toàn accessibility setting này. Ví dụ `UIColor.systemGray4` sẽ đậm hơn khi Increase Contrast bật, còn custom `UIColor(white: 0.78, alpha: 1.0)` thì không thay đổi.

**Elevated appearance trên iPad** — Khi app chạy trong Slide Over hoặc trên elevated surface, `UIColor.systemBackground` tự động adjust. Đây là thứ không thể replicate với static colors.

```swift
// ❌ Fragile - breaks in Dark Mode, Increase Contrast, Elevated
view.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
label.textColor = .black

// ✅ Adaptive - works everywhere automatically
view.backgroundColor = .systemGroupedBackground
label.textColor = .label
```

**Khi nào dùng custom colors?** — Brand colors (logo, primary action button) đương nhiên cần custom. Nhưng nên define chúng trong Asset Catalog với **Light/Dark variants**, hoặc tạo semantic naming:

```swift
// Asset Catalog: "BrandPrimary" với 2 appearances (Light + Dark)
let brandColor = UIColor(named: "BrandPrimary")

// Hoặc programmatic
extension UIColor {
    static let brandPrimary = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
            : UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
    }
}
```

### Dynamic Type — Tại sao không hardcode font size

Dynamic Type cho phép user chọn preferred text size trong Settings. Apple report rằng **một lượng lớn user thay đổi default text size** — không chỉ người khiếm thị, mà cả người lớn tuổi, người dùng màn hình nhỏ, và người thích text lớn hơn cho comfort.

**Dùng text styles thay vì fixed size:**

```swift
// ❌ Fixed - bỏ qua user preference hoàn toàn
label.font = UIFont.systemFont(ofSize: 16)

// ✅ Dynamic - scale theo user settings
label.font = UIFont.preferredFont(forTextStyle: .body)
label.adjustsFontForContentSizeCategory = true
```

**Các text styles chính** và vai trò semantic:

`largeTitle` dùng cho screen title lớn (navigation large title). `title1/2/3` dùng cho section headers theo hierarchy. `headline` dùng cho emphasized text, mặc định bold. `body` dùng cho main content text. `callout` dùng cho secondary content. `subheadline` dùng cho supporting text. `footnote/caption1/caption2` dùng cho metadata, timestamps, labels nhỏ.

Mỗi style có **weight, size, leading** tối ưu cho từng content size category. Apple đã user-test các tỷ lệ này — tự hardcode size thì bạn phải tự làm lại toàn bộ typography scaling.

**Custom font với Dynamic Type:**

```swift
// Custom font mà vẫn respect Dynamic Type
guard let customFont = UIFont(name: "Avenir-Medium", size: 17) else {
    return UIFont.preferredFont(forTextStyle: .body)
}
label.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: customFont)
label.adjustsFontForContentSizeCategory = true
```

**Layout phải co giãn được** — Dynamic Type không chỉ về font. Khi text scale lên 2x, layout phải accommodate. Cell height phải tự grow, horizontal text có thể cần wrap, icon cạnh text cần scale theo `UIFontMetrics.scaledValue(for: 24)`. Nếu layout dùng fixed height constraint, text sẽ bị cắt ở Accessibility sizes.

### Tại sao Senior cần champion điều này

**App Store Review** — Apple ngày càng strict về accessibility. App không support Dynamic Type ở mức cơ bản có thể bị flag.

**Legal compliance** — Nhiều thị trường (US, EU) có accessibility laws. App dùng trong enterprise hoặc government thường yêu cầu WCAG compliance, và Dynamic Type + system colors là baseline.

**Consistency across ecosystem** — Khi app dùng system colors và text styles, nó tự động "fit in" với phần còn lại của iOS. User chuyển từ Settings sang app của bạn không bị jarring. Đây là phần Apple rất coi trọng trong design philosophy — **app là citizen của ecosystem, không phải island**.

**Effort rất thấp, value rất cao** — Đây là một trong những thay đổi có ROI cao nhất. Dùng `.label` thay vì `.black` tốn cùng effort lúc code, nhưng giải quyết Dark Mode, Increase Contrast, và Elevated appearance cùng lúc. Dùng `preferredFont(forTextStyle:)` thay vì fixed size cũng vậy. Senior dev cần set đây là standard trong code review — reject PR nào hardcode color hoặc font size mà không có lý do chính đáng.
