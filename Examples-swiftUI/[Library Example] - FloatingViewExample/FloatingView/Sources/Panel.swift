//
//  Panel.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import UIKit


/// A floating Panel inspired by the iOS 11 Maps.app UI
@objc
public class FloatingViewControler: UIViewController {

    private lazy var gestures: PanelGestures = self.makeGestures()
    private(set) lazy var constraints: PanelConstraints = self.makeConstraints()
    private(set) lazy var animator: PanelAnimator = self.makeAnimator()
    private var _configuration: FloatingConfiguration {
        didSet {
            self.handleConfigurationChange(from: oldValue, to: self.configuration)
        }
    }

    // MARK: - Properties
    public lazy var panelView: UIView  = self.makePanelView()
    @objc public var isVisible: Bool { return self.parent != nil && self.animator.isMovingFromParent == false }
    public weak var sizeDelegate: PanelSizeDelegate?
    public weak var resizeDelegate: PanelResizeDelegate?
    public weak var repositionDelegate: PanelRepositionDelegate?
    public weak var gestureDelegate: UIGestureRecognizerDelegate?

    var configuration: FloatingConfiguration {
        get { return self._configuration }
        set { self._configuration = newValue.validated() }
    }

    @objc public var contentViewController: UIViewController? {
        didSet {
            self.exchangeContentViewController(oldValue, with: self.contentViewController)
            self.view.setNeedsLayout()
            self.fixLayoutMargins()
        }
    }

    // MARK: - Lifecycle

    init(configuration: FloatingConfiguration) {
        self._configuration = configuration.validated()
        super.init(nibName: nil, bundle: nil)
    }

