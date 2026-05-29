# SwiftUI: View Modifiers — Giải thích chi tiết

## 1. Bản chất — Biến đổi View thành View mới

View Modifier là function/struct **nhận một View → trả về View MỚI** đã được thay đổi. Mỗi modifier không mutate view gốc — nó **wrap** view gốc bên trong view mới với thuộc tính bổ sung.

```swift
Text("Hello")                    // View gốc: Text
    .font(.title)                // → ModifiedContent<Text, _FontModifier>
    .foregroundStyle(.blue)      // → ModifiedContent<ModifiedContent<...>, _ForegroundStyleModifier>
    .padding()                   // → ModifiedContent<ModifiedContent<...>, _PaddingModifier>
```

Mỗi `.modifier()` tạo một **lớp wrapper mới** — giống matryoshka (búp bê Nga lồng nhau):

```
padding
  └── foregroundStyle(.blue)
        └── font(.title)
              └── Text("Hello")   ← view gốc ở trong cùng
```

---

## 2. THỨ TỰ QUAN TRỌNG — Modifier order thay đổi kết quả

Vì mỗi modifier wrap view trước đó, **thứ tự khác nhau → kết quả khác nhau**:

### Ví dụ: `padding` trước vs sau `background`

```swift
// padding TRƯỚC background
Text("Hello")
    .padding()              // 1. Thêm padding quanh Text
    .background(.blue)      // 2. Background phủ LÊN vùng đã padding
```

```
┌─── background (blue) ───────────┐
│ ┌─── padding ─────────────────┐ │
│ │                             │ │
│ │        Hello                │ │
│ │                             │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
  ↑ background phủ CẢ padding → vùng xanh LỚN
```

```swift
// background TRƯỚC padding
Text("Hello")
    .background(.blue)      // 1. Background chỉ phủ lên Text
    .padding()              // 2. Padding thêm quanh (background + Text)
```

```
┌─── padding (trong suốt) ───────┐
│ ┌─── background (blue) ──────┐ │
│ │        Hello               │ │
│ └────────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
  ↑ background chỉ phủ Text → vùng xanh NHỎ, padding trong suốt
```

### Ví dụ: `frame` trước vs sau `border`

```swift
// border TRƯỚC frame
Text("Hello")
    .border(.red)
    .frame(width: 200, height: 100)

// border bao quanh Text (nhỏ), frame mở rộng KHÔNG có border

// frame TRƯỚC border
Text("Hello")
    .frame(width: 200, height: 100)
    .border(.red)

// frame mở rộng trước, border bao quanh frame (lớn)
```

### Quy tắc ghi nhớ

```
Đọc modifier chain TỪ TRÊN XUỐNG:
  Modifier ở TRÊN → áp dụng TRƯỚC (gần view gốc hơn)
  Modifier ở DƯỚI → áp dụng SAU (wrap bên ngoài)

Mỗi modifier "thấy" view mà modifier TRƯỚC đó tạo ra,
KHÔNG thấy view gốc ban đầu.
```

---

## 3. Phân loại View Modifiers

### 3.1 Layout Modifiers — Kích thước & Vị trí

```swift
Text("Hello")
    .frame(width: 200, height: 50)          // kích thước cố định
    .frame(maxWidth: .infinity)              // mở rộng hết chiều ngang
    .frame(minHeight: 44)                    // chiều cao tối thiểu
    .padding()                               // padding đều 4 cạnh (16pt mặc định)
    .padding(.horizontal, 20)               // padding trái/phải 20pt
    .padding(.top, 8)                        // padding trên 8pt
    .offset(x: 10, y: -5)                   // dịch chuyển
    .position(x: 100, y: 200)               // vị trí tuyệt đối trong parent
    .edgesIgnoringSafeArea(.all)             // bỏ qua safe area
    .layoutPriority(1)                       // ưu tiên layout cao hơn
```

### 3.2 Appearance Modifiers — Giao diện

