//
//  PrimaryButton.swift
//  WhatsForDinner
//
//  Created by Matt Burke on 1/17/21.
//

import Foundation
import SwiftUI

fileprivate let CORNER_RADIUS = CGFloat(8.0)

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(.white)
            .padding()
            .background(Color.pink)
            .cornerRadius(CORNER_RADIUS)
    }
}

struct SecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(.white)
            .padding()
            .background(Color.gray)
            .cornerRadius(CORNER_RADIUS)
    }
}
