import XCTest

final class LoginDemoUITests: XCTestCase {
    private var app: XCUIApplication!
    private var loginScreen: LoginScreen!
    private var homeScreen: HomeScreen!
    
    override func setUpWithError() throws {
        continueAfterFailure = false  // Fail fast
        
        app = XCUIApplication()
        app.launchArguments = [
            "-UITestResetState",
            "-UITestDisableAnimations"
        ]
        app.launch()
        
        loginScreen = LoginScreen(app: app)
        homeScreen = HomeScreen(app: app)
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Test cases
    
    /// TC1: Login button disable khi chưa nhập đủ field
    func test_loginButton_isDisabled_whenFieldsEmpty() {
        loginScreen.waitUntilLoaded()
        XCTAssertFalse(loginScreen.loginButton.isEnabled)
        
        loginScreen.enterUsername("admin")
        XCTAssertFalse(loginScreen.loginButton.isEnabled)
        
        loginScreen.enterPassword("123456")
        XCTAssertTrue(loginScreen.loginButton.isEnabled)
    }
    
    /// TC2: Sai password → hiện error
    func test_login_withWrongCredentials_showsError() {
        loginScreen
            .waitUntilLoaded()
            .login(username: "admin", password: "wrong")
        
        loginScreen.errorLabel.waitAndAssert()
        XCTAssertEqual(loginScreen.errorLabel.label, "Sai username hoặc password")
        XCTAssertFalse(homeScreen.welcomeLabel.exists)
    }
    
    /// TC3: Login đúng → chuyển Home
    func test_login_withValidCredentials_navigatesToHome() {
        loginScreen
            .waitUntilLoaded()
            .login(username: "admin", password: "123456")
        
        homeScreen.waitUntilLoaded()
        homeScreen.assertUsername("admin")
    }
    
    /// TC4: Remember Me ON → lần sau mở app, field tự fill
    func test_rememberMe_persistsCredentialsAcrossLaunches() {
        // Launch 1: login với remember
        loginScreen
            .waitUntilLoaded()
            .login(username: "admin", password: "123456", remember: true)
        homeScreen.waitUntilLoaded()
        
        // Relaunch WITHOUT reset state
        app.terminate()
        app.launchArguments = ["-UITestDisableAnimations"]  // bỏ reset
        app.launch()
        
        loginScreen.waitUntilLoaded()
        
        let retrievedUser = loginScreen.usernameField.value as? String
        XCTAssertTrue(retrievedUser == "admin", "Expected 'admin', but got '\(String(describing: retrievedUser))'. This could mean data was not saved correctly to UserDefaults.")
        
        let valueStr = String(describing: loginScreen.rememberMeToggle.value)
        let isOn = valueStr.contains("1") || valueStr.lowercased().contains("true")
        XCTAssertTrue(isOn, "Toggle should be ON")
    }
    
    /// TC5: Remember Me OFF → relaunch field rỗng
    func test_rememberMe_off_doesNotPersist() {
        loginScreen
            .waitUntilLoaded()
            .login(username: "admin", password: "123456", remember: false)
        homeScreen.waitUntilLoaded()
        
        app.terminate()
        app.launchArguments = ["-UITestDisableAnimations"]
        app.launch()
        
        loginScreen.waitUntilLoaded()
        // SwiftUI placeholder không nằm trong value khi field rỗng
        let value = loginScreen.usernameField.value as? String ?? ""
        XCTAssertTrue(value.isEmpty || value == "Username")
    }
    
    /// TC6: Loading indicator hiển thị khi đang login
    func test_loading_isShown_duringLogin() {
        loginScreen
            .waitUntilLoaded()
            .enterUsername("admin")
            .enterPassword("123456")
            .tapLogin()
        
        // Login simulate 2.0s → bắt được loading
        let loading = app.activityIndicators["login.loading.indicator"]
        XCTAssertTrue(loading.waitForExistence(timeout: 2.0))
    }
}
