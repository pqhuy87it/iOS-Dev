# SwiftUI: `ViewModifier` Protocol — Giải thích chi tiết

## 1. Bản chất — Đóng gói biến đổi View thành unit tái sử dụng

`ViewModifier` là protocol cho phép **đóng gói một chuỗi modifier** thành một unit riêng biệt, có thể tái sử dụng trên nhiều view khác nhau. Thay vì copy-paste cùng một chuỗi `.padding().background().clipShape()...` ở nhiều nơi, ta đóng gói vào struct conform `ViewModifier`.

```swift
// ❌ Copy-paste modifier chain ở nhiều nơi
Text("Hello").padding().background(.blue).clipShape(Capsule())
Text("World").padding().background(.blue).clipShape(Capsule())
Button("Tap") {}.padding().background(.blue).clipShape(Capsule())

// ✅ Đóng gói vào ViewModifier, dùng 1 lần
Text("Hello").modifier(BlueCapsule())
Text("World").modifier(BlueCapsule())
Button("Tap") {}.modifier(BlueCapsule())
```

---

## 2. Protocol Definition

```swift
protocol ViewModifier {
    associatedtype Body: View
    
    @ViewBuilder
    func body(content: Content) -> Self.Body
    //              ↑ Content = view gốc được truyền vào
    //                         (placeholder cho view bất kỳ)
}
```

Chỉ yêu cầu **1 method**: `body(content:)` — nhận view gốc (`content`), trả về view mới đã biến đổi.

### `Content` là gì?

`Content` là **placeholder** đại diện cho view mà modifier được áp dụng lên. Ta không biết cụ thể nó là `Text`, `Button`, hay `Image` — chỉ biết nó là "some View":

```swift
struct MyModifier: ViewModifier {
    func body(content: Content) -> some View {
        //              ↑ content = view gốc (Text, Button, Image...)
        content          // ← giữ nguyên view gốc
            .padding()   // ← thêm modifier lên nó
            .background(.blue)
    }
}

// Khi dùng:
Text("Hello").modifier(MyModifier())
// content = Text("Hello")
// Kết quả = Text("Hello").padding().background(.blue)

Image("photo").modifier(MyModifier())
// content = Image("photo")
// Kết quả = Image("photo").padding().background(.blue)
```

---

## 3. Tạo Custom ViewModifier — Từ cơ bản đến nâng cao

### 3.1 Cơ bản — Đóng gói modifier chain

```swift
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// Sử dụng
Text("Card content")
    .modifier(CardStyle())
```

### 3.2 Có parameters — Customizable modifier

```swift
struct RoundedBorder: ViewModifier {
    let color: Color
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    
    func body(content: Content) -> some View {
        content
            .padding(12)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color, lineWidth: lineWidth)
            )
    }
}

// Sử dụng
TextField("Email", text: $email)
    .modifier(RoundedBorder(color: .blue, cornerRadius: 10, lineWidth: 2))
```

### 3.3 Default parameters — Giá trị mặc định

```swift
struct ElevatedCard: ViewModifier {
    var cornerRadius: CGFloat = 12
    var shadowRadius: CGFloat = 8
    var shadowColor: Color = .black.opacity(0.1)
    var backgroundColor: Color = .white
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: shadowColor, radius: shadowRadius, y: 4)
    }
}

// Dùng default
Text("Default card").modifier(ElevatedCard())

// Dùng custom
Text("Custom card").modifier(ElevatedCard(
    cornerRadius: 20,
    shadowRadius: 16,
    backgroundColor: .yellow.opacity(0.1)
))
```

---

## 4. Extension method — Cú pháp gọn hơn `.modifier()`

`.modifier(MyModifier())` dài dòng. Convention chuẩn: tạo **extension trên View** để gọi tự nhiên như built-in modifier:

```swift
// Định nghĩa
struct CardStyle: ViewModifier {
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(radius: 8)
    }
}

// Extension cho cú pháp gọn
extension View {
    func cardStyle(cornerRadius: CGFloat = 12) -> some View {
        modifier(CardStyle(cornerRadius: cornerRadius))
    }
}

// Giờ gọi tự nhiên:
Text("Hello")
    .cardStyle()                    // default cornerRadius = 12

Text("Custom")
    .cardStyle(cornerRadius: 20)   // custom cornerRadius
```

**Trước và sau:**

