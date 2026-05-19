import SwiftUI

@main
struct XCUITestDemoApp: App {
    init() {
            handleLaunchArguments()
        }
        
        var body: some Scene {
            WindowGroup {
                LoginView()
            }
        }
        
        private func handleLaunchArguments() {
            let args = ProcessInfo.processInfo.arguments
            
            // Reset UserDefaults trước mỗi test → đảm bảo state sạch
            if args.contains("-UITestResetState") {
                if let bundleID = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: bundleID)
                }
            }
            
            // Disable animation cho test chạy nhanh và ổn định
            if args.contains("-UITestDisableAnimations") {
                UIView.setAnimationsEnabled(false)
            }
        }
}
