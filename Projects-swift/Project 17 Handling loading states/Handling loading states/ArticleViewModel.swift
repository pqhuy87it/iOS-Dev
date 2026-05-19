//
//  ArticleViewModel.swift
//  Handling loading states
//
//  Created by mybkhn on 2021/06/14.
//

import SwiftUI

struct Article: Codable, Hashable, Identifiable {
	let id: Int?
	let title: String?
	let body: String?
}

class ArticleViewModel: ObservableObject, LoadableObject {

	@Published var state = LoadingState<[Article]>.idle
	
	func load() {
		
	}
}
