//
//  PassValueObject.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/26.
//

import Foundation
import Combine

class PassValueObject: ObservableObject {
	@Published var value: String = ""
}
