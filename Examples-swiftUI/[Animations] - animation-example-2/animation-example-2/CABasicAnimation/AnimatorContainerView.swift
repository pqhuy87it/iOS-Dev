//
//  AnimationDemoView.swift
//  AnimationDemo
//
//  Giữ NGUYÊN logic Core Animation (CABasicAnimation + CAMediaTiming) trong
//  một UIView, chỉ đổi phần UI (nút, slider) sang SwiftUI qua UIViewRepresentable.
//

import SwiftUI
import UIKit

// MARK: - UIView giữ toàn bộ logic Core Animation cũ

final class AnimatorContainerView: UIView, CAAnimationDelegate {

    let animatorView = UIView()
    private var displayLink: CADisplayLink?
    private let animationDuration: CFTimeInterval = 5.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .lightGray
        animatorView.backgroundColor = .systemBlue
        animatorView.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        animatorView.center = CGPoint(x: 60, y: 120)
        addSubview(animatorView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: CABasicAnimation (giữ nguyên tinh thần code cũ, cho chạy bình thường)
    func startAnimation() {
        let animation = CABasicAnimation(keyPath: "position")
        animation.delegate = self
        let fromPoint = animatorView.center
        let toPoint = CGPoint(x: 300.0, y: 500.0)
        animation.fromValue = NSValue(cgPoint: fromPoint)
        animation.toValue = NSValue(cgPoint: toPoint)
        animation.duration = animationDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false

        // Đảm bảo layer chạy thời gian bình thường mỗi lần start
        animatorView.layer.speed = 1.0
        animatorView.layer.timeOffset = 0.0
        animatorView.layer.beginTime = 0.0

        animatorView.layer.add(animation, forKey: "KVCkey")
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if let basic = anim as? CABasicAnimation,
           let toValue = basic.toValue as? NSValue {
            animatorView.center = toValue.cgPointValue
        }
    }

    // MARK: Pause / Resume (giữ nguyên kỹ thuật CAMediaTiming)
    func pauseLayer() {
        let layer = animatorView.layer
        let pauseTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0.0
        layer.timeOffset = pauseTime
    }

    func resumeLayer() {
        let layer = animatorView.layer
        let pauseTime = layer.timeOffset
        layer.speed = 1.0
        layer.timeOffset = 0.0
        layer.beginTime = 0.0
        let timeSincePause = layer.convertTime(CACurrentMediaTime(), from: nil) - pauseTime
        layer.beginTime = timeSincePause
    }

    // MARK: Scrubbing bằng timeOffset (giữ nguyên logic đã sửa trước đó)
    func beginScrub() {
        let layer = animatorView.layer
        let now = layer.convertTime(CACurrentMediaTime(), from: nil)
        let elapsed = min(max(now - layer.beginTime, 0), animationDuration)
        layer.speed = 0.0
        layer.timeOffset = elapsed
    }

    /// value: 0...1 từ slider
    func scrub(to value: Double) {
        animatorView.layer.timeOffset = value * animationDuration
    }

    func reset() {
        let layer = animatorView.layer
        layer.removeAllAnimations()
        layer.speed = 1.0
        layer.timeOffset = 0.0
        layer.beginTime = 0.0
        animatorView.center = CGPoint(x: 60, y: 120)
    }

    // MARK: DisplayLink (giữ nguyên, API đã hiện đại hóa)
    func startDisplayLink() {
        if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
            displayLink?.preferredFramesPerSecond = 12
            displayLink?.add(to: .current, forMode: .common)
        }
        displayLink?.isPaused = false
    }

    func stopDisplayLink() {
        displayLink?.isPaused = true
        displayLink?.remove(from: .current, forMode: .common)
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func handleDisplayLink(_ link: CADisplayLink) {
        print("displaylink last time : \(link.timestamp)")
    }
}

// MARK: - Cầu nối UIKit -> SwiftUI

struct AnimatorRepresentable: UIViewRepresentable {
    let onMake: (AnimatorContainerView) -> Void

    func makeUIView(context: Context) -> AnimatorContainerView {
        let view = AnimatorContainerView()
        onMake(view)
        return view
    }

    func updateUIView(_ uiView: AnimatorContainerView, context: Context) {}
}

// MARK: - Giao diện SwiftUI

struct AnimationDemoView: View {

    @State private var animator: AnimatorContainerView?
    @State private var sliderValue: Double = 0
    @State private var isScrubbing = false

    var body: some View {
        VStack(spacing: 20) {

            AnimatorRepresentable { view in
                DispatchQueue.main.async { self.animator = view }
            }
            .frame(height: 560)
            .cornerRadius(12)

            HStack(spacing: 12) {
                Button("Start") { animator?.startAnimation() }
                    .buttonStyle(.borderedProminent)
                Button("Pause") { animator?.pauseLayer() }
                Button("Resume") { animator?.resumeLayer() }
                Button("Reset") {
                    animator?.reset()
                    sliderValue = 0
                }
            }

            Slider(
                value: $sliderValue,
                in: 0...1,
                onEditingChanged: { editing in
                    if editing {
                        animator?.beginScrub()
                        isScrubbing = true
                    } else {
                        isScrubbing = false
                    }
                }
            )
            .onChange(of: sliderValue) { _, newValue in
                if isScrubbing {
                    animator?.scrub(to: newValue)
                }
            }

            HStack {
                Button("Start DisplayLink") { animator?.startDisplayLink() }
                Button("Stop DisplayLink") { animator?.stopDisplayLink() }
            }
            .font(.caption)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    AnimationDemoView()
}
