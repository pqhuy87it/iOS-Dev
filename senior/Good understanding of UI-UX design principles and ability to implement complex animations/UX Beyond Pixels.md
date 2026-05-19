# Tư duy UX Beyond Pixels cho Senior iOS Developer

Senior iOS Developer không chỉ nhìn design mockup rồi code pixel-perfect. Bạn cần hiểu **tại sao** design hoạt động (hoặc không), và có khả năng **phát hiện vấn đề UX** ngay từ lúc review spec hoặc review PR — trước khi user phải chịu đựng.

---

## 1. Affordance — "Nhìn vào là biết làm gì"

### Khái niệm

Affordance là thuộc tính của một element khiến user **tự nhiên hiểu** cách tương tác với nó mà không cần hướng dẫn. Một cái button trông "nhấn được" là có affordance tốt. Một đoạn text màu xanh có underline trông "tap được" là có affordance tốt. Ngược lại, element có thể tương tác nhưng trông giống static content → **false affordance** hoặc **thiếu affordance** → user không biết tap vào đâu.

### Ứng dụng thực tế trong iOS

**System controls có affordance sẵn** — `UIButton` với style `.system` tự động có highlight state khi tap, text color thay đổi, opacity giảm nhẹ. User đã quen với visual language này. Khi bạn custom button quá mức — flat design, không border, không highlight — bạn đang **phá vỡ affordance** mà user đã học.

```swift
// ✅ Affordance rõ ràng - user biết đây là action
let button = UIButton(configuration: .filled())
button.title = "Submit"

// ⚠️ Affordance yếu - trông giống plain text
let label = UILabel()
label.text = "Submit"
label.textColor = .systemBlue
// Thêm tap gesture lên label → user có thể không nhận ra
```

**Ví dụ thực tế trong code review:** Junior dev tạo một custom card view, bên trong có vài element tappable nhưng toàn bộ card trông đồng nhất, không có visual differentiation. Senior cần flag: "User không biết vùng nào tap được. Cần thêm chevron `›` cho navigation items, hoặc dùng tinted text cho actionable elements."

**Signifier vs Affordance** — Don Norman phân biệt: affordance là khả năng thực sự, signifier là **dấu hiệu trực quan** cho biết affordance đó. Trong iOS, signifier phổ biến là: chevron (`>`) ở trailing edge cell → "tap để xem thêm"; grabber bar trên modal sheet → "kéo xuống để dismiss"; icon `+` trên navigation bar → "tạo mới". Senior dev cần đảm bảo signifier có mặt đúng chỗ — thiếu signifier thì affordance vô nghĩa vì user không phát hiện ra.

### Anti-patterns cần catch

**Hamburger menu ẩn quá sâu** — Feature quan trọng nằm sau icon 3 gạch ở góc trên, không có label text. User không biết nó tồn tại → discoverability bằng 0. Senior nên suggest tab bar hoặc visible entry point.

**Swipe actions không có hint** — Swipe-to-delete trong `UITableView` là convention quen thuộc, nhưng custom swipe actions (archive, pin, mute) trên custom views thì user không có cách nào biết nếu không có onboarding hint. Cần cân nhắc thêm visual cue hoặc long-press menu alternative.

**Disabled state không rõ ràng** — Button disabled nhưng chỉ giảm opacity từ 1.0 xuống 0.8, user vẫn tap và không hiểu tại sao không có gì xảy ra. Apple recommend opacity ~0.3-0.4 cho disabled state, hoặc dùng `UIButton.configuration` với `.disabled` state tự động.

---

## 2. Cognitive Load — "Não user có giới hạn"

### Khái niệm

Cognitive load là lượng **mental effort** mà user phải bỏ ra để hiểu và sử dụng interface. Theo Miller's Law, working memory con người giữ được khoảng **7±2 items** cùng lúc. Screen nhồi nhét quá nhiều thông tin, quá nhiều lựa chọn, quá nhiều visual noise → user bị overwhelm → hoặc bỏ cuộc, hoặc mắc lỗi.

Có 3 loại cognitive load:

**Intrinsic load** — độ phức tạp tự nhiên của task. Ví dụ: chuyển tiền ngân hàng inherently cần nhiều thông tin (số tài khoản, số tiền, ngân hàng nhận...). Không thể giảm, chỉ có thể tổ chức tốt hơn.

