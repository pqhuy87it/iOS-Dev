//
//  SettingsPage.swift
//  WhatsForDinner
//
//  Created by Matt Burke on 1/17/21.
//

import SwiftUI

struct SettingsPage: View {

    @EnvironmentObject private var model: AppModel

    func onDelete(offsets: IndexSet) {
        model.restaurants.remove(atOffsets: offsets)
    }

    func onSave(restaurant: Restaurant) {
        let existingIndex = model.restaurants.firstIndex(where: { $0.id == restaurant.id })
        if let indexToUpdate = existingIndex {
            model.restaurants[indexToUpdate] = restaurant
        } else {
            model.restaurants.append(restaurant)
        }

    }


    var body: some View {
        NavigationView {
            List {
                ForEach(model.restaurants) { restaurant in
                    NavigationLink(destination: EditPage(original: restaurant, complete: onSave)) {
                        Text(restaurant.name)
                    }
                }
                .onDelete(perform: onDelete)
            }
            .navigationTitle("Settings")
            .navigationBarItems(
                leading: EditButton(),
                trailing:
                    NavigationLink(destination: EditPage(original: nil, complete: onSave)) {
                        Image(systemName: "plus.circle")
                    }
            )
        }
    }
}

struct SettingsPage_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPage()
            .environmentObject(AppModel.sample())
    }
}
