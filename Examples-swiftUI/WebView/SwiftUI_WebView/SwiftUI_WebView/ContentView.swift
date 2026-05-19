//
//  ContentView.swift
//  SwiftUI_WebView
//
//  Created by Pham Quang Huy on 2021/01/17.
//

import SwiftUI

struct ContentView: View {
    @StateObject var webViewStore = WebViewStore()
    
    var body: some View {
        NavigationView {
            WebView(webView: webViewStore.webView)
                .navigationBarTitle(Text(verbatim: webViewStore.title ?? ""), displayMode: .inline)
                .navigationBarItems(trailing: HStack {
                    Button(action: goBack) {
                        Image(systemName: "chevron.left")
                            .imageScale(.large)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                    }.disabled(!webViewStore.canGoBack)
                    Button(action: goForward) {
                        Image(systemName: "chevron.right")
                            .imageScale(.large)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                    }.disabled(!webViewStore.canGoForward)
                })
        }.onAppear {
            self.webViewStore.webView.load(URLRequest(url: URL(string: "https://apple.com")!))
        }
    }
    
    func goBack() {
        webViewStore.webView.goBack()
    }
    
    func goForward() {
        webViewStore.webView.goForward()
    }
}
