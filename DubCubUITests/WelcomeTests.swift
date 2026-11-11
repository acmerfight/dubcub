import XCTest

@MainActor
final class WelcomeTests: XCTestCase {
    func testGivenInstalledAppWhenOpenedThenWelcomeIsVisible() {
        // Given: 用户已安装 App。
        let app = XCUIApplication()

        // When: 用户打开 App。
        app.launch()

        // Then: 用户看到应用名称、欢迎信息与当前功能说明。
        XCTAssertTrue(app.staticTexts["DubCub"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["欢迎来到你的配音工作台"].exists)
        XCTAssertTrue(app.staticTexts["这是用于验证 iPhone 和 iPad 安装的起始页面，配音功能将在后续加入。"].exists)
    }
}
