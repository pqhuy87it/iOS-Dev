//
//  DragGestureBlock.swift
//  SwiftUI-Components
//
//  Created by Pham Quang Huy on 2021/03/27.
//

import SwiftUI

struct DragGestureBlock : View {
    @State var color : Color = .accentColor
    
    var body : some View {
        Text("Drag Gesture")
            .gesture(drag)
            .foregroundColor(color)
    }
    
    var drag: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                self.color = (value.distance > 300) ? .green : .red
            }
            .onEnded { value in
                self.color = (value.distance > 300) ? .green : .accentColor
            }
    }
}
