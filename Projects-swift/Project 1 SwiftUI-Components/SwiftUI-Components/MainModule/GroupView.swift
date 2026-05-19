//
//  GroupView.swift
//  SwiftUI-Components
//
//  Created by Pham Quang Huy on 2021/01/09.
//

import SwiftUI

struct Grouping<Content: View>: View {
    var title: String
    var icon: String
    var content: () -> Content
    
    var body: some View {
        NavigationLink(destination: GroupView(title: title, content: content)) {
            Label(title, systemImage: icon).font(.headline).padding(.vertical, 8)
        }
    }
}

struct GroupView<Content: View>: View {
    var title: String
    let content: () -> Content
    
    var body: some View {
        return List {
            content()
        }
        .listStyle(InsetGroupedListStyle())
        .navigationBarTitle(title, displayMode: .inline)
    }
}

struct GroupView_Previews: PreviewProvider {
    static var previews: some View {
        GroupView(title: "Group", content: { Text("Content") })
            .previewLayout(.sizeThatFits)
    }
}