**Extraneous load** — độ phức tạp do **design tệ** tạo ra. Ví dụ: form chuyển tiền có 15 fields hiện cùng lúc, font size khác nhau, label không rõ ràng, validation message ở chỗ user không nhìn thấy. Đây là thứ senior dev cần **eliminate**.

**Germane load** — effort để build mental model. Ví dụ: user lần đầu dùng app cần thời gian hiểu structure. Good design giảm germane load bằng cách dùng patterns quen thuộc (tab bar, search bar ở trên, pull-to-refresh).

### Ứng dụng thực tế trong iOS

**Progressive disclosure** — Không hiện tất cả cùng lúc. Chia task phức tạp thành steps. Ví dụ: thay vì form đăng ký 10 fields trên một screen, chia thành 3 screens (account info → personal info → preferences). Apple làm điều này rất tốt trong Setup Wizard của iPhone.

```swift
// ❌ Cognitive overload - 10 fields cùng lúc
class RegistrationViewController: UIViewController {
    let emailField, passwordField, confirmPasswordField,
        firstNameField, lastNameField, phoneField,
        addressField, cityField, zipField, countryField: UITextField
}

// ✅ Progressive disclosure - từng bước một
class RegistrationFlowController {
    private let steps: [UIViewController] = [
        AccountStepVC(),    // email + password
        PersonalStepVC(),   // name + phone
        PreferencesStepVC() // optional settings
    ]
    private var currentStep = 0
    
    func advance() {
        currentStep += 1
        navigationController?.pushViewController(
            steps[currentStep], animated: true
        )
    }
}
```

**Hick's Law** — Thời gian ra quyết định **tăng logarithmically** theo số lượng lựa chọn. Menu có 3 options → user chọn nhanh. Menu có 15 options → user scan lâu, dễ chọn sai, hoặc bỏ cuộc. Khi review design có action sheet với 8+ actions, senior nên flag: "Cần group hoặc prioritize — đưa 2-3 common actions lên trước, còn lại vào submenu hoặc 'More'."

**Chunking** — Nhóm thông tin related lại. Ví dụ: màn hình profile thay vì list flat 20 rows, nhóm thành sections: "Personal Info", "Security", "Preferences". iOS `UITableView` grouped style và section headers phục vụ mục đích này. Senior dev khi design data model cho screen cần nghĩ theo sections, không phải flat array.

**Visual hierarchy** — Không phải mọi thông tin đều quan trọng như nhau. Dùng size, weight, color, spacing để tạo hierarchy rõ ràng. User scan screen theo F-pattern hoặc Z-pattern — thông tin quan trọng nhất phải ở nơi mắt nhìn đầu tiên:

```swift
// Tạo visual hierarchy rõ ràng
titleLabel.font = .preferredFont(forTextStyle: .title2)    // lớn, bold
titleLabel.textColor = .label                               // high contrast

subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
subtitleLabel.textColor = .secondaryLabel                   // giảm emphasis

metadataLabel.font = .preferredFont(forTextStyle: .caption1)
metadataLabel.textColor = .tertiaryLabel                    // lowest emphasis
```

### Trong code review, senior catch gì?

"Screen này có 5 CTA buttons cùng prominence level — user không biết tap cái nào trước. Cần 1 primary, còn lại secondary/tertiary." Hoặc: "Section này mix 3 loại content khác nhau không có divider hoặc spacing — cần visual separation để giảm parsing effort."

---

## 3. Fitts's Law — "Size và distance quyết định tốc độ"

### Khái niệm

Fitts's Law phát biểu rằng thời gian để di chuyển đến một target tỷ lệ thuận với **khoảng cách** đến target và tỷ lệ nghịch với **kích thước** target. Công thức:

```
T = a + b × log₂(2D / W)
```

Trong đó `D` là distance, `W` là width (size) của target. Nói đơn giản: **target càng lớn và càng gần vị trí hiện tại của ngón tay → tap càng nhanh và chính xác**.

### Ứng dụng thực tế trong iOS

**Minimum touch target 44×44 points** — Đây là Apple HIG guideline. Không phải visual size, mà là **tappable area**. Button có thể nhìn nhỏ 24×24pt (icon), nhưng hit area phải ít nhất 44×44pt:

