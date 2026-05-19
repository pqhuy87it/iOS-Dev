//
//  ContentView.swift
//  UITabBarControllerWithSwiftUI
//
//  Created by Pham Quang Huy on 2021/05/01.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        UITabBarWrapper([
            TabBarElement(tabBarElementItem: .init(title: "First", systemImageName: "house.fill")) {
                Text("First View")
            },
            TabBarElement(tabBarElementItem: .init(title: "Second", systemImageName: "pencil.circle.fill")) {
                Text("Second View")
            },
            TabBarElement(tabBarElementItem: .init(title: "Third", systemImageName: "folder.fill")) {
                Text("Third View")
            },
            TabBarElement(tabBarElementItem: .init(title: "Fourth", systemImageName: "tray.fill")) {
                Text("Fourth View")
            },
            TabBarElement(tabBarElementItem: .init(title: "Fifth", systemImageName: "doc.fill")) {
                Text("Fifth View")
            },
            TabBarElement(tabBarElementItem: .init(title: "Sixth", systemImageName: "link.circle.fill")) {
                Text("Sixth View")
            },
            TabBarElement(tabBarElementItem: .init(title: "Seventh", systemImageName: "person.fill")) {
                Text("Seventh View")
            }
        ])
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
