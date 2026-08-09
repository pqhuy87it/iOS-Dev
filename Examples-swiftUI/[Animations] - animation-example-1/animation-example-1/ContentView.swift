//
//  ContentView.swift
//  Shared
//
//  Created by Jimmy S on 14/04/22.
//

import SwiftUI

/// Represents a single animation that can be pushed onto the navigation stack.
struct AnimationItem: Identifiable {
    let id = UUID()
    let title: String
    let view: AnyView

    init<Content: View>(_ title: String, @ViewBuilder view: () -> Content) {
        self.title = title
        self.view = AnyView(view())
    }
}

struct ContentView: View {

    private let animations: [AnimationItem] = [
        AnimationItem("Line Wave") { LineWaveAnimation(color: .white) },
        AnimationItem("Wave") { WaveAnimation(color: .white, iconColor: .black) },
        AnimationItem("Dots") { DotsAnimation(color: .white) },
        AnimationItem("Arc Rotation") { ArcRotationAnimation(color: .white) },
        AnimationItem("Heart") { HeartAnimation(color: .white) },
        AnimationItem("Flipping Square") { FlippingSquare(color: .white) },
        AnimationItem("Pacman") { PacmanAnimation(color: .white) },
        AnimationItem("Rotating Dot") { RotatingDotAnimation(color: .white) },
        AnimationItem("Square Fill") { SquareFillAnimation(color: .white) },
        AnimationItem("Stepper") { StepperAnimation(color: .white) },
        AnimationItem("Three Bounce") { ThreeBounceAnimation(color: .white) },
        AnimationItem("Three Circle Blink Dots") { ThreeCircleBlinkDots(color: .white) },
        AnimationItem("Three Circle Blinking Lines") { ThreeCircleBlinkingLines(color: .white) },
        AnimationItem("Three Horizontal Swaping Dots") { ThreeHorizontalSwapingDots(color: .white) },
        AnimationItem("Three Rotating Dots") { ThreeRotatingDots(color: .white) },
        AnimationItem("Three Triangle Rotating Dots") { ThreeTriangleRotatingDots(color: .white) },
        AnimationItem("Three Triangle Swaping Dots") { ThreeTriangleSwapingDots(color: .white) },
        AnimationItem("Twin Circle Scale") { TwinCircleScale() },
        AnimationItem("Twin Circle Transition") { TwinCircleTransition() },
        AnimationItem("Clock") { ClockAnimation() }
    ]

    var body: some View {
        NavigationStack {
            List(animations) { item in
                NavigationLink(item.title) {
                    ZStack {
                        Color.init("bgColor")
                        item.view
                    }
                    .ignoresSafeArea()
                    .navigationTitle(item.title)
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .navigationTitle("Animations")
        }
    }
}

#Preview {
    ContentView()
}