```swift
class ExpandedTapButton: UIButton {
    private let minimumHitSize = CGSize(width: 44, height: 44)
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let expandedWidth = max(bounds.width, minimumHitSize.width)
        let expandedHeight = max(bounds.height, minimumHitSize.height)
        let expandedBounds = CGRect(
            x: bounds.midX - expandedWidth / 2,
            y: bounds.midY - expandedHeight / 2,
            width: expandedWidth,
            height: expandedHeight
        )
        return expandedBounds.contains(point)
    }
}
```

**Thumb zone trên phone** — Nghiên cứu của Steven Hoober cho thấy vùng dễ reach nhất bằng ngón cái là **phần dưới-giữa** screen. Đây là lý do Apple đặt tab bar ở bottom, Safari đặt address bar ở bottom (iOS 15+), và Large Title navigation co lại khi scroll. Action quan trọng nhất nên nằm trong **comfortable thumb zone**, không phải góc trên bên trái:

```
┌─────────────────────┐
│  ○ Hard to reach     │  ← Navigation items ở đây
│                      │     → chỉ nên đặt infrequent actions
│                      │
│  ◐ OK to reach       │  ← Content area
│                      │
│  ● Easy to reach     │  ← Primary actions nên ở đây
│                      │     → tab bar, floating action button
└─────────────────────┘
```

**Spacing giữa interactive elements** — Hai button cạnh nhau mà khoảng cách quá nhỏ → user tap nhầm. HIG recommends minimum 8pt spacing giữa tappable elements. Trong table view, nếu cell có button "Edit" và "Delete" cạnh nhau → spacing phải đủ lớn, hoặc tốt hơn là dùng swipe actions để tách biệt hoàn toàn.

**Edge targets và infinite width** — Element dính sát cạnh screen (edge) có lợi thế: user có thể swipe từ ngoài vào mà không cần chính xác. Đây là lý do swipe-from-left-edge to go back hoạt động tốt — edge là target có "infinite width" theo Fitts's Law. Senior dev nên tận dụng edge gestures cho frequent actions.

### Trong code review, senior catch gì?

"Icon button này chỉ có frame 20×20, cần override `point(inside:with:)` hoặc dùng `contentEdgeInsets` để expand hit area lên 44×44." Hoặc: "Destructive action (Delete) đặt ngay cạnh primary action (Save) — cần tách xa hơn hoặc thêm confirmation để prevent miss-tap." Hoặc: "CTA chính của screen này nằm ở navigation bar bên phải trên cùng — user one-handed phải với tay. Nên đặt ở bottom."

---

## 4. Feedback Loop — "Mọi action cần có reaction"

### Khái niệm

Feedback loop nghĩa là **mỗi hành động của user phải có phản hồi tức thì** từ system. Không có feedback → user không biết action đã được nhận → tap lại → duplicate action → frustration. Feedback cần đáp ứng 3 tiêu chí: **immediate** (xảy ra ngay), **informative** (cho biết chuyện gì đang xảy ra), **proportional** (mức độ feedback tương xứng với mức độ action).

### Timing thresholds

Jakob Nielsen define 3 ngưỡng thời gian quan trọng:

**< 100ms** — User cảm nhận là **instant**. Tap highlight, button state change, toggle switch phải respond trong ngưỡng này. Nếu chậm hơn → cảm giác laggy.

**100ms – 1 second** — User nhận ra có delay nhưng vẫn cảm thấy **flow liên tục**. Navigation push animation, content loading từ cache. Không cần loading indicator nhưng cần visual transition để fill gap.

**> 1 second** — User mất focus. **Bắt buộc** phải có loading indicator. Nếu > 3-5 giây, cần progress indicator (xác định hoặc không xác định) và có thể cần cho phép cancel.

```swift
// Feedback cho từng phase
func submitOrder() {
    // Phase 1: Instant feedback (< 100ms)
    submitButton.configuration?.showsActivityIndicator = true
    submitButton.isEnabled = false  // prevent double-tap
    
    // Phase 2: Network request (> 1 second)
    // ActivityIndicator đã visible từ Phase 1
    
    Task {
        do {
            let result = try await orderService.submit(order)
            // Phase 3: Success feedback
            showSuccessHaptic()
            showConfirmation(order: result)
        } catch {
            // Phase 3: Error feedback
            showErrorHaptic()
            showRetryableError(error)
            submitButton.configuration?.showsActivityIndicator = false
            submitButton.isEnabled = true  // cho phép retry
        }
    }
}
```

