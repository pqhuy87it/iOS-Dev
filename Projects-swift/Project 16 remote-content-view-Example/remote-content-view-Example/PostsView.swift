//
//  PostsView.swift
//  remote-content-view-Example
//
//  Created by mybkhn on 2021/05/31.
//

import SwiftUI

let url = URL(string: "https://jsonplaceholder.typicode.com/posts")!

struct PostsView: View {
	let content = DecodableRemoteContent(url: url, type: [Post].self, decoder: JSONDecoder())

	var body: some View {
		RemoteContentView(remoteContent: content) { posts in
			List(posts, id: \Post.id) { post in
				VStack {
					Text(post.title)
					Text(post.body)
				}
			}
		}
	}
}

struct PostsView_Previews: PreviewProvider {
    static var previews: some View {
        PostsView()
    }
}
