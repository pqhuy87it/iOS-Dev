# UI Testing (XCUITest) — Chi tiết cho Senior iOS Developer

UI Testing là lớp test cao nhất trong Testing Pyramid — mô phỏng chính xác cách user tương tác với app: tap, swipe, type, scroll... XCUITest chạy một **process riêng biệt** với app, communicate qua accessibility framework. Điều này có nghĩa test thực sự "nhìn" app như user nhìn.

---

## 1. XCUITest Foundation — Hiểu sâu cơ chế

### Architecture

```
┌─────────────────┐     Accessibility      ┌─────────────────┐
│   Test Runner    │ ◄──── Framework ─────► │   App Process   │
│   (XCUITest)     │     (IPC Bridge)       │   (Your App)    │
└─────────────────┘                         └─────────────────┘
     Process A                                   Process B
```

Test và app chạy ở **2 process khác nhau**. Test không access được code, variable, hay memory của app. Mọi interaction đều đi qua accessibility layer. Đây là điều fundamental mà senior cần hiểu — nó giải thích tại sao UI test chậm và tại sao accessibility identifiers quan trọng.

### Core API

```swift
// XCUIApplication — đại diện cho app
let app = XCUIApplication()
app.launch()

// XCUIElement — mọi thứ trên screen
let loginButton = app.buttons["loginButton"]
let emailField = app.textFields["emailTextField"]
let errorLabel = app.staticTexts["errorLabel"]

// XCUIElementQuery — tìm elements
let allCells = app.cells              // Tất cả cells
let firstCell = app.cells.firstMatch  // Cell đầu tiên
let cellCount = app.cells.count       // Đếm cells
```

### Interactions cơ bản

```swift
// Tap
loginButton.tap()

// Type text
emailField.tap()
emailField.typeText("huy@example.com")

// Clear và type lại
emailField.tap()
emailField.press(forDuration: 1.2)  // Long press để select all
app.menuItems["Select All"].tap()
emailField.typeText("new@example.com")

// Swipe
app.swipeUp()
app.swipeLeft()

// Scroll đến element
let targetCell = app.cells["item_50"]
targetCell.scrollToElement()  // Custom extension (sẽ nói bên dưới)

// Adjust slider, picker
app.sliders["volumeSlider"].adjust(toNormalizedSliderPosition: 0.7)
app.pickerWheels.element.adjust(toPickerWheelValue: "March")
```

### Assertions

```swift
// Existence
XCTAssertTrue(loginButton.exists)
XCTAssertFalse(errorLabel.exists)

// Properties
XCTAssertEqual(errorLabel.label, "Invalid email format")
XCTAssertTrue(loginButton.isEnabled)
XCTAssertTrue(profileImage.isHittable)  // Visible và tappable

// Waiting — CỰC KỲ QUAN TRỌNG cho UI test
let predicate = NSPredicate(format: "exists == true")
expectation(for: predicate, evaluatedWith: successBanner, handler: nil)
waitForExpectations(timeout: 5)

// Hoặc gọn hơn (iOS 16.4+):
XCTAssertTrue(successBanner.waitForExistence(timeout: 5))
```

---

## 2. Accessibility Identifiers — Nền tảng của UI Test

### Tại sao không dùng text trực tiếp?

```swift
// ❌ BRITTLE — text thay đổi khi localize hoặc redesign
app.buttons["Login"].tap()
app.staticTexts["Welcome back, Huy!"].tap()

// ✅ STABLE — identifier không thay đổi theo ngôn ngữ hay UI
app.buttons["loginButton"].tap()
app.staticTexts["welcomeMessage"].tap()
```

### Đặt identifier trong code

```swift
// UIKit
loginButton.accessibilityIdentifier = "loginButton"
emailTextField.accessibilityIdentifier = "emailTextField"

// SwiftUI
Button("Login") { viewModel.login() }
    .accessibilityIdentifier("loginButton")

TextField("Email", text: $email)
    .accessibilityIdentifier("emailTextField")
```

### Chiến lược đặt tên — Senior level

Senior dev cần thiết lập **naming convention** cho cả team:

