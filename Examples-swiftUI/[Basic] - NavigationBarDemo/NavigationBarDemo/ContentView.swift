//
//  ContentView.swift
//  NavigationBarDemo
//
//  Created by huy on 2026/04/18.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Hello World!")
            }
            .navigationTitle("NavigatioBar Demo")
//            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") { }
                }
            }
        }
        
    }
}

#Preview {
    ContentView()
}
