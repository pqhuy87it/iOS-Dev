import SwiftUI

// ============================================================
// PHẦN 1 — Initial approach: ripple + circular reveal
// ============================================================

extension AnyTransition {
    static func simpleRipple(from point: CGPoint) -> AnyTransition {
        .asymmetric(
            insertion: .init(RippleInsertionTransition(tapLocation: point)),
            removal: .opacity
        )
    }
}

struct RippleInsertionTransition: Transition {
    var tapLocation: CGPoint

    func body(content: Content, phase: TransitionPhase) -> some View {
        let progress = 1.0 + phase.value   // insert: -1→0  =>  0→1

        return content
            .visualEffect { content, proxy in
                content.distortionEffect(
                    ShaderLibrary.rippleDistortion(
                        .float2(Float(proxy.size.width), Float(proxy.size.height)),
                        .float(Float(progress)),
                        .float2(Float(tapLocation.x), Float(tapLocation.y))
                    ),
                    maxSampleOffset: CGSize(width: 20, height: 20)
                )
            }
            .clipShape(CircularRevealShape(center: tapLocation, progress: progress))
    }
}

struct CircularRevealShape: Shape {
    var center: CGPoint
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let maxRadius = sqrt(pow(rect.width, 2) + pow(rect.height, 2))
        let currentRadius = progress * maxRadius * 1.4
        var path = Path()
        path.addEllipse(in: CGRect(
            x: center.x - currentRadius,
            y: center.y - currentRadius,
            width: currentRadius * 2,
            height: currentRadius * 2
        ))
        return path
    }
}

struct SimpleRippleTestView: View {
    @State private var currentIndex = 0
    @State private var tapLocation: CGPoint = CGPoint(x: 175, y: 175)

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                ForEach(DemoContent.gradients.indices, id: \.self) { index in
                    if currentIndex == index {
                        Rectangle()
                            .fill(DemoContent.gradients[index])
                            .frame(width: 350, height: 350)
                            .transition(.simpleRipple(from: tapLocation))
                    }
                }
            }
            .frame(width: 350, height: 350)
            .contentShape(Rectangle())
            .onTapGesture { location in
                tapLocation = location
                withAnimation(.easeInOut(duration: 2)) {
                    currentIndex = (currentIndex + 1) % DemoContent.gradients.count
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 10)

            Text("Tap ảnh — ripple + circular reveal")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding()
    }
}

// ============================================================
// PHẦN 2 — A better approach: slide-away (Pavel), không cần masking
// ============================================================

struct SlideAwayRippleTransition: Transition {
    let direction: Float

    func body(content: Content, phase: TransitionPhase) -> some View {
        // insertion: -1→0 => 0→1 ; removal: 0→1 => 1→0
        let progress = direction == 1
            ? Float(1.0 + phase.value)
            : Float(1.0 - phase.value)

        return content
            .visualEffect { content, proxy in
                content.distortionEffect(
                    ShaderLibrary.slideAwayRipple(
                        .float2(Float(proxy.size.width), Float(proxy.size.height)),
                        .float(progress),
                        .float(direction)
                    ),
                    maxSampleOffset: CGSize(width: 0, height: 0)
                )
            }
    }
}

extension AnyTransition {
    static var slideAwayRipple: AnyTransition {
        .asymmetric(
            insertion: .init(SlideAwayRippleTransition(direction: 1)),
            removal: .init(SlideAwayRippleTransition(direction: -1))
        )
    }
}

struct SimpleSlideAwayRipple: View {
    @State private var currentIndex = 0

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                ForEach(DemoContent.gradients.indices, id: \.self) { index in
                    if currentIndex == index {
                        Rectangle()
                            .fill(DemoContent.gradients[index])
                            .frame(width: 350, height: 350)
                            .transition(.slideAwayRipple)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 3)) {
                                    currentIndex = (currentIndex + 1) % DemoContent.gradients.count
                                }
                            }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 10)

            Text("Tap ảnh — slide away (chạy chậm 3s để thấy rõ)")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding()
    }
}

// ============================================================
// PHẦN 3 — Improving my ripples: liquid wave
// ============================================================

struct LiquidWaveTransition: Transition {
    let direction: Float

    func body(content: Content, phase: TransitionPhase) -> some View {
        let progress = direction == 1
            ? Float(1.0 + phase.value)
            : Float(1.0 - phase.value)

        return content
            .visualEffect { content, proxy in
                content.distortionEffect(
                    ShaderLibrary.liquidWave(
                        .float2(Float(proxy.size.width), Float(proxy.size.height)),
                        .float(progress),
                        .float(direction)
                    ),
                    // liquidWave đẩy pixel tối đa ~25pt nên cần offset để không bị cắt mép
                    maxSampleOffset: CGSize(width: 30, height: 30)
                )
            }
    }
}

extension AnyTransition {
    static var liquidWave: AnyTransition {
        .asymmetric(
            insertion: .init(LiquidWaveTransition(direction: 1)),
            removal: .init(LiquidWaveTransition(direction: -1))
        )
    }
}

struct SimpleLiquidWave: View {
    @State private var currentIndex = 0

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                ForEach(DemoContent.gradients.indices, id: \.self) { index in
                    if currentIndex == index {
                        Rectangle()
                            .fill(DemoContent.gradients[index])
                            .frame(width: 350, height: 350)
                            .transition(.liquidWave)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 3)) {
                                    currentIndex = (currentIndex + 1) % DemoContent.gradients.count
                                }
                            }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 10)

            Text("Tap ảnh — liquid wave từ tâm")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding()
    }
}

// ============================================================
// Nội dung demo dùng chung (thay cho asset ảnh)
// ============================================================

enum DemoContent {
    static let gradients: [LinearGradient] = [
        LinearGradient(colors: [.orange, .pink],   startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [.blue, .cyan],     startPoint: .top,        endPoint: .bottom),
        LinearGradient(colors: [.purple, .yellow], startPoint: .leading,    endPoint: .trailing)
    ]
}

// ============================================================
// Menu chọn demo
// ============================================================

struct MetalTransitionsMenu: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("1 · Initial approach (ripple + reveal)") {
                    SimpleRippleTestView().navigationTitle("Ripple + reveal")
                }
                NavigationLink("2 · Better approach (slide away)") {
                    SimpleSlideAwayRipple().navigationTitle("Slide away")
                }
                NavigationLink("3 · Improved (liquid wave)") {
                    SimpleLiquidWave().navigationTitle("Liquid wave")
                }
            }
            .navigationTitle("Metal Transitions")
        }
    }
}

#Preview { MetalTransitionsMenu() }
