//
//  DataInputView.swift
//  PageViewWithKeyboard
//
//  Created by Pham Quang Huy on 2021/03/08.
//

import SwiftUI

struct DataInputView: View {
    @State var name: String = ""
    
    var body: some View {
        VStack {
            Image(uiImage: UIImage(named: "image.jpg")!)
                .resizable()
                .padding()
            
            Spacer()
            
            TextField("", text: $name)
                .padding()
                .adaptToKeyboard()
        }
    }
}

struct DataInputView_Previews: PreviewProvider {
    static var previews: some View {
        DataInputView()
    }
}