```swift
// ❌ Dài dòng
Text("Hi").modifier(CardStyle(cornerRadius: 12))

// ✅ Tự nhiên như built-in modifier
Text("Hi").cardStyle()
```

---

## 5. ViewModifier có `@State` — Modifier có state riêng

ViewModifier có thể chứa **`@State`, `@Binding`, `@Environment`** — mỗi view áp dụng modifier sẽ có state instance riêng biệt.

### 5.1 Shake animation modifier

```swift
struct ShakeEffect: ViewModifier {
    @State private var offset: CGFloat = 0
    var trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _, _ in
                withAnimation(
                    .default
                    .repeatCount(3, autoreverses: true)
                    .speed(6)
                ) {
                    offset = 10
                }
                // Reset sau animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation { offset = 0 }
                }
            }
    }
}

extension View {
    func shake(trigger: Bool) -> some View {
        modifier(ShakeEffect(trigger: trigger))
    }
}

// Sử dụng
struct LoginView: View {
    @State private var password = ""
    @State private var hasError = false
    
    var body: some View {
        SecureField("Password", text: $password)
            .shake(trigger: hasError)
        //                      ↑ hasError toggle → shake animation
        
        Button("Login") {
            if password != "correct" {
                hasError.toggle()    // trigger shake
            }
        }
    }
}
```

### 5.2 Glow / Pulse animation modifier

```swift
struct PulseGlow: ViewModifier {
    let color: Color
    let isActive: Bool
    
    @State private var animating = false
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: isActive ? color.opacity(animating ? 0.6 : 0.1) : .clear,
                radius: animating ? 12 : 4
            )
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    animating = true
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        animating = true
                    }
                } else {
                    withAnimation { animating = false }
                }
            }
    }
}

extension View {
    func pulseGlow(color: Color = .blue, isActive: Bool = true) -> some View {
        modifier(PulseGlow(color: color, isActive: isActive))
    }
}

// Nút "Recording" nhấp nháy đỏ
Button("Recording") { }
    .pulseGlow(color: .red, isActive: isRecording)
```

### 5.3 Hover effect modifier (iOS 17.0+ / macOS)

```swift
struct HoverScale: ViewModifier {
    @State private var isHovered = false
    var scale: CGFloat = 1.05
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func hoverScale(_ scale: CGFloat = 1.05) -> some View {
        modifier(HoverScale(scale: scale))
    }
}
```

---

## 6. ViewModifier có `@Binding`

```swift
struct ClearableField: ViewModifier {
    @Binding var text: String
    
    func body(content: Content) -> some View {
        HStack {
            content
            
            if !text.isEmpty {
                Button {
                    withAnimation { text = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

extension View {
    func clearable(text: Binding<String>) -> some View {
        modifier(ClearableField(text: text))
    }
}

// Sử dụng
TextField("Search", text: $query)
    .clearable(text: $query)
// [ Search...              ⓧ ]
//                           ↑ tap → clear text
```

### Character counter

```swift
struct CharacterCounter: ViewModifier {
    @Binding var text: String
    let maxLength: Int
    
    private var remaining: Int { maxLength - text.count }
    private var isOverLimit: Bool { remaining < 0 }
    
    func body(content: Content) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            content
                .onChange(of: text) { _, newValue in
                    // Optional: truncate if over limit
                    if newValue.count > maxLength {
                        text = String(newValue.prefix(maxLength))
                    }
                }
            
            Text("\(text.count)/\(maxLength)")
                .font(.caption)
                .foregroundStyle(isOverLimit ? .red : .secondary)
        }
    }
}

extension View {
    func characterLimit(_ max: Int, text: Binding<String>) -> some View {
        modifier(CharacterCounter(text: text, maxLength: max))
    }
}

TextEditor(text: $bio)
    .characterLimit(280, text: $bio)
// [TextEditor content here      ]
//                        140/280
```

---

## 7. ViewModifier có `@Environment`

```swift
struct AdaptiveCard: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var sizeClass
    
    func body(content: Content) -> some View {
        content
            .padding(sizeClass == .regular ? 24 : 16)
            .background(colorScheme == .dark ? Color(.systemGray6) : .white)
            .clipShape(RoundedRectangle(cornerRadius: sizeClass == .regular ? 16 : 12))
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.1),
                radius: 8, y: 4
            )
    }
}

extension View {
    func adaptiveCard() -> some View {
        modifier(AdaptiveCard())
    }
}
// Tự adapt theo dark/light mode VÀ iPhone/iPad
```

