//
//  ButtonsGroup.swift
//  SwiftUI-Components
//
//  Created by Pham Quang Huy on 2021/01/09.
//

import SwiftUI

let DEFAULT_SCALE: Double = 0.85
let DEFAULT_ROTATION: Double = 0
let DEFAULT_BLUR: Double = 0
let DEFAULT_COLOR: Color = Color.primary.opacity(0.75)
let DEFAULT_ANIMATE: Bool = true
let DEFAULT_RESPONSE: Double = 0.35
let DEFAULT_DAMPING: Double = 0.35
let DEFAULT_DURATION: Double = 1
let DEFAULT_BUTTONCOLOR: Color = Color.black
let DEFAULT_TEXTCOLOR: Color = Color.white

struct ButtonsGroup: View {
    @State private var showingAlert = false
    @State private var showingSheet = false
    @State private var showingActionSheet = false
    @State private var showButtonSheet = false
    
    @State private var scale = DEFAULT_SCALE
    @State private var rotation = DEFAULT_ROTATION
    @State private var blur = DEFAULT_BLUR
    @State private var color = DEFAULT_COLOR
    @State private var buttonColor = DEFAULT_BUTTONCOLOR
    @State private var textColor = DEFAULT_TEXTCOLOR
    @State private var animate = DEFAULT_ANIMATE
    @State private var response = DEFAULT_RESPONSE
    @State private var damping = DEFAULT_DAMPING
    @State private var duration = DEFAULT_DURATION
    
    var body: some View {
        Group {
            SectionView(headerTitle: "Button",
                        footerTitle: "A control that performs an action when triggered.",
                        content: {
                Group {
                    Button(action: {
                        self.showingAlert = true
                    }) {
                        Text("Show Alert")
                    }
                    .alert(isPresented: $showingAlert) {
                        Alert(title: Text("Title"),
                              message: Text("Message"),
                              primaryButton: .default(Text("Confirm")),
                              secondaryButton: .cancel()
                        )
                    }
                    
                    Button(action: {
                        self.showingSheet = true
                    }) {
                        Text("Show Sheet")
                    }.sheet(isPresented: $showingSheet) {
                        Text("Sheet").padding()
                    }
                    
                    Button(action: {
                        self.showingActionSheet = true
                    }) {
                        Text("Show Action Sheet")
                    }
                    .actionSheet(isPresented: $showingActionSheet) {
                        ActionSheet(title: Text("Title"), message: Text("Message"), buttons: [
                            .destructive(Text("Delete")),
                            .default(Text("Option 1")) { },
                            .default((Text("Option 2"))) { },
                            .cancel()
                        ])
                    }
                    
                    Button(action: { }) {
                        Text("tap here")
                            .modifier(TestButton(textColor: textColor))
                    }
                    .buttonStyle(ButtonPressedStyle(style: getParams(), drawBackground: true))
                    .foregroundColor(buttonColor)
                    
                    Button(action: { }) {
                        Image(systemName: "star.fill")
                            .modifier(TestButton(textColor: textColor))
                    }
                    .buttonStyle(ButtonPressedStyle(style: getParams(), drawBackground: true))
                    .foregroundColor(buttonColor)
                }
            })
        }
    }
    
    private func getParams() -> ButtonStyleParams {
        return ButtonStyleParams(scale: scale,
                                 rotation: rotation,
                                 blur: blur,
                                 color: color,
                                 unpressedColor: buttonColor,
                                 animate: animate,
                                 response: response,
                                 damping: damping,
                                 duration: duration)
    }
}

struct ButtonsGroup_Previews: PreviewProvider {
    static var previews: some View {
        ButtonsGroup()
    }
}
