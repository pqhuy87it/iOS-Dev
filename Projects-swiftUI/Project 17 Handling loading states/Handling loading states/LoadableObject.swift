//
//  LoadableObject.swift
//  Handling loading states
//
//  Created by mybkhn on 2021/06/14.
//

import SwiftUI

enum LoadingState<Value> {
	case idle
	case loading
	case failed(Error)
	case loaded(Value)
}

func ==<T: Codable>(lhs: LoadingState<T>, rhs: LoadingState<T>) -> Bool {
	if case .loading = lhs, case .loading = rhs {
		return true
	}
	return false
}

protocol LoadableObject: ObservableObject {
	associatedtype Output
	var state: LoadingState<Output> { get }
	func load()
}
