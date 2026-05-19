//
//  LongPressGestureBlock.swift
//  SwiftUI-Components
//
//  Created by Pham Quang Huy on 2021/03/27.
//

import SwiftUI

struct LongPressGestureBlock: View {
    @GestureState var isDetectingLongPress = false
    @State var completedLongPress = false
    
    var longPress: some Gesture {
        LongPressGesture(minimumDuration: 3)
            .updating($isDetectingLongPress) { currentstate, gestureState,transaction in
                gestureState = currentstate
                transaction.animation = Animation.easeIn(duration: 2.0)
            }
            .onEnded { finished in
                self.completedLongPress = finished
            }
    }
    
    var body: some View {
        Text("LongPress Gesture")
            .foregroundColor(textColor())
            .gesture(longPress)
    }
    
    func textColor()->Color{
        return self.isDetectingLongPress ? Color.red :
            (self.completedLongPress ? .green : .accentColor)
    }
}