```swift
Text("Hello")
    .font(.title)                            // font
    .fontWeight(.bold)                       // weight
    .foregroundStyle(.blue)                  // màu text/icon
    .background(.yellow)                     // màu nền
    .background(.ultraThinMaterial)          // blur material
    .opacity(0.5)                            // độ trong suốt
    .cornerRadius(12)                        // bo góc (deprecated, dùng clipShape)
    .clipShape(RoundedRectangle(cornerRadius: 12))  // clip theo shape
    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
    .border(Color.gray, width: 1)            // viền
    .overlay { Badge() }                     // view phủ lên trên
    .tint(.purple)                           // accent color
```

### 3.3 Text-specific Modifiers

```swift
Text("Hello World")
    .bold()                                  // in đậm
    .italic()                                // in nghiêng
    .underline()                             // gạch chân
    .strikethrough()                         // gạch ngang
    .lineLimit(2)                            // tối đa 2 dòng
    .multilineTextAlignment(.center)         // căn giữa
    .truncationMode(.tail)                   // cắt đuôi "..."
    .textCase(.uppercase)                    // chữ hoa
    .kerning(2)                              // khoảng cách ký tự
    .baselineOffset(5)                       // dịch baseline
    .minimumScaleFactor(0.5)                 // thu nhỏ font tối thiểu 50%
```

### 3.4 Interaction Modifiers

```swift
Button("Tap") { }
    .disabled(isLoading)                     // vô hiệu hoá
    .allowsHitTesting(false)                 // bỏ qua touch

Text("Hello")
    .onTapGesture { print("Tapped") }       // tap
    .onLongPressGesture { print("Long") }   // long press
    .gesture(DragGesture().onChanged { ... })// custom gesture
    .contextMenu { MenuItem() }              // context menu
    .swipeActions { Button("Delete") { } }   // swipe actions (List)
```

### 3.5 Navigation & Presentation Modifiers

```swift
view
    .navigationTitle("Home")                 // tiêu đề navigation
    .navigationBarTitleDisplayMode(.large)    // display mode
    .toolbar { ToolbarItem { Button(...) } } // toolbar items
    .sheet(isPresented: $show) { SheetView() }
    .fullScreenCover(item: $item) { DetailView(item: $0) }
    .alert("Error", isPresented: $showAlert) { Button("OK") { } }
    .confirmationDialog("Choose", isPresented: $showDialog) { ... }
    .popover(isPresented: $showPopover) { PopoverContent() }
```

### 3.6 Animation Modifiers

```swift
view
    .animation(.spring, value: isExpanded)   // animate khi value đổi
    .transition(.slide)                       // transition insert/remove
    .scaleEffect(isPressed ? 0.95 : 1.0)    // scale
    .rotationEffect(.degrees(45))            // xoay
    .rotation3DEffect(.degrees(60), axis: (x: 1, y: 0, z: 0))
    .matchedGeometryEffect(id: "hero", in: namespace)  // hero animation
```

### 3.7 State & Data Flow Modifiers

```swift
view
    .onAppear { loadData() }                 // view xuất hiện
    .onDisappear { cleanup() }               // view biến mất
    .task { await fetchData() }              // async task (cancel khi disappear)
    .onChange(of: selection) { old, new in }  // value thay đổi
    .onReceive(timer) { date in }            // nhận Combine publisher
    .environment(\.colorScheme, .dark)        // inject environment
    .environmentObject(viewModel)             // inject object
    .focused($focusedField, equals: .email)  // focus state
    .id(refreshID)                            // identity
```

### 3.8 Accessibility Modifiers

```swift
view
    .accessibilityLabel("Play button")       // label cho VoiceOver
    .accessibilityHint("Double tap to play") // hint
    .accessibilityValue("50%")               // value
    .accessibilityHidden(true)               // ẩn khỏi accessibility
    .accessibilityAddTraits(.isButton)       // trait
```

---