---

## 8. ViewModifier wrap/thêm views — Không chỉ chain modifier

ViewModifier có thể **thêm views bao quanh** content, không chỉ chain modifier lên nó:

### Loading overlay

```swift
struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    var message: String = "Loading..."
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 3 : 0)
            
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

extension View {
    func loadingOverlay(_ isLoading: Bool, message: String = "Loading...") -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, message: message))
    }
}

// Sử dụng
List(items) { item in ItemRow(item: item) }
    .loadingOverlay(vm.isLoading)
```

### Error banner

```swift
struct ErrorBanner: ViewModifier {
    let error: String?
    
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            if let error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                    Spacer()
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(12)
                .background(.red)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            content
        }
        .animation(.spring(duration: 0.3), value: error)
    }
}

extension View {
    func errorBanner(_ error: String?) -> some View {
        modifier(ErrorBanner(error: error))
    }
}

// Sử dụng
NavigationStack { ... }
    .errorBanner(vm.errorMessage)
// ┌─────────────────────────────┐
// │ ⚠ Network connection lost   │  ← banner (khi có error)
// ├─────────────────────────────┤
// │ Content                      │
// └─────────────────────────────┘
```

### Badge / Notification dot

```swift
struct BadgeModifier: ViewModifier {
    let count: Int
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if count > 0 {
                    Text(count > 99 ? "99+" : "\(count)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.red))
                        .offset(x: 8, y: -8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: count)
    }
}

extension View {
    func badge(count: Int) -> some View {
        modifier(BadgeModifier(count: count))
    }
}

// Sử dụng
Image(systemName: "bell.fill")
    .font(.title2)
    .badge(count: 5)
//  🔔
//    ⑤  ← badge đỏ góc trên phải
```

---

## 9. ViewModifier + `onAppear` / `task` — Lifecycle hooks

```swift
struct TrackAppearance: ViewModifier {
    let screenName: String
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                Analytics.trackScreenView(screenName)
            }
            .onDisappear {
                Analytics.trackScreenExit(screenName)
            }
    }
}

extension View {
    func trackScreen(_ name: String) -> some View {
        modifier(TrackAppearance(screenName: name))
    }
}

// Sử dụng — DRY analytics tracking
struct HomeView: View {
    var body: some View {
        ScrollView { ... }
            .trackScreen("Home")
    }
}

struct ProfileView: View {
    var body: some View {
        Form { ... }
            .trackScreen("Profile")
    }
}
```

### Auto-refresh modifier

```swift
struct AutoRefresh: ViewModifier {
    let interval: TimeInterval
    let action: () async -> Void
    
    func body(content: Content) -> some View {
        content
            .task {
                // Lần đầu
                await action()
                // Sau đó refresh định kỳ
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(interval))
                    guard !Task.isCancelled else { break }
                    await action()
                }
            }
    }
}

extension View {
    func autoRefresh(every interval: TimeInterval, action: @escaping () async -> Void) -> some View {
        modifier(AutoRefresh(interval: interval, action: action))
    }
}

// Sử dụng
List(vm.items) { item in ItemRow(item: item) }
    .autoRefresh(every: 30) {
        await vm.loadItems()    // refresh mỗi 30 giây
    }
```

---

## 10. ViewModifier vs View Extension — Quyết định

### Khi nào dùng Extension đơn giản (KHÔNG cần ViewModifier)?

```swift
// Chỉ chain modifier sẵn, không state, không binding, không environment
extension View {
    func primaryButton() -> some View {
        self                            // ← dùng self thay vì content
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    func sectionTitle() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(.bottom, 4)
    }
}
```

### Khi nào BẮT BUỘC dùng ViewModifier?

```swift
// 1. Cần @State → chỉ ViewModifier hỗ trợ
struct ShakeEffect: ViewModifier {
    @State private var offset: CGFloat = 0    // ← @State
    // Extension không thể có @State
}

// 2. Cần @Binding
struct ClearableField: ViewModifier {
    @Binding var text: String                  // ← @Binding
}

// 3. Cần @Environment
struct AdaptiveCard: ViewModifier {
    @Environment(\.colorScheme) var colorScheme // ← @Environment
}

// 4. Cần thêm views (ZStack, overlay logic phức tạp)
struct LoadingOverlay: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {                               // ← wrap content trong ZStack
            content
            if isLoading { ProgressView() }
        }
    }
}

// 5. Cần lifecycle hooks (onAppear, task, onChange)
struct TrackScreen: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { ... }                  // ← lifecycle hook
            .onDisappear { ... }
    }
}
```

