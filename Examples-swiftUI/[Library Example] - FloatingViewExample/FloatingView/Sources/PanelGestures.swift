//
//  PanelGestures.swift
//  Aiolos
//
//  Created by Matthias Tretter on 14/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import UIKit

// swiftlint:disable file_length

/// Manages Gestures added to the Panel
final class PanelGestures: NSObject {

    private unowned let panel: FloatingViewControler

    private lazy var verticalPan: NoDelayPanGestureRecognizer = self.makeVerticalPanGestureRecognizer()
    private lazy var verticalPanState: VerticalGestureState = .init(handler: self.verticalHandler)
    private lazy var verticalHandler: VerticalHandler = .init(gestures: self)

    // MARK: - Lifecycle

    init(panel: FloatingViewControler) {
        self.panel = panel
    }

    // MARK: - PanelGestures

    func install() {
        self.panel.view.addGestureRecognizer(self.verticalPan)
    }
    
    func cancel() {
        self.verticalPan.cancel()
    }
}

// MARK: - UIGestureRecognizerDelegate


extension PanelGestures: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let shouldBegin = self.panel.gestureDelegate?.gestureRecognizerShouldBegin?(gestureRecognizer) {
            return shouldBegin
        }

        return self.verticalHandler.shouldStartPan(gestureRecognizer)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let shouldRecognize = self.panel.gestureDelegate?.gestureRecognizer?(gestureRecognizer, shouldRecognizeSimultaneouslyWith: otherGestureRecognizer) {
            return shouldRecognize
        }

        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // horizontal and vertical pan (or pointer scroll) should not happen together
//        if gestureRecognizer == self.horizontalPan {
//            return otherGestureRecognizer == self.verticalPan || otherGestureRecognizer == self.verticalPointerScroll
//        }

        if let shouldRequireFailureOf = self.panel.gestureDelegate?.gestureRecognizer?(gestureRecognizer, shouldRequireFailureOf: otherGestureRecognizer) {
            return shouldRequireFailureOf
        }

        // fail for built-in drag gesture recognizers 🤷‍♂️
        let className = String(describing: type(of: otherGestureRecognizer))
        if className.contains("UIDrag") { return true }

        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let shouldBeRequiredToFailBy = self.panel.gestureDelegate?.gestureRecognizer?(gestureRecognizer, shouldBeRequiredToFailBy: otherGestureRecognizer) {
            return shouldBeRequiredToFailBy
        }

        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
        if let shouldReceivePress = self.panel.gestureDelegate?.gestureRecognizer?(gestureRecognizer, shouldReceive: press) {
            return shouldReceivePress
        }

        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let shouldReceiveTouch = self.panel.gestureDelegate?.gestureRecognizer?(gestureRecognizer, shouldReceive: touch) {
            return shouldReceiveTouch
        }

        return true
    }
}

// MARK: - Private

private extension PanelGestures {

    typealias PanOrScrollGestureRecognizer = UIGestureRecognizer & PanGestureRecognizer

    struct Constants {
        static let minTranslation: CGFloat = 5.0
    }

    // MARK: - VerticalGestureState

    /// Handles NoDelayPanGestureRecognizer and PointerScrollGestureRecognizer and provides them with state
    final class VerticalGestureState {

        private unowned let handler: VerticalHandler
        private var initialPoint: CGPoint?
        private var currentPoint: CGPoint?

        // MARK: - Properties

        /// Tells us if the gesture has passed the threshold of Constants.minTranslation at least once
        private(set) var didPan: Bool = false
//        var startMode: PanelGestures.StartMode = .onFixedArea

        // MARK: - Lifecycle

        init(handler: VerticalHandler) {
            self.handler = handler
        }

        // MARK: - VerticalGestureState

        @objc
        func handlePan(_ pan: PanOrScrollGestureRecognizer) {
            let location = pan.location(in: pan.view?.window)
            self.currentPoint = location

            switch pan.state {
            case .possible:
                break
            case .began:
                self.initialPoint = location

            case .changed:
                self.currentPoint = location
                if self.totalTranslation(in: pan.view).hypotenuse() >= Constants.minTranslation, self.didPan == false {
                    self.didPan = true

                    guard self.totalTranslation(in: pan.view).direction() == .vertical else {
                        pan.state = .cancelled
                        return
                    }
                }

            case .ended, .failed, .cancelled:
                self.handler.handlePan(pan, state: self)
                self.cleanup() // We can't use defer for this because we're in a switch statement
                return

            @unknown default:
                break
            }

            self.handler.handlePan(pan, state: self)
        }