    @objc
    public convenience init() {
        self.init(configuration: .default)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - UIViewController

public extension FloatingViewControler {

    override var shouldAutomaticallyForwardAppearanceMethods: Bool {
        return false
    }

    override var isMovingToParent: Bool {
        return self.animator.isMovingToParent
    }

    override var isMovingFromParent: Bool {
        return self.animator.isMovingFromParent
    }

    override func loadView() {
        self.view = self.makeShadowView(for: self.panelView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.gestures.install()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.panelView.frame = self.view.bounds
        self.contentViewController?.view.frame = self.panelView.bounds
        self.fixLayoutMargins()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.contentViewController?.viewWillTransition(to: size, with: coordinator)
    }

    override func overrideTraitCollection(forChild childViewController: UIViewController) -> UITraitCollection? {
        let sizeClasses = self.sizeDelegate?.panelSizeClassesForContentViewController(self) ?? (.compact, .compact)
        let horizontalTraits = UITraitCollection(horizontalSizeClass: sizeClasses.horizontal)
        let verticalTraits = UITraitCollection(verticalSizeClass: sizeClasses.vertical)

        return UITraitCollection(traitsFrom: [horizontalTraits, verticalTraits])
    }
}

// MARK: - Panel

public extension FloatingViewControler {

    func add(to parent: UIViewController, at position: Int? = nil, completion: (() -> Void)? = nil) {
        guard self.parent !== parent || self.animator.isMovingFromParent else { return }

        if self.animator.isMovingFromParent {
            self.animator.stopCurrentAnimation()
        }

        let contentViewController = self.contentViewController
        contentViewController?.beginAppearanceTransition(true, animated: true)

        parent.addChild(self)
        if let position = position {
            parent.view.insertSubview(self.view, at: position)
        } else {
            parent.view.addSubview(self.view)
        }
        self.didMove(toParent: parent)

        let size = self.size(for: self.configuration.mode)
        
        self.animator.addToParent(with: size) {
            contentViewController?.endAppearanceTransition()
            self.fixLayoutMargins()
            completion?()
        }

    }

    func removeFromParentView(completion: (() -> Void)? = nil) {
        guard self.parent != nil || self.animator.isMovingToParent else { return }

        if let repositionDelegate = self.repositionDelegate {
            guard repositionDelegate.panelCanBeDismissed(self) else { return }
        }

        if self.animator.isMovingToParent {
            self.animator.stopCurrentAnimation()
        }

        let contentViewController = self.contentViewController
        contentViewController?.beginAppearanceTransition(false, animated: true)
        self.willMove(toParent: nil)
        self.animator.removeFromParent {
            contentViewController?.endAppearanceTransition()
            self.view.removeFromSuperview()
            self.removeFromParent()
            completion?()
        }
    }

    func performWithoutAnimation(_ changes: () -> Void) {
        let animateChanges = self.animator.animateChanges
        self.animator.animateChanges = false
        defer { self.animator.animateChanges = animateChanges }

        changes()
    }

    func reloadSize() {
        let size = self.size(for: self.configuration.mode)

        self.animator.notifyDelegateOfTransition(to: size)
        self.constraints.updateSizeConstraints(for: size)
    }
    
}

// MARK: - Internal

internal extension FloatingViewControler {

    func size(for mode: FloatingMode) -> CGSize {
        guard let sizeDelegate = self.sizeDelegate else { return .zero }
        guard let parent = self.parent else { return .zero }

        let delegateSize = sizeDelegate.panel(self, sizeForMode: mode)

        // we overwrite the width in .bottom position
        let width: CGFloat = parent.view.frame.width

        // we overwrite the height in .minimal/.fullHeight mode
        let height: CGFloat
        switch mode {
        case .fullScreen:
            let screen = parent.view.window?.screen ?? UIScreen.main
            height = screen.fixedCoordinateSpace.bounds.height
        case .halfScreen, .compact:
            height = delegateSize.height
        }

        return CGSize(width: width, height: height)
    }

    // this is a workaround for a layout bug, when the panel is placed within non-safe areas.
    // the navigationBar automatically inherits the safeAreaInsets of the device, but we don't want that.
    // the panel itself takes care that the contentViewController is fully visible so all its children
    // should have no safeAreaInsets set
    func fixLayoutMargins() {
        func visit(_ view: UIView) {
            view.insetsLayoutMarginsFromSafeArea = false
            view.subviews.forEach(visit(_:))

            if view.superview is UINavigationBar {
                let safeAreaConstraints = view.constraints.filter { constraint in
                    guard let identifier = constraint.identifier else { return false }

                    return identifier.hasPrefix("UIView" + "SafeAre" + "aLayout" + "Guide") || identifier.hasSuffix("-guide" + "-constraint")
                }

                for constraint in safeAreaConstraints {
                    constraint.constant = 0.0
                }
            }
        }

        if let view = self.contentViewController?.view {
            visit(view)
        }
    }
}

// MARK: - Private

// MARK: - Factory

private extension FloatingViewControler {

    func makePanelView() -> UIView {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }

    func makeShadowView(for view: UIView) -> UIView {
        let shadowView = UIView()
        let container = UIView()

        container.translatesAutoresizingMaskIntoConstraints = false
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        shadowView.addSubview(container)
        container.addSubview(view)

        NSLayoutConstraint.activate([
            shadowView.topAnchor.constraint(equalTo: container.topAnchor),
            shadowView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            shadowView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            shadowView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])

        return shadowView
    }


    func makeGestures() -> PanelGestures {
        return PanelGestures(panel: self)
    }

    func makeConstraints() -> PanelConstraints {
        return PanelConstraints(panel: self)
    }

    func makeAnimator() -> PanelAnimator {
        return PanelAnimator(panel: self)
    }
}

// MARK: - Layout

private extension FloatingViewControler {

    func exchangeContentViewController(_ oldContentViewController: UIViewController?, with newContentViewController: UIViewController?) {
        let callAppearanceMethods = self.isVisible || self.isMovingToParent

        // remove old contentViewController
        if let oldContentViewController = oldContentViewController {
            if callAppearanceMethods { oldContentViewController.beginAppearanceTransition(false, animated: false) }
            oldContentViewController.willMove(toParent: nil)
            oldContentViewController.view.removeFromSuperview()
            oldContentViewController.removeFromParent()
            if callAppearanceMethods { oldContentViewController.endAppearanceTransition() }
        }

        // add new contentViewController
        if let newContentViewController = newContentViewController {
            if callAppearanceMethods { newContentViewController.beginAppearanceTransition(true, animated: false) }
            self.addChild(newContentViewController)
            newContentViewController.view.translatesAutoresizingMaskIntoConstraints = true
            newContentViewController.view.frame = self.panelView.bounds
            self.panelView.addSubview(newContentViewController.view)
            newContentViewController.didMove(toParent: self)
            if callAppearanceMethods { newContentViewController.endAppearanceTransition() }
        }
    }

    func handleConfigurationChange(from oldConfiguration: FloatingConfiguration, to newConfiguration: FloatingConfiguration) {

        guard self.isVisible else { return }

        let modeChanged = oldConfiguration.mode != newConfiguration.mode

        if modeChanged {
            self.gestures.cancel()
        }

        if modeChanged  {
            let size = self.size(for: newConfiguration.mode)

            if modeChanged { self.animator.notifyDelegateOfTransition(from: oldConfiguration.mode, to: newConfiguration.mode) }
            self.animator.notifyDelegateOfTransition(to: size)
            self.constraints.updateSizeConstraints(for: size)
        }
    }
}
