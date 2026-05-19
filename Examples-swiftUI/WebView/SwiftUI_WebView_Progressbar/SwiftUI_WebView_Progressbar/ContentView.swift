//
//  ContentView.swift
//  SwiftUI_WebView_Progressbar
//
//  Created by Pham Quang Huy on 2021/01/17.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        Webview(url: URL(string: "https://www.apple.com")!)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
