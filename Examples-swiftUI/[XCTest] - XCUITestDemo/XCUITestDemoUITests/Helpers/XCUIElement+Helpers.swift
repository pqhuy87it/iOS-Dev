import XCTest

extension XCUIElement {
    /// Wait + return self để chain
    @discardableResult
    func waitAndAssert(timeout: TimeInterval = 5,
                       file: StaticString = #file,
                       line: UInt = #line) -> XCUIElement {
        let exists = waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Element \(self) không xuất hiện sau \(timeout)s",
                      file: file, line: line)
        return self
    }
    
    /// Clear text rồi gõ mới (TextField giữ giá trị cũ là pitfall thường gặp)
    func clearAndType(_ text: String) {
        guard let stringValue = self.value as? String, !stringValue.isEmpty else {
            self.tap()
            self.typeText(text)
            return
        }
        
        // SwiftUI TextField often returns placeholder text in `value` when empty
        if stringValue == self.placeholderValue || stringValue == "Username" || stringValue == "Password" {
            self.tap()
            self.typeText(text)
            return
        }
        
        self.tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
        self.typeText(text)
    }
}
