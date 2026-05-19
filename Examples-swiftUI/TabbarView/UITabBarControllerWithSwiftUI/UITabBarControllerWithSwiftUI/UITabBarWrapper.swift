//
//  UITabBarWrapper.swift
//  UITabBarControllerWithSwiftUI
//
//  Created by Pham Quang Huy on 2021/05/01.
//
import SwiftUI

struct UITabBarWrapper: View {
    var controllers: [UIHostingController<TabBarElement>] // 1
    
    init(_ elements: [TabBarElement]) {
        self.controllers = elements.enumerated().map { // 2
            let hostingController = UIHostingController(rootView: $1)
            
            hostingController.tabBarItem = UITabBarItem( // 3
                title: $1.tabBarElementItem.title,
                image: UIImage.init(systemName: $1.tabBarElementItem.systemImageName),
                tag: $0 // 4
            )
            
            return hostingController
        }
    }
    
    var body: some View {
        UITabBarControllerWrapper(viewControllers: self.controllers) // 5
    }
}

struct UITabBarWrapper_Previews: PreviewProvider {
    static var previews: some View {
        UITabBarWrapper([
            TabBarElement(tabBarElementItem:
                            TabBarElementItem(title: "Test 1", systemImageName: "house.fill")) {
                Text("Test 1 Text")
            }
        ])
    }
}
