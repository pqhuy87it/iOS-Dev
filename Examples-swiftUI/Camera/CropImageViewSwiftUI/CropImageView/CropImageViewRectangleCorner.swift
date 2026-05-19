//
//  CropImageViewRectangleCorner.swift
//  CropImageView
//
//  Created by Pham Quang Huy on 2021/02/15.
//

import SwiftUI

struct CropImageViewRectangleCorner: View {
    @Binding var currentPosition: CGPoint
    @Binding var newPosition: CGPoint
    
    var displacementX: CGFloat
    var displacementY: CGFloat
    
    var body: some View {
        Circle().foregroundColor(Color.blue).frame(width: 24,
												   height: 24)
            .offset(x: self.currentPosition.x,
					y: self.currentPosition.y)
            .gesture(DragGesture()
						.onChanged { value in
                            self.currentPosition = CGPoint(x: value.translation.width + self.newPosition.x,
														   y: value.translation.height + self.newPosition.y)
                        }
                        .onEnded { value in
                            self.currentPosition = CGPoint(x: value.translation.width + self.newPosition.x,
														   y: value.translation.height + self.newPosition.y)
                            self.newPosition = self.currentPosition
                        }
            )
            .opacity(0.5)
            .position(CGPoint(x: 0, y: 0))
            .onAppear() {
                if self.displacementX > 0 || self.displacementY > 0 {
                    self.currentPosition = CGPoint(x: self.displacementX,
												   y: self.displacementY)
                    self.newPosition = self.currentPosition
                }
            }
    }
}
