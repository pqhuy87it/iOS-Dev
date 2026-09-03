//
//  AlamofireSampleMainView.swift
//  AlamofireSample
//
//  Created by Pham Quang Huy on 7/7/26.
//

import SwiftUI

struct AlamofireSampleMainView: View {
    var body: some View {
            TabView {
                PhotosListView()
                    .tabItem { Label("Home", systemImage: "house") }

                TopicsListView()
                    .tabItem { Label("Topics", systemImage: "square.grid.2x2") }

                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
            }
        }
}

#Preview {
    AlamofireSampleMainView()
}