## 4. Cách hoạt động bên trong — `ModifiedContent`

Mỗi modifier tạo `ModifiedContent<Content, Modifier>`:

```swift
// Khi viết:
Text("Hi").bold().padding()

// Compiler thấy:
ModifiedContent<
    ModifiedContent<Text, _BoldModifier>,
    _PaddingLayout
>
```

Đó là lý do return type phức tạp → dùng `some View` để giấu:

```swift
var body: some View {
    Text("Hi")
        .bold()
        .padding()
    // Compiler suy ra concrete type nhưng giấu đi
}
```

---

## 5. Custom View Modifier — Tạo modifier riêng

### 5.1 `ViewModifier` Protocol

```swift
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// Sử dụng:
Text("Card content")
    .modifier(CardModifier())
```

### 5.2 Extension cho cú pháp gọn

```swift
extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// Giờ gọi tự nhiên:
Text("Card content")
    .cardStyle()
```

### 5.3 Modifier với parameters

```swift
struct RoundedBorderModifier: ViewModifier {
    let color: Color
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    
    func body(content: Content) -> some View {
        content
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color, lineWidth: lineWidth)
            )
    }
}

extension View {
    func roundedBorder(
        color: Color = .gray,
        cornerRadius: CGFloat = 8,
        lineWidth: CGFloat = 1
    ) -> some View {
        modifier(RoundedBorderModifier(
            color: color,
            cornerRadius: cornerRadius,
            lineWidth: lineWidth
        ))
    }
}

// Sử dụng:
TextField("Email", text: $email)
    .roundedBorder(color: .blue, cornerRadius: 12)
```

### 5.4 Modifier với State

ViewModifier có thể **chứa @State** — mỗi view áp dụng modifier sẽ có state riêng:

```swift
struct ShakeModifier: ViewModifier {
    @State private var shakeOffset: CGFloat = 0
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: trigger) { _, _ in
                withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
                    shakeOffset = 10
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    shakeOffset = 0
                }
            }
    }
}

extension View {
    func shake(trigger: Bool) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}

// Sử dụng:
TextField("Password", text: $password)
    .shake(trigger: hasError)
```

### 5.5 Modifier với Binding

```swift
struct ClearableModifier: ViewModifier {
    @Binding var text: String
    
    func body(content: Content) -> some View {
        HStack {
            content
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                }
            }
        }
    }
}

extension View {
    func clearable(text: Binding<String>) -> some View {
        modifier(ClearableModifier(text: text))
    }
}

TextField("Search", text: $query)
    .clearable(text: $query)
```

### 5.6 Modifier với Environment

```swift
struct ThemedModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.1),
                radius: 8
            )
    }
}
```

---

## 6. ViewModifier vs View Extension — Khi nào dùng cái nào

### Extension method đơn giản (không cần ViewModifier)

```swift
// Khi chỉ chain các modifier có sẵn, không cần state
extension View {
    func primaryButtonStyle() -> some View {
        self
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.blue)
            .clipShape(Capsule())
    }
}

Button("Submit") { }
    .primaryButtonStyle()
```

### ViewModifier (cần khi có state, binding, environment, hoặc logic phức tạp)

```swift
// Khi cần @State, @Binding, @Environment, hoặc event handling
struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

extension View {
    func loadingOverlay(_ isLoading: Bool) -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading))
    }
}

// Sử dụng:
ContentView()
    .loadingOverlay(viewModel.isLoading)
```

### Quy tắc chọn

```
Chỉ chain modifier sẵn, không state/binding/environment?
  → Extension method ✅ (gọn hơn)

Cần @State, @Binding, @Environment, hoặc logic phức tạp?
  → ViewModifier protocol ✅ (mạnh hơn)
```

---

## 7. Conditional Modifier — Áp dụng có điều kiện

### ⚠️ Cách SAI thường thấy

