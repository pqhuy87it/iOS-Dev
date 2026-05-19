//
//  RestaurantPicker.swift
//  WhatsForDinner
//
//  Created by Matt Burke on 1/17/21.
//

import SwiftUI
import os

fileprivate var log = Logger(subsystem: "View", category: "RestaurantPicker")

struct RestaurantPicker: View {
    @EnvironmentObject private var model: AppModel
    @State private var restaurant: Restaurant? = Restaurant.samples[0];

    var restaurants: [Restaurant] { model.restaurants }

    var isLoaded: Bool { restaurant != nil }

    private func pickRestaurant() -> Restaurant? {
        if (restaurants.count == 0) {
            return nil;
        }

        if (restaurants.count == 1) {
            return restaurants[0];
        }

        var attempt: Restaurant;
        repeat {
            attempt = restaurants.randomElement()!
        } while attempt == restaurant

        log.debug("Found restaurant: [ \(attempt.name, privacy: .public)]")
        return attempt
    }

    func onAppear() {
        pickAgain()
    }

    func pickAgain() {
        log.info("Selecting from \(model.restaurants.count, privacy: .public) restaurants")
        restaurant = pickRestaurant()
    }

    var body: some View {
        VStack {
            if isLoaded {
                VStack {
                    Text("The almighty Restaurant Picker has chosen")
                        .multilineTextAlignment(.center)
                    Spacer()
                    Text(restaurant!.name)
                        .font(.largeTitle)
                    Spacer()

                    Button("I don't want it, pick again", action: pickAgain)
                        .buttonStyle(PrimaryButton())

                }
                .padding(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
            } else {
                Text("Loading...")
            }
        }
        .onAppear(perform: onAppear)
    }
}

struct RestaurantPicker_Previews: PreviewProvider {
    static var previews: some View {
        RestaurantPicker()
            .environmentObject(AppModel.sample())
    }
}
