## Migrate UIKit → SwiftUI với sự hỗ trợ của LLM — Chi tiết cho Senior iOS Developer

### 1. Tại sao migration này phức tạp?

UIKit và SwiftUI có **triết lý hoàn toàn khác nhau**: UIKit là imperative (bạn nói *cách* làm), SwiftUI là declarative (bạn nói *muốn gì*). Không phải cứ dịch 1:1 từng dòng code là xong — nhiều pattern trong UIKit không có equivalent trực tiếp trong SwiftUI, và ngược lại. Đây là lý do LLM rất hữu ích nhưng cũng rất nguy hiểm nếu không review kỹ.

### 2. Chiến lược migration tổng thể

Không ai migrate cả app một lần. Chiến lược phổ biến nhất là **Strangler Fig Pattern** — bọc UIKit trong SwiftUI (hoặc ngược lại) rồi thay thế dần:

```
Phase 1: Embed SwiftUI views trong UIKit host (UIHostingController)
Phase 2: Migrate từng screen/component, bắt đầu từ leaf views
Phase 3: Migrate navigation layer (phức tạp nhất)
Phase 4: Loại bỏ UIKit hoàn toàn (nếu cần)
```

### 3. Ví dụ cụ thể: Migrate một UIKit component

Giả sử bạn có một **ProfileHeaderView** trong UIKit:

```swift
// UIKit - ProfileHeaderView.swift
final class ProfileHeaderView: UIView {
    
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 40
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let bioLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let followButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Follow", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 20
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private var isFollowing = false
    var onFollowTapped: ((Bool) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        followButton.addTarget(self, action: #selector(followTapped), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(name: String, bio: String, avatarURL: URL?, isFollowing: Bool) {
        nameLabel.text = name
        bioLabel.text = bio
        self.isFollowing = isFollowing
        updateFollowButton()
        // Load image with Kingfisher/SDWebImage...
    }
    
    @objc private func followTapped() {
        isFollowing.toggle()
        updateFollowButton()
        onFollowTapped?(isFollowing)
    }
    
    private func updateFollowButton() {
        followButton.setTitle(isFollowing ? "Following" : "Follow", for: .normal)
        followButton.backgroundColor = isFollowing ? .systemGray5 : .systemBlue
        followButton.setTitleColor(isFollowing ? .label : .white, for: .normal)
    }
    
    private func setupViews() {
        addSubview(avatarImageView)
        addSubview(nameLabel)
        addSubview(bioLabel)
        addSubview(followButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            avatarImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            avatarImageView.widthAnchor.constraint(equalToConstant: 80),
            avatarImageView.heightAnchor.constraint(equalToConstant: 80),
            
            nameLabel.topAnchor.constraint(equalTo: avatarImageView.topAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            bioLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            bioLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            bioLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            
            followButton.topAnchor.constraint(equalTo: bioLabel.bottomAnchor, constant: 12),
            followButton.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            followButton.widthAnchor.constraint(equalToConstant: 120),
            followButton.heightAnchor.constraint(equalToConstant: 40),
            followButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
}
```

### 4. Bước 1 — Đưa cho LLM kèm context đầy đủ

Đây là chỗ senior dev khác junior. Bạn không chỉ paste code rồi nói "convert sang SwiftUI". Bạn cung cấp **prompt có context**:

```
Convert this UIKit ProfileHeaderView to SwiftUI.

Requirements:
- Target iOS 16+ (can use NavigationStack, modern APIs)
- Use AsyncImage for avatar loading (no third-party)
- Follow button state should be managed by the parent 
  via @Binding
- Use SwiftUI animation for follow button state change
- Keep accessibility support (VoiceOver labels)
- The component should be preview-able with mock data

Here is the UIKit code:
[paste code ở trên]
```

### 5. Bước 2 — LLM output (ví dụ điển hình)

LLM sẽ trả về một thứ kiểu như:

```swift
// SwiftUI - ProfileHeaderView.swift (LLM generated)
struct ProfileHeaderView: View {
    let name: String
    let bio: String
    let avatarURL: URL?
    @Binding var isFollowing: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                case .empty:
                    ProgressView()
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text(bio)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFollowing.toggle()
                    }
                } label: {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 120, height: 40)
                        .foregroundStyle(isFollowing ? .primary : .white)
                        .background(isFollowing ? Color(.systemGray5) : .blue)
                        .clipShape(Capsule())
                }
                .accessibilityLabel(isFollowing ? "Unfollow \(name)" : "Follow \(name)")
            }
        }
        .padding(16)
    }
}

#Preview {
    @Previewable @State var isFollowing = false
    ProfileHeaderView(
        name: "John Doe",
        bio: "iOS Developer | SwiftUI enthusiast | Building cool stuff",
        avatarURL: URL(string: "https://example.com/avatar.jpg"),
        isFollowing: $isFollowing
    )
}
```

### 6. Bước 3 — Senior Review: Những gì LLM thường làm sai

Đây là phần quan trọng nhất. Bạn phải review với con mắt của senior dev:

**a) State ownership — LLM hay nhầm**

LLM có thể đặt `isFollowing` là `@State` thay vì `@Binding`. Trông thì chạy được trong Preview, nhưng khi embed vào real app, state sẽ không sync với parent. Senior dev phải quyết định: state này thuộc view này hay thuộc ViewModel/parent?

```swift
// ❌ LLM có thể generate — state bị cô lập
@State private var isFollowing: Bool

// ✅ Đúng — parent control state
@Binding var isFollowing: Bool

// ✅ Hoặc nếu dùng MVVM
@ObservedObject var viewModel: ProfileViewModel
// iOS 17+: @Bindable var viewModel: ProfileViewModel
```

