import XCTest

struct HomeScreen {
    let app: XCUIApplication
    
    var welcomeLabel: XCUIElement { app.staticTexts["home.welcome.label"] }
    var usernameLabel: XCUIElement { app.staticTexts["home.username.label"] }
    
    @discardableResult
    func waitUntilLoaded() -> Self {
        welcomeLabel.waitAndAssert(timeout: 5)
        return self
    }
    
    func assertUsername(_ expected: String,
                       file: StaticString = #file,
                       line: UInt = #line) {
        XCTAssertEqual(usernameLabel.label, "Hello, \(expected)",
                       file: file, line: line)
    }
}
