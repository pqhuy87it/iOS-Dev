//
//  EntryAppearanceDescriptor.swift
//  SwiftEntryKit
//
//  Created by Daniel Huri on 1/5/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

internal import UIKit

/**
 An anti-pattern for SwiftEntryKit views to know more about their appearence,
 if necessary, since views don't have access to EKAttributes.
 This is a solution to bug #117 (round buttons in alert)
 */
protocol EntryAppearanceDescriptor: AnyObject {
    var bottomCornerRadius: CGFloat { get set }
}