**b) AsyncImage — thiếu caching**

LLM thường generate `AsyncImage` và coi như xong. Nhưng `AsyncImage` **không cache** image giữa các lần rerender. Nếu view này nằm trong List/ScrollView, mỗi lần scroll sẽ fetch lại. Senior dev biết cần evaluate:

```swift
// AsyncImage không cache — OK cho prototype, 
// không OK cho production list
// Cần custom CachedAsyncImage hoặc dùng 
// Kingfisher/Nuke cho SwiftUI
```

**c) Performance trong List**

Nếu ProfileHeaderView nằm trong `LazyVStack` hoặc `List`, LLM không tự optimize. Senior dev cần check:

```swift
// Nếu dùng trong List, cần đảm bảo Equatable 
// để SwiftUI không re-render khi không cần
struct ProfileHeaderView: View, Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name &&
        lhs.bio == rhs.bio &&
        lhs.isFollowing == rhs.isFollowing
    }
    // ...
}
```

**d) Callback pattern vs Binding**

UIKit dùng `onFollowTapped: ((Bool) -> Void)?` (closure callback). LLM có thể giữ pattern này trong SwiftUI. Nhưng senior dev biết rằng SwiftUI prefer `@Binding` hoặc action closure tùy context:

```swift
// Approach 1: Binding — khi parent own state
@Binding var isFollowing: Bool

// Approach 2: Action closure — khi cần side effect
let onFollowTapped: (Bool) -> Void

// Senior dev chọn dựa trên architecture:
// - MVVM: Binding to ViewModel's published property
// - TCA: Send action to store
// - Simple: Binding là đủ
```

**e) Layout differences — LLM không test edge case**

UIKit dùng Auto Layout constraints rõ ràng. SwiftUI dùng stack-based layout. LLM convert nhìn OK nhưng có thể break khi:

```swift
// LLM không test: bio text rất dài → 
// layout bị vỡ trên small screen?
// LLM không test: name + bio đều empty → 
// spacing có hợp lý không?
// LLM không test: Dynamic Type lớn → 
// HStack có nên chuyển thành VStack không?

// Senior dev thêm adaptive layout:
ViewThatFits {
    HStack(alignment: .top, spacing: 12) { content }
    VStack(spacing: 12) { content }  // fallback cho small screen
}
```

**f) Accessibility — LLM thường bỏ sót**

LLM có thể thêm `.accessibilityLabel` cơ bản nhưng bỏ qua:

```swift
// Thiếu: grouping elements cho VoiceOver
.accessibilityElement(children: .combine)

// Thiếu: accessibility action cho follow
.accessibilityAction(named: isFollowing ? "Unfollow" : "Follow") {
    isFollowing.toggle()
}

// Thiếu: dynamic type support test
// Thiếu: reduce motion preference
```

### 7. Bước 4 — Integration: embed SwiftUI vào UIKit host

Trong giai đoạn migration, bạn cần chạy song song. LLM generate được phần này nhưng thường thiếu edge case:

```swift
// Trong UIKit ViewController
let profileView = ProfileHeaderView(
    name: user.name,
    bio: user.bio,
    avatarURL: user.avatarURL,
    isFollowing: Binding(
        get: { [weak self] in self?.isFollowing ?? false },
        set: { [weak self] newValue in
            self?.isFollowing = newValue
            self?.viewModel.toggleFollow()  // sync với business logic
        }
    )
)

let hostingController = UIHostingController(rootView: profileView)
addChild(hostingController)
view.addSubview(hostingController.view)
hostingController.didMove(toParent: self)

// ⚠️ LLM thường quên:
// 1. Set hosting view background transparent
hostingController.view.backgroundColor = .clear
// 2. Disable safe area từ hosting controller
hostingController.safeAreaRegions = []  // iOS 16.4+
// 3. Invalidate intrinsic content size khi data thay đổi
hostingController.view.invalidateIntrinsicContentSize()
```

### 8. Checklist review cho Senior Dev sau khi LLM generate

Mỗi lần LLM convert một component, bạn chạy qua mental checklist:

| Hạng mục | Câu hỏi cần trả lời |
|---|---|
| **State** | Ai own state? `@State` vs `@Binding` vs `@Observable`? |
| **Lifecycle** | `onAppear`/`onDisappear`/`.task` đúng chưa? Có leak không? |
| **Performance** | Nằm trong List? Cần `Equatable`? `AsyncImage` có cache? |
| **Navigation** | Deep link có hoạt động? Back button behavior đúng? |
| **Accessibility** | VoiceOver flow hợp lý? Dynamic Type? Reduce Motion? |
| **Edge cases** | Empty state, error state, rất dài/rất ngắn? RTL language? |
| **Architecture fit** | Component có fit vào architecture hiện tại (MVVM/TCA)? |
| **iOS version** | API nào require iOS 16/17? Có cần `if #available`? |

### 9. Kết luận

Tóm lại, workflow thực tế là:

1. **Bạn quyết định** component nào migrate trước (leaf views → container views → navigation).
2. **LLM convert** syntax và layout — tiết kiệm 60-70% thời gian viết boilerplate.
3. **Bạn review** state management, performance, edge cases, architecture fit — đây là phần không thể thay thế.
4. **Bạn test** trên real device, accessibility audit, performance profile bằng Instruments.

LLM giỏi phần "dịch cú pháp" nhưng không hiểu **context của app bạn** — business logic, user flow, performance requirement, team convention. Đó là lý do cần senior dev ở bước review.