```swift
// Pattern: screen_componentType_purpose
enum AccessibilityID {
    enum Login {
        static let emailField = "login_textField_email"
        static let passwordField = "login_textField_password"
        static let submitButton = "login_button_submit"
        static let errorLabel = "login_label_error"
        static let forgotPasswordLink = "login_button_forgotPassword"
    }
    
    enum Home {
        static let feedTable = "home_table_feed"
        static let profileAvatar = "home_image_avatar"
        static let notificationBadge = "home_label_notificationCount"
        
        // Dynamic identifiers cho list items
        static func feedCell(index: Int) -> String {
            "home_cell_feed_\(index)"
        }
        
        static func feedCell(id: String) -> String {
            "home_cell_feed_\(id)"
        }
    }
    
    enum Cart {
        static let checkoutButton = "cart_button_checkout"
        static let totalLabel = "cart_label_total"
        static let emptyState = "cart_view_emptyState"
        
        static func itemCell(productId: String) -> String {
            "cart_cell_item_\(productId)"
        }
        
        static func removeButton(productId: String) -> String {
            "cart_button_remove_\(productId)"
        }
    }
}

// Sử dụng trong production code
checkoutButton.accessibilityIdentifier = AccessibilityID.Cart.checkoutButton

// Sử dụng trong test
app.buttons[AccessibilityID.Cart.checkoutButton].tap()
```

Cách này đảm bảo production code và test code dùng cùng source of truth, tránh typo và desync.

---

## 3. Page Object Pattern — Core Architecture cho UI Test

### Vấn đề khi KHÔNG dùng Page Object

```swift
// ❌ Test dài, lặp lại, brittle — thay đổi 1 element ảnh hưởng 50 tests
func test_loginSuccess() {
    let app = XCUIApplication()
    app.launch()
    app.textFields["login_textField_email"].tap()
    app.textFields["login_textField_email"].typeText("huy@test.com")
    app.secureTextFields["login_textField_password"].tap()
    app.secureTextFields["login_textField_password"].typeText("password123")
    app.buttons["login_button_submit"].tap()
    XCTAssertTrue(app.staticTexts["home_label_welcome"].waitForExistence(timeout: 5))
}

func test_loginFailure() {
    let app = XCUIApplication()
    app.launch()
    app.textFields["login_textField_email"].tap()
    app.textFields["login_textField_email"].typeText("wrong@test.com")
    app.secureTextFields["login_textField_password"].tap()
    app.secureTextFields["login_textField_password"].typeText("wrong")
    app.buttons["login_button_submit"].tap()
    XCTAssertTrue(app.staticTexts["login_label_error"].waitForExistence(timeout: 5))
}
// Nếu designer đổi emailField thành dropdown -> sửa TẤT CẢ tests
```

### Page Object Pattern — Giải pháp

Mỗi screen được đại diện bởi một **Page Object** chứa toàn bộ elements và actions. Test chỉ gọi high-level methods.

```swift
// MARK: - Base Page
protocol Page {
    var app: XCUIApplication { get }
}

extension Page {
    // Helper chờ element xuất hiện
    @discardableResult
    func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> XCUIElement {
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Element \(element.identifier) not found within \(timeout)s"
        )
        return element
    }
    
    // Verify đang ở đúng screen
    func assertIsDisplayed(
        identifier: String, 
        timeout: TimeInterval = 5
    ) {
        let marker = app.otherElements[identifier]
        XCTAssertTrue(
            marker.waitForExistence(timeout: timeout),
            "Screen with marker \(identifier) not displayed"
        )
    }
}
```

```swift
// MARK: - Login Page
class LoginPage: Page {
    let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    // MARK: Elements (private — test không cần biết chi tiết UI)
    private var emailField: XCUIElement {
        app.textFields["login_textField_email"]
    }
    
    private var passwordField: XCUIElement {
        app.secureTextFields["login_textField_password"]
    }
    
    private var submitButton: XCUIElement {
        app.buttons["login_button_submit"]
    }
    
    private var errorLabel: XCUIElement {
        app.staticTexts["login_label_error"]
    }
    
    private var forgotPasswordButton: XCUIElement {
        app.buttons["login_button_forgotPassword"]
    }
    
    // MARK: Actions (return Page tiếp theo — fluent interface)
    
    @discardableResult
    func typeEmail(_ email: String) -> LoginPage {
        waitForElement(emailField).tap()
        emailField.typeText(email)
        return self
    }
    
    @discardableResult
    func typePassword(_ password: String) -> LoginPage {
        waitForElement(passwordField).tap()
        passwordField.typeText(password)
        return self
    }
    
    func tapLogin() -> HomePage {
        submitButton.tap()
        return HomePage(app: app)
    }
    
    func tapLoginExpectingError() -> LoginPage {
        submitButton.tap()
        return self
    }
    
    func tapForgotPassword() -> ForgotPasswordPage {
        forgotPasswordButton.tap()
        return ForgotPasswordPage(app: app)
    }
    
    // MARK: Assertions
    
    @discardableResult
    func assertErrorMessage(_ expectedText: String) -> LoginPage {
        waitForElement(errorLabel)
        XCTAssertEqual(errorLabel.label, expectedText)
        return self
    }
    
    @discardableResult
    func assertSubmitButtonDisabled() -> LoginPage {
        XCTAssertFalse(submitButton.isEnabled)
        return self
    }
    
    @discardableResult
    func assertOnLoginScreen() -> LoginPage {
        waitForElement(emailField)
        waitForElement(passwordField)
        return self
    }
}
```

