//
//  CustomTransitionPlayground.swift
//  Thực hành custom Transition (protocol Transition, iOS 17+)
//
//  Cách dùng: tạo iOS App (SwiftUI), dán toàn bộ file này vào,
//  rồi đổi body của app thành:
//
//      var body: some View { CustomTransitionPlayground() }
//
//  Yêu cầu: iOS 17+ (protocol `Transition` và `TransitionPhase`).
//

import SwiftUI

// =====================================================================
// MARK: - 1. Hiểu về TransitionPhase
// =====================================================================
//
// Protocol `Transition` yêu cầu 1 hàm:
//     func body(content: Content, phase: TransitionPhase) -> some View
//
// `phase` có 3 trạng thái:
//   .willAppear    -> view SẮP xuất hiện (trạng thái đầu của insertion)
//   .identity      -> view HIỂN THỊ bình thường (phase.isIdentity == true)
//   .didDisappear  -> view ĐÃ biến mất  (trạng thái cuối của removal)
//
// SwiftUI nội suy giữa các phase. Mẹo đọc code:
//   phase.isIdentity == true  => giá trị lúc view hiển thị đầy đủ
//   phase.isIdentity == false => giá trị lúc view "vắng mặt"
//
// Bạn cũng có thể phân biệt insertion vs removal bằng chính phase,
// điều mà .modifier(active:identity:) cũ không làm được gọn.


// =====================================================================
// MARK: - 2. Các custom Transition
// =====================================================================

/// Ví dụ gốc trong đề bài: xoay 360° + scale từ 0.
struct RotateScaleTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .rotationEffect(.degrees(phase.isIdentity ? 0 : -360))
            .scaleEffect(phase.isIdentity ? 1 : 0)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

/// Blur + scale nhẹ: view mờ và hơi thu lại khi vắng mặt.
struct BlurScaleTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .blur(radius: phase.isIdentity ? 0 : 20)
            .scaleEffect(phase.isIdentity ? 1 : 0.6)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

/// Phân biệt insertion vs removal NGAY trong 1 struct.
/// Đây là ưu điểm lớn nhất của protocol so với AnyTransition.asymmetric:
/// bạn dùng chính `phase` để rẽ nhánh.
struct DirectionalTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .offset(x: xOffset(for: phase))
            .opacity(phase.isIdentity ? 1 : 0)
    }

    private func xOffset(for phase: TransitionPhase) -> CGFloat {
        switch phase {
        case .willAppear:   return -300   // insertion: bắt đầu từ bên TRÁI
        case .identity:     return 0      // hiển thị: đúng vị trí
        case .didDisappear: return 300    // removal: kết thúc ở bên PHẢI
        @unknown default:   return 0
        }
    }
}

/// Transition có THAM SỐ — làm cho custom transition tái sử dụng được.
struct FlipTransition: Transition {
    var axis: (x: CGFloat, y: CGFloat, z: CGFloat)

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .rotation3DEffect(
                .degrees(phase.isIdentity ? 0 : 90),
                axis: axis
            )
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

/// Kết hợp nhiều hiệu ứng + dùng value ngoài phase.isIdentity.
/// Ở đây removal và insertion có scale khác nhau nhờ đọc phase cụ thể.
struct PopTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(scale(for: phase))
            .rotationEffect(.degrees(phase.isIdentity ? 0 : 15))
            .opacity(phase.isIdentity ? 1 : 0)
    }

    private func scale(for phase: TransitionPhase) -> CGFloat {
        switch phase {
        case .willAppear:   return 0.3   // vào: bung ra từ nhỏ
        case .identity:     return 1
        case .didDisappear: return 1.4   // ra: phồng to rồi biến mất
        @unknown default:   return 1
        }
    }
}