        // MARK: - Private

        private func cleanup() {
            self.didPan = false
//            self.startMode = .onFixedArea
        }

        private func totalTranslation(in view: UIView?) -> CGPoint {
            guard let view = view else { return .zero }
            guard let initialPoint = self.initialPoint else { return .zero }
            guard let currentPoint = self.currentPoint else { return .zero }

            return self.translation(from: initialPoint, to: currentPoint, in: view)
        }

        private func translation(from startPoint: CGPoint, to endPoint: CGPoint, in view: UIView) -> CGPoint {
            guard let window = view.window else { return .zero }

            let startPointInView = window.convert(startPoint, to: view)
            let endPointInView = window.convert(endPoint, to: view)

            return CGPoint(x: endPointInView.x - startPointInView.x, y: endPointInView.y - startPointInView.y)
        }
    }

    // MARK: - VerticalHandler

    final class VerticalHandler {

        private unowned let gestures: PanelGestures
        private var panel: FloatingViewControler { return self.gestures.panel }
        private var originalConfiguration: PanelGestures.Configuration?

        init(gestures: PanelGestures) {
            self.gestures = gestures
        }

        func shouldStartPan(_ pan: UIGestureRecognizer) -> Bool {
//            let gestureResizingMode = self.panel.configuration.gestureResizingMode
//            if pan == self.gestures.verticalPan && gestureResizingMode.contains(.byTouch) == false { return false }
            
//            if pan == self.gestures.verticalPointerScroll && gestureResizingMode.contains(.byPointerScroll) == false { return false }
            
            guard let contentViewController = self.panel.contentViewController else { return false }

            let isWithinContentArea = self.gestures.gestureRecognizer(pan, isWithinContentAreaOf: contentViewController)
            guard isWithinContentArea else { return true }

            return self.gestures.gestureRecognizer(pan, isAllowedToStartByContentOf: contentViewController)
        }

        func handlePan(_ pan: PanOrScrollGestureRecognizer, state: VerticalGestureState) {
            switch pan.state {
            case .began:
                self.handlePanStarted(pan, state: state)
            case .changed:
                self.handlePanChanged(pan, state: state)
            case .ended:
                self.handlePanEnded(pan, state: state)
            case .cancelled:
                self.handlePanCancelled(pan)
            default:
                break
            }
        }

        private func handlePanStarted(_ pan: PanOrScrollGestureRecognizer, state: VerticalGestureState) {
            let configuration = PanelGestures.Configuration(mode: self.panel.configuration.mode, animateChanges: self.panel.animator.animateChanges)
            // remember initial state
            self.originalConfiguration = configuration

//            if let contentViewController = self.panel.contentViewController {
//                if self.gestures.gestureRecognizer(pan, isWithinContentAreaOf: contentViewController), let scrollView = self.gestures.verticallyScrollableView(of: contentViewController, interactingWith: pan) {
//                    state.startMode = .onVerticallyScrollableArea(competingScrollView: scrollView)
//                } else {
//                    state.startMode = .onFixedArea
//                }
//            }
        }

        private func handlePanDragStart(_ pan: PanOrScrollGestureRecognizer, state: VerticalGestureState) -> Bool {
            self.panel.animator.animateChanges = false
            self.panel.animator.performWithoutAnimation {
                self.panel.constraints.updateForPanStart(with: self.panel.view.frame.size)
            }

            pan.cancelsTouchesInView = true

            let velocity = pan.velocity(in: self.panel.view)

            self.panel.animator.notifyDelegateOfResizing()

            return true
        }

        private func handlePanChanged(_ pan: PanOrScrollGestureRecognizer, state: VerticalGestureState) {
            func dragOffset(for translation: CGPoint) -> CGFloat {
                let fudgeFactor: CGFloat = 60.0
                let supportedModes = self.panel.configuration.supportedModes
                let minHeight = (supportedModes.map { self.height(for: $0) }.min() ?? 0.0) + fudgeFactor
                let maxHeight = self.panel.constraints.maxHeight - fudgeFactor
                let currentHeight = self.panel.currentHeight

                // slow down resizing if the current height exceeds certain limits
                let isNearingEdge = (currentHeight < minHeight && translation.y > 0.0) || (currentHeight > maxHeight && translation.y < 0.0)
                if isNearingEdge {
                    return translation.y / 3.0
                } else {
                    return translation.y
                }
            }

            let translation = pan.translation(in: self.panel.view)
            let yOffset = dragOffset(for: translation)
            guard yOffset != 0.0 else { return }

            // We reset the translation to get incremental updates from now on
            pan.setTranslation(.zero, in: self.panel.view)

            // However, didPan still works with totalTranslation under the covers
            if state.didPan && pan.cancelsTouchesInView == false {
                guard self.handlePanDragStart(pan, state: state) else { return }
            }

            self.panel.animator.performWithoutAnimation { self.panel.constraints.updateForPan(with: yOffset) }
            self.panel.animator.notifyDelegateOfTransition(to: CGSize(width: self.panel.view.frame.width, height: self.panel.currentHeight))
        }

