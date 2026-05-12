import SwiftData
import SwiftUI

@main struct CleanArchitectureDemoApp: App {
    var environment = AppEnvironment.bootstrap()

    @StateObject private var factory: AppViewModelFactory
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let env = AppEnvironment.bootstrap()
        environment = env
        _factory = StateObject(wrappedValue: AppViewModelFactory(
            interactors: env.diContainer.interactors,
            appState: env.diContainer.appState
        ))
    }

    var body: some Scene {
        WindowGroup {
            CleanArchitectureMainView()
                .modelContainer(environment.modelContainer)
                .injectFactory(factory)
                .inject(environment.diContainer)
        }
        // Cập nhật AppState.system.isActive mỗi khi scenePhase thay đổi
        .onChange(of: scenePhase) { _, newPhase in
            environment.diContainer.appState[\.system.isActive] = (newPhase == .active)
        }
    }
}
