//
//  UniversalLinksDemoApp.swift
//  UniversalLinksDemo
//
//  Created by huy on 2026/05/11.
//

import SwiftUI

@main struct UniversalLinksDemoApp: App {
    @StateObject private var registrationStore = RegistrationStore()
    @StateObject private var appState = AppState()
    @StateObject private var deepLinkCoordinator = DeepLinkCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(registrationStore)
                .environmentObject(appState)
                .environmentObject(deepLinkCoordinator)
                .onOpenURL { url in
                    deepLinkCoordinator.handle(url)
                }
                .task {
                    // Setup coordinator
                    deepLinkCoordinator.configure(store: registrationStore,
                                                  appState: appState)

                    // Restore route theo step đã lưu (resume sau khi kill app)
                    if registrationStore.currentStep != .notStarted {
                        appState.route = .registration
                    }

                    // Báo coordinator: app ready, replay pending deep link nếu có
                    deepLinkCoordinator.appDidBecomeReady()
                }
        }
    }
}
