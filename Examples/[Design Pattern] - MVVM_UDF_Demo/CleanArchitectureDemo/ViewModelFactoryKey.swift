import SwiftUI

private struct ViewModelFactoryKey: EnvironmentKey {
    // Mặc định trả về Stub để Canvas Preview không bao giờ bị lỗi thiếu Environment
    @MainActor static let defaultValue: any ViewModelFactory = StubViewModelFactory()
}

extension EnvironmentValues {
    var viewModelFactory: any ViewModelFactory {
        get { self[ViewModelFactoryKey.self] }
        set { self[ViewModelFactoryKey.self] = newValue }
    }
}

// Helper extension trên View để tiện inject
extension View {
    func injectFactory(_ factory: any ViewModelFactory) -> some View {
        self.environment(\.viewModelFactory, factory)
    }
}
