//
//  ContentView.swift
//  PickerComponent
//
//  Created by Mickael Mas on 09/03/2020.
//  Copyright © 2020 APPIWEDIA. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    
    @State private var selection = 0
    @State private var meteoSelection = 0

    var body: some View {
        
        NavigationView {
            Form {
                Section {
                    Picker("Choisir un pays", selection: $selection) {
                        Text("France").tag(0)
                        Text("Italie").tag(1)
                        Text("Allemagne").tag(2)
                        Text("Espagne").tag(3)
                        Text("Brésil").tag(4)
                    }.padding()
                    .navigationBarTitle("Infos météo")
                    .labelsHidden() // Permet de masquer le label "Choisir un pays"
                }
                
                Section {
                    Picker("Quel temps fait-il ?", selection: $meteoSelection) {
                        
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .foregroundColor(.yellow)
                            Text("Ensoleillé")
                        }.tag(0)
                        
                        HStack {
                            Image(systemName: "cloud.fill")
                                .foregroundColor(.gray)
                            Text("Nuageux")
                        }.tag(1)

                        HStack {
                            Image(systemName: "snow")
                            .foregroundColor(.blue)
                            Text("Neigeux")
                        }.tag(2)
                        
                        HStack {
                            Image(systemName: "cloud.bolt.rain.fill")
                                .foregroundColor(.red)
                            Text("Orageux")
                        }.tag(3)
                        
                    }.padding()
                    .navigationBarTitle("Infos météo")
                    .labelsHidden() // Permet de masquer le label "Quel temps fait-il ?"
                }                
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
