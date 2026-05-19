//
//  AppModel.swift
//  WhatsForDinner
//
//  Created by Matt Burke on 1/17/21.
//

import Foundation

class AppModel: ObservableObject {
    @Published var restaurants: [Restaurant]

    init(restaurants: [Restaurant]) {
        self.restaurants = restaurants
    }

    static func sample() -> AppModel {
        AppModel(restaurants: Restaurant.samples)
    }
}