```swift
// MARK: - Home Page
class HomePage: Page {
    let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    private var welcomeLabel: XCUIElement {
        app.staticTexts["home_label_welcome"]
    }
    
    private var feedTable: XCUIElement {
        app.tables["home_table_feed"]
    }
    
    private var profileTab: XCUIElement {
        app.tabBars.buttons["Profile"]
    }
    
    @discardableResult
    func assertWelcomeMessage(contains text: String) -> HomePage {
        waitForElement(welcomeLabel)
        XCTAssertTrue(welcomeLabel.label.contains(text))
        return self
    }
    
    @discardableResult
    func assertFeedLoaded(minimumCells: Int = 1) -> HomePage {
        waitForElement(feedTable)
        XCTAssertGreaterThanOrEqual(app.cells.count, minimumCells)
        return self
    }
    
    func goToProfile() -> ProfilePage {
        profileTab.tap()
        return ProfilePage(app: app)
    }
}
```

### Test sau khi áp dụng Page Object

```swift
// ✅ CLEAN — đọc như user story
class LoginFlowUITests: XCTestCase {
    var app: XCUIApplication!
    var loginPage: LoginPage!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]  // Flag để app biết đang test
        app.launch()
        loginPage = LoginPage(app: app)
    }
    
    func test_successfulLogin_shouldShowHomeScreen() {
        loginPage
            .typeEmail("huy@test.com")
            .typePassword("validPass123")
            .tapLogin()
            .assertWelcomeMessage(contains: "Huy")
            .assertFeedLoaded()
    }
    
    func test_invalidCredentials_shouldShowError() {
        loginPage
            .typeEmail("wrong@test.com")
            .typePassword("wrongPass")
            .tapLoginExpectingError()
            .assertErrorMessage("Invalid email or password")
    }
    
    func test_emptyFields_shouldDisableSubmit() {
        loginPage
            .assertSubmitButtonDisabled()
    }
    
    func test_forgotPassword_shouldNavigateCorrectly() {
        loginPage
            .tapForgotPassword()
            .assertOnForgotPasswordScreen()
            .typeEmail("huy@test.com")
            .tapSubmit()
            .assertConfirmationShown()
    }
}
```

Khi UI thay đổi (ví dụ email field đổi thành phone number field), bạn chỉ sửa **LoginPage** — tất cả tests tự động cập nhật.

---

## 4. Advanced Patterns

### Launch Arguments & Environment — Kiểm soát app state

Senior dev không để UI test depend vào real backend. Bạn dùng launch arguments để app switch sang mock data:

```swift
// Trong test
override func setUp() {
    app = XCUIApplication()
    app.launchArguments = [
        "--uitesting",
        "--reset-state",             // Clear UserDefaults, Keychain
        "--mock-api",                // Dùng mock server
        "--skip-onboarding"          // Bỏ qua onboarding flow
    ]
    app.launchEnvironment = [
        "MOCK_USER": "premium_user",
        "MOCK_SCENARIO": "full_cart",
        "ANIMATION_SPEED": "0"       // Tắt animation cho test nhanh hơn
    ]
    app.launch()
}

// Trong AppDelegate hoặc App init
#if DEBUG
if CommandLine.arguments.contains("--uitesting") {
    // Disable analytics
    // Setup mock network layer
    // Load fixture data
}

if CommandLine.arguments.contains("--reset-state") {
    UserDefaults.standard.removePersistentDomain(
        forName: Bundle.main.bundleIdentifier!
    )
    try? KeychainManager.clearAll()
}

if ProcessInfo.processInfo.environment["ANIMATION_SPEED"] == "0" {
    UIView.setAnimationsEnabled(false)
}
#endif
```

### Handling System Alerts

iOS hay show system alerts (permissions, notifications...) làm test bị block:

