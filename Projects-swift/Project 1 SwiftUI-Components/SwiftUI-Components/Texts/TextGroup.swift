//
//  TextGroup.swift
//  SwiftUI-Components
//
//  Created by Pham Quang Huy on 2021/01/10.
//

import SwiftUI

struct TextGroup: View {
    @State private var text = ""
    @State private var password = ""
    @State private var textEditor = ""
    
    var body: some View {
        Group {
            let extractedExpr = SectionView(headerTitle: "Text", footerTitle: "A view that displays one or more lines of read-only text.", content: {
                Text("Example")
            })
            extractedExpr
            
            SectionView(headerTitle: "TextField", footerTitle: "A control that displays an editable text interface.", content: {
                TextField("Placeholder", text: $text)
            })
            
            SectionView(headerTitle: "SecureField", footerTitle: "A control into which the user securely enters private text.", content: {
                SecureField("Password", text: $password)
            })
            
            SectionView(headerTitle: "Redacted", footerTitle: "Modifier which hides the text, for example while loading.", content: {
                Text("You cannot read me")
                    .redacted(reason: .placeholder)
            })
            
            SectionView(headerTitle: "TextEditor", footerTitle: "A view that can display and edit long-form text.", content: {
                TextEditor(text: $textEditor)
                    .frame(height: 88)
            })
        }
    }
}

struct TextGroup_Previews: PreviewProvider {
    static var previews: some View {
        TextGroup()
    }
}
