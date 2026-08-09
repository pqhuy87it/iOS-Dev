//
//  AsymmetricTransitionPlayground.swift
//  Thực hành .transition(.asymmetric(insertion:removal:)) trong SwiftUI
//
//  Cách dùng: tạo iOS App (SwiftUI), dán toàn bộ file này vào,
//  rồi đổi body của app thành:
//
//      var body: some View { AsymmetricTransitionPlayground() }
//
//  Yêu cầu: iOS 16+ (case .pushVsOpacity dùng .push cần iOS 16).
//

import SwiftUI

// MARK: - Model mô tả từng ví dụ asymmetric

/// `.asymmetric` cho phép insertion (lúc thêm view) và removal (lúc xóa view)
/// dùng transition KHÁC NHAU. Rất hợp cho toast, banner, sheet tùy biến...
enum AsymmetricKind: String, CaseIterable, Identifiable {
    case topInFadeOut     = "Trượt xuống vào · fade ra"
    case scaleInSlideOut  = "Phóng to vào · trượt ra"
    case pushVsOpacity    = "Push vào · mờ ra"
    case combinedBoth     = "Ghép combined 2 chiều"
    case leadingTrailing  = "Vào trái · ra phải"
    case offsetVsScale    = "Offset vào · thu nhỏ ra"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .topInFadeOut:
            return "insertion: move(.top)+opacity · removal: opacity"
        case .scaleInSlideOut:
            return "insertion: scale · removal: move(.leading)+opacity"
        case .pushVsOpacity:
            return "insertion: push(.trailing) · removal: opacity"
        case .combinedBoth:
            return "cả 2 chiều đều combined nhiều hiệu ứng"
        case .leadingTrailing:
            return "insertion: move(.leading) · removal: move(.trailing)"
        case .offsetVsScale:
            return "insertion: offset · removal: scale(0.3)+opacity"
        }
    }

    /// Transition bất đối xứng tương ứng.
    var transition: AnyTransition {
        switch self {
        case .topInFadeOut:
            return .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            )

        case .scaleInSlideOut:
            return .asymmetric(
                insertion: .scale,
                removal: .move(edge: .leading).combined(with: .opacity)
            )

        case .pushVsOpacity:
            return .asymmetric(
                insertion: .push(from: .trailing),
                removal: .opacity
            )

        case .combinedBoth:
            return .asymmetric(
                insertion: .scale(scale: 0.8)
                    .combined(with: .opacity)
                    .combined(with: .move(edge: .bottom)),
                removal: .scale(scale: 1.2)
                    .combined(with: .opacity)
            )

        case .leadingTrailing:
            return .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            )

        case .offsetVsScale:
            return .asymmetric(
                insertion: .offset(x: 0, y: 150).combined(with: .opacity),
                removal: .scale(scale: 0.3).combined(with: .opacity)
            )
        }
    }
}

// MARK: - View cha: danh sách ví dụ

struct AsymmetricTransitionPlayground: View {
    var body: some View {
        NavigationStack {
            List(AsymmetricKind.allCases) { kind in
                NavigationLink(value: kind) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.rawValue)
                            .font(.headline)
                        Text(kind.subtitle)
                            .font(.caption)
                            .monospaced()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Asymmetric")
            .navigationDestination(for: AsymmetricKind.self) { kind in
                AsymmetricDemoView(kind: kind)
            }
        }
    }
}

// MARK: - Màn demo: tách riêng nút Hiện và Ẩn để thấy rõ 2 chiều khác nhau

struct AsymmetricDemoView: View {
    let kind: AsymmetricKind
    @State private var isShown = false

    var body: some View {
        VStack(spacing: 28) {

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [6]))

                if isShown {
                    demoCard
                        .transition(kind.transition)   // ← asymmetric transition
                }
            }
            .frame(height: 280)
            .clipped()
            .padding(.horizontal)

            // Hai nút riêng biệt: cách tốt nhất để cảm nhận insertion ≠ removal.
            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        isShown = true
                    }
                } label: {
                    Label("Hiện", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isShown)

                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        isShown = false
                    }
                } label: {
                    Label("Ẩn", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .disabled(!isShown)
            }
            .padding(.horizontal)

            VStack(spacing: 6) {
                Text("insertion").font(.caption).foregroundStyle(.secondary)
                Text(kind.subtitle)
                    .font(.footnote)
                    .monospaced()
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.top, 24)
        .navigationTitle("Asymmetric")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                isShown = true
            }
        }
    }

    private var demoCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 40, weight: .semibold))
            Text("Vào ≠ Ra")
                .font(.title3.bold())
        }
        .foregroundStyle(.white)
        .frame(width: 200, height: 200)
        .background(
            LinearGradient(colors: [.pink, .orange],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
    }
}

// MARK: - Ví dụ thực tế: Toast notification dùng asymmetric

/// Trường hợp dùng phổ biến nhất của asymmetric: banner trượt vào từ trên,
/// nhưng chỉ fade ra êm ái thay vì trượt ngược lên.
struct ToastDemoView: View {
    @State private var showToast = false

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            Button("Hiện Toast") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showToast = true
                }
                // Tự ẩn sau 2 giây.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showToast = false
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 200)

            if showToast {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Đã lưu thành công")
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding()
                .background(.green, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: AsymmetricTransitionPlayground(), label: {
                    Text("AsymmetricTransitionPlayground")
                })

                NavigationLink(destination: ToastDemoView(), label: {
                    Text("ToastDemoView")
                })
            }.navigationBarTitle("Animation Asymmetric Demo")
        }
    }
}

// MARK: - Preview

#Preview("Playground") {
    AsymmetricTransitionPlayground()
}

#Preview("Toast") {
    ToastDemoView()
}