```swift
// Cách 1: addUIInterruptionMonitor
override func setUp() {
    // Auto-accept tất cả system alerts
    addUIInterruptionMonitor(withDescription: "System Alert") { alert in
        let allowButton = alert.buttons["Allow"]
        let okButton = alert.buttons["OK"]
        
        if allowButton.exists {
            allowButton.tap()
            return true
        } else if okButton.exists {
            okButton.tap()
            return true
        }
        return false
    }
}

// Cách 2: Reset permissions trong setUp (Xcode 14.3+)
override func setUp() {
    let app = XCUIApplication()
    app.resetAuthorizationStatus(for: .photos)
    app.resetAuthorizationStatus(for: .camera)
    app.launch()
}
```

### Custom Wait Helpers

Async UI transitions là nguồn chính gây flaky tests. Senior dev xây helper chắc chắn:

```swift
extension XCUIElement {
    /// Chờ element xuất hiện rồi tap
    func waitAndTap(timeout: TimeInterval = 5) {
        guard waitForExistence(timeout: timeout) else {
            XCTFail("Element \(identifier) not found after \(timeout)s")
            return
        }
        tap()
    }
    
    /// Chờ element biến mất (loading spinner, skeleton...)
    func waitForDisappearance(timeout: TimeInterval = 10) {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: self
        )
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, 
            "Element \(identifier) still exists after \(timeout)s")
    }
    
    /// Scroll trong list đến khi tìm thấy element
    func scrollToVisible(
        in scrollableElement: XCUIElement,
        maxScrolls: Int = 10
    ) -> Bool {
        for _ in 0..<maxScrolls {
            if isHittable { return true }
            scrollableElement.swipeUp()
        }
        return isHittable
    }
}

extension XCUIApplication {
    /// Chờ loading xong (spinner biến mất)
    func waitForLoadingToFinish(timeout: TimeInterval = 10) {
        let spinner = activityIndicators["loadingSpinner"]
        if spinner.exists {
            spinner.waitForDisappearance(timeout: timeout)
        }
    }
}
```

### Screen Recording cho Debug

Khi UI test fail trên CI, bạn cần biết chuyện gì xảy ra. Xcode tự capture screenshot khi fail, nhưng senior dev cấu hình thêm:

```swift
override func setUp() {
    continueAfterFailure = false  // Dừng ngay khi fail
    
    // Xcode tự attach screenshot khi fail
    // Nhưng bạn có thể capture thêm tại các điểm quan trọng:
}

func takeScreenshot(name: String) {
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
}

func test_checkoutFlow() {
    loginPage.typeEmail("huy@test.com").typePassword("pass").tapLogin()
    takeScreenshot(name: "01_after_login")
    
    homePage.goToCart()
    takeScreenshot(name: "02_cart_screen")
    
    cartPage.tapCheckout()
    takeScreenshot(name: "03_checkout_screen")
    
    // Nếu test fail, bạn có đầy đủ screenshots để debug
}
```

---

## 5. Test Data & Network Strategy

### Approach 1: Mock Server (Khuyến nghị)

Chạy một local mock server mà app gọi tới khi đang UI test:

```swift
// Dùng thư viện như Embassy, Swifter, hoặc custom URLProtocol

// Trong test setUp
override func setUp() {
    mockServer = MockServer()
    mockServer.setup(route: "/api/user/123") { _ in
        return MockResponse(
            status: 200,
            json: ["name": "Huy", "email": "huy@test.com"]
        )
    }
    mockServer.setup(route: "/api/cart") { _ in
        return MockResponse(
            status: 200,
            json: ["items": [], "total": 0]
        )
    }
    mockServer.start(port: 8080)
    
    app = XCUIApplication()
    app.launchEnvironment["API_BASE_URL"] = "http://localhost:8080"
    app.launch()
}

override func tearDown() {
    mockServer.stop()
}
```

### Approach 2: Bundled Fixture Data

App detect `--uitesting` flag và load JSON fixtures thay vì gọi API:

```swift
// Trong app code
#if DEBUG
class MockNetworkLayer: NetworkLayerProtocol {
    func request(_ endpoint: Endpoint) async throws -> Data {
        let fixtureName = endpoint.fixtureName  // "user_123", "cart_empty"
        guard let url = Bundle.main.url(
            forResource: fixtureName,
            withExtension: "json",
            subdirectory: "Fixtures"
        ) else {
            throw MockError.fixtureNotFound(fixtureName)
        }
        return try Data(contentsOf: url)
    }
}
#endif
```

### Approach 3: Mỗi test scenario có state riêng

