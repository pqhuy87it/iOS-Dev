//
//  AsyncContentView.swift
//  Handling loading states
//
//  Created by mybkhn on 2021/06/14.
//

import SwiftUI
import Combine

typealias DefaultProgressView = ProgressView<EmptyView, EmptyView>

struct AsyncContentView<Source: LoadableObject,
						LoadingView: View,
						Content: View>: View {
	@ObservedObject var source: Source
	var loadingView: LoadingView
	var content: (Source.Output) -> Content

	init(source: Source,
		 @ViewBuilder content: @escaping (Source.Output) -> Content) {
		self.source = source
		self.content = content
		self.loadingView = ProgressView() as! LoadingView
	}

	init(source: Source,
		 loadingView: LoadingView,
		 @ViewBuilder content: @escaping (Source.Output) -> Content) {
		self.source = source
		self.loadingView = loadingView
		self.content = content
	}

	var body: some View {
		switch source.state {
		case .idle:
			Color.clear.onAppear(perform: source.load)
		case .loading:
			loadingView
		case .failed(let error):
			Text(error.localizedDescription)
		case .loaded(let output):
			content(output)
		}
	}
}

extension AsyncContentView {
	init<P: Publisher>(
		source: P,
		@ViewBuilder content: @escaping (P.Output) -> Content
	) where Source == PublishedObject<P> {
		self.init(
			source: PublishedObject(publisher: source),
			content: content
		)
	}
}

extension AsyncContentView where LoadingView == DefaultProgressView {
	init(
		source: Source,
		@ViewBuilder content: @escaping (Source.Output) -> Content
	) {
		self.init(
			source: source,
			loadingView: ProgressView(),
			content: content
		)
	}
}