        private func handlePanEnded(_ pan: PanOrScrollGestureRecognizer, state: VerticalGestureState) {
//            guard let originalMode = self.originalConfiguration?.mode else { return }

            self.panel.constraints.updateForPanEnd()
            guard state.didPan else {
                self.handlePanCancelled(pan)
                return
            }

            let targetMode = self.targetMode(for: pan, state: state)
            let initialVelocity = self.initialVelocity(for: pan, targetMode: targetMode)

            self.animate(to: targetMode, initialVelocity: initialVelocity)
            self.cleanUp(pan: pan)
        }

        private func handlePanCancelled(_ pan: PanOrScrollGestureRecognizer) {
            guard let originalMode = self.originalConfiguration?.mode else { return }

            let currentHeight = self.panel.currentHeight
            self.cleanUp(pan: pan)

            let size = self.panel.size(for: originalMode)
            self.panel.constraints.updateForPanCancelled(with: size)
            if currentHeight != size.height {
                self.panel.animator.notifyDelegateOfTransition(to: size)
            }
        }

        private func targetMode(for pan: PanOrScrollGestureRecognizer, state: VerticalGestureState) -> FloatingMode {
            let supportedModes = self.panel.configuration.supportedModes
            guard let originalConfiguration = self.originalConfiguration else { return supportedModes.first! }

            let minVelocity: CGFloat = 20.0
            let velocity = pan.velocity(in: self.panel.view).y
            let currentHeight = self.panel.currentHeight

            let isMovingUpwards = velocity < -minVelocity
            let isMovingDownwards = velocity > minVelocity

            // all supported modes sorted by height, from smallest (.compact) to tallest (.fullScreen)
            let sortedModes = supportedModes.sorted { self.height(for: $0) < self.height(for: $1) }
            guard sortedModes.isEmpty == false else { return originalConfiguration.mode }

            // clear upwards flick -> snap to the next taller mode
            if isMovingUpwards {
                return sortedModes.first(where: { self.height(for: $0) > currentHeight }) ?? sortedModes.last!
            }

            // clear downwards flick -> snap to the next shorter mode
            if isMovingDownwards {
                return sortedModes.last(where: { self.height(for: $0) < currentHeight }) ?? sortedModes.first!
            }

            // no clear velocity -> snap to the mode whose height is closest to the current height
            return sortedModes.min(by: { abs(self.height(for: $0) - currentHeight) < abs(self.height(for: $1) - currentHeight) }) ?? originalConfiguration.mode
        }

        private func cleanUp(pan: PanOrScrollGestureRecognizer) {
            pan.cancelsTouchesInView = false

            guard let originalConfiguration = self.originalConfiguration else { return }

//            self.gestures.updateResizeHandle()
            self.panel.animator.animateChanges = originalConfiguration.animateChanges
            self.originalConfiguration = nil
        }

        private func height(for mode: FloatingMode) -> CGFloat {
            if mode == .fullScreen {
                return self.panel.constraints.maxHeight
            } else {
                return self.panel.size(for: mode).height
            }
        }

        private func initialVelocity(for pan: PanOrScrollGestureRecognizer, targetMode: FloatingMode) -> CGFloat {
            let velocity = pan.velocity(in: self.panel.view).y
            let currentHeight = self.panel.currentHeight
            let targetHeight = self.height(for: targetMode)

            let distance = targetHeight - currentHeight
            return abs(velocity / distance)
        }

        private func timing(for initialVelocity: CGFloat) -> UITimingCurveProvider {
            let springTiming = Animation.springy.makeTiming(with: initialVelocity)
            guard let originalConfiguration = self.originalConfiguration else { return springTiming }

            if originalConfiguration.mode == .halfScreen || initialVelocity < 13.0 {
                return Animation.overdamped.makeTiming(with: initialVelocity)
            } else {
                return springTiming
            }
        }

