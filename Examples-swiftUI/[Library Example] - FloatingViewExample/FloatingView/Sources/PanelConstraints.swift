//
//  PanelConstraints.swift
//  Aiolos
//
//  Created by Matthias Tretter on 13/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import UIKit


/// Internal class used for managing NSLayoutConstraints of the Panel
final class PanelConstraints {

    private unowned let panel: FloatingViewControler
    private var isTransitioning: Bool = false
    private var topConstraint: NSLayoutConstraint?
    private var topConstraintMargin: CGFloat = 0.0
    private var widthConstraint: NSLayoutConstraint?
    private var positionConstraints: [NSLayoutConstraint] = []
    private(set) var heightConstraint: NSLayoutConstraint?


    // MARK: - Lifecycle

    init(panel: FloatingViewControler) {
        self.panel = panel
    }

    // MARK: - PanelConstraints

    func updateSizeConstraints(for size: CGSize) {
        guard self.isTransitioning == false else { return }
        guard let widthConstraint = self.widthConstraint, let heightConstraint = self.heightConstraint else {
            self.activateSizeConstraints(for: size)
            return
        }

        self.panel.animator.animateIfNeeded {
            widthConstraint.constant = size.width
            heightConstraint.constant = size.height
        }
    }

    func updateConstraints() {
        guard self.isTransitioning == false else { return }
        guard let view = self.panel.view else { return }
        guard let parentView = self.panel.parent?.view else { return }
       
        let topConstraint = view.topAnchor.constraint(greaterThanOrEqualTo: parentView.safeAreaLayoutGuide.topAnchor,
                                                      constant: 0).withIdentifier("Panel Top")
        let leadingConstraint = view.leadingAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.leadingAnchor,
                                                              constant: 0).withIdentifier("Panel Leading")
        let trailingConstraint = view.trailingAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.trailingAnchor,
                                                                constant: 0).withIdentifier("Panel Trailing")
        
        var constraints = [
            view.bottomAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.bottomAnchor,
                                         constant: 0).configure { $0.priority = .defaultHigh; $0.identifier = "Panel Bottom" },
            view.bottomAnchor.constraint(lessThanOrEqualTo: parentView.safeAreaLayoutGuide.bottomAnchor,
                                         constant: 0).withIdentifier("Panel Bottom <="),
            topConstraint
        ]
        
        constraints += [
            leadingConstraint,
            trailingConstraint
        ]


        self.topConstraintMargin = topConstraint.constant
        self.panel.animator.animateIfNeeded {
            NSLayoutConstraint.deactivate(self.positionConstraints)
            self.topConstraint = topConstraint
            self.positionConstraints = constraints
            NSLayoutConstraint.activate(self.positionConstraints)
        }
    }
}

// MARK: - Internal (Dragging Support)

internal extension PanelConstraints {

    var safeArea: CGRect {
        guard let parentView = self.panel.parent?.view else { return .zero }

        var insets: NSDirectionalEdgeInsets = .zero

        return parentView.bounds.inset(by: UIEdgeInsets(directionalEdgeInsets: insets))
    }

    var effectiveBounds: CGRect {
        let insets = NSDirectionalEdgeInsets(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 0.0)
        return self.safeArea.inset(by: UIEdgeInsets(directionalEdgeInsets: insets))
    }

    var maxHeight: CGFloat {
        return self.panel.view.frame.maxY - self.safeArea.minY
    }

    func updateForPanStart(with currentSize: CGSize) {
        // the normal height constraint for .fullHeight can have a higher constant, but the actual height is constrained by the safeAreaInsets
        // this fixes this discrepancy by setting the heightConstraint's constant to the actual current height of the panel, when a drag starts
        self.heightConstraint?.constant = currentSize.height
        // we don't want to limit the height by the safeAreaInsets during dragging
        self.setTopConstraintIsRelaxed(true)
    }

    func updateForPan(with yOffset: CGFloat) {
        self.isTransitioning = true
        self.heightConstraint?.constant -= yOffset
    }

    func updateForPanEnd() {
        self.setTopConstraintIsRelaxed(false)
        self.isTransitioning = false
    }

    func prepareForPanEndAnimation() {
        self.isTransitioning = true
    }

    func updateForPanEndAnimation(to height: CGFloat) {
        self.heightConstraint?.constant = height
        self.panel.parent?.view.layoutIfNeeded()
        self.isTransitioning = false
    }

    func updateForPanCancelled(with targetSize: CGSize) {
        self.setTopConstraintIsRelaxed(false)
        self.isTransitioning = false
        self.updateSizeConstraints(for: targetSize)
    }

    func prepareForHorizontalPanEndAnimation() {
        self.isTransitioning = true
    }

    func updateForHorizontalPanEndAnimationCompleted() {
        self.isTransitioning = false
    }
}

// MARK: - Private

private extension PanelConstraints {
    func activateSizeConstraints(for size: CGSize) {
        let widthConstraint = self.panel.view.widthAnchor.constraint(equalToConstant: size.width).configure { constraint in
            constraint.identifier = "Panel Width"
            constraint.priority = .defaultHigh
        }

        let minHeightConstraint = self.panel.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).withIdentifier("Panel Min Height")
        let heightConstraint = self.panel.view.heightAnchor.constraint(equalToConstant: size.height).configure { constraint in
            constraint.identifier = "Panel Height"
            constraint.priority = .defaultHigh
        }

        self.widthConstraint = widthConstraint
        self.heightConstraint = heightConstraint
        NSLayoutConstraint.activate([widthConstraint, heightConstraint, minHeightConstraint])
    }

    func setTopConstraintIsRelaxed(_ relaxed: Bool) {
        guard let topConstraint = self.topConstraint else { return }

        if relaxed {
            topConstraint.constant = -50.0 // arbitrary number to let panel be dragged beyond the top
        } else {
            topConstraint.constant = self.topConstraintMargin
        }
    }
}

// MARK: - NSLayoutConstraint

private extension NSLayoutConstraint {

    func configure(_ configuration: (NSLayoutConstraint) -> Void) -> NSLayoutConstraint {
        configuration(self)
        return self
    }

    func withIdentifier(_ identifier: String) -> NSLayoutConstraint {
        return self.configure { constraint in
            constraint.identifier = identifier
        }
    }
}

// MARK: - UIEdgeInsets

private extension UIEdgeInsets {

//    init(directionalEdgeInsets: NSDirectionalEdgeInsets, isRTL: Bool) {
    init(directionalEdgeInsets: NSDirectionalEdgeInsets) {
        let left = directionalEdgeInsets.leading
        let right = directionalEdgeInsets.trailing

        self.init(top: directionalEdgeInsets.top, left: left, bottom: directionalEdgeInsets.bottom, right: right)
    }
}
