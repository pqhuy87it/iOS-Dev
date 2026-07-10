import SwiftUI

private struct ViewModelFactoryKey: EnvironmentKey {
    @MainActor static let defaultValue: any ViewModelFactory = StubViewModelFactory()
}

extension EnvironmentValues {
    var viewModelFactory: any ViewModelFactory {
        get { self[ViewModelFactoryKey.self] }
        set { self[ViewModelFactoryKey.self] = newValue }
    }
}

extension View {
    func injectFactory(_ factory: any ViewModelFactory) -> some View {
        self.environment(\.viewModelFactory, factory)
    }
}
