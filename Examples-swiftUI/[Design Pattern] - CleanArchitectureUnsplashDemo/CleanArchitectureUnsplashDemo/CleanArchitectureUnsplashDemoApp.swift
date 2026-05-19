import SwiftUI
import SwiftData

@main
struct CleanArchitectureUnsplashDemoApp: App {
    let environment = AppEnvironment.bootstrap()
    
    var body: some Scene {
        WindowGroup {
            CleanArchitectureMainView()
                .modelContainer(environment.modelContainer)
                .inject(environment.diContainer)
        }
    }
}