        private func animate(to targetMode: FloatingMode, initialVelocity: CGFloat) {
            let height = self.height(for: targetMode)
            let size = self.panel.size(for: targetMode)
            let timing = self.timing(for: initialVelocity)

            self.panel.constraints.prepareForPanEndAnimation()
            self.panel.configuration.mode = targetMode
            self.panel.animator.animateWithTiming(timing, animations: {
                self.panel.constraints.updateForPanEndAnimation(to: height)
                self.panel.animator.notifyDelegateOfTransition(to: size)
            }, completion: {
                self.panel.constraints.updateSizeConstraints(for: size)
            })
        }
    }
}

private extension PanelGestures {

    struct Configuration {
        let mode: FloatingMode
        let animateChanges: Bool
    }

    struct Animation {
        let mass: CGFloat
        let stiffness: CGFloat
        let damping: CGFloat

        static let springy: Animation = Animation(mass: 6.0, stiffness: 2400.0, damping: 195.0)
        static let overdamped: Animation = Animation(mass: 6.0, stiffness: 2400.0, damping: 250.0)

        func makeTiming(with velocity: CGFloat) -> UISpringTimingParameters {
            return UISpringTimingParameters(mass: self.mass, stiffness: self.stiffness, damping: self.damping, initialVelocity: CGVector(dx: velocity, dy: velocity))
        }
    }

    func makeVerticalPanGestureRecognizer() -> NoDelayPanGestureRecognizer {
        let pan = NoDelayPanGestureRecognizer(target: self.verticalPanState, action: #selector(VerticalGestureState.handlePan))
        pan.delegate = self
        pan.cancelsTouchesInView = false
        return pan
    }

    // allow pan gestures to be triggered within non-safe area on top (UINavigationBar)
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, isWithinContentAreaOf contentViewController: UIViewController) -> Bool {
        let offset: CGFloat = 10.0
        let safeAreaTop: CGFloat
        if let navigationController = contentViewController as? UINavigationController {
            safeAreaTop = navigationController.navigationBar.frame.maxY + offset
        } else {
            safeAreaTop = offset
        }

        let location = gestureRecognizer.location(in: self.panel.panelView)
        return location.y >= safeAreaTop
    }

    // allow pan gesture to be triggered when a) there's no scrollView or b) the scrollView can't be scrolled downwards
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, isAllowedToStartByContentOf contentViewController: UIViewController) -> Bool {
//        guard self.panel.configuration.gestureResizingMode.contains(.content) else { return false }

        guard let enclosingScrollView = self.verticallyScrollableView(of: contentViewController, interactingWith: gestureRecognizer) else { return true }
        // don't allow resizing gesture if textView is currently text editing
        if let textView = enclosingScrollView as? UITextView, textView.isFirstResponder {
            return false
        }

        return enclosingScrollView.isScrolledToTop
    }

    func verticallyScrollableView(of contentViewController: UIViewController, interactingWith gestureRecognizer: UIGestureRecognizer) -> UIScrollView? {
        let location = gestureRecognizer.location(in: contentViewController.view)
        guard let hitView = contentViewController.view.hitTest(location, with: nil) else { return nil }

        return hitView.findFirstSuperview(ofClass: UIScrollView.self, where: { $0.scrollsVertically })
    }
}

private extension UIView {

    func findFirstSuperview<T>(ofClass viewClass: T.Type, where predicate: (T) -> Bool) -> T? where T: UIView {
        var view: UIView? = self
        while view != nil {
            if let typedView = view as? T, predicate(typedView) {
                break
            }

            view = view?.superview
        }

        return view as? T
    }
}

private extension UIScrollView {

    var isScrolledToTop: Bool {
        return self.contentOffset.y <= -self.contentInset.top
    }

    var scrollsVertically: Bool {
        guard self.isScrollEnabled && self.isUserInteractionEnabled else { return false }

        let visibleHeight = self.bounds.height - self.adjustedContentInset.top - self.adjustedContentInset.bottom
        return self.alwaysBounceVertical || self.contentSize.height > visibleHeight
    }
}

private extension UIGestureRecognizer {

    func cancel() {
        guard self.isEnabled else { return }

        self.isEnabled = false
        self.isEnabled = true
    }
}

private extension FloatingViewControler {

    var currentHeight: CGFloat {
        return self.constraints.heightConstraint!.constant
    }
}

private extension CGPoint {

    enum Direction {
        case horizontal
        case vertical
    }

    func hypotenuse() -> CGFloat {
        return sqrt(self.x * self.x + self.y * self.y)
    }

    func direction() -> Direction {
        let horizontalDiff = self.x * self.x
        let verticalDiff = self.y * self.y

        return horizontalDiff > verticalDiff ? .horizontal : .vertical
    }
}
