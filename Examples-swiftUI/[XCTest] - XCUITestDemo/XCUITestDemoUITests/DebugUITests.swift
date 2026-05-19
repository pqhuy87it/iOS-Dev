import XCTest

final class DebugUITests: XCTestCase {
    func testToggleBehavior() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestDisableAnimations"]
        app.launch()
        
        let toggle = app.switches["login.rememberMe.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Toggle must exist")
        
        print("--- BEFORE TAP: \(String(describing: toggle.value))")
        
        // Tap on toggle
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        
        // Wait a bit
        Thread.sleep(forTimeInterval: 1.0)
        
        print("--- AFTER TAP: \(String(describing: toggle.value))")
    }
}
