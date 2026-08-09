import SwiftUI

// ============================================================
// View màu dùng chung cho mọi demo (theo bài viết)
// ============================================================

struct ColorView: View {
    let index: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(colorForIndex(index))
            .overlay(
                Text("Item \(index + 1)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            )
    }

    func colorForIndex(_ index: Int) -> Color {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue,
                               .purple, .pink, .teal, .cyan, .brown]
        return colors[index % colors.count]
    }
}

// ============================================================
// 1. SYMMETRICAL — một hiệu ứng chung khi view VÀO và RA
//    Dùng scrollTransition(_:axis:transition:)
//    Ở đây: thu nhỏ khi đang vào/ra, giữ nguyên khi hiển thị đầy đủ.
// ============================================================

struct SymmetricalTransitionView: View {
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 20) {
                ForEach(0..<10) { index in
                    ColorView(index: index)
                        .frame(height: 200)
                        .scrollTransition(
                            .interactive(timingCurve: .easeInOut),
                            axis: .vertical
                        ) { content, phase in
                            // phase.isIdentity == true khi view hiển thị đầy đủ (không đổi)
                            // phase.value: -1 (topLeading) -> 0 (identity) -> 1 (bottomTrailing)
                            content.scaleEffect(phase.isIdentity ? 1 : 1 - 0.4 * abs(phase.value))
                        }
                }
            }
            .padding()
        }
        .navigationTitle("Symmetrical")
    }
}

// ============================================================
// 2. ASYMMETRICAL — hiệu ứng KHÁC nhau khi vào (top) và ra (bottom)
//    Dùng scrollTransition(topLeading:bottomTrailing:axis:transition:)
//    - topLeading: xoay, cấu hình interactive (thay đổi mượt theo scroll)
//    - bottomTrailing: phóng to, cấu hình animated bouncy (nhảy 1 phát tại threshold)
// ============================================================

struct AsymmetricalTransitionView: View {
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 20) {
                ForEach(0..<10) { index in
                    ColorView(index: index)
                        .frame(height: 200)
                        .scrollTransition(
                            topLeading: .interactive(timingCurve: .easeIn),
                            bottomTrailing: .animated(.bouncy(duration: 0.8)),
                            axis: .vertical
                        ) { content, phase in
                            content
                                // Chỉ xoay khi ở mép trên (đang vào)
                                .rotationEffect(.degrees(phase == .topLeading ? -90 * phase.value : 0))
                                // Chỉ scale khi ở mép dưới (đang ra)
                                .scaleEffect(phase == .bottomTrailing ? 1 + 0.5 * phase.value : 1)
                                // Mờ dần ở cả hai đầu
                                .opacity(1 - abs(phase.value))
                        }
                }
            }
            .padding()
        }
        .navigationTitle("Asymmetrical")
    }
}

// ============================================================
// 3. ANIMATED vs INTERACTIVE — so sánh hai kiểu configuration
//    interactive: nội suy dần theo vị trí scroll
//    animated: đổi một phát khi chạm ngưỡng (threshold)
// ============================================================

struct ConfigComparisonView: View {
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 20) {
                ForEach(0..<10) { index in
                    ColorView(index: index)
                        .frame(height: 200)
                        .scrollTransition(
                            // Đổi giữa .interactive và .animated để thấy khác biệt
                            index.isMultiple(of: 2)
                                ? .interactive(timingCurve: .easeInOut)
                                : .animated(.bouncy(duration: 0.8)),
                            axis: .vertical
                        ) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.2)
                                .scaleEffect(phase.isIdentity ? 1 : 0.6)
                        }
                }
            }
            .padding()
        }
        .navigationTitle("Animated vs Interactive")
    }
}

// ============================================================
// Menu chọn demo
// ============================================================

struct ScrollTransitionMenu: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("1 · Symmetrical (vào = ra)") {
                    SymmetricalTransitionView()
                }
                NavigationLink("2 · Asymmetrical (vào ≠ ra)") {
                    AsymmetricalTransitionView()
                }
                NavigationLink("3 · Animated vs Interactive") {
                    ConfigComparisonView()
                }
            }
            .navigationTitle("scrollTransition")
        }
    }
}

#Preview { ScrollTransitionMenu() }
