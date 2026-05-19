//
//  applicationWillTerminateDemoApp.swift
//  applicationWillTerminateDemo
//
//  Created by huy on 2026/05/02.
//

import SwiftUI

@main
struct applicationWillTerminateDemoApp: App {
    // Inject AppDelegate vào SwiftUI
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
