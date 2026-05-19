//
//  SearchableExampleApp.swift
//  SearchableExample
//
//  Created by huy on 2026/04/12.
//

import SwiftUI

@main
struct SearchableExampleApp: App {
    @State var dataSource = DataSource()
    
    var body: some Scene {
        WindowGroup {
            SearchView()
                .environment(dataSource)
        }
    }
}
