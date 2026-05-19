//
//  CropImageViewRectangle.swift
//  CropImageView
//
//  Created by Pham Quang Huy on 2021/02/15.
//

import SwiftUI

struct CropImageViewRectangle: View {
    @Binding var currentPositionTopLeft: CGPoint
    @Binding var currentPositionTopRight: CGPoint
    @Binding var currentPositionBottomLeft: CGPoint
    @Binding var currentPositionBottomRight: CGPoint
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: self.currentPositionTopLeft)
                path.addLine(
                    to: .init(
                        x: self.currentPositionTopRight.x,
                        y: self.currentPositionTopRight.y
                    )
                )
                path.addLine(
                    to: .init(
                        x: self.currentPositionBottomRight.x,
                        y: self.currentPositionBottomRight.y
                    )
                )
                path.addLine(
                    to: .init(
                        x: self.currentPositionBottomLeft.x,
                        y: self.currentPositionBottomLeft.y
                    )
                )
                path.addLine(
                    to: .init(
                        x: self.currentPositionTopLeft.x,
                        y: self.currentPositionTopLeft.y
                    )
                )
            }
            .stroke(Color.blue, lineWidth: CGFloat(1))
        }
    }
}

