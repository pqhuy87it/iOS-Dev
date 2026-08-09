//
//  CombinedTransitionPlayground.swift
//  Thực hành AnyTransition kết hợp .combined(with:) trong SwiftUI
//
//  Cách dùng: tạo iOS App (SwiftUI), dán toàn bộ file này vào,
//  rồi đổi body của app thành:
//
//      var body: some View { CombinedTransitionPlayground() }
//
//  Yêu cầu: iOS 16+.
//

import SwiftUI

// =====================================================================
// MARK: - 1. Các AnyTransition tùy biến bằng .combined(with:)
// =====================================================================
//
// .combined(with:) ghép NHIỀU transition chạy ĐỒNG THỜI.
// Ví dụ .scale.combined(with: .opacity) = vừa phóng vừa mờ cùng lúc.
//
// Kết hợp với .asymmetric để insertion và removal ghép hiệu ứng khác nhau
// — đúng như mẫu rotateAndFade trong đề bài.

// LƯU Ý: AnyTransition KHÔNG có member .rotationEffect (đó là view modifier,
// không phải transition dựng sẵn). Muốn xoay như một transition, ta bọc
// rotationEffect vào ViewModifier rồi biến thành AnyTransition qua
// .modifier(active:identity:) — đây chính là cơ chế nền của mọi transition.
struct RotationModifier: ViewModifier {
    let angle: Double
    func body(content: Content) -> some View {
        content.rotationEffect(.degrees(angle))
    }
}

extension AnyTransition {

    /// Transition xoay tự định nghĩa (thay cho .rotationEffect không tồn tại).
    /// active  = trạng thái trước-khi-vào / sau-khi-ra
    /// identity = trạng thái hiển thị bình thường
    static var rotate: AnyTransition {
        .modifier(
            active: RotationModifier(angle: 180),
            identity: RotationModifier(angle: 0)
        )
    }

    /// Mẫu đề bài: vào thì scale+fade, ra thì xoay 180°+fade.
    static var rotateAndFade: AnyTransition {
        let insertion = AnyTransition.scale
            .combined(with: .opacity)
        let removal = AnyTransition.rotate          // dùng .rotate tự định nghĩa
            .combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }

    /// Đối xứng: cùng một tổ hợp cho cả vào lẫn ra.
    /// Trượt từ dưới + phóng nhẹ + mờ, tất cả đồng thời.
    static var slideScaleFade: AnyTransition {
        .move(edge: .bottom)
        .combined(with: .scale(scale: 0.85))
        .combined(with: .opacity)
    }

    /// Ghép 3 hiệu ứng, bất đối xứng rõ rệt.
    static var dramatic: AnyTransition {
        let insertion = AnyTransition.move(edge: .leading)
            .combined(with: .scale(scale: 0.5, anchor: .leading))
            .combined(with: .opacity)
        let removal = AnyTransition.move(edge: .trailing)
            .combined(with: .scale(scale: 1.5))
            .combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }

    /// Kết hợp offset + scale + opacity — kiểu "rơi vào từ trên".
    static var dropIn: AnyTransition {
        .offset(y: -200)
        .combined(with: .scale(scale: 0.7))
        .combined(with: .opacity)
    }

    /// Có THAM SỐ: hàm static trả về AnyTransition tùy biến theo cạnh.
    static func swoosh(from edge: Edge) -> AnyTransition {
        .move(edge: edge)
        .combined(with: .opacity)
        .combined(with: .scale(scale: 0.9))
    }
}


// =====================================================================
// MARK: - 2. Model danh sách ví dụ
// =====================================================================

enum CombinedKind: String, CaseIterable, Identifiable {
    case rotateAndFade  = "rotateAndFade (đề bài)"
    case slideScaleFade = "slideScaleFade (đối xứng)"
    case dramatic       = "dramatic (3 lớp, bất đối xứng)"
    case dropIn         = "dropIn (offset + scale)"
    case swooshTrailing = "swoosh(from: .trailing)"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .rotateAndFade:  return "in: scale+opacity · out: rotation(180)+opacity"
        case .slideScaleFade: return "move(.bottom)+scale(0.85)+opacity"
        case .dramatic:       return "in: leading+scale+opacity · out: trailing+scale+opacity"
        case .dropIn:         return "offset(y:-200)+scale(0.7)+opacity"
        case .swooshTrailing: return "move(.trailing)+opacity+scale(0.9)"
        }
    }

    var transition: AnyTransition {
        switch self {
        case .rotateAndFade:  return .rotateAndFade
        case .slideScaleFade: return .slideScaleFade
        case .dramatic:       return .dramatic
        case .dropIn:         return .dropIn
        case .swooshTrailing: return .swoosh(from: .trailing)
        }
    }
}


// =====================================================================
// MARK: - 3. View cha + màn demo
// =====================================================================

struct CombinedTransitionPlayground: View {
    var body: some View {
        NavigationStack {
            List(CombinedKind.allCases) { kind in
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
            .navigationTitle("Combined")
            .navigationDestination(for: CombinedKind.self) { kind in
                CombinedDemoView(kind: kind)
            }
        }
    }
}

struct CombinedDemoView: View {
    let kind: CombinedKind
    @State private var showCard = false

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [6]))

                if showCard {
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(colors: [.blue, .cyan],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        )
                        .frame(width: 220, height: 130)
                        .overlay(
                            Text(kind.rawValue)
                                .font(.headline).foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding()
                        )
                        .transition(kind.transition)   // ← AnyTransition kết hợp .combined
                }
            }
            .frame(height: 300)
            .clipped()
            .padding(.horizontal)

            // Nút toggle giống đề bài — combined chạy đủ nhanh để xem bằng toggle.
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showCard.toggle()
                }
            } label: {
                Label(showCard ? "Toggle (đang hiện)" : "Toggle (đang ẩn)",
                      systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Text(kind.subtitle)
                .font(.footnote).monospaced()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.top, 24)
        .navigationTitle("Combined")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showCard = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CombinedTransitionPlayground()
}