```swift
func test_emptyCart_shouldShowEmptyState() {
    app.launchEnvironment["MOCK_SCENARIO"] = "empty_cart"
    app.launch()
    
    CartPage(app: app)
        .assertEmptyStateVisible()
        .assertCheckoutButtonHidden()
}

func test_fullCart_shouldShowItems() {
    app.launchEnvironment["MOCK_SCENARIO"] = "cart_with_3_items"
    app.launch()
    
    CartPage(app: app)
        .assertItemCount(3)
        .assertTotalPrice("$59.97")
        .assertCheckoutButtonEnabled()
}
```

---

## 6. Trade-offs & Chiến lược chọn test — Senior Mindset

### Testing Pyramid trong iOS

```
         ▲
        / \
       / UI \          ← Ít nhất: 5-10 critical flows
      / Tests \           Chậm, brittle, expensive
     /─────────\
    / Integration\     ← Vừa phải: API contracts, DB queries
   /    Tests     \       Module boundaries
  /────────────────\
 /    Unit Tests    \  ← Nhiều nhất: ViewModels, Services, Utils
/____________________\    Nhanh, stable, cheap
```

### UI Test chỉ nên cover Critical User Flows

```swift
// ✅ NÊN test bằng UI test
// - Login / Registration (revenue gate)
// - Checkout / Payment (trực tiếp ảnh hưởng revenue)
// - Onboarding (first impression, retention)
// - Core feature happy path (cái user dùng nhiều nhất)
// - Deep link navigation (dễ break khi refactor)

// ❌ KHÔNG NÊN test bằng UI test
// - Validation logic (unit test ViewModel)
// - Formatting (unit test formatters)
// - Edge cases (unit test)
// - Mọi combination của form inputs (unit test)
// - Styling / layout chi tiết (snapshot test)
```

### Chi phí thực tế

| Metric | Unit Test | UI Test |
|---|---|---|
| Thời gian chạy 1 test | ~0.01s | ~5-30s |
| Setup effort | Thấp | Cao |
| Maintenance cost | Thấp | Cao (UI thay đổi thường xuyên) |
| Flakiness | Gần 0 | 5-15% nếu không cẩn thận |
| Debug khi fail | Dễ (stack trace rõ) | Khó (cần screenshot, recording) |
| Confidence level | Từng unit đúng | Cả flow hoạt động end-to-end |

### Chiến lược chống Flaky Tests

Flaky UI test phá huỷ confidence của cả team vào test suite. Senior dev cần:

**Retry mechanism trong CI** — cho phép test fail 1 lần rồi retry trước khi báo đỏ:

```yaml
# fastlane hoặc CI config
scan(
  scheme: "UITests",
  retry_count: 2,  # Retry mỗi failed test tối đa 2 lần
  result_bundle: true
)
```

**Quarantine flaky tests** — tag test đang flaky, chạy riêng, không block PR:

```swift
func test_notificationFlow() throws {
    // Temporarily flaky do system alert timing
    try XCTSkipIf(
        ProcessInfo.processInfo.environment["CI"] == "true",
        "Skipping flaky test on CI — tracking in JIRA-1234"
    )
    // ... test code
}
```

**Parallel execution** — Xcode hỗ trợ chạy UI test parallel trên nhiều simulator:

```swift
// Trong Test Plan (.xctestplan)
// Enable "Execute in parallel" for UI test target
// Mỗi test class chạy trên 1 simulator riêng

// LƯU Ý: Test classes phải hoàn toàn độc lập
// Không share state giữa classes
// Mỗi test tự launch app với state riêng
```

---

## 7. Kết hợp với CI/CD — Senior Responsibility

```yaml
# Ví dụ GitHub Actions workflow
name: UI Tests

on:
  pull_request:
    branches: [main, develop]

jobs:
  ui-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      
      - name: Run UI Tests
        run: |
          xcodebuild test \
            -workspace App.xcworkspace \
            -scheme "UITests" \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.2' \
            -resultBundlePath TestResults.xcresult \
            -retry-tests-on-failure \
            -test-iterations 2
      
      - name: Upload Test Results
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: TestResults.xcresult
```

Senior dev đảm bảo CI chạy UI test trên mỗi PR cho critical flows, upload screenshots/recordings khi fail, và maintain test suite ở mức tin cậy cao (>95% pass rate). Nếu pass rate xuống dưới ngưỡng, đó là signal cần refactor test hoặc quarantine flaky tests — không bao giờ để team quen với việc ignore test failures.
