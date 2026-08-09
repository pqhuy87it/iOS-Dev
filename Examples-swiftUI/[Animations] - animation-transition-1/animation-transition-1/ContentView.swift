//
//  TransitionPlayground.swift
//  Thực hành các loại transition trong SwiftUI
//
//  Cách dùng: tạo iOS App (SwiftUI), dán toàn bộ file này vào,
//  rồi đổi nội dung ContentView của app thành:
//
//      var body: some View { TransitionPlayground() }
//
//  Yêu cầu: iOS 17+ (vì có .blurReplace và Transition protocol nếu bạn mở rộng).
//  Nếu target < iOS 17, chỉ cần bỏ case .blurReplace.
//

import SwiftUI

// MARK: - Model mô tả từng loại transition

/// Mỗi case là 1 ví dụ transition. RawValue dùng làm tiêu đề hiển thị.
enum TransitionKind: String, CaseIterable, Identifiable {
    case opacity          = "opacity"
    case slide            = "slide"
    case scale            = "scale"
    case scaleAnchored    = "scale(scale: 0.5, anchor: .topLeading)"
    case moveBottom       = "move(edge: .bottom)"
    case pushTrailing     = "push(from: .trailing)"
    case offset           = "offset(x:y:)"
    case blurReplace      = "blurReplace"
    case identity         = "identity"

    var id: String { rawValue }

    /// Mô tả ngắn để người học biết mình sắp thấy gì.
    var subtitle: String {
        switch self {
        case .opacity:       return "Mờ dần vào / ra. Transition mặc định của SwiftUI."
        case .slide:         return "Trượt vào từ leading, ra trailing."
        case .scale:         return "Phóng to từ 0 tại tâm view."
        case .scaleAnchored: return "Phóng từ 0.5 với neo ở góc trên-trái."
        case .moveBottom:    return "Trượt vào/ra qua cạnh dưới."
        case .pushTrailing:  return "Đẩy vào từ phải như hiệu ứng navigation (iOS 16+)."
        case .offset:        return "Dịch chuyển theo offset cố định (x: 200, y: 100)."
        case .blurReplace:   return "Làm mờ rồi thay thế (iOS 17+)."
        case .identity:      return "Không có hiệu ứng — xuất/biến tức thì dù có animation."
        }
    }

    /// AnyTransition tương ứng với từng case.
    var transition: AnyTransition {
        switch self {
        case .opacity:
            return .opacity
        case .slide:
            return .slide
        case .scale:
            return .scale
        case .scaleAnchored:
            return .scale(scale: 0.5, anchor: .topLeading)
        case .moveBottom:
            return .move(edge: .bottom)
        case .pushTrailing:
            return .push(from: .trailing)
        case .offset:
            return .offset(x: 200, y: 100)
        case .blurReplace:
            if #available(iOS 17.0, *) {
                return AnyTransition(.blurReplace)   // wrap Transition -> AnyTransition
            } else {
                return .opacity   // fallback cho máy cũ
            }
        case .identity:
            return .identity
        }
    }
}

// MARK: - View cha: danh sách các ví dụ

struct TransitionPlayground: View {
    var body: some View {
        NavigationStack {
            List(TransitionKind.allCases) { kind in
                // NavigationLink push thẳng vào màn demo của ví dụ đó.
                NavigationLink(value: kind) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.rawValue)
                            .font(.headline)
                            .monospaced()
                        Text(kind.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Transitions")
            .navigationDestination(for: TransitionKind.self) { kind in
                TransitionDemoView(kind: kind)
            }
        }
    }
}

// MARK: - Màn demo cho từng transition

struct TransitionDemoView: View {
    let kind: TransitionKind
    @State private var isShown = false

    var body: some View {
        VStack(spacing: 32) {

            // Vùng chứa view được thêm/xóa. Cần khung cố định để nhìn rõ chuyển động.
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [6]))

                if isShown {
                    demoCard
                        .transition(kind.transition)   // ← điểm mấu chốt: gắn transition
                }
            }
            .frame(height: 260)
            .clipped()                                  // giữ hiệu ứng trong khung
            .padding(.horizontal)

            // Nút toggle. withAnimation cung cấp timing để transition chạy.
            Button {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    isShown.toggle()
                }
            } label: {
                Label(isShown ? "Ẩn (removal)" : "Hiện (insertion)",
                      systemImage: isShown ? "eye.slash" : "eye")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            // Ghi chú nhắc lại nguyên tắc.
            Text("Transition chỉ chạy khi (1) view được thêm/xóa qua `if`, và (2) thay đổi state được bọc trong `withAnimation`.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.top, 24)
        .navigationTitle(kind == .scaleAnchored ? "scale + anchor" : kind.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Tự động hiện sau khi push để thấy ngay insertion.
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                isShown = true
            }
        }
    }

    // View mẫu được animate.
    private var demoCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
            Text(kind.rawValue)
                .font(.headline)
                .monospaced()
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .frame(width: 200, height: 200)
        .background(
            LinearGradient(colors: [.blue, .purple],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
    }
}

// MARK: - Preview

#Preview {
    TransitionPlayground()
}
