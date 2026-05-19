//
//  ContentView.swift
//  WhatsForDinner
//
//  Created by Matt Burke on 1/17/21.
//

import SwiftUI
import CoreData

struct ContentView: View {

    var body: some View {
        TabView {
            RestaurantPicker()
                .tabItem {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Picker")
                }

            SettingsPage()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .environmentObject(AppModel(restaurants: Restaurant.samples))
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
