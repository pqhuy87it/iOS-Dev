//
//  ContentView.swift
//  ReusableContentLoadingView
//
//  Created by mybkhn on 2021/05/06.
//

import SwiftUI

struct ContentView: View {
	let url = URL(string: "https://jsonplaceholder.typicode.com/posts")!

    var body: some View {
		let content = DecodableRemoteContent(url: url, type: [Post].self, decoder: JSONDecoder())

		RemoteContentView(remoteContent: content,
						  empty: {
							EmptyView()
						  },
						  inProgress: { progress in
							Text(verbatim: "Loading in progress: \(String(describing: progress))")
						  },
						  failure: { error, retry in
							VStack {
								Text("error")
								Button("Retry", action: retry)
							}
						  },
						  content: { posts in
							List(posts, id: \Post.id) { post in
								VStack {
									Text(post.title)
									Text(post.body)
								}
							}
						  })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
