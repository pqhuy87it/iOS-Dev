//
//  DetachedTaskAsyncLetDemoApp.swift
//  DetachedTaskAsyncLetDemo
//
//  Created by huy on 2026/04/16.
//

import SwiftUI

@main
struct DetachedTaskAsyncLetDemoApp: App {
    var body: some Scene {
        WindowGroup {
            AsyncLetCancellationView()
        }
    }
}
