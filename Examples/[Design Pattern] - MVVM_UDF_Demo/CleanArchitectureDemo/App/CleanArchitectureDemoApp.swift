import SwiftData
import SwiftUI

@main struct CleanArchitectureDemoApp: App {
    var environment = AppEnvironment.bootstrap()

    /// Khởi tạo Factory thật ở cấp cao nhất
    @StateObject private var factory: AppViewModelFactory

    init() {
        let env = AppEnvironment.bootstrap()
        environment = env
        _factory = StateObject(wrappedValue: AppViewModelFactory(interactors: env.diContainer.interactors))
    }

    var body: some Scene {
        WindowGroup {
            CleanArchitectureMainView()
                .modelContainer(environment.modelContainer)
                .injectFactory(factory)
        }
    }
}
