//
//  TestButton.swift
//  SwiftUI-Components
//
//  Created by Pham Quang Huy on 2021/01/10.
//

import SwiftUI

struct TestButton: ViewModifier {
    
    let textColor: Color
    
    func body(content: Content) -> some View {
        content
            .font(Font.body.bold())
            .imageScale(.large)
            .padding()
            .foregroundColor(textColor)
        //            .colorInvert()
    }
}
