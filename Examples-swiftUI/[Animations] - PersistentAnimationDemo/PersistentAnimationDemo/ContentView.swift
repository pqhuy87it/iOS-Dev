//
//  PersistentAnimationDemoView.swift
//  AnimationDemo
//
//  Demo SwiftUI dùng 2 extension:
//    - CALayer+AnimationPlayback.swift   (pause/resume toàn bộ layer tree)
//    - CALayer+PersistentAnimations.swift (giữ animation qua background/foreground)
//
//  Cách kiểm chứng persistent:
//    1. Bấm Start -> vòng tròn chạy lặp vô hạn.
//    2. Nhấn Home / vuốt ra ngoài để app vào background rồi quay lại.
//       -> Animation vẫn tiếp tục đúng chỗ (nếu KHÔNG dùng extension này,
//          animation sẽ biến mất khi quay lại foreground).
//    3. Bấm Pause/Resume để dừng và chạy tiếp tại chỗ.
//
//  LƯU Ý: Cần thêm 2 file extension đính kèm vào cùng target thì mới build được.
//

import SwiftUI
import UIKit

// MARK: - UIView chứa layer được animate

final class PersistentAnimatorView: UIView {

    private let box = CALayer()
    private let animationKey = "positionLoop"
    private let travelDuration: CFTimeInterval = 3.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground

        box.backgroundColor = UIColor.systemBlue.cgColor
        box.cornerRadius = 12
        box.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        layer.addSublayer(box)

        // Kích hoạt cơ chế giữ animation qua background/foreground
        // (từ CALayer+PersistentAnimations.swift)
        layer.makeAnimationsPersistent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Đặt vị trí ban đầu ở giữa theo chiều dọc, sát trái
        if box.animation(forKey: animationKey) == nil {
            box.position = CGPoint(x: 50, y: bounds.midY)
        }
    }

    // MARK: Điều khiển

    func startAnimation() {
        box.removeAnimation(forKey: animationKey)

        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = 50
        animation.toValue = bounds.width - 50
        animation.duration = travelDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.autoreverses = true                 // đi rồi quay lại
        animation.repeatCount = .infinity              // lặp vô hạn -> dễ thấy hiệu ứng persistent
        animation.isRemovedOnCompletion = false

        // Đảm bảo layer đang chạy (phòng khi trước đó bị pause)
        if layer.isAnimationsPaused {
            layer.resumeAnimations()
        }
        box.add(animation, forKey: animationKey)
    }

    func pause() {
        // pauseAnimations() từ CALayer+AnimationPlayback.swift
        layer.pauseAnimations()
    }

    func resume() {
        // resumeAnimations() từ CALayer+AnimationPlayback.swift
        layer.resumeAnimations()
    }

    func reset() {
        box.removeAnimation(forKey: animationKey)
        layer.speed = 1.0
        layer.timeOffset = 0.0
        layer.beginTime = 0.0
        box.position = CGPoint(x: 50, y: bounds.midY)
    }

    var isPaused: Bool { layer.isAnimationsPaused }
}

// MARK: - Cầu nối UIKit -> SwiftUI

struct PersistentAnimatorRepresentable: UIViewRepresentable {
    let onMake: (PersistentAnimatorView) -> Void

    func makeUIView(context: Context) -> PersistentAnimatorView {
        let view = PersistentAnimatorView()
        onMake(view)
        return view
    }

    func updateUIView(_ uiView: PersistentAnimatorView, context: Context) {}
}

// MARK: - Giao diện SwiftUI

struct PersistentAnimationDemoView: View {

    @State private var animator: PersistentAnimatorView?
    @State private var isPaused = false

    var body: some View {
        VStack(spacing: 20) {

            Text("Persistent Animation Demo")
                .font(.headline)

            Text("Bấm Start rồi đưa app vào background và quay lại — animation vẫn tiếp tục.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            PersistentAnimatorRepresentable { view in
                DispatchQueue.main.async { self.animator = view }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Button("Start") {
                    animator?.startAnimation()
                    isPaused = false
                }
                .buttonStyle(.borderedProminent)

                Button(isPaused ? "Resume" : "Pause") {
                    guard let animator else { return }
                    if animator.isPaused {
                        animator.resume()
                    } else {
                        animator.pause()
                    }
                    isPaused = animator.isPaused
                }

                Button("Reset") {
                    animator?.reset()
                    isPaused = false
                }
            }

            Spacer()
        }
        .padding()
    }
}

#Preview {
    PersistentAnimationDemoView()
}