### Các hình thức feedback trên iOS

**Visual feedback** — highlight state khi tap, animation khi transition, skeleton screen khi loading content, checkmark khi action thành công. Đây là hình thức phổ biến và quan trọng nhất.

**Haptic feedback** — `UIImpactFeedbackGenerator`, `UINotificationFeedbackGenerator`, `UISelectionFeedbackGenerator`. Haptic tạo cảm giác "physical" cho digital interaction. Dùng đúng chỗ rất hiệu quả, dùng sai thì annoying:

```swift
// ✅ Đúng: notification haptic cho success/error
let generator = UINotificationFeedbackGenerator()
generator.notificationOccurred(.success)  // sau khi save thành công

// ✅ Đúng: selection haptic cho picker scroll
let selection = UISelectionFeedbackGenerator()
selection.selectionChanged()  // mỗi khi picker value thay đổi

// ❌ Sai: impact haptic cho mỗi character typed
// → annoying, drain battery
```

**Auditory feedback** — Keyboard click, send message sound (như iMessage "whoosh"). Thường dùng ít trong third-party app, nhưng rất hiệu quả cho key moments (payment success, message sent).

**State-based feedback** — Empty states, error states, loading states. Mỗi screen cần handle đầy đủ **4 states chính**:

```swift
enum ViewState<T> {
    case loading                    // spinner hoặc skeleton
    case loaded(T)                  // content chính
    case empty                      // "No results" + illustration + CTA
    case error(Error)               // error message + retry button
}
```

### Anti-patterns cần catch

**"Swallow" tap silently** — User tap button, network request fire nhưng không có visual change. User tap lại → duplicate request. Fix: disable button + show indicator ngay lập tức, trước khi network request bắt đầu.

**Loading state chỉ có spinner** — Spinner không nói gì về progress hoặc context. Tốt hơn: skeleton screen cho content loading (user biết layout sắp có gì), progress bar cho upload/download (user biết còn bao lâu), shimmer effect cho list items.

**Error không actionable** — Alert hiện "Something went wrong" với button "OK". User tap OK rồi... làm gì? Cần error message **cụ thể** và **có action**: "Không thể kết nối server. [Thử lại]" hoặc "Phiên đăng nhập hết hạn. [Đăng nhập lại]".

**Missing optimistic UI** — User toggle một setting, app gửi API request, chờ response rồi mới update UI. Trong 1-2 giây đó user không biết tap có tác dụng không. Tốt hơn: update UI ngay (optimistic), rollback nếu API fail:

```swift
func toggleFavorite(item: Item) {
    // Optimistic update - feedback tức thì
    item.isFavorite.toggle()
    updateUI(item: item)
    hapticFeedback(.success)
    
    Task {
        do {
            try await api.updateFavorite(item.id, value: item.isFavorite)
        } catch {
            // Rollback nếu fail
            item.isFavorite.toggle()
            updateUI(item: item)
            showError("Không thể cập nhật. Vui lòng thử lại.")
        }
    }
}
```

---

## 5. Tổng hợp — Senior mindset khi review UX

Khi review PR hoặc review design spec, senior iOS developer chạy **mental checklist** dựa trên các nguyên tắc trên:

**Affordance check:** Mọi interactive element có trông tappable không? Có signifier không (chevron, color, icon)? Disabled state có rõ ràng không?

**Cognitive load check:** Screen có quá nhiều thông tin cùng lúc không? Có thể progressive disclosure không? Visual hierarchy có rõ ràng không? Có group/chunk thông tin hợp lý không?

**Fitts's Law check:** Touch target có ≥ 44pt không? Primary action có nằm trong thumb zone không? Destructive actions có cách xa primary actions không?

**Feedback check:** Mọi tap có immediate response không? Loading states đầy đủ chưa? Error states có actionable không? 4 states (loading, loaded, empty, error) đã handle hết chưa?

Đây không phải việc của designer — đây là **shared responsibility**. Designer có thể miss technical constraints (animation performance, touch target overlap), và developer là người catch cuối cùng trước khi code đến tay user. Senior dev có UX awareness tốt sẽ **giảm số lần redesign**, **giảm bug UX**, và **tăng chất lượng product** rõ rệt.