### Bảng quyết định

```
Chỉ chain modifier sẵn (.padding, .font, .background...)?
  → Extension ✅ (gọn hơn)

Cần @State, @Binding, @Environment?
  → ViewModifier ✅ (bắt buộc)

Cần thêm views bao quanh (ZStack, overlay, banner)?
  → ViewModifier ✅ (bắt buộc)

Cần lifecycle hooks (onAppear, task, onChange)?
  → ViewModifier ✅ (rõ ràng hơn)
  → Extension cũng được nhưng ViewModifier organize tốt hơn
```

---

## 11. Design System — Tổ chức ViewModifiers trong production

### Cấu trúc thư mục

```
Modifiers/
├── Appearance/
│   ├── CardModifier.swift
│   ├── ElevatedModifier.swift
│   └── GlassModifier.swift
├── Input/
│   ├── ClearableFieldModifier.swift
│   ├── CharacterCountModifier.swift
│   └── ValidationModifier.swift
├── Feedback/
│   ├── ShakeModifier.swift
│   ├── PulseGlowModifier.swift
│   └── LoadingOverlayModifier.swift
├── Layout/
│   ├── ConditionalFrameModifier.swift
│   └── ResponsiveModifier.swift
└── Utility/
    ├── TrackScreenModifier.swift
    ├── AutoRefreshModifier.swift
    └── ErrorBannerModifier.swift
```

### Ví dụ design system hoàn chỉnh

```swift
// MARK: - Design Tokens
enum DS {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
    }
}

// MARK: - Modifiers
struct DSCard: ViewModifier {
    enum Elevation { case flat, raised, floating }
    let elevation: Elevation
    
    func body(content: Content) -> some View {
        content
            .padding(DS.Spacing.md)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                y: shadowY
            )
    }
    
    private var shadowColor: Color {
        switch elevation {
        case .flat: .clear
        case .raised: .black.opacity(0.08)
        case .floating: .black.opacity(0.15)
        }
    }
    private var shadowRadius: CGFloat {
        switch elevation {
        case .flat: 0
        case .raised: 8
        case .floating: 20
        }
    }
    private var shadowY: CGFloat {
        switch elevation {
        case .flat: 0
        case .raised: 4
        case .floating: 10
        }
    }
}

struct DSInputField: ViewModifier {
    @FocusState.Binding var isFocused: Bool
    let hasError: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(DS.Spacing.md)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )
            .animation(.easeOut(duration: 0.15), value: isFocused)
            .animation(.easeOut(duration: 0.15), value: hasError)
    }
    
    private var borderColor: Color {
        if hasError { return .red }
        if isFocused { return .accentColor }
        return .clear
    }
}

// MARK: - Extensions
extension View {
    func dsCard(_ elevation: DSCard.Elevation = .raised) -> some View {
        modifier(DSCard(elevation: elevation))
    }
    
    func dsInputField(isFocused: FocusState<Bool>.Binding, hasError: Bool = false) -> some View {
        modifier(DSInputField(isFocused: isFocused, hasError: hasError))
    }
}

// MARK: - Usage
struct CheckoutView: View {
    @FocusState private var focusedField: Field?
    @State private var cardNumber = ""
    @State private var errors: Set<Field> = []
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Order summary card
            OrderSummary(items: cart.items)
                .dsCard(.raised)
            
            // Input fields
            TextField("Card Number", text: $cardNumber)
                .dsInputField(
                    isFocused: $focusedField.equals(.cardNumber),
                    hasError: errors.contains(.cardNumber)
                )
            
            // Pay button
            Button("Pay \(cart.total, format: .currency(code: "USD"))") {
                processPayment()
            }
            .primaryButton()
        }
        .padding(DS.Spacing.md)
        .loadingOverlay(isProcessing)
        .errorBanner(paymentError)
    }
}
```

---

## 12. Sai lầm thường gặp

### ❌ @State trong Extension (không hoạt động)

```swift
// ❌ Extension KHÔNG THỂ có @State
extension View {
    func shake(trigger: Bool) -> some View {
        @State var offset: CGFloat = 0    // ❌ Compile error
        return self.offset(x: offset)
    }
}

// ✅ Dùng ViewModifier
struct ShakeEffect: ViewModifier {
    @State private var offset: CGFloat = 0    // ✅
    // ...
}
```

