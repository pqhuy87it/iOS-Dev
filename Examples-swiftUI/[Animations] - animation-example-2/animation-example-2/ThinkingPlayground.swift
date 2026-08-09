//
//  ThinkingPlayground.swift
//  Thực hành Symbol Effects + hiệu ứng chữ "thinking" (dựng từ 3 file đính kèm)
//
//  Cách dùng: thêm file này vào project, điều hướng tới ThinkingPlayground()
//  (đã được ráp sẵn trong App bên dưới).
//
//  Yêu cầu: iOS 18+ (.wiggle, .breathe symbol effects; .phaseAnimator dạng
//  content-closure). Nếu target iOS 17, bỏ .wiggle và .breathe.
//

import SwiftUI
internal import Combine

// =====================================================================
// MARK: - Danh sách các phrase dùng chung
// =====================================================================

private enum ThinkingPhrases {
    // Các chuỗi cùng độ dài (đệm khoảng trắng) để layout không nhảy khi đổi câu.
    static let all = [
        "Thinking           ",
        "Weighing Options   ",
        "Evaluating Sentence"
    ]
}

// =====================================================================
// MARK: - 1. Combined Symbol Effects (từ CombinedSymbolEffects.swift)
// =====================================================================
//
// Điểm học: chồng NHIỀU .symbolEffect lên một SF Symbol và kích hoạt đồng
// thời bằng .phaseAnimator. Mỗi effect .byLayer chạy độc lập trên từng lớp
// của symbol; .repeat(3) lặp 3 lần mỗi khi `animate` đổi giá trị.

struct CombinedSymbolEffectsView: View {
    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 128, weight: .heavy))
            .foregroundStyle(
                EllipticalGradient(
                    colors: [.blue, .indigo],
                    center: .center,
                    startRadiusFraction: 0.0,
                    endRadiusFraction: 0.5
                )
            )
            .phaseAnimator([false, true]) { symbol, animate in
                symbol
                    .symbolEffect(.wiggle.byLayer,   options: .repeat(3), value: animate)
                    .symbolEffect(.bounce.byLayer,   options: .repeat(3), value: animate)
                    .symbolEffect(.pulse.byLayer,    options: .repeat(3), value: animate)
                    .symbolEffect(.breathe.byLayer,  options: .repeat(3), value: animate)
            }
    }
}

// =====================================================================
// MARK: - 2. Thinking (từ Thinking.swift) — hiệu ứng chữ chạy sóng
// =====================================================================
//
// Điểm học: animate từng KÝ TỰ với delay lệch nhau (Double(index)/20) tạo
// hiệu ứng sóng lan. hueRotation đổi màu, opacity + scaleEffect tạo nhịp
// "thở". repeatForever(autoreverses: false) để lặp mãi một chiều.

struct ThinkingWaveView: View {
    @State private var thinking = false
    let letters = Array("Evaluating Sentence")

    var body: some View {
        HStack {
            sparkles

            HStack(spacing: 0) {
                ForEach(letters.indices, id: \.self) { i in
                    Text(String(letters[i]))
                        .foregroundStyle(.blue)
                        .hueRotation(.degrees(thinking ? 220 : 0))
                        .opacity(thinking ? 0 : 1)
                        .scaleEffect(x: thinking ? 0.75 : 1,
                                     y: thinking ? 1.25 : 1,
                                     anchor: .bottom)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .delay(1)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) / 20),   // lệch pha theo vị trí ký tự
                            value: thinking
                        )
                }
            }
        }
        .onAppear { thinking = true }
    }

    private var sparkles: some View {
        Image(systemName: "sparkles")
            .font(.title)
            .foregroundStyle(
                EllipticalGradient(colors: [.blue, .indigo], center: .center,
                                   startRadiusFraction: 0.0, endRadiusFraction: 0.5)
            )
            .phaseAnimator([false, true]) { ai, thinking in
                ai.symbolEffect(.breathe.byLayer, value: thinking)
            }
    }
}

// =====================================================================
// MARK: - 3. Thinking2 (từ Thinking2.swift) — đổi câu theo timer
// =====================================================================
//
// Điểm học: kết hợp Timer.publish để luân phiên câu mỗi 5 giây, trong khi
// từng ký tự vẫn chạy hiệu ứng sóng. currentPhraseIndex đổi trong
// withAnimation nên việc chuyển câu cũng được animate.

struct ThinkingRotatingView: View {
    @State private var currentPhraseIndex = 0
    @State private var thinking = false
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            sparkles
            Spacer()
            HStack(spacing: 0) {
                let phrase = Array(ThinkingPhrases.all[currentPhraseIndex].enumerated())
                ForEach(phrase, id: \.offset) { index, letter in
                    Text(String(letter))
                        .foregroundStyle(.blue)
                        .hueRotation(.degrees(thinking ? 220 : 0))
                        .opacity(thinking ? 0 : 1)
                        .scaleEffect(thinking ? 1.5 : 1, anchor: .bottom)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .delay(1)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) / 20),
                            value: thinking
                        )
                }
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 90)
        .onAppear { thinking = true }
        .onReceive(timer) { _ in
            withAnimation {
                currentPhraseIndex = (currentPhraseIndex + 1) % ThinkingPhrases.all.count
            }
        }
    }

    private var sparkles: some View {
        Image(systemName: "sparkles")
            .font(.title)
            .foregroundStyle(
                EllipticalGradient(colors: [.blue, .indigo], center: .center,
                                   startRadiusFraction: 0.0, endRadiusFraction: 0.5)
            )
            .phaseAnimator([false, true]) { ai, thinking in
                ai
                    .symbolEffect(.wiggle.byLayer, value: thinking)
                    .symbolEffect(.bounce.byLayer, value: thinking)
                    .symbolEffect(.breathe.byLayer, value: thinking)
            }
    }
}

// =====================================================================
// MARK: - View cha điều hướng giữa 3 ví dụ
// =====================================================================

enum ThinkingDemo: String, CaseIterable, Identifiable {
    case combined = "Combined Symbol Effects"
    case wave     = "Thinking (chữ chạy sóng)"
    case rotating = "Thinking (đổi câu theo timer)"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .combined: return "wiggle + bounce + pulse + breathe cùng lúc"
        case .wave:     return "animate từng ký tự với delay lệch pha"
        case .rotating: return "Timer luân phiên câu mỗi 5 giây"
        }
    }
}

struct ThinkingPlayground: View {
    var body: some View {
        List(ThinkingDemo.allCases) { demo in
            NavigationLink {
                ThinkingDemoDetail(demo: demo)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(demo.rawValue).font(.headline)
                    Text(demo.subtitle)
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// Màn chi tiết cho từng demo. Dùng NavigationLink dạng closure để tránh khai
/// báo navigationDestination trên view đã bị push (gây cảnh báo
/// "declared earlier on the stack").
struct ThinkingDemoDetail: View {
    let demo: ThinkingDemo

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch demo {
            case .combined: CombinedSymbolEffectsView()
            case .wave:     ThinkingWaveView()
            case .rotating: ThinkingRotatingView()
            }
        }
        .navigationTitle(demo.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ThinkingPlayground()
            .navigationTitle("Symbol & Text Effects")
    }
}
