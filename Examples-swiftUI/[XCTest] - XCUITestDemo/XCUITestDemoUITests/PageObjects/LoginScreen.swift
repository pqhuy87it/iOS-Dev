import XCTest

struct LoginScreen {
    let app: XCUIApplication
    
    // MARK: - Elements
    var title: XCUIElement { app.staticTexts["login.title"] }
    var usernameField: XCUIElement { app.textFields["login.username.textField"] }
    var passwordField: XCUIElement { app.secureTextFields["login.password.secureField"] }
    var rememberMeToggle: XCUIElement { app.switches["login.rememberMe.toggle"] }
    var loginButton: XCUIElement { app.buttons["login.submit.button"] }
    var errorLabel: XCUIElement { app.staticTexts["login.error.label"] }
    
    // MARK: - Actions
    @discardableResult
    func waitUntilLoaded() -> Self {
        title.waitAndAssert()
        return self
    }
    
    @discardableResult
    func enterUsername(_ value: String) -> Self {
        usernameField.clearAndType(value)
        return self
    }
    
    @discardableResult
    func enterPassword(_ value: String) -> Self {
        passwordField.clearAndType(value)
        // Nhấn Return (Enter) để đóng bàn phím lại, tránh việc bàn phím che mất Toggle/Button
        passwordField.typeText("\n")
        return self
    }
    
    @discardableResult
    func toggleRememberMe(_ on: Bool) -> Self {
        let valueStr = String(describing: rememberMeToggle.value)
        let isOn = valueStr.contains("1") || valueStr.lowercased().contains("true")
        
        print("--- [LoginScreen] Toggle current state isOn: \(isOn) (valueStr: \(valueStr)). We want on: \(on)")
        
        if isOn != on {
            print("--- [LoginScreen] Tapping toggle to turn it \(on)")
            sleep(2)
            rememberMeToggle.tap()
        } else {
            print("--- [LoginScreen] Toggle is already in desired state.")
        }
        
        return self
    }
    
    @discardableResult
    func tapLogin() -> Self {
        loginButton.tap()
        return self
    }
    
    func login(username: String, password: String, remember: Bool = false) {
        enterUsername(username)
        .enterPassword(password)
            
        toggleRememberMe(remember)
    
        tapLogin()
    }
}
