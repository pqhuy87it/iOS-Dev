//
//  PanelDelegate.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import UIKit


// The various delegates of a Panel are informed about relevant events

// MARK: - PanelSizeDelegate

public protocol PanelSizeDelegate: AnyObject {

    /// Asks the delegate for the size of the panel in a specific mode. either width or height might be ignored, based on the mode
    func panel(_ panel: FloatingViewControler, sizeForMode mode: FloatingMode) -> CGSize

    /// Asks the delegate for the size class it should set for its contentViewController
    func panelSizeClassesForContentViewController(_ panel: FloatingViewControler) -> (horizontal: UIUserInterfaceSizeClass, vertical: UIUserInterfaceSizeClass)
}

public extension PanelSizeDelegate {

    func panelSizeClassesForContentViewController(_ panel: FloatingViewControler) -> (horizontal: UIUserInterfaceSizeClass, vertical: UIUserInterfaceSizeClass) {
        return (.compact, .compact)
    }
}

// MARK: - PanelResizeDelegate

public protocol PanelResizeDelegate: AnyObject {

    /// Tells the delegate that the `panel` has started resizing
    func panelDidStartResizing(_ panel: FloatingViewControler)

    /// Tells the delegate that the `panel` is resizing to a specific size
    func panel(_ panel: FloatingViewControler, willResizeTo size: CGSize)

    /// Tells the delegate that the `panel` is transitioning to a specific mode
    func panel(_ panel: FloatingViewControler, willTransitionFrom oldMode: FloatingMode?, to newMode: FloatingMode, with coordinator: PanelTransitionCoordinator)
}

// MARK: - PanelRepositionDelegate

public protocol PanelRepositionDelegate: AnyObject {
    /// Asks the delegate whether the `panel` can be removed from its parent
    func panelCanBeDismissed(_ panel: FloatingViewControler) -> Bool

    /// Tells the delegate that the `panel` will move to a specific frame
    /// Returning `false`, will result in a rubber-band effect
    func panel(_ panel: FloatingViewControler, willMoveTo frame: CGRect) -> Bool

    /// Tells the delegate that the `panel` did stop moving
//    func panel(_ panel: Panel, didStopMoving endFrame: CGRect, with context: PanelRepositionContext) -> PanelRepositionContext.Instruction

    // Tells the delegate that the `panel` is transitioning to a specific position
    func panel(_ panel: FloatingViewControler, with coordinator: PanelTransitionCoordinator)

    // Tells the delegate that the `panel` is transitioning to a hidden state
    func panelWillTransitionToHiddenState(_ panel: FloatingViewControler, with coordinator: PanelTransitionCoordinator)
}
