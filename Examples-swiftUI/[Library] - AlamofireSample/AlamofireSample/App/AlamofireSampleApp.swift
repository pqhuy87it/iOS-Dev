//
//  AlamofireSampleApp.swift
//  AlamofireSample
//
//  Created by Pham Quang Huy on 7/7/26.
//

import SwiftUI
import SwiftData

@main
struct AlamofireSampleApp: App {
    // Build the real dependency graph (repositories + interactors) once.
    private let environment = AppEnvironment.bootstrap()

    var body: some Scene {
        WindowGroup {
            AlamofireSampleMainView()
                // Inject the real DIContainer so views use the live interactors
                // instead of the `.stub` fallback default.
                .inject(environment.diContainer)
                .modelContainer(environment.modelContainer)
        }
    }
}