```swift
// ❌ Anti-pattern: if/else trong modifier chain
extension View {
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

Text("Hello")
    .if(isHighlighted) { $0.foregroundStyle(.red) }
// ⚠️ Hai nhánh trả về TYPE KHÁC NHAU
// → SwiftUI không thể diff → destroy + recreate view
// → Mất state (text input, scroll position, animation)
```

### ✅ Cách đúng: dùng giá trị dynamic

```swift
// ✅ Dùng ternary trong modifier value
Text("Hello")
    .foregroundStyle(isHighlighted ? .red : .primary)
    .fontWeight(isBold ? .bold : .regular)
    .opacity(isVisible ? 1.0 : 0.0)
    .scaleEffect(isPressed ? 0.95 : 1.0)

// ✅ Dùng optional value
Text("Hello")
    .background(backgroundColor ?? .clear)

// ✅ Modifier bên trong mà tự handle condition
struct ConditionalBorderModifier: ViewModifier {
    let isActive: Bool
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? color : .clear, lineWidth: isActive ? 2 : 0)
            )
    }
}
// → Cùng view tree dù isActive true/false → giữ state
```

---

## 8. Ví dụ thực tế — Design System với Modifiers

### Định nghĩa design tokens

```swift
// MARK: - Design Tokens
enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

// MARK: - Reusable Modifiers
struct InputFieldModifier: ViewModifier {
    @FocusState.Binding var isFocused: Bool
    let hasError: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.md)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )
            .animation(.easeInOut(duration: 0.15), value: isFocused)
            .animation(.easeInOut(duration: 0.15), value: hasError)
    }
    
    private var borderColor: Color {
        if hasError { return .red }
        if isFocused { return .blue }
        return Color(.systemGray4)
    }
}

struct SectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(0.5)
    }
}

struct PrimaryButtonModifier: ViewModifier {
    let isEnabled: Bool
    
    func body(content: Content) -> some View {
        content
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isEnabled ? .blue : .gray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Extensions
extension View {
    func inputFieldStyle(isFocused: FocusState<Bool>.Binding, hasError: Bool = false) -> some View {
        modifier(InputFieldModifier(isFocused: isFocused, hasError: hasError))
    }
    
    func sectionHeader() -> some View {
        modifier(SectionHeaderModifier())
    }
    
    func primaryButton(isEnabled: Bool = true) -> some View {
        modifier(PrimaryButtonModifier(isEnabled: isEnabled))
    }
}
```

### Sử dụng

```swift
struct SignUpView: View {
    enum Field: Hashable { case name, email, password }
    
    @FocusState private var focusedField: Field?
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errors: Set<Field> = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Account Details")
                    .sectionHeader()
                
                TextField("Full Name", text: $name)
                    .focused($focusedField, equals: .name)
                    .inputFieldStyle(
                        isFocused: $focusedField.equals(.name),
                        hasError: errors.contains(.name)
                    )
                
                TextField("Email", text: $email)
                    .focused($focusedField, equals: .email)
                    .keyboardType(.emailAddress)
                    .inputFieldStyle(
                        isFocused: $focusedField.equals(.email),
                        hasError: errors.contains(.email)
                    )
                
                SecureField("Password", text: $password)
                    .focused($focusedField, equals: .password)
                    .inputFieldStyle(
                        isFocused: $focusedField.equals(.password),
                        hasError: errors.contains(.password)
                    )
                
                Button("Create Account") { submit() }
                    .primaryButton(isEnabled: isFormValid)
            }
            .padding(AppSpacing.lg)
        }
    }
}
```

---

## 9. Sai lầm thường gặp

### ❌ Không hiểu modifier order

```swift
// ❌ Padding TRONG background → padding không có màu nền
Text("Hello")
    .background(.blue)
    .padding(20)
// Vùng padding 20pt xung quanh TRONG SUỐT

// ✅ Padding TRƯỚC background → cả vùng padding có nền xanh
Text("Hello")
    .padding(20)
    .background(.blue)
```

