//
//  TapGesture.swift
//  SwiftUI-Components
//
//  Created by Pham Quang Huy on 2021/03/27.
//

import SwiftUI

struct TapGestureBlock : View {
    @State var count = 1
    var body : some View {
        Group{
            HStack{
                Text("Tap Gesture")
                Spacer()
                Text("Tap count: \(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onTapGesture(count: count, perform: tapped)
    }
    func tapped() {
        self.count += 1
    }
}
