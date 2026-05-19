//
//  ImageView.swift
//  remote-content-view-Example
//
//  Created by mybkhn on 2021/05/31.
//

import SwiftUI

let imageUrl = URL(string: "https://scx1.b-cdn.net/csz/news/800a/2019/galaxy.jpg")!

struct ImageView: View {
	let remoteImage = RemoteImage(url: imageUrl)

    var body: some View {
		RemoteContentView(remoteContent: remoteImage) {
			Image(uiImage: $0)
		}
    }
}

struct ImageView_Previews: PreviewProvider {
    static var previews: some View {
        ImageView()
    }
}
