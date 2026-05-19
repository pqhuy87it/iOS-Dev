//
//  ContentView.swift
//  WkWebViewJavaScrip
//
//  Created by mybkhn on 2021/02/28.
//

import SwiftUI

struct ContentView: View {
	var body: some View {
		let url = URL(string: "http://localhost/webLogin/pc/memberService")
		WebView(url: url!)
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
