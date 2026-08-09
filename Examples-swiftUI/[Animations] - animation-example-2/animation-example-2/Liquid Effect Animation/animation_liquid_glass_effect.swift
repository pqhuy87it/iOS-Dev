//
//  LiquidGlassPlayground.swift
//  Thực hành Liquid Glass (GlassEffectContainer + glassEffect + PhaseAnimator)
//
//  Cách dùng: tạo iOS App (SwiftUI), dán toàn bộ file này vào,
//  rồi đổi body của app thành:
//
//      var body: some View { LiquidGlassPlayground() }
//
//  ⚠️ YÊU CẦU: iOS 26.0+ / Xcode 26+.
//  GlassEffectContainer, .glassEffect(), .glassEffectID() là API mới của
//  Liquid Glass (WWDC 2025). Build trên iOS < 26 sẽ KHÔNG biên dịch được.
//

import SwiftUI

// =====================================================================
// MARK: - 1. Ví dụ gốc của bạn (PhaseAnimator morph khoảng cách)
// =====================================================================
//
// PhaseAnimator lặp qua các phase [false, true] vô hạn, mỗi lần đổi phase
// SwiftUI animate từ trạng thái này sang trạng thái kia. Ở đây phase điều
// khiển `spacing` của HStack: khi -15 hai nút CHỒNG lên nhau nên glass
// blend/morph thành một khối; khi 50 chúng tách rời.
//
// GlassEffectContainer(spacing: 50) đặt ngưỡng morph: các phần tử cách nhau
// <= 50pt sẽ hòa vào nhau về mặt thị giác.

struct GlassPhaseMorphView: View {
    var body: some View {
        GlassEffectContainer(spacing: 50) {
            PhaseAnimator([false, true]) { morph in
                HStack(spacing: morph ? 50.0 : -15.0) {
                    Button {
                        // action
                    } label: {
                        Image(systemName: "scribble.variable")
                    }
                    .padding()
                    .glassEffect()

                    Button {
                        // action
                    } label: {
                        Image(systemName: "eraser.fill")
                    }
                    .padding()
                    .glassEffect()
                }
                .tint(.green)
                .font(.system(size: 64.0))
            } animation: { _ in
                // Thử đổi qua lại các dòng dưới để cảm nhận curve khác nhau:
                // .bouncy(duration: 2, extraBounce: 0.5)
                // .easeOut(duration: 2)
                .easeInOut(duration: 2)
                // .timingCurve(0.68, -0.6, 0.32, 1.6, duration: 2)
            }
        }
    }
}

// =====================================================================
// MARK: - 2. Morph bằng glassEffectID (kiểu FAB mở rộng — pattern "native")
// =====================================================================
//
// Cách morph phổ biến nhất: nút chính luôn hiện, các nút phụ xuất/biến qua
// `if`. Mỗi nút có glassEffectID + chung 1 @Namespace, nên khi thêm/xóa
// SwiftUI morph khối glass chảy mượt từ trạng thái này sang trạng thái kia.

struct GlassExpandableView: View {
    @State private var isExpanded = false
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer(spacing: 24) {
            VStack(spacing: 20) {
                if isExpanded {
                    glassButton("camera.fill", id: "camera")
                    glassButton("photo.fill", id: "photo")
                    glassButton("folder.fill", id: "folder")
                }

                // Nút toggle luôn hiển thị.
                Button {
                    withAnimation(.bouncy(duration: 0.45, extraBounce: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "xmark" : "plus")
                        .font(.system(size: 32, weight: .semibold))
                        .frame(width: 64, height: 64)
                }
                .glassEffect()
                .glassEffectID("toggle", in: namespace)
            }
        }
        .tint(.cyan)
    }

    private func glassButton(_ symbol: String, id: String) -> some View {
        Button {
            // action
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .medium))
                .frame(width: 64, height: 64)
        }
        .glassEffect()
        .glassEffectID(id, in: namespace)
    }
}

// =====================================================================
// MARK: - 3. Biến thể glassEffect: tint, interactive, shape
// =====================================================================
//
// .glassEffect() nhận biến thể (.regular / .clear) và có thể chain
// .tint(_:) và .interactive(). .interactive() thêm scale/bounce/shimmer
// khi chạm. Tham số `in:` đổi shape nền (mặc định Capsule).

struct GlassVariantsView: View {
    var body: some View {
        GlassEffectContainer(spacing: 30) {
            VStack(spacing: 28) {
                Text("Regular")
                    .padding()
                    .glassEffect()   // mặc định: regular + Capsule

                Text("Tinted")
                    .padding()
                    .glassEffect(.regular.tint(.purple))

                Text("Interactive")
                    .padding()
                    .glassEffect(.regular.tint(.orange).interactive())

                Text("Rounded Rect")
                    .padding()
                    .glassEffect(.regular.tint(.mint),
                                 in: RoundedRectangle(cornerRadius: 16))
            }
            .font(.title2.bold())
            .foregroundStyle(.white)
        }
    }
}

// =====================================================================
// MARK: - 4. View cha điều hướng
// =====================================================================

enum GlassDemo: String, CaseIterable, Identifiable {
    case phaseMorph = "PhaseAnimator morph (ví dụ gốc)"
    case expandable = "Expandable FAB (glassEffectID)"
    case variants   = "Biến thể glassEffect (tint/interactive/shape)"

    var id: String { rawValue }
}

struct LiquidGlassPlayground: View {
    var body: some View {
        List(GlassDemo.allCases) { demo in
            NavigationLink(demo.rawValue) {
                GlassDemoDetail(demo: demo)
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// Màn chi tiết cho từng demo. Tách riêng để dùng NavigationLink dạng closure,
/// tránh khai báo navigationDestination trên view đã bị push (gây cảnh báo
/// "declared earlier on the stack").
struct GlassDemoDetail: View {
    let demo: GlassDemo

    var body: some View {
        ZStack {
            // Glass cần nền có màu/gradient để thấy hiệu ứng khúc xạ.
            LinearGradient(
                colors: [.indigo, .black, .teal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch demo {
            case .phaseMorph: GlassPhaseMorphView()
            case .expandable: GlassExpandableView()
            case .variants:   GlassVariantsView()
            }
        }
        .navigationTitle("Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LiquidGlassPlayground()
    }
}