### ❌ Frame sau modifier giao diện

```swift
// ❌ clipShape trước frame → clip chỉ ảnh hưởng content nhỏ
Image("photo")
    .clipShape(Circle())
    .frame(width: 200, height: 200)

// ✅ frame trước → resize xong rồi clip
Image("photo")
    .resizable()
    .frame(width: 200, height: 200)
    .clipShape(Circle())
```

### ❌ Quá nhiều modifier lặp lại → cần extract

```swift
// ❌ Copy-paste modifier stack
TextField("Name", text: $name)
    .padding()
    .background(.white)
    .cornerRadius(8)
    .shadow(radius: 2)

TextField("Email", text: $email)
    .padding()
    .background(.white)
    .cornerRadius(8)
    .shadow(radius: 2)

// ✅ Extract thành custom modifier
TextField("Name", text: $name).inputStyle()
TextField("Email", text: $email).inputStyle()
```

### ❌ Conditional modifier phá view identity

```swift
// ❌ if/else tạo view tree khác → reset state
if isSpecial {
    text.bold().foregroundStyle(.red)
} else {
    text
}

// ✅ Giá trị dynamic → cùng view tree
text
    .fontWeight(isSpecial ? .bold : .regular)
    .foregroundStyle(isSpecial ? .red : .primary)
```

---

## 10. Tóm tắt

| Khía cạnh | Chi tiết |
|---|---|
| **Là gì?** | Function/struct nhận View → trả View MỚI đã biến đổi |
| **Cơ chế** | Wrap view gốc trong `ModifiedContent` — lồng nhau từ trong ra ngoài |
| **Thứ tự** | **QUAN TRỌNG** — modifier trên áp dụng trước, dưới wrap bên ngoài |
| **Built-in** | Layout, Appearance, Text, Interaction, Navigation, Animation, State, Accessibility |
| **Custom** | `ViewModifier` protocol + extension method |
| **Extension vs ViewModifier** | Extension: chain modifier đơn giản. ViewModifier: cần state/binding/environment |
| **Conditional** | Dùng giá trị dynamic trong modifier (ternary), KHÔNG dùng if/else wrap view |
| **Best practice** | Extract modifier lặp, hiểu thứ tự, dùng design system |

-----

View Modifiers là nền tảng cú pháp của SwiftUI — gần như mọi dòng code đều dùng modifiers, Huy. Ba điểm cốt lõi:

**Modifier wrap chứ không mutate.** Mỗi `.modifier()` tạo **view MỚI** bọc quanh view trước đó (`ModifiedContent<Content, Modifier>`). Lồng nhau từ trong ra ngoài giống búp bê Nga. Đây là lý do **thứ tự modifier cực kỳ quan trọng**: `.padding().background(.blue)` (padding có nền xanh) khác hoàn toàn `.background(.blue).padding()` (nền xanh nhỏ, padding trong suốt). Quy tắc: đọc từ trên xuống — modifier trên áp dụng trước (gần view gốc), modifier dưới wrap bên ngoài.

**Custom ViewModifier cho code reusable.** Hai cách: Extension method đơn giản khi chỉ chain modifier sẵn. `ViewModifier` protocol khi cần `@State`, `@Binding`, `@Environment`, hoặc logic phức tạp (shake animation, loading overlay, themed styling). Pattern production: tạo design system với modifier tokens (`inputFieldStyle()`, `primaryButton()`, `sectionHeader()`) → nhất quán UI, giảm duplicate code.

**Conditional modifier — sai lầm phổ biến nhất.** Pattern `if condition { view.bold() } else { view }` tạo **hai view tree khác nhau** → SwiftUI destroy + recreate view → mất state (text input, scroll, animation). Cách đúng: dùng giá trị dynamic trong modifier (`.fontWeight(isBold ? .bold : .regular)`, `.opacity(isVisible ? 1 : 0)`) → cùng view tree dù giá trị thay đổi → giữ state.
