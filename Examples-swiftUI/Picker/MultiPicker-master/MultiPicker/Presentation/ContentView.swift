//
//  ContentView.swift
//  MultiPicker
//
//  Created by Heiner Gerdes on 17.05.20.
//  Copyright © 2020 Heiner Gerdes. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @State var selectedView: Int = 1
    
    var body: some View {
        TabView(selection: self.$selectedView){
            HoursFormView()
                .tabItem {
                    VStack {
                        Image(systemName: "clock.fill")
                        Text("Hours Form")
                    }
            }.tag(0)
            
            Example1View()
                .tabItem {
                    VStack {
                        Image(systemName: "1.circle")
                        Text("Example 1")
                    }
            }.tag(1)
            
            Example2View()
                .tabItem {
                    VStack {
                        Image(systemName: "2.circle")
                        Text("Example 2")
                    }
            }.tag(2)
            
            
        }
    }
}
