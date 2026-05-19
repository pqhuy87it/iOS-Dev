//
//  WebView.swift
//  WkWebViewJavaScrip
//
//  Created by mybkhn on 2021/02/28.
//

import SwiftUI

import SwiftUI

import WebKit



struct WebView: UIViewRepresentable {

	var url: URL

	func makeUIView(context: Context) -> WKWebView {

		let webConfig = WKWebViewConfiguration()

		let userController = WKUserContentController()

		userController.add(makeCoordinator(), name: "hoge")

		webConfig.userContentController = userController

		let wkWebView = WKWebView(frame: .zero, configuration: webConfig)

		return wkWebView

	}



	func updateUIView(_ uiView: WKWebView, context: Context) {

		 let req = URLRequest(url: url)

		 uiView.load(req)

//		guard let path: String = Bundle.main.path(forResource: "index", ofType: "html") else { return }
//
//		let localHTMLUrl = URL(fileURLWithPath: path, isDirectory: false)
//
//		uiView.loadFileURL(localHTMLUrl, allowingReadAccessTo: localHTMLUrl)

	}

	/*

	これだと動かない

	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

	if message.name == "hoge" {

	print("JavaScript is sending a message \(message.body)")

	}

	}

	*/

	func makeCoordinator() -> WebView.Coordinator {

		return Coordinator()

	}



} // struct

extension WebView {

	class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {

		func userContentController(

			_ userContentController: WKUserContentController,

			didReceive message: WKScriptMessage) {

			if message.name == "hoge" {

				let number = message.body as! Int

				print("JavaScript is sending a number \(number)")

			}

		}

		func webView(_ webView: WKWebView, decidePolicyFor navigationResponse:
						WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
			decisionHandler(.allow)
		}
		

	}

}



struct WebView_Previews: PreviewProvider {

	static var previews: some View {

		WebView(url: URL(string: "dummy")!)

	}

}
