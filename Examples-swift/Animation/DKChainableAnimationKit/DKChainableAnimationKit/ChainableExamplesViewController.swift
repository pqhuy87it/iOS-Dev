//
//  ChainableExamplesViewController.swift
//  DKChainableAnimationKit
//
//  A gallery of examples showing how to use DKChainableAnimationKit.
//  Each button triggers a distinct chain so you can see individual features
//  (move / scale / rotate / color / path / easing / spring …) in isolation.
//

import UIKit

class ChainableExamplesViewController: UIViewController {

    /// The single view every example animates. It is reset to `home` before each demo
    /// so examples never interfere with each other.
    private let box: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBlue
        v.layer.cornerRadius = 8
        return v
    }()

    /// A second helper view used by the "concurrent" example.
    private let companion: UIView = {
        let v = UIView()
        v.backgroundColor = .systemOrange
        v.layer.cornerRadius = 8
        return v
    }()

    private let boxSize: CGFloat = 60
    private var home: CGRect = .zero

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Chainable Examples"

        view.addSubview(companion)
        view.addSubview(box)
        buildMenu()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Park the box in the upper-center of the screen and remember that as "home".
        if home == .zero {
            let x = (view.bounds.width - boxSize) / 2
            let y = view.safeAreaInsets.top + 24
            home = CGRect(x: x, y: y, width: boxSize, height: boxSize)
            resetBox()
        }
    }

    // MARK: - Menu

    private struct Demo {
        let title: String
        let run: () -> Void
    }

    private func buildMenu() {
        let demos: [Demo] = [
            Demo(title: "1. Move + color chain") { [weak self] in self?.moveAndColor() },
            Demo(title: "2. Scale + rotate (easeInOutBack)") { [weak self] in self?.scaleAndRotate() },
            Demo(title: "3. Spring pop") { [weak self] in self?.springPop() },
            Demo(title: "4. Bounce across screen") { [weak self] in self?.bounceAcross() },
            Demo(title: "5. Follow a Bézier path") { [weak self] in self?.followPath() },
            Demo(title: "6. Polar orbit (movePolar)") { [weak self] in self?.polarOrbit() },
            Demo(title: "7. Morph into a circle") { [weak self] in self?.morphToCircle() },
            Demo(title: "8. Anchored flip (anchorLeft)") { [weak self] in self?.anchoredFlip() },
            Demo(title: "9. Multi-step sequence") { [weak self] in self?.multiStep() },
            Demo(title: "10. Two views at once") { [weak self] in self?.concurrent() },
            Demo(title: "↺ Reset") { [weak self] in self?.resetBox() },
        ]

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        for demo in demos {
            let button = UIButton(type: .system)
            button.setTitle(demo.title, for: .normal)
            button.contentHorizontalAlignment = .leading
            button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
            button.backgroundColor = .secondarySystemBackground
            button.layer.cornerRadius = 10
            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
            button.addAction(UIAction { _ in demo.run() }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)

        NSLayoutConstraint.activate([
            // Menu occupies the bottom half; the box animates in the top half.
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scroll.topAnchor.constraint(equalTo: view.centerYAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
        ])
    }

    // MARK: - Reset

    /// Clears any transform / layer state and returns the box to `home`.
    private func resetBox() {
        box.layer.removeAllAnimations()
        box.layer.transform = CATransform3DIdentity
        box.transform = .identity
        box.frame = home
        box.backgroundColor = .systemBlue
        box.alpha = 1
        box.layer.cornerRadius = 8
        box.layer.borderWidth = 0
        box.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        companion.layer.removeAllAnimations()
        companion.transform = .identity
        companion.frame = CGRect(x: home.minX, y: home.maxY + 16, width: boxSize, height: boxSize)
        companion.backgroundColor = .systemOrange
    }

    // MARK: - Examples

    /// Move right then down while morphing the background color. `thenAfter`
    /// runs the next link after the previous one finishes.
    private func moveAndColor() {
        resetBox()
        box.animation
            .moveX(120).makeBackground(.systemPurple).thenAfter(0.4)
            .moveY(120).makeBackground(.systemGreen).animate(0.4)
    }

    /// Grow to 1.8x and spin a half-turn with an overshooting ease curve.
    private func scaleAndRotate() {
        resetBox()
        box.animation
            .makeScale(1.8)
            .rotate(180)
            .easeInOutBack
            .animate(0.7)
    }

    /// A quick springy "pop" — scale up with spring physics, then settle back.
    private func springPop() {
        resetBox()
        box.animation
            .makeScale(1.6).spring.thenAfter(0.5)
            .makeScale(1.0).spring.animate(0.5)
    }

    /// Bounce the box to the right edge of the screen.
    private func bounceAcross() {
        resetBox()
        let travel = view.bounds.width - boxSize - home.minX - 16
        box.animation
            .moveX(travel).bounce.animate(1.0)
    }

    /// Drive the box along a curved Bézier path using `moveAndRotateOnPath`,
    /// so it also rotates to face the direction of travel.
    private func followPath() {
        resetBox()
        let path = UIBezierPath()
        let start = box.layer.position
        path.move(to: start)
        path.addCurve(
            to: CGPoint(x: start.x + 180, y: start.y + 40),
            controlPoint1: CGPoint(x: start.x + 40, y: start.y - 120),
            controlPoint2: CGPoint(x: start.x + 140, y: start.y - 120)
        )
        box.animation
            .moveAndRotateOnPath(path)
            .easeInOutSine
            .animate(1.2)
    }

    /// Orbit outward using polar coordinates: `movePolar(radius, angleInDegrees)`.
    private func polarOrbit() {
        resetBox()
        box.animation
            .movePolar(130, 45).thenAfter(0.4)
            .movePolar(130, 135).thenAfter(0.4)
            .movePolar(130, 225).thenAfter(0.4)
            .movePolar(130, 315).animate(0.4)
    }

    /// Animate corner radius + border to turn the square into a bordered circle.
    private func morphToCircle() {
        resetBox()
        box.animation
            .makeCornerRadius(boxSize / 2)
            .makeBorderWidth(6)
            .makeBorderColor(.systemRed)
            .makeBackground(.systemYellow)
            .easeOutCubic
            .animate(0.6)
    }

    /// Set the anchor point to the left edge, then rotate — the box swings like a door.
    private func anchoredFlip() {
        resetBox()
        box.animation
            .anchorLeft
            .rotate(80).easeOutBack.thenAfter(0.5)
            .rotate(0).easeInBack.animate(0.5)
    }

    /// A longer story chain using `thenAfter` between links and a completion block.
    private func multiStep() {
        resetBox()
        box.animation
            .moveX(100).makeBackground(.systemPink).thenAfter(0.35)
            .moveY(100).makeScale(1.4).thenAfter(0.35)
            .moveX(-100).rotate(180).thenAfter(0.35)
            .moveY(-100).makeScale(1.0).rotate(360).makeBackground(.systemBlue)
            .animateWithCompletion(0.4) { [weak self] in
                self?.box.layer.transform = CATransform3DIdentity
            }
    }

    /// Two independent views animating at the same time — each `UIView` owns its
    /// own animation chain, so they run concurrently.
    private func concurrent() {
        resetBox()
        box.animation
            .moveX(120).makeScale(1.3).easeInOutQuad.animate(0.8)
        companion.animation
            .moveX(120).rotate(360).easeInOutQuad.animate(0.8)
    }
}
