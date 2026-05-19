//
//  Item.swift
//  PassObjectToSubView
//
//  Created by mybkhn on 2021/03/01.
//

import SwiftUI

struct Item: Identifiable {
	var id = UUID()
	var title: String

	init(title: String) {
		self.title = title
	}
}
