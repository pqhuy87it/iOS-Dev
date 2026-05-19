//
//  ButtonPressedStyle.swift
//  SwiftUI-Components
//
//  Created by Pham Quang Huy on 2021/01/10.
//

import SwiftUI

struct ButtonStyleParams {
    let scale: Double
    let rotation: Double
    let blur: Double
    let color: Color
    let unpressedColor: Color
    let animate: Bool
    let response: Double
    let damping: Double
    let duration: Double
}

struct ButtonPressedStyle: ButtonStyle {
    var style: ButtonStyleParams
    var drawBackground: Bool
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .background(Capsule()
                            .foregroundColor(configuration.isPressed ? style.color : style.unpressedColor)
                            .opacity(drawBackground ? 1 : 0))
            .scaleEffect(configuration.isPressed ? CGFloat(style.scale) : 1.0)
            .rotationEffect(.degrees(configuration.isPressed ? style.rotation : 0))
            .blur(radius: configuration.isPressed ? CGFloat(style.blur) : 0)
            .animation(style.animate ? Animation.spring(response: style.response, dampingFraction: style.damping, blendDuration: style.duration) : .none)
    }
}