### ❌ Modifier tạo view tree khác nhau theo condition

```swift
// ❌ Conditional trả type khác → view identity thay đổi → state reset
struct BadModifier: ViewModifier {
    let isSpecial: Bool
    
    func body(content: Content) -> some View {
        if isSpecial {
            content.bold().foregroundStyle(.red)    // type A
        } else {
            content                                  // type B
        }
        // Hai nhánh khác type → SwiftUI destroy/recreate view
    }
}

// ✅ Dùng giá trị dynamic → cùng view tree
struct GoodModifier: ViewModifier {
    let isSpecial: Bool
    
    func body(content: Content) -> some View {
        content
            .fontWeight(isSpecial ? .bold : .regular)
            .foregroundStyle(isSpecial ? .red : .primary)
        // Cùng view tree dù isSpecial true/false
    }
}
```

### ❌ Quên tạo Extension → gọi .modifier() dài dòng

```swift
// ❌ Không có extension → cú pháp xấu
Text("Hi")
    .modifier(ElevatedCard(cornerRadius: 12, shadow: 8))
    .modifier(ShakeEffect(trigger: hasError))
    .modifier(LoadingOverlay(isLoading: isLoading))

// ✅ Có extension → đọc tự nhiên
Text("Hi")
    .elevatedCard(cornerRadius: 12)
    .shake(trigger: hasError)
    .loadingOverlay(isLoading)
```

### ❌ Modifier quá lớn — nên tách

```swift
// ❌ Modifier làm quá nhiều việc
struct EverythingModifier: ViewModifier {
    // padding, background, shadow, animation, loading, error, analytics...
    // → Khó test, khó maintain
}

// ✅ Tách thành nhiều modifier nhỏ, compose
Text("Hello")
    .cardStyle()              // appearance
    .shake(trigger: error)    // animation
    .loadingOverlay(loading)  // loading state
    .trackScreen("Home")      // analytics
// Mỗi modifier làm 1 việc → dễ test, dễ tái sử dụng
```

---

## 13. Tóm tắt

| Khía cạnh | Chi tiết |
|---|---|
| **Là gì?** | Protocol đóng gói chuỗi modifier thành unit tái sử dụng |
| **Yêu cầu** | 1 method: `body(content:) -> some View` |
| **`Content`** | Placeholder cho view gốc (bất kỳ view nào) |
| **Có @State?** | ✅ (Extension không thể) |
| **Có @Binding?** | ✅ |
| **Có @Environment?** | ✅ |
| **Thêm views?** | ✅ (ZStack, overlay, banner...) |
| **Extension method** | Convention: luôn tạo extension cho cú pháp `.myModifier()` |
| **vs Extension** | Extension: chain modifier đơn giản. ViewModifier: cần state/binding/views |
| **Best practice** | Single responsibility, tạo extension, compose nhiều modifier nhỏ |
| **Dùng khi** | Design system, reusable styling, animation, loading/error overlay, analytics |

----

`ViewModifier` là cách đóng gói biến đổi View thành unit tái sử dụng, Huy. Ba điểm cốt lõi:

**Protocol chỉ yêu cầu 1 method:** `body(content:) -> some View`. `content` là placeholder cho view gốc — modifier không biết đó là Text, Button hay Image, chỉ nhận vào và trả về view mới đã biến đổi. Có thể chain modifier lên content, wrap trong ZStack, thêm overlay, banner — bất kỳ biến đổi nào.

**Sức mạnh thực sự: `@State`, `@Binding`, `@Environment` bên trong ViewModifier.** Đây là điều Extension method **không thể làm**. Shake animation cần `@State` offset, clearable field cần `@Binding` text, adaptive card cần `@Environment(\.colorScheme)`. Quy tắc chọn: chỉ chain modifier sẵn → Extension đủ. Cần state/binding/environment hoặc thêm views bao quanh → ViewModifier bắt buộc.

**Convention: luôn tạo Extension method.** `.modifier(ShakeEffect(trigger: hasError))` dài dòng và khác biệt với built-in modifier. Tạo extension `func shake(trigger:) -> some View` → gọi `.shake(trigger: hasError)` tự nhiên, đọc giống built-in. Production code tổ chức thành design system: mỗi modifier làm 1 việc (single responsibility), compose nhiều modifier nhỏ thay vì 1 modifier khổng lồ, nhóm theo mục đích (Appearance, Input, Feedback, Utility).