// =====================================================================
// MARK: - 3. Cách gọi custom Transition — 3 kiểu cú pháp
// =====================================================================
//
// (a) Trực tiếp:            .transition(RotateScaleTransition())
// (b) Qua extension tĩnh:   .transition(.rotateScale)
// (c) Có tham số:           .transition(.flip(axis: .vertical))
//
// (b) và (c) chỉ khả dụng khi bạn viết extension dưới đây.

extension Transition where Self == RotateScaleTransition {
    static var rotateScale: RotateScaleTransition { .init() }
}

extension Transition where Self == BlurScaleTransition {
    static var blurScale: BlurScaleTransition { .init() }
}

extension Transition where Self == DirectionalTransition {
    static var directional: DirectionalTransition { .init() }
}

extension Transition where Self == PopTransition {
    static var pop: PopTransition { .init() }
}

extension Transition where Self == FlipTransition {
    /// Flip quanh trục dọc (mặc định) hoặc ngang.
    static func flip(vertical: Bool = true) -> FlipTransition {
        FlipTransition(axis: vertical ? (0, 1, 0) : (1, 0, 0))
    }
}


// =====================================================================
// MARK: - 4. Model danh sách ví dụ
// =====================================================================

enum CustomKind: String, CaseIterable, Identifiable {
    case rotateScale = "RotateScale (đề bài)"
    case blurScale   = "BlurScale"
    case directional = "Directional (vào trái · ra phải)"
    case flipV       = "Flip 3D (trục dọc)"
    case flipH       = "Flip 3D (trục ngang)"
    case pop         = "Pop (scale khác chiều)"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .rotateScale: return "rotationEffect(-360) + scaleEffect(0)"
        case .blurScale:   return "blur(20) + scaleEffect(0.6)"
        case .directional: return "dùng phase để đổi hướng vào/ra"
        case .flipV:       return "rotation3DEffect quanh trục Y, có tham số"
        case .flipH:       return "rotation3DEffect quanh trục X"
        case .pop:         return "willAppear 0.3 · didDisappear 1.4"
        }
    }

    /// Trả về view đã gắn transition tương ứng.
    @ViewBuilder
    func card(_ card: DemoCard) -> some View {
        switch self {
        case .rotateScale: card.transition(.rotateScale)
        case .blurScale:   card.transition(.blurScale)
        case .directional: card.transition(.directional)
        case .flipV:       card.transition(.flip(vertical: true))
        case .flipH:       card.transition(.flip(vertical: false))
        case .pop:         card.transition(.pop)
        }
    }
}


// =====================================================================
// MARK: - 5. View cha + màn demo
// =====================================================================

struct CustomTransitionPlayground: View {
    var body: some View {
        NavigationStack {
            List(CustomKind.allCases) { kind in
                NavigationLink(value: kind) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.rawValue).font(.headline)
                        Text(kind.subtitle)
                            .font(.caption).monospaced()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Custom Transition")
            .navigationDestination(for: CustomKind.self) { kind in
                CustomDemoView(kind: kind)
            }
        }
    }
}

struct CustomDemoView: View {
    let kind: CustomKind
    @State private var isShown = false

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [6]))

                if isShown {
                    kind.card(DemoCard(title: kind.rawValue))
                }
            }
            .frame(height: 300)
            .clipped()
            .padding(.horizontal)

            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        isShown = true
                    }
                } label: {
                    Label("Hiện", systemImage: "eye")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isShown)

                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        isShown = false
                    }
                } label: {
                    Label("Ẩn", systemImage: "eye.slash")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .disabled(!isShown)
            }
            .padding(.horizontal)

            Text(kind.subtitle)
                .font(.footnote).monospaced()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.top, 24)
        .navigationTitle("Custom")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isShown = true
            }
        }
    }
}

// View mẫu tách riêng để dùng lại (transition áp lên chính nó).
struct DemoCard: View {
    let title: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 44, weight: .semibold))
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .frame(width: 220, height: 220)
        .background(
            LinearGradient(colors: [.indigo, .teal],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }
}

// MARK: - Preview

#Preview {
    CustomTransitionPlayground()
}
