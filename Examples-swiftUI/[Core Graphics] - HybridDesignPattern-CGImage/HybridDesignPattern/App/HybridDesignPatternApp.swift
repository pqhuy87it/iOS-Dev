import SwiftData
import SwiftUI

@main struct HybridDesignPatternApp: App {
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
            HybridDesignPatternMainView()
                .modelContainer(environment.modelContainer)
                .injectFactory(factory)
                .inject(environment.diContainer)
        }
        .onChange(of: scenePhase) { _, newPhase in
            environment.diContainer.appState[\.system.isActive] = (newPhase == .active)
        }
    }
}
