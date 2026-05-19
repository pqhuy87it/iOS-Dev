//
//  View+Extension.swift
//  DetectDeviceRotation
//
//  Created by mybkhn on 2021/03/23.
//

import SwiftUI

// A View wrapper to make the modifier easier to use
extension View {
	func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
		self.modifier(DeviceRotationViewModifier(action: action))
	}
}
